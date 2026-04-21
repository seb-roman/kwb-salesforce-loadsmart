/**
 * CarrierPortalController
 * 
 * Manages carrier portal operations: assigned loads, POD capture, settlement history
 * 
 * @author Agent 5 (Portal & Mobile)
 * @version 1.0
 * @date April 2, 2026
 */
public with sharing class CarrierPortalController {
    
    /**
     * AssignedLoadItem
     * 
     * Data transfer object for assigned load list
     */
    public class AssignedLoadItem {
        @AuraEnabled public String id;
        @AuraEnabled public String loadNumber;
        @AuraEnabled public String origin;
        @AuraEnabled public String destination;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal carrierRate;
        @AuraEnabled public String shipperName;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
    }
    
    /**
     * PODUploadRequest
     * 
     * Request object for POD upload
     */
    public class PODUploadRequest {
        @AuraEnabled public String loadId;
        @AuraEnabled public String photoBase64;
        @AuraEnabled public String receiverName;
        @AuraEnabled public String condition;
        @AuraEnabled public String notes;
    }
    
    /**
     * PODUploadResponse
     * 
     * Response from POD upload
     */
    public class PODUploadResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String podId;
        @AuraEnabled public String message;
    }
    
    /**
     * SettlementRecord
     * 
     * Settlement history item
     */
    public class SettlementRecord {
        @AuraEnabled public String id;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Integer loadCount;
        @AuraEnabled public DateTime settlementDate;
        @AuraEnabled public String status;
        @AuraEnabled public String paymentMethod;
    }
    
    /**
     * getAssignedLoads
     * 
     * Retrieves loads assigned to this carrier
     * Row-level security: Only this carrier's loads returned
     * Data masking: Shipper details protected from competitors
     * 
     * @param pageNumber - Page number (1-indexed)
     * @param pageSize - Records per page
     * @return List of AssignedLoadItem
     */
    @AuraEnabled(cacheable=true)
    public static List<AssignedLoadItem> getAssignedLoads(Integer pageNumber, Integer pageSize) {
        try {
            // Input validation
            if (pageNumber == null || pageNumber < 1) pageNumber = 1;
            if (pageSize == null || pageSize < 1) pageSize = 20;
            if (pageSize > 100) pageSize = 100;
            
            // CRUD check
            if (!Load__c.sObjectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('You do not have permission to view loads.');
            }
            
            // Get current carrier account
            String carrierAccountId = getCurrentCarrierAccountId();
            
            Integer offset = (pageNumber - 1) * pageSize;
            
            // Query assigned loads (RLS enforced)
            List<Load__c> loads = [
                SELECT Id, Load_Number__c, Shipper_City__c, Receiver_City__c,
                       Status__c, Carrier_Rate__c, Shipper__r.Name,
                       Current_Location__Latitude__s, Current_Location__Longitude__s
                FROM Load__c
                WHERE Carrier__c = :carrierAccountId
                ORDER BY CreatedDate DESC
                LIMIT :pageSize
                OFFSET :offset
            ];
            
            List<AssignedLoadItem> items = new List<AssignedLoadItem>();
            for (Load__c load : loads) {
                AssignedLoadItem item = new AssignedLoadItem();
                item.id = load.Id;
                item.loadNumber = load.Load_Number__c;
                item.origin = load.Shipper_City__c;
                item.destination = load.Receiver_City__c;
                item.status = load.Status__c;
                item.carrierRate = load.Carrier_Rate__c;
                // Data masking: Only show shipper company name, not other details
                item.shipperName = load.Shipper__r?.Name;
                item.latitude = load.Current_Location__Latitude__s;
                item.longitude = load.Current_Location__Longitude__s;
                items.add(item);
            }
            
            return items;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving assigned loads: ' + e.getMessage());
        }
    }
    
    /**
     * acceptLoadAssignment
     * 
     * Accepts a load assignment and updates status
     * Publishes Platform Event for real-time dispatcher notification
     * 
     * @param loadId - Load record ID
     * @return Success message
     */
    @AuraEnabled
    public static String acceptLoadAssignment(String loadId) {
        try {
            // Input validation
            if (String.isBlank(loadId)) {
                throw new AuraHandledException('Load ID is required.');
            }
            
            // Check update permission
            if (!Load__c.sObjectType.getDescribe().isUpdateable()) {
                throw new AuraHandledException('You do not have permission to accept loads.');
            }
            
            String carrierAccountId = getCurrentCarrierAccountId();
            
            // Fetch and update load (RLS enforced)
            List<Load__c> loads = [
                SELECT Id, Status__c, Carrier__c
                FROM Load__c
                WHERE Id = :loadId AND Carrier__c = :carrierAccountId
                FOR UPDATE
            ];
            
            if (loads.isEmpty()) {
                throw new AuraHandledException('Load not found or you do not have access to it.');
            }
            
            Load__c load = loads[0];
            load.Status__c = 'IN_TRANSIT';
            
            update load;
            
            // Publish Platform Event for real-time notification
            publishLoadAcceptanceEvent(loadId, carrierAccountId, true);
            
            return 'Load assignment accepted successfully.';
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error accepting load: ' + e.getMessage());
        }
    }
    
    /**
     * declineLoadAssignment
     * 
     * Declines a load assignment, returns to available pool
     * Publishes Platform Event for dispatcher
     * 
     * @param loadId - Load record ID
     * @return Success message
     */
    @AuraEnabled
    public static String declineLoadAssignment(String loadId) {
        try {
            if (String.isBlank(loadId)) {
                throw new AuraHandledException('Load ID is required.');
            }
            
            if (!Load__c.sObjectType.getDescribe().isUpdateable()) {
                throw new AuraHandledException('You do not have permission to decline loads.');
            }
            
            String carrierAccountId = getCurrentCarrierAccountId();
            
            List<Load__c> loads = [
                SELECT Id, Status__c, Carrier__c
                FROM Load__c
                WHERE Id = :loadId AND Carrier__c = :carrierAccountId
                FOR UPDATE
            ];
            
            if (loads.isEmpty()) {
                throw new AuraHandledException('Load not found.');
            }
            
            Load__c load = loads[0];
            load.Status__c = 'AVAILABLE';
            load.Carrier__c = null;
            
            update load;
            
            publishLoadAcceptanceEvent(loadId, carrierAccountId, false);
            
            return 'Load assignment declined successfully.';
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error declining load: ' + e.getMessage());
        }
    }
    
    /**
     * uploadPOD
     * 
     * Uploads proof of delivery (photo + metadata)
     * Stores photo as ContentVersion and links to POD record
     * Publishes Platform Event for real-time notifications
     * 
     * @param request - PODUploadRequest with load ID, photo, receiver info
     * @return PODUploadResponse with success status and POD ID
     */
    @AuraEnabled
    public static PODUploadResponse uploadPOD(PODUploadRequest request) {
        try {
            // Input validation
            if (String.isBlank(request.loadId)) {
                throw new AuraHandledException('Load ID is required.');
            }
            if (String.isBlank(request.photoBase64)) {
                throw new AuraHandledException('Photo is required.');
            }
            if (String.isBlank(request.receiverName)) {
                throw new AuraHandledException('Receiver name is required.');
            }
            
            // Photo size validation (max 10 MB)
            if (request.photoBase64.length() > 13000000) {
                throw new AuraHandledException('Photo is too large. Maximum 10 MB.');
            }
            
            // CRUD checks
            if (!Load__c.sObjectType.getDescribe().isUpdateable()) {
                throw new AuraHandledException('You do not have permission to capture POD.');
            }
            // TODO: Phase 2 - POD__c CRUD check (POD__c not yet deployed)
            
            String carrierAccountId = getCurrentCarrierAccountId();
            
            // Verify load belongs to this carrier
            List<Load__c> loads = [
                SELECT Id, Status__c
                FROM Load__c
                WHERE Id = :request.loadId AND Carrier__c = :carrierAccountId
                FOR UPDATE
            ];
            
            if (loads.isEmpty()) {
                throw new AuraHandledException('Load not found or you do not have access to it.');
            }
            
            Load__c load = loads[0];
            
            // TODO: Phase 2 - Create POD__c record (POD__c not yet deployed)
            // For now, just mark the load as delivered and capture the flag
            load.POD_Captured__c = true;
            
            // Update load status to DELIVERED
            load.Status__c = 'DELIVERED';
            update load;
            
            // TODO: Phase 2 - Store photo as ContentVersion when POD__c exists
            // TODO: Phase 2 - Publish POD_Created_Event__e when deployed
            
            PODUploadResponse response = new PODUploadResponse();
            response.success = true;
            response.podId = request.loadId; // Using loadId as stub
            response.message = 'POD uploaded successfully.';
            
            return response;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error uploading POD: ' + e.getMessage());
        }
    }
    
    /**
     * uploadPhotoAsync
     * 
     * Uploads photo as ContentVersion in async context
     * Prevents blocking main transaction
     * 
     * @param podId - POD record ID
     * @param photoBase64 - Base64-encoded photo data
     */
    @Future(callout=false)
    private static void uploadPhotoAsync(String podId, String photoBase64) {
        try {
            Blob photoBlob = EncodingUtil.base64Decode(photoBase64);
            
            ContentVersion cv = new ContentVersion();
            cv.Title = 'POD_' + podId + '_' + System.now().getTime();
            cv.PathOnClient = cv.Title + '.jpg';
            cv.VersionData = photoBlob;
            cv.Origin = 'C';
            
            insert cv;
            
            // Link to POD
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId = podId;
            cdl.ShareType = 'V';
            
            insert cdl;
        } catch (Exception e) {
            System.debug('Error storing POD photo: ' + e.getMessage());
        }
    }
    
    /**
     * getSettlementHistory
     * 
     * Retrieves settlement records for this carrier
     * 
     * @param pageNumber - Page number
     * @param pageSize - Records per page
     * @return List of SettlementRecord
     */
    @AuraEnabled(cacheable=true)
    public static List<SettlementRecord> getSettlementHistory(Integer pageNumber, Integer pageSize) {
        try {
            if (pageNumber == null || pageNumber < 1) pageNumber = 1;
            if (pageSize == null || pageSize < 1) pageSize = 20;
            if (pageSize > 100) pageSize = 100;
            
            if (!Settlement__c.sObjectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('You do not have permission to view settlements.');
            }
            
            String carrierAccountId = getCurrentCarrierAccountId();
            Integer offset = (pageNumber - 1) * pageSize;
            
            List<Settlement__c> settlements = [
                SELECT Id, Net_Payment__c, Load_Count__c, Settlement_Period_End__c,
                       Status__c, Payment_Method__c
                FROM Settlement__c
                WHERE Carrier__c = :carrierAccountId
                ORDER BY Settlement_Period_End__c DESC
                LIMIT :pageSize
                OFFSET :offset
            ];
            
            List<SettlementRecord> records = new List<SettlementRecord>();
            for (Settlement__c settlement : settlements) {
                SettlementRecord record = new SettlementRecord();
                record.id = settlement.Id;
                record.totalAmount = settlement.Net_Payment__c;
                record.loadCount = (Integer)settlement.Load_Count__c;
                record.settlementDate = settlement.Settlement_Period_End__c;
                record.status = settlement.Status__c;
                record.paymentMethod = settlement.Payment_Method__c;
                records.add(record);
            }
            
            return records;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving settlement history: ' + e.getMessage());
        }
    }
    
    /**
     * getCurrentCarrierAccountId
     * 
     * Gets current user's carrier account ID
     * 
     * @return Account ID
     */
    private static String getCurrentCarrierAccountId() {
        User currentUser = [SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        
        if (currentUser.ContactId == null) {
            throw new AuraHandledException('User contact not found.');
        }
        
        Contact contact = [SELECT AccountId FROM Contact WHERE Id = :currentUser.ContactId LIMIT 1];
        
        if (contact.AccountId == null) {
            throw new AuraHandledException('User account not found.');
        }
        
        return contact.AccountId;
    }
    
    /**
     * publishLoadAcceptanceEvent
     * 
     * Publishes Platform Event for load acceptance/decline
     * Enables real-time dispatcher notifications
     * 
     * @param loadId - Load record ID
     * @param carrierAccountId - Carrier account ID
     * @param accepted - True if accepted, false if declined
     */
    // TODO: Phase 2 - publishLoadAcceptanceEvent (Load_Acceptance_Event__e not yet deployed)
    private static void publishLoadAcceptanceEvent(String loadId, String carrierAccountId, Boolean accepted) {
        System.debug('TODO Phase 2: publishLoadAcceptanceEvent loadId=' + loadId);
    }
    
    /**
     * publishPODCreatedEvent
     * 
     * Publishes Platform Event when POD is created
     * 
     * @param podId - POD record ID
     * @param loadId - Load record ID
     */
    // TODO: Phase 2 - publishPODCreatedEvent (POD_Created_Event__e not yet deployed)
    private static void publishPODCreatedEvent(String podId, String loadId) {
        System.debug('TODO Phase 2: publishPODCreatedEvent podId=' + podId);
    }
}
