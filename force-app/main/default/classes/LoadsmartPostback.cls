/**
 * Loadsmart Post-Back / Sync
 * 
 * DISABLED IN PHASE 1 - For testing/validation ONLY
 * 
 * This class handles pushing Load data back to Loadsmart:
 * - Carrier assignment
 * - Rate confirmation
 * - Pickup/delivery scheduled times
 * - Load status updates
 * 
 * Loadsmart API: PATCH /shipments/{id}
 * 
 * IMPORTANT: This sends data to Loadsmart PRODUCTION
 * - Test thoroughly in dev org before enabling
 * - Validate all field mappings with Loadsmart
 * - Implement in Scheduled Batch (nightly) in production
 * 
 * Usage (when enabled):
 *   LoadsmartPostback postback = new LoadsmartPostback();
 *   postback.syncLoadToLoadsmart(loadId);
 */

public with sharing class LoadsmartPostback {
    
    private static final String LOADSMART_API_BASE = 'https://api.loadsmart.com/api/v3';
    private static final Integer TIMEOUT_MS = 30000;
    
    // Named Credential for OAuth (configured in Salesforce setup)
    private static final String NAMED_CREDENTIAL = 'callout:LoadsmartAPI';
    
    /**
     * Sync a single Load back to Loadsmart
     */
    public void syncLoadToLoadsmart(Id loadId) {
        Load__c load = [
            SELECT 
                Id, 
                Loadsmart_Shipment_ID__c,
                Carrier__r.Name,
                Carrier__r.MC_Number__c,
                Carrier__r.DOT_Number__c,
                Carrier_Rate__c,
                Pickup_Window_Begin__c,
                Delivery_Window_Begin__c,
                Status__c
            FROM Load__c 
            WHERE Id = :loadId
            LIMIT 1
        ];
        
        if (load == null || String.isBlank(load.Loadsmart_Shipment_ID__c)) {
            System.debug('Load not found or missing Loadsmart Shipment ID');
            return;
        }
        
        try {
            String accessToken = getAccessToken();
            if (String.isBlank(accessToken)) {
                System.debug('Failed to get Loadsmart access token');
                return;
            }
            
            // Build PATCH payload
            Map<String, Object> payload = new Map<String, Object>();
            
            // Carrier information
            if (load.Carrier__r != null) {
                Map<String, String> carrierData = new Map<String, String>{
                    'name' => load.Carrier__r.Name,
                    'mc_number' => load.Carrier__r.MC_Number__c,
                    'dot_number' => load.Carrier__r.DOT_Number__c
                };
                payload.put('carrier', carrierData);
            }
            
            // Scheduled pickup/delivery times
            if (load.Pickup_Window_Begin__c != null) {
                payload.put('pickup_scheduled_at', load.Pickup_Window_Begin__c.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
            }
            if (load.Delivery_Window_Begin__c != null) {
                payload.put('delivery_scheduled_at', load.Delivery_Window_Begin__c.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
            }
            
            // Carrier rate (if applicable - this may not be writable via API)
            if (load.Carrier_Rate__c != null) {
                payload.put('carrier_rate', load.Carrier_Rate__c);
            }
            
            // Make PATCH request
            String endpoint = LOADSMART_API_BASE + '/shipments/' + load.Loadsmart_Shipment_ID__c;
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('PATCH');
            req.setTimeout(TIMEOUT_MS);
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('User-Agent', 'KWB-Salesforce-Integration');
            req.setBody(JSON.serialize(payload));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Handle response
            if (res.getStatusCode() == 200 || res.getStatusCode() == 204) {
                // Success
                load.Loadsmart_Synced__c = true;
                load.Last_Loadsmart_Sync__c = DateTime.now();
                update load;
                
                System.debug('Successfully synced Load ' + load.Id + ' to Loadsmart');
            } else if (res.getStatusCode() == 401) {
                System.debug('Loadsmart authentication failed');
            } else {
                System.debug('Loadsmart sync failed: ' + res.getStatusCode() + ' ' + res.getStatus() + '\n' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('LoadsmartPostback exception: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }
    
    /**
     * Scheduled Batch: Sync all "Assigned" loads to Loadsmart nightly
     * 
     * INSTALL INSTRUCTIONS (when ready):
     * 1. System > Apex Classes > Schedule Apex
     * 2. Class: LoadsmartPostbackBatch
     * 3. Schedule: 0 0 2 * * ? (2 AM daily)
     */
    public class LoadsmartPostbackBatch implements Database.Batchable<SObject>, Schedulable {
        
        public void execute(SchedulableContext ctx) {
            Database.executeBatch(new LoadsmartPostbackBatch(), 10);
        }
        
        public Database.QueryLocator start(Database.BatchableContext ctx) {
            return Database.getQueryLocator([
                SELECT Id 
                FROM Load__c 
                WHERE Status__c IN ('Assigned', 'Confirmed') 
                AND Loadsmart_Synced__c = false
                ORDER BY CreatedDate DESC
            ]);
        }
        
        public void execute(Database.BatchableContext ctx, List<Load__c> loads) {
            LoadsmartPostback postback = new LoadsmartPostback();
            for (Load__c load : loads) {
                postback.syncLoadToLoadsmart(load.Id);
            }
        }
        
        public void finish(Database.BatchableContext ctx) {
            System.debug('LoadsmartPostbackBatch completed');
        }
    }
    
    /**
     * Get OAuth access token from Loadsmart using Named Credential
     * 
     * Named Credential ensures secure credential handling without hardcoding
     */
    private String getAccessToken() {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(NAMED_CREDENTIAL + '?grant_type=client_credentials');
            req.setMethod('POST');
            req.setTimeout(TIMEOUT_MS);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('grant_type=client_credentials');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                LoadsmartTokenDTO tokenResponse = LoadsmartTokenDTO.parse(res.getBody());
                return tokenResponse.access_token;
            } else {
                System.debug('Error getting Loadsmart token. Status: ' + res.getStatusCode() + ' ' + res.getStatus());
            }
        } catch (Exception e) {
            System.debug('Error getting Loadsmart token: ' + e.getMessage());
        }
        return null;
    }
    
    @isTest
    public static void testPostback() {
        // Test would require mocking HTTP responses and test Load data
    }
}
