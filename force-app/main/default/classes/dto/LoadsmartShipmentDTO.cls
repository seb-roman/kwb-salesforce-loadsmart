/**
 * DTO for Loadsmart Shipment Object
 * 
 * Handles deserialization from:
 * GET /shipments/ endpoint response
 * 
 * Provides type-safe access to shipment data for mapping to Load__c
 */
public class LoadsmartShipmentDTO {
    
    @AuraEnabled
    public String id { get; set; }
    
    @AuraEnabled
    public String shipment_reference { get; set; }
    
    @AuraEnabled
    public String status { get; set; }
    
    @AuraEnabled
    public LoadsmartRateDTO rate { get; set; }
    
    @AuraEnabled
    public List<LoadsmartStopDTO> stops { get; set; }
    
    @AuraEnabled
    public String equipment_type { get; set; }
    
    @AuraEnabled
    public LoadsmartWeightDTO weight { get; set; }
    
    @AuraEnabled
    public String commodity { get; set; }
    
    @AuraEnabled
    public String updated_at { get; set; }
    
    @AuraEnabled
    public String created_at { get; set; }
    
    /**
     * Nested DTO: Rate information
     */
    public class LoadsmartRateDTO {
        @AuraEnabled
        public Decimal amount { get; set; }
        
        @AuraEnabled
        public String currencyCode { get; set; } // renamed from currency (reserved word)
    }
    
    /**
     * Nested DTO: Stop (pickup/delivery location)
     */
    public class LoadsmartStopDTO {
        @AuraEnabled
        public String type { get; set; }  // 'pickup' or 'delivery'
        
        @AuraEnabled
        public String location_name { get; set; }
        
        @AuraEnabled
        public String address { get; set; }
        
        @AuraEnabled
        public String city { get; set; }
        
        @AuraEnabled
        public String state { get; set; }
        
        @AuraEnabled
        public String zipcode { get; set; }
        
        @AuraEnabled
        public String planned_date { get; set; }  // ISO date format
        
        @AuraEnabled
        public String latitude { get; set; }
        
        @AuraEnabled
        public String longitude { get; set; }
    }
    
    /**
     * Nested DTO: Weight information
     */
    public class LoadsmartWeightDTO {
        @AuraEnabled
        public Decimal value { get; set; }
        
        @AuraEnabled
        public String unit { get; set; }  // 'lbs', 'kg', etc.
    }
    
    /**
     * Deserialize from JSON response
     */
    public static LoadsmartShipmentDTO parse(String jsonBody) {
        return (LoadsmartShipmentDTO) JSON.deserialize(jsonBody, LoadsmartShipmentDTO.class);
    }
    
    /**
     * Deserialize list of shipments from shipments array
     */
    public static List<LoadsmartShipmentDTO> parseList(List<Object> shipmentsArray) {
        List<LoadsmartShipmentDTO> shipments = new List<LoadsmartShipmentDTO>();
        for (Object shipmentObj : shipmentsArray) {
            String json = JSON.serialize(shipmentObj);
            shipments.add(parse(json));
        }
        return shipments;
    }
}
