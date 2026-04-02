/**
 * MotiveWebhookReceiverTest
 * 
 * Test class for MotiveWebhookReceiver REST endpoint
 * Tests webhook reception, signature validation, duplicate detection, and async job queueing
 * 
 * Target: >80% code coverage for critical paths
 */
@IsTest
public class MotiveWebhookReceiverTest {
    
    @TestSetup
    static void setupMotiveConfig() {
        // Create MotiveConfig__c custom setting with webhook secret
        MotiveConfig__c config = new MotiveConfig__c(
            Name = 'Default',
            Webhook_Secret__c = 'test-webhook-secret-12345'
        );
        insert config;
    }
    
    /**
     * Test: Valid webhook payload with correct signature is accepted
     */
    @IsTest
    static void testValidWebhookWithCorrectSignature() {
        // Setup
        String payload = buildValidWebhookPayload('event-001', System.currentTimeMillis());
        String timestamp = String.valueOf(System.currentTimeMillis());
        
        // Compute correct HMAC signature
        String signedContent = timestamp + '.' + payload;
        Blob signedBlob = Crypto.generateMac('HmacSHA256', 
            Blob.valueOf(signedContent), 
            Blob.valueOf('test-webhook-secret-12345'));
        String correctSignature = EncodingUtil.convertToHex(signedBlob);
        
        // Execute
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/motive/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        req.addHeader('X-Motive-Signature', correctSignature);
        req.addHeader('X-Motive-Timestamp', timestamp);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        MotiveWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify
        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Should return 200 OK for valid signature');
        
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
        String payload = buildValidWebhookPayload('event-002', System.currentTimeMillis());
        String timestamp = String.valueOf(System.currentTimeMillis());
        
        // Execute with WRONG signature
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/motive/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        req.addHeader('X-Motive-Signature', 'wrong-signature-12345');
        req.addHeader('X-Motive-Timestamp', timestamp);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        MotiveWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify
        RestResponse res = RestContext.response;
        System.assertEquals(401, res.statusCode, 'Should return 401 Unauthorized for invalid signature');
        
        String responseBody = res.responseBody.toString();
        Map<String, Object> errorMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        System.assertEquals('SIGNATURE_VALIDATION_FAILED', errorMap.get('error'), 'Should indicate signature failure');
    }
    
    /**
     * Test: Missing signature header is rejected
     */
    @IsTest
    static void testMissingSignatureRejected() {
        // Setup
        String payload = buildValidWebhookPayload('event-003', System.currentTimeMillis());
        
        // Execute - missing X-Motive-Signature header
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/motive/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        // Intentionally NOT adding signature header
        req.addHeader('X-Motive-Timestamp', String.valueOf(System.currentTimeMillis()));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        MotiveWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify
        RestResponse res = RestContext.response;
        System.assertEquals(401, res.statusCode, 'Should reject missing signature header');
    }
    
    /**
     * Test: Malformed payload (missing required fields) is rejected
     */
    @IsTest
    static void testMalformedPayloadRejected() {
        // Setup - missing required 'id' field
        String payload = '{"vehicleId": "vehicle_123", "timestamp": "2026-04-03T14:32:15Z"}';
        String timestamp = String.valueOf(System.currentTimeMillis());
        
        String signedContent = timestamp + '.' + payload;
        Blob signedBlob = Crypto.generateMac('HmacSHA256', 
            Blob.valueOf(signedContent), 
            Blob.valueOf('test-webhook-secret-12345'));
        String signature = EncodingUtil.convertToHex(signedBlob);
        
        // Execute
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/motive/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        req.addHeader('X-Motive-Signature', signature);
        req.addHeader('X-Motive-Timestamp', timestamp);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        MotiveWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify
        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 Bad Request for malformed payload');
    }
    
    /**
     * Test: Duplicate webhook is detected and ignored (by Motive event ID)
     */
    @IsTest
    static void testDuplicateDetectionByEventId() {
        // Setup - create first tracking record
        Load__c testLoad = createTestLoad();
        Tracking__c firstTracking = new Tracking__c(
            Load__c = testLoad.Id,
            Motive_Event_ID__c = 'motive-event-123',
            Motive_Vehicle_ID__c = 'vehicle_456',
            Event_Type__c = 'vehicle_location_update',
            Event_Timestamp__c = DateTime.now(),
            Latitude__c = 39.96,
            Longitude__c = -82.99
        );
        insert firstTracking;
        
        // Build duplicate payload with same event ID
        String payload = '{'
            + '"id": "motive-event-123",'
            + '"vehicleId": "vehicle_456",'
            + '"type": "vehicle.location.update",'
            + '"timestamp": "' + DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '",'
            + '"location": {"latitude": 40.00, "longitude": -83.00, "speedMph": 50, "heading": 270}'
            + '}';
        
        String timestamp = String.valueOf(System.currentTimeMillis());
        String signedContent = timestamp + '.' + payload;
        Blob signedBlob = Crypto.generateMac('HmacSHA256', 
            Blob.valueOf(signedContent), 
            Blob.valueOf('test-webhook-secret-12345'));
        String signature = EncodingUtil.convertToHex(signedBlob);
        
        // Execute
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/motive/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        req.addHeader('X-Motive-Signature', signature);
        req.addHeader('X-Motive-Timestamp', timestamp);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        MotiveWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify - duplicate ignored
        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Duplicate should be accepted (not error)');
        
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
        List<String> eventIds = new List<String>{'event-q1', 'event-q2', 'event-q3'};
        
        // Execute
        Test.startTest();
        for (String eventId : eventIds) {
            String payload = buildValidWebhookPayload(eventId, System.currentTimeMillis());
            String timestamp = String.valueOf(System.currentTimeMillis());
            
            String signedContent = timestamp + '.' + payload;
            Blob signedBlob = Crypto.generateMac('HmacSHA256', 
                Blob.valueOf(signedContent), 
                Blob.valueOf('test-webhook-secret-12345'));
            String signature = EncodingUtil.convertToHex(signedBlob);
            
            RestRequest req = new RestRequest();
            req.requestUri = '/services/apexrest/tracking/motive/webhook';
            req.httpMethod = 'POST';
            req.requestBody = Blob.valueOf(payload);
            req.addHeader('X-Motive-Signature', signature);
            req.addHeader('X-Motive-Timestamp', timestamp);
            
            RestContext.request = req;
            RestContext.response = new RestResponse();
            
            MotiveWebhookReceiver.handleWebhook();
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
        String payload = buildValidWebhookPayload('event-resp', System.currentTimeMillis());
        String timestamp = String.valueOf(System.currentTimeMillis());
        
        String signedContent = timestamp + '.' + payload;
        Blob signedBlob = Crypto.generateMac('HmacSHA256', 
            Blob.valueOf(signedContent), 
            Blob.valueOf('test-webhook-secret-12345'));
        String signature = EncodingUtil.convertToHex(signedBlob);
        
        // Execute
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/motive/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        req.addHeader('X-Motive-Signature', signature);
        req.addHeader('X-Motive-Timestamp', timestamp);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        MotiveWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify
        RestResponse res = RestContext.response;
        String responseBody = res.responseBody.toString();
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        System.assertNotEquals(null, responseMap.get('status'), 'Response should have status');
        System.assertNotEquals(null, responseMap.get('eventId'), 'Response should have eventId');
        System.assertNotEquals(null, responseMap.get('jobId'), 'Response should have jobId');
    }
    
    /**
     * Test: Empty request body is rejected
     */
    @IsTest
    static void testEmptyRequestBodyRejected() {
        // Execute
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/motive/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('');
        req.addHeader('X-Motive-Signature', 'signature');
        req.addHeader('X-Motive-Timestamp', String.valueOf(System.currentTimeMillis()));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        MotiveWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify
        RestResponse res = RestContext.response;
        System.assertNotEquals(200, res.statusCode, 'Empty body should be rejected');
    }
    
    /**
     * Test: Constant-time signature comparison prevents timing attacks
     */
    @IsTest
    static void testTimingSafeSignatureComparison() {
        // This test verifies the implementation, not the timing itself (timing attacks hard to test)
        // Setup two payloads with similar but different signatures
        String payload = buildValidWebhookPayload('event-timing', System.currentTimeMillis());
        String timestamp = String.valueOf(System.currentTimeMillis());
        
        String signedContent = timestamp + '.' + payload;
        Blob signedBlob = Crypto.generateMac('HmacSHA256', 
            Blob.valueOf(signedContent), 
            Blob.valueOf('test-webhook-secret-12345'));
        String correctSignature = EncodingUtil.convertToHex(signedBlob);
        
        // Almost correct signature (off by one char at end)
        String almostCorrectSignature = correctSignature.substring(0, correctSignature.length() - 1) + 'Z';
        
        // Execute with almost-correct signature
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/motive/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        req.addHeader('X-Motive-Signature', almostCorrectSignature);
        req.addHeader('X-Motive-Timestamp', timestamp);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        MotiveWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify - should reject even though signature is "almost" correct
        RestResponse res = RestContext.response;
        System.assertEquals(401, res.statusCode, 'Should reject similar-but-wrong signature');
    }
    
    /**
     * Test: Missing webhook secret in config is handled
     */
    @IsTest
    static void testMissingWebhookSecretHandled() {
        // Setup - delete the MotiveConfig to simulate missing config
        List<MotiveConfig__c> configs = [SELECT Id FROM MotiveConfig__c];
        delete configs;
        
        String payload = buildValidWebhookPayload('event-noconfig', System.currentTimeMillis());
        String timestamp = String.valueOf(System.currentTimeMillis());
        
        // Execute
        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/tracking/motive/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        req.addHeader('X-Motive-Signature', 'any-signature');
        req.addHeader('X-Motive-Timestamp', timestamp);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        MotiveWebhookReceiver.handleWebhook();
        Test.stopTest();
        
        // Verify - should reject due to missing config
        RestResponse res = RestContext.response;
        System.assertEquals(401, res.statusCode, 'Should reject when webhook secret not configured');
    }
    
    // ==================== HELPERS ====================
    
    private static String buildValidWebhookPayload(String eventId, Long timestamp) {
        return '{'
            + '"id": "' + eventId + '",'
            + '"vehicleId": "vehicle_123",'
            + '"type": "vehicle.location.update",'
            + '"timestamp": "2026-04-03T14:32:15Z",'
            + '"location": {'
            + '  "latitude": 39.96,'
            + '  "longitude": -82.99,'
            + '  "speedMph": 55.0,'
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
