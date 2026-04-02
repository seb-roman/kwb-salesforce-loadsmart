/**
 * SamsaraWebhookReceiverTest
 * 
 * Test class for SamsaraWebhookReceiver REST endpoint
 * Tests webhook reception, signature validation, duplicate detection, and async job queueing
 * 
 * Target: >80% code coverage for critical paths
 */
@IsTest
public class SamsaraWebhookReceiverTest {
    
    /**
     * Test: Valid webhook payload is accepted and queued
     */
    @IsTest
    static void testValidWebhookAccepted() {
        // Setup
        String payload = buildValidWebhookPayload();
        
        // Execute
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/samsara/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        req.addHeader('X-Samsara-Signature', 'valid-signature-placeholder');
        req.addHeader('X-Samsara-Timestamp', String.valueOf(System.currentTimeMillis()));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        SamsaraWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify
        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Should return 200 OK');
        
        String responseBody = res.responseBody.toString();
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        System.assertEquals('RECEIVED', responseMap.get('status'), 'Should indicate received status');
    }
    
    /**
     * Test: Webhook with invalid signature is rejected
     */
    @IsTest
    static void testInvalidSignatureRejected() {
        // Setup
        String payload = buildValidWebhookPayload();
        
        // Execute
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/samsara/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        // Missing signature header - should fail validation
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        SamsaraWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify
        RestResponse res = RestContext.response;
        System.assertEquals(401, res.statusCode, 'Should return 401 Unauthorized');
    }
    
    /**
     * Test: Malformed payload is rejected
     */
    @IsTest
    static void testMalformedPayloadRejected() {
        // Setup - payload missing required fields
        String payload = '{"invalidField": "value"}';
        
        // Execute
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/samsara/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        req.addHeader('X-Samsara-Signature', 'valid-signature-placeholder');
        req.addHeader('X-Samsara-Timestamp', String.valueOf(System.currentTimeMillis()));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        SamsaraWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify
        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 Bad Request');
    }
    
    /**
     * Test: Duplicate webhook is detected and ignored
     */
    @IsTest
    static void testDuplicateDetection() {
        // Setup - create first tracking record
        Load__c testLoad = createTestLoad();
        Tracking__c firstTracking = new Tracking__c(
            Load__c = testLoad.Id,
            Samsara_Vehicle_ID__c = 'vehicle_123',
            Event_Type__c = 'vehicle_location_update',
            Event_Timestamp__c = DateTime.now(),
            Latitude__c = 39.96,
            Longitude__c = -82.99
        );
        insert firstTracking;
        
        // Build duplicate payload with same vehicle ID and timestamp
        String payload = '{'
            + '"id": "duplicate-event",'
            + '"vehicleId": "vehicle_123",'
            + '"type": "vehicle.location.update",'
            + '"timestamp": "' + firstTracking.Event_Timestamp__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '",'
            + '"location": {"latitude": 39.96, "longitude": -82.99, "speedMph": 55, "heading": 270}'
            + '}';
        
        // Execute
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/samsara/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        req.addHeader('X-Samsara-Signature', 'valid-signature-placeholder');
        req.addHeader('X-Samsara-Timestamp', String.valueOf(System.currentTimeMillis()));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        SamsaraWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify - duplicate ignored
        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Duplicate should be silently accepted');
        
        String responseBody = res.responseBody.toString();
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        System.assertEquals('DUPLICATE_IGNORED', responseMap.get('status'), 'Should indicate duplicate status');
    }
    
    /**
     * Test: Multiple concurrent webhooks are queued
     */
    @IsTest
    static void testConcurrentWebhookQueueing() {
        // Setup
        List<String> payloads = new List<String>();
        payloads.add(buildValidWebhookPayload());
        payloads.add(buildValidWebhookPayload());
        payloads.add(buildValidWebhookPayload());
        
        // Execute
        Test.startTest();
        for (String payload : payloads) {
            RestRequest req = new RestRequest();
            req.requestUri = '/services/apexrest/tracking/samsara/webhook';
            req.httpMethod = 'POST';
            req.requestBody = Blob.valueOf(payload);
            req.addHeader('X-Samsara-Signature', 'valid-signature-placeholder');
            req.addHeader('X-Samsara-Timestamp', String.valueOf(System.currentTimeMillis()));
            
            RestContext.request = req;
            RestContext.response = new RestResponse();
            
            SamsaraWebhookReceiver.handleWebhook();
        }
        Test.stopTest();
        
        // Verify - all three should be queued
        System.assertEquals(3, Limits.getQueueableJobsAdded(), 'Should queue 3 jobs');
    }
    
    /**
     * Test: Response format is correct
     */
    @IsTest
    static void testResponseFormat() {
        // Setup
        String payload = buildValidWebhookPayload();
        
        // Execute
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/samsara/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        req.addHeader('X-Samsara-Signature', 'valid-signature-placeholder');
        req.addHeader('X-Samsara-Timestamp', String.valueOf(System.currentTimeMillis()));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        SamsaraWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify
        RestResponse res = RestContext.response;
        String responseBody = res.responseBody.toString();
        
        // Should have valid JSON structure
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        System.assertNotEquals(null, responseMap.get('status'), 'Response should have status');
        System.assertNotEquals(null, responseMap.get('eventId'), 'Response should have eventId');
        System.assertNotEquals(null, responseMap.get('jobId'), 'Response should have jobId');
    }
    
    /**
     * Test: Webhook handles missing optional fields gracefully
     */
    @IsTest
    static void testMissingOptionalFields() {
        // Setup - minimal payload
        String payload = '{'
            + '"id": "event-minimal",'
            + '"vehicleId": "vehicle_xyz",'
            + '"type": "vehicle.location.update",'
            + '"timestamp": "2026-04-03T14:32:15Z"'
            + '}';
        
        // Execute
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/samsara/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        req.addHeader('X-Samsara-Signature', 'valid-signature-placeholder');
        req.addHeader('X-Samsara-Timestamp', String.valueOf(System.currentTimeMillis()));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        SamsaraWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify - should still be queued even without location data
        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Should queue even with minimal data');
    }
    
    /**
     * Test: Empty request body is rejected
     */
    @IsTest
    static void testEmptyRequestBodyRejected() {
        // Execute
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/samsara/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('');
        req.addHeader('X-Samsara-Signature', 'valid-signature-placeholder');
        req.addHeader('X-Samsara-Timestamp', String.valueOf(System.currentTimeMillis()));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        SamsaraWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify
        RestResponse res = RestContext.response;
        System.assertNotEquals(200, res.statusCode, 'Empty body should be rejected');
    }
    
    // ==================== HELPERS ====================
    
    private static String buildValidWebhookPayload() {
        return '{'
            + '"id": "event-' + System.currentTimeMillis() + '",'
            + '"vehicleId": "vehicle_123",'
            + '"type": "vehicle.location.update",'
            + '"timestamp": "2026-04-03T14:32:15Z",'
            + '"location": {'
            + '  "latitude": 39.96,'
            + '  "longitude": -82.99,'
            + '  "speedMph": 55,'
            + '  "heading": 270'
            + '},'
            + '"driver": {'
            + '  "id": "driver_456",'
            + '  "name": "John Smith"'
            + '}'
            + '}';
    }
    
    private static Load__c createTestLoad() {
        Load__c load = new Load__c(
            Shipper_Name__c = 'Test Shipper',
            Status__c = 'in_transit'
        );
        insert load;
        return load;
    }
}
