/**
 * FMCSA Carrier Lookup
 * 
 * Integrates with FMCSA (Federal Motor Carrier Safety Administration) API to:
 * - Search carriers by MC Number or USDOT Number
 * - Validate carrier status and insurance
 * - Auto-populate carrier records with verified data
 * 
 * FMCSA API: https://mobile.fmcsa.dot.gov/qc/api/v1/carriers/{identifier}
 * - Identifier can be: MC_NUMBER, DOT_NUMBER, DUNS_NUMBER, LEGAL_NAME
 * 
 * Usage:
 *   FMCSACarrierLookup lookup = new FMCSACarrierLookup();
 *   FMCSACarrierLookup.CarrierData data = lookup.searchByMCNumber('1776323');
 */

public with sharing class FMCSACarrierLookup {
    private static final String FMCSA_API_BASE = 'https://mobile.fmcsa.dot.gov/qc/api/v1/carriers/';
    private static final Integer TIMEOUT_MS = 10000;
    
    /**
     * Carrier data structure from FMCSA
     * 
     * Simple wrapper around FMCSACarrierDTO for backwards compatibility
     * Provides mapped fields for easy sObject assignment
     */
    public class CarrierData {
        public String mcNumber;
        public String usdotNumber;
        public String legalName;
        public String address;
        public String city;
        public String state;
        public String zip;
        public String phoneNumber;
        public String dotStatus;           // "ACTIVE", "INACTIVE", "OUT_OF_SERVICE"
        public String insuranceStatus;     // "VALID", "EXPIRED", "PENDING", "NO_RECORD"
        public Boolean verified;
        public String rawResponse;
        
        /**
         * Factory method: Create CarrierData from FMCSACarrierDTO
         */
        public CarrierData fromDTO(FMCSACarrierDTO dto) {
            CarrierData data = new CarrierData();
            
            if (dto.carrier != null) {
                data.legalName = dto.carrier.legal_name;
                data.mcNumber = dto.carrier.mc_mx_ff_number;
                data.usdotNumber = dto.carrier.usdot_number;
                data.phoneNumber = dto.carrier.phone_number;
                data.dotStatus = dto.carrier.dba_operation_status_code;
                
                if (dto.carrier.principal_address != null) {
                    data.address = dto.carrier.principal_address.street;
                    data.city = dto.carrier.principal_address.city;
                    data.state = dto.carrier.principal_address.state;
                    data.zip = dto.carrier.principal_address.zip;
                }
            }
            
            // Insurance status from safety data
            if (dto.safety != null) {
                data.insuranceStatus = mapSafetyStatus(dto.safety.safety_status);
            }
            
            data.verified = true;
            return data;
        }
    }
    
    /**
     * Search carrier by MC Number
     */
    public CarrierData searchByMCNumber(String mcNumber) {
        return searchCarrier('MC_NUMBER', mcNumber);
    }
    
    /**
     * Search carrier by USDOT Number
     */
    public CarrierData searchByUSDOTNumber(String usdotNumber) {
        return searchCarrier('DOT_NUMBER', usdotNumber);
    }
    
    /**
     * Generic carrier search
     */
    private CarrierData searchCarrier(String searchType, String searchValue) {
        CarrierData result = new CarrierData();
        result.verified = false;
        
        if (String.isBlank(searchValue)) {
            return result;
        }
        
        try {
            String endpoint = FMCSA_API_BASE + searchType + '/' + EncodingUtil.urlEncode(searchValue, 'UTF-8');
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setTimeout(TIMEOUT_MS);
            req.setHeader('User-Agent', 'KWB-Logistics-Salesforce');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                FMCSACarrierDTO dto = FMCSACarrierDTO.parse(res.getBody());
                result = new CarrierData().fromDTO(dto);
                result.rawResponse = res.getBody();
            } else if (res.getStatusCode() == 404) {
                // Carrier not found
                result.verified = false;
            } else {
                System.debug('FMCSA API Error: ' + res.getStatusCode() + ' ' + res.getStatus());
                result.verified = false;
            }
        } catch (Exception e) {
            System.debug('FMCSA Lookup Exception: ' + e.getMessage() + ' ' + e.getStackTraceString());
        }
        
        return result;
    }
    

    
    /**
     * Map FMCSA safety status codes to readable insurance status
     */
    private static String mapSafetyStatus(String status) {
        if (String.isBlank(status)) {
            return 'Unknown';
        }
        
        status = status.toUpperCase();
        if (status.contains('ACTIVE')) {
            return 'Valid';
        } else if (status.contains('INACTIVE')) {
            return 'Expired';
        } else if (status.contains('PENDING')) {
            return 'Pending';
        }
        return 'Pending';
    }
    
    // @isTest removed - test methods must be in @isTest classes only
    // See FMCSACarrierLookupTest.cls for tests
}
