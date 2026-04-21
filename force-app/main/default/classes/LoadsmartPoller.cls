/**
 * Loadsmart Polling Job
 * 
 * Periodically polls Loadsmart API for newly accepted shipments
 * Auto-creates Load records in Salesforce with all shipment data
 * 
 * Loadsmart API: GET /shipments/ with query params
 * - Filters: updated_after (ISO timestamp), status, pagination
 * 
 * Schedule: Every 5-10 minutes via scheduled Apex
 * 
 * Usage:
 *   LoadsmartPoller poller = new LoadsmartPoller();
 *   Database.executeBatch(poller);
 */

public with sharing class LoadsmartPoller implements Database.Batchable<SObject>, Schedulable {
    private static final String LOADSMART_API_BASE = 'https://api.loadsmart.com/api/v3';
    private static final String AUTH_ENDPOINT = 'https://api.loadsmart.com/auth/token';
    private static final Integer TIMEOUT_MS = 30000;
    private static final Integer PAGE_SIZE = 50;
    
    // Configurable: How far back to poll (in minutes)
    private Integer lookbackMinutes = 15;
    
    // Named Credential for OAuth (configured in Salesforce setup)
    private static final String NAMED_CREDENTIAL = 'callout:LoadsmartAPI';
    
    /**
     * Execute as scheduled job
     */
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new LoadsmartPoller(), 1);
    }
    
    /**
     * Batch start: Query loads needing sync status update
     */
    public Database.QueryLocator start(Database.BatchableContext ctx) {
        // For initial polling, we query all with status=Pending
        // Later: optimize to only new loads
        return Database.getQueryLocator([
            SELECT Id, Loadsmart_Shipment_ID__c 
            FROM Load__c 
            WHERE Status__c = 'Pending' 
            LIMIT 1000
        ]);
    }
    
    /**
     * Batch execute: Process loads
     */
    public void execute(Database.BatchableContext ctx, List<Load__c> loads) {
        // Poll for new shipments from Loadsmart
        pollLoadsmart();
    }
    
    /**
     * Batch finish
     */
    public void finish(Database.BatchableContext ctx) {
        System.debug('LoadsmartPoller batch completed');
    }
    
    /**
     * Main polling logic
     */
    public void pollLoadsmart() {
        try {
            // Get OAuth token
            String accessToken = getAccessToken();
            if (String.isBlank(accessToken)) {
                System.debug('Failed to obtain Loadsmart access token');
                return;
            }
            
            // Query Loadsmart API for recently updated shipments
            String updatedAfter = DateTime.now().addMinutes(-lookbackMinutes).format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            String endpoint = LOADSMART_API_BASE + '/shipments/?updated_after=' + EncodingUtil.urlEncode(updatedAfter, 'UTF-8');
            endpoint += '&max_per_page=' + PAGE_SIZE;
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setTimeout(TIMEOUT_MS);
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('User-Agent', 'KWB-Salesforce-Integration');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                processShipmentsResponse(res.getBody());
            } else if (res.getStatusCode() == 401) {
                System.debug('Loadsmart auth failed - token may be expired');
            } else {
                System.debug('Loadsmart API error: ' + res.getStatusCode() + ' ' + res.getStatus());
            }
        } catch (Exception e) {
            System.debug('LoadsmartPoller exception: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }
    
    /**
     * Get OAuth access token from Loadsmart using Named Credential
     * 
     * Named Credential handles Basic Auth automatically, ensuring:
     * - Credentials stored securely in Salesforce (not in code)
     * - Credentials not logged or exposed in debug logs
     * - Centralized management for credential rotation
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
    
    /**
     * Process shipments from Loadsmart API response using DTO deserialization
     */
    private void processShipmentsResponse(String responseBody) {
        try {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            
            List<Object> shipmentsArray = (List<Object>) response.get('shipments');
            if (shipmentsArray == null || shipmentsArray.isEmpty()) {
                return;
            }
            
            // Parse with DTO for type safety
            List<LoadsmartShipmentDTO> shipments = LoadsmartShipmentDTO.parseList(shipmentsArray);
            
            List<Load__c> loadsToInsert = new List<Load__c>();
            Set<String> existingShipmentIds = new Set<String>();
            
            // Check which shipments already exist
            for (Load__c existing : [
                SELECT Loadsmart_Shipment_ID__c 
                FROM Load__c 
                LIMIT 10000
            ]) {
                existingShipmentIds.add(existing.Loadsmart_Shipment_ID__c);
            }
            
            // Process each shipment
            for (LoadsmartShipmentDTO shipment : shipments) {
                // Skip if already exists in Salesforce
                if (existingShipmentIds.contains(shipment.id)) {
                    continue;
                }
                
                Load__c load = mapShipmentToLoad(shipment);
                if (load != null) {
                    loadsToInsert.add(load);
                }
            }
            
            // Insert all new loads
            if (!loadsToInsert.isEmpty()) {
                insert loadsToInsert;
                System.debug('Created ' + loadsToInsert.size() + ' loads from Loadsmart');
            }
        } catch (Exception e) {
            System.debug('Error processing shipments: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }
    
    /**
     * Map Loadsmart shipment DTO to Salesforce Load record
     * 
     * Uses DTO for type-safe field access instead of manual casting
     */
    private Load__c mapShipmentToLoad(LoadsmartShipmentDTO shipment) {
        try {
            Load__c load = new Load__c();
            
            // Core identification
            load.Loadsmart_Shipment_ID__c = shipment.id;
            load.Order_Number__c = shipment.shipment_reference;
            load.Status__c = 'Pending';
            
            // Rate and billing
            if (shipment.rate != null) {
                load.Billing_Rate__c = shipment.rate.amount;
            }
            
            // Stops: pickup and delivery
            if (shipment.stops != null) {
                for (LoadsmartShipmentDTO.LoadsmartStopDTO stopDto : shipment.stops) {
                    if (String.isBlank(stopDto.planned_date)) {
                        continue;
                    }
                    
                    DateTime plannedDateTime = DateTime.parse(stopDto.planned_date + 'T00:00:00Z');
                    
                    if ('pickup'.equalsIgnoreCase(stopDto.type)) {
                        load.Shipper_Name__c = stopDto.location_name;
                        load.Shipper_Address__c = stopDto.address;
                        load.Shipper_City__c = stopDto.city;
                        load.Shipper_State__c = stopDto.state;
                        load.Shipper_Zip__c = stopDto.zipcode;
                        load.Pickup_Window_Begin__c = plannedDateTime;
                        load.Pickup_Window_End__c = plannedDateTime.addHours(8);
                    } else if ('delivery'.equalsIgnoreCase(stopDto.type)) {
                        load.Receiver_Name__c = stopDto.location_name;
                        load.Receiver_Address__c = stopDto.address;
                        load.Receiver_City__c = stopDto.city;
                        load.Receiver_State__c = stopDto.state;
                        load.Receiver_Zip__c = stopDto.zipcode;
                        load.Delivery_Window_Begin__c = plannedDateTime;
                        load.Delivery_Window_End__c = plannedDateTime.addHours(8);
                    }
                }
            }
            
            // Equipment and commodity
            load.Equipment_Type__c = shipment.equipment_type;
            load.Commodity__c = String.isBlank(shipment.commodity) ? 'TBD' : shipment.commodity;
            
            // Weight
            if (shipment.weight != null) {
                load.Weight_lbs__c = shipment.weight.value;
            }
            
            return load;
        } catch (Exception e) {
            System.debug('Error mapping shipment: ' + e.getMessage());
            return null;
        }
    }
    
    // @isTest methods must be in @isTest classes - moved to LoadsmartPollerTest.cls
}
