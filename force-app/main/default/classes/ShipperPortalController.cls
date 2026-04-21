/**
 * ShipperPortalController
 * 
 * Manages shipper portal operations: load list, detail view, search, filtering
 * 
 * @author Agent 5 (Portal & Mobile)
 * @version 1.0
 * @date April 2, 2026
 */
public with sharing class ShipperPortalController {
    
    /**
     * LoadListItem
     * 
     * Data transfer object for load list
     */
    public class LoadListItem {
        @AuraEnabled public String id;
        @AuraEnabled public String loadNumber;
        @AuraEnabled public String origin;
        @AuraEnabled public String destination;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal ratePerMile;
        @AuraEnabled public String assignedCarrier;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
    }
    
    /**
     * LoadDetail
     * 
     * Complete load details with all associated data
     */
    public class LoadDetail {
        @AuraEnabled public String id;
        @AuraEnabled public String loadNumber;
        @AuraEnabled public String referenceNumber;
        @AuraEnabled public Decimal shipper_rate;
        @AuraEnabled public String origin;
        @AuraEnabled public String destination;
        @AuraEnabled public DateTime pickupWindow;
        @AuraEnabled public DateTime deliveryWindow;
        @AuraEnabled public String status;
        @AuraEnabled public String assignedCarrier;
        @AuraEnabled public String carrierContactName;
        @AuraEnabled public String carrierPhone;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public String currentAddress;
        @AuraEnabled public DateTime lastUpdateTime;
    }
    
    /**
     * getLoadList
     * 
     * Retrieves paginated list of loads for shipper
     * Row-level security: Only shipper's own loads returned
     * 
     * @param pageNumber - Page number (1-indexed)
     * @param pageSize - Records per page (default 20, max 100)
     * @return List of LoadListItem for current shipper
     */
    @AuraEnabled(cacheable=true)
    public static List<LoadListItem> getLoadList(Integer pageNumber, Integer pageSize) {
        try {
            // Input validation
            if (pageNumber == null || pageNumber < 1) pageNumber = 1;
            if (pageSize == null || pageSize < 1) pageSize = 20;
            if (pageSize > 100) pageSize = 100;
            
            // CRUD check
            if (!Load__c.sObjectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('You do not have permission to view loads.');
            }
            
            // Get current shipper account
            String shipperAccountId = getCurrentShipperAccountId();
            
            // Calculate offset
            Integer offset = (pageNumber - 1) * pageSize;
            
            // Query loads for this shipper (RLS enforced)
            List<Load__c> loads = [
                SELECT Id, Load_Number__c, Shipper_City__c, Receiver_City__c, 
                       Status__c, Billing_Rate__c, Carrier__r.Name,
                       Current_Location__Latitude__s, Current_Location__Longitude__s
                FROM Load__c
                WHERE Shipper__c = :shipperAccountId
                ORDER BY CreatedDate DESC
                LIMIT :pageSize
                OFFSET :offset
            ];
            
            List<LoadListItem> items = new List<LoadListItem>();
            for (Load__c load : loads) {
                LoadListItem item = new LoadListItem();
                item.id = load.Id;
                item.loadNumber = load.Load_Number__c;
                item.origin = load.Shipper_City__c;
                item.destination = load.Receiver_City__c;
                item.status = load.Status__c;
                item.ratePerMile = load.Billing_Rate__c;
                item.assignedCarrier = load.Carrier__r != null ? load.Carrier__r.Name : 'Unassigned';
                item.latitude = load.Current_Location__Latitude__s;
                item.longitude = load.Current_Location__Longitude__s;
                items.add(item);
            }
            
            return items;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving loads: ' + e.getMessage());
        }
    }
    
    /**
     * getLoadDetail
     * 
     * Retrieves complete load details by ID
     * Row-level security: Shipper can only view own loads
     * 
     * @param loadId - Load record ID
     * @return LoadDetail object
     */
    @AuraEnabled(cacheable=true)
    public static LoadDetail getLoadDetail(String loadId) {
        try {
            // Input validation
            if (String.isBlank(loadId)) {
                throw new AuraHandledException('Load ID is required.');
            }
            
            // CRUD check
            if (!Load__c.sObjectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('You do not have permission to view loads.');
            }
            
            // Get current shipper
            String shipperAccountId = getCurrentShipperAccountId();
            
            // Query single load (RLS: must belong to this shipper)
            List<Load__c> loads = [
                SELECT Id, Load_Number__c, Customer_Reference_Number__c, Billing_Rate__c,
                       Shipper_City__c, Receiver_City__c, Status__c,
                       Pickup_Window_Begin__c, Pickup_Window_End__c,
                       Delivery_Window_Begin__c, Delivery_Window_End__c,
                       Carrier__r.Name, Carrier__r.Phone,
                       Current_Location__Latitude__s, Current_Location__Longitude__s,
                       Current_Address__c, Last_Status_Update__c
                FROM Load__c
                WHERE Id = :loadId AND Shipper__c = :shipperAccountId
            ];
            
            if (loads.isEmpty()) {
                throw new AuraHandledException('Load not found or you do not have access to it.');
            }
            
            Load__c load = loads[0];
            
            LoadDetail detail = new LoadDetail();
            detail.id = load.Id;
            detail.loadNumber = load.Load_Number__c;
            detail.referenceNumber = load.Customer_Reference_Number__c;
            detail.shipper_rate = load.Billing_Rate__c;
            detail.origin = load.Shipper_City__c;
            detail.destination = load.Receiver_City__c;
            detail.status = load.Status__c;
            detail.assignedCarrier = load.Carrier__r != null ? load.Carrier__r.Name : 'Unassigned';
            detail.carrierContactName = null;
            detail.carrierPhone = load.Carrier__r?.Phone;
            detail.latitude = load.Current_Location__Latitude__s;
            detail.longitude = load.Current_Location__Longitude__s;
            detail.currentAddress = load.Current_Address__c;
            detail.lastUpdateTime = load.Last_Status_Update__c;
            
            return detail;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving load details: ' + e.getMessage());
        }
    }
    
    /**
     * searchLoads
     * 
     * Searches shipper's loads by load number, reference, or city
     * Uses LIKE with parameterized queries (SOQL injection safe)
     * 
     * @param searchTerm - Search term (minimum 2 characters)
     * @return List of matching LoadListItem
     */
    @AuraEnabled(cacheable=true)
    public static List<LoadListItem> searchLoads(String searchTerm) {
        try {
            // Input validation
            if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
                throw new AuraHandledException('Search term must be at least 2 characters.');
            }
            
            if (!Load__c.sObjectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('You do not have permission to view loads.');
            }
            
            String shipperAccountId = getCurrentShipperAccountId();
            String searchPattern = '%' + searchTerm + '%';
            
            // Search across multiple fields
            List<Load__c> loads = [
                SELECT Id, Load_Number__c, Shipper_City__c, Receiver_City__c,
                       Status__c, Billing_Rate__c, Carrier__r.Name,
                       Current_Location__Latitude__s, Current_Location__Longitude__s
                FROM Load__c
                WHERE Shipper__c = :shipperAccountId
                AND (Load_Number__c LIKE :searchPattern
                     OR Customer_Reference_Number__c LIKE :searchPattern
                     OR Shipper_City__c LIKE :searchPattern
                     OR Receiver_City__c LIKE :searchPattern)
                LIMIT 50
            ];
            
            List<LoadListItem> items = new List<LoadListItem>();
            for (Load__c load : loads) {
                LoadListItem item = new LoadListItem();
                item.id = load.Id;
                item.loadNumber = load.Load_Number__c;
                item.origin = load.Shipper_City__c;
                item.destination = load.Receiver_City__c;
                item.status = load.Status__c;
                item.ratePerMile = load.Billing_Rate__c;
                item.assignedCarrier = load.Carrier__r != null ? load.Carrier__r.Name : 'Unassigned';
                item.latitude = load.Current_Location__Latitude__s;
                item.longitude = load.Current_Location__Longitude__s;
                items.add(item);
            }
            
            return items;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error searching loads: ' + e.getMessage());
        }
    }
    
    /**
     * getLoadStatuses
     * 
     * Returns available status picklist values
     * 
     * @return List of status values
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getLoadStatuses() {
        try {
            List<String> statuses = new List<String>();
            Schema.DescribeFieldResult statusField = Load__c.Status__c.getDescribe();
            List<Schema.PicklistEntry> picklistValues = statusField.getPicklistValues();
            
            for (Schema.PicklistEntry entry : picklistValues) {
                statuses.add(entry.getValue());
            }
            
            return statuses;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving statuses: ' + e.getMessage());
        }
    }
    
    /**
     * getCurrentShipperAccountId
     * 
     * Gets current user's shipper account ID
     * Uses User → Contact → Account relationship
     * 
     * @return Account ID
     */
    private static String getCurrentShipperAccountId() {
        // Get current user
        User currentUser = [SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        
        if (currentUser.ContactId == null) {
            throw new AuraHandledException('User contact not found.');
        }
        
        // Get contact's account
        Contact contact = [SELECT AccountId FROM Contact WHERE Id = :currentUser.ContactId LIMIT 1];
        
        if (contact.AccountId == null) {
            throw new AuraHandledException('User account not found.');
        }
        
        return contact.AccountId;
    }
}
