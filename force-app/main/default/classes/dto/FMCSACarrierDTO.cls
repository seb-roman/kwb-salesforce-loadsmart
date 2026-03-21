/**
 * DTO for FMCSA Carrier Response
 * 
 * Handles deserialization from:
 * GET https://mobile.fmcsa.dot.gov/qc/api/v1/carriers/{identifier}
 * 
 * Provides type-safe access to carrier data for creating/updating Carrier__c records
 */
public class FMCSACarrierDTO {
    
    @AuraEnabled
    public FMCSACarrierDataDTO carrier { get; set; }
    
    @AuraEnabled
    public FMCSASafetyDataDTO safety { get; set; }
    
    /**
     * Nested DTO: Carrier core data
     */
    public class FMCSACarrierDataDTO {
        @AuraEnabled
        public String legal_name { get; set; }
        
        @AuraEnabled
        public String mc_mx_ff_number { get; set; }  // MC Number
        
        @AuraEnabled
        public String usdot_number { get; set; }    // DOT Number
        
        @AuraEnabled
        public String phone_number { get; set; }
        
        @AuraEnabled
        public String dba_operation_status_code { get; set; }  // DOT Status
        
        @AuraEnabled
        public FMCSAAddressDTO principal_address { get; set; }
    }
    
    /**
     * Nested DTO: Address information
     */
    public class FMCSAAddressDTO {
        @AuraEnabled
        public String street { get; set; }
        
        @AuraEnabled
        public String city { get; set; }
        
        @AuraEnabled
        public String state { get; set; }
        
        @AuraEnabled
        public String zip { get; set; }
    }
    
    /**
     * Nested DTO: Safety data (insurance status, etc.)
     */
    public class FMCSASafetyDataDTO {
        @AuraEnabled
        public String safety_status { get; set; }
        
        @AuraEnabled
        public String safety_rating { get; set; }
    }
    
    /**
     * Deserialize from JSON response
     */
    public static FMCSACarrierDTO parse(String jsonBody) {
        return (FMCSACarrierDTO) JSON.deserialize(jsonBody, FMCSACarrierDTO.class);
    }
    
    /**
     * Helper: Extract carrier data only (commonly used)
     */
    public FMCSACarrierDataDTO getCarrierData() {
        return carrier;
    }
    
    /**
     * Helper: Get address
     */
    public FMCSAAddressDTO getAddress() {
        return (carrier != null) ? carrier.principal_address : null;
    }
}
