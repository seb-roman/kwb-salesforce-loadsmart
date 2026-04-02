/**
 * MotiveWebhookReceiver
 * 
 * REST endpoint for receiving GPS tracking events from Motive.
 * - Validates HMAC-SHA256 signature
 * - Parses Motive webhook payload
 * - Detects duplicates (idempotent)
 * - Enqueues async TrackingIngestJob for processing
 * - Returns 200 OK within <3 sec SLA
 * 
 * Endpoint: /services/apexrest/tracking/motive/webhook
 * Method: POST
 * 
 * Design Spec: AGENT3_ARCHITECTURE_DIAGRAMS_AND_DELIVERABLES.md
 */
@RestResource(urlMapping='/tracking/motive/webhook')
global with sharing class MotiveWebhookReceiver {

    // Configuration constants
    private static final String MOTIVE_API_KEY_CUSTOM_SETTING = 'MotiveApiKey';
    private static final String MOTIVE_WEBHOOK_SECRET_SETTING = 'MotiveWebhookSecret';
    private static final Integer RESPONSE_TIMEOUT_MS = 3000;
    private static final String WEBHOOK_SIGNATURE_HEADER = 'X-Motive-Signature';
    private static final String WEBHOOK_TIMESTAMP_HEADER = 'X-Motive-Timestamp';
    
    // Tracking event type mappings
    private static final Map<String, String> EVENT_TYPE_MAPPING = new Map<String, String>{
        'vehicle.location.update' => 'vehicle_location_update',
        'vehicle.eld_status.change' => 'eld_status_change',
        'vehicle.geofence_event' => 'geofence_event',
        'vehicle.harsh_acceleration' => 'harsh_acceleration',
        'vehicle.harsh_braking' => 'harsh_braking'
    };
    
    /**
     * Handle incoming Motive webhook
     */
    @HttpPost
    global static void handleWebhook() {
        try {
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            
            // Set response content type
            res.addHeader('Content-Type', 'application/json');
            
            // 1. Validate HMAC signature
            if (!validateSignature(req)) {
                res.statusCode = 401;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    new ErrorResponse('SIGNATURE_VALIDATION_FAILED', 'Invalid HMAC signature')
                ));
                return;
            }
            
            // 2. Parse request body
            String requestBody = req.requestBody.toString();
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
            
            // 3. Validate payload structure
            if (!isValidPayload(payload)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    new ErrorResponse('INVALID_PAYLOAD', 'Missing required fields in webhook payload')
                ));
                return;
            }
            
            // 4. Check for duplicates (idempotent)
            String eventId = (String) payload.get('id');
            String vehicleId = (String) payload.get('vehicleId');
            DateTime eventTimestamp = parseDateTime((String) payload.get('timestamp'));
            
            if (isDuplicate(vehicleId, eventId, eventTimestamp)) {
                // Duplicate - return 200 OK but don't reprocess
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    new SuccessResponse('DUPLICATE_IGNORED', 'Event already processed')
                ));
                return;
            }
            
            // 5. Enqueue async processor job (high-volume safe)
            TrackingIngestJob job = new TrackingIngestJob(requestBody);
            String jobId = System.enqueueJob(job);
            
            // 6. Return 200 OK immediately
            res.statusCode = 200;
            Map<String, Object> successPayload = new Map<String, Object>{
                'status' => 'RECEIVED',
                'message' => 'Webhook received and queued for processing',
                'eventId' => eventId,
                'jobId' => jobId
            };
            res.responseBody = Blob.valueOf(JSON.serialize(successPayload));
            
        } catch (Exception e) {
            RestResponse res = RestContext.response;
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(
                new ErrorResponse('INTERNAL_ERROR', 'Error processing webhook: ' + e.getMessage())
            ));
            
            // Log error for debugging
            logError('MotiveWebhookReceiver', 'handleWebhook', e);
        }
    }
    
    /**
     * Validate HMAC-SHA256 signature from Motive
     * 
     * Implements security protocol per https://docs.motive.com/webhooks#signature-verification
     * Computes HMAC-SHA256(timestamp + '.' + requestBody) and compares with X-Motive-Signature header
     * 
     * @param req RestRequest containing webhook payload and signature headers
     * @return true if signature is valid, false otherwise
     */
    private static Boolean validateSignature(RestRequest req) {
        try {
            // Get signature and timestamp from headers
            String signature = req.getHeader(WEBHOOK_SIGNATURE_HEADER);
            String timestamp = req.getHeader(WEBHOOK_TIMESTAMP_HEADER);
            String requestBody = req.requestBody.toString();
            
            if (String.isEmpty(signature) || String.isEmpty(timestamp)) {
                logWarning('Missing signature or timestamp header');
                return false;
            }
            
            // Retrieve webhook secret from MotiveConfig custom setting
            String webhookSecret = getWebhookSecret();
            if (String.isEmpty(webhookSecret)) {
                logWarning('Webhook secret not configured in MotiveConfig__c');
                return false;
            }
            
            // Construct signed content per Motive spec: timestamp.requestBody
            String signedContent = timestamp + '.' + requestBody;
            
            // Compute HMAC-SHA256
            String expectedSignature = generateHMAC(signedContent, webhookSecret);
            
            // Use constant-time comparison to prevent timing attacks
            return constantTimeEquals(signature, expectedSignature);
            
        } catch (Exception e) {
            logError('MotiveWebhookReceiver', 'validateSignature', e);
            return false;
        }
    }
    
    /**
     * Retrieve webhook secret from custom setting MotiveConfig__c
     * @return the webhook secret, or empty string if not configured
     */
    private static String getWebhookSecret() {
        try {
            // Query MotiveConfig__c custom setting (stored at org level)
            List<MotiveConfig__c> configs = [
                SELECT Webhook_Secret__c FROM MotiveConfig__c LIMIT 1
            ];
            
            if (configs.isEmpty()) {
                return '';
            }
            
            return configs[0].Webhook_Secret__c ?? '';
        } catch (Exception e) {
            logWarning('Error retrieving MotiveConfig: ' + e.getMessage());
            return '';
        }
    }
    
    /**
     * Generate HMAC-SHA256 digest
     * 
     * @param input The data to sign
     * @param secret The signing key
     * @return The base64-encoded HMAC-SHA256 digest
     */
    private static String generateHMAC(String input, String secret) {
        // Convert input and secret to blobs
        Blob inputBlob = Blob.valueOf(input);
        Blob secretBlob = Blob.valueOf(secret);
        
        // Generate HMAC-SHA256
        Blob hmacBlob = Crypto.generateMac('HmacSHA256', inputBlob, secretBlob);
        
        // Return hexadecimal representation (Motive uses hex, not base64)
        return EncodingUtil.convertToHex(hmacBlob);
    }
    
    /**
     * Constant-time string comparison to prevent timing attacks
     * 
     * @param a First string
     * @param b Second string
     * @return true if equal (timing-safe), false otherwise
     */
    private static Boolean constantTimeEquals(String a, String b) {
        // Simple constant-time comparison
        if (a == null || b == null) {
            return false;
        }
        
        if (a.length() != b.length()) {
            return false;
        }
        
        Integer result = 0;
        for (Integer i = 0; i < a.length(); i++) {
            result |= (a.charAt(i) ^ b.charAt(i));
        }
        
        return result == 0;
    }
    
    /**
     * Validate that payload has required fields
     */
    private static Boolean isValidPayload(Map<String, Object> payload) {
        return payload != null 
            && payload.containsKey('id')
            && payload.containsKey('vehicleId')
            && payload.containsKey('timestamp');
    }
    
    /**
     * Check if this event is a duplicate (already processed)
     * 
     * Uses Motive event ID as the unique identifier (exact match).
     * Also checks by Vehicle ID + Event ID combination to ensure idempotency.
     * 
     * @param vehicleId The Motive vehicle ID
     * @param eventId The unique Motive event ID
     * @param eventTimestamp The event timestamp (for reference)
     * @return true if this event has already been processed, false otherwise
     */
    private static Boolean isDuplicate(String vehicleId, String eventId, DateTime eventTimestamp) {
        try {
            if (String.isEmpty(eventId) || String.isEmpty(vehicleId)) {
                return false;
            }
            
            // Query by Motive event ID (exact match, not time window)
            // Event IDs are globally unique from Motive, so we don't need vehicle ID
            List<Tracking__c> existing = [
                SELECT Id FROM Tracking__c 
                WHERE Motive_Event_ID__c = :eventId 
                LIMIT 1
            ];
            
            if (!existing.isEmpty()) {
                logWarning('Duplicate event detected: ' + eventId);
                return true;
            }
            
            // Fallback: Also check by vehicle + event ID combination within last 24 hours
            // This helps catch delayed retries from Motive
            DateTime oneDayAgo = eventTimestamp.addHours(-24);
            List<Tracking__c> recentEvents = [
                SELECT Id FROM Tracking__c 
                WHERE Motive_Vehicle_ID__c = :vehicleId 
                AND Motive_Event_ID__c = :eventId
                AND Event_Timestamp__c >= :oneDayAgo
                LIMIT 1
            ];
            
            return !recentEvents.isEmpty();
            
        } catch (Exception e) {
            logError('MotiveWebhookReceiver', 'isDuplicate', e);
            return false; // Don't block on error
        }
    }
    
    /**
     * Parse ISO 8601 datetime string to DateTime
     */
    private static DateTime parseDateTime(String dateTimeStr) {
        // Example: "2026-04-03T14:32:15Z"
        if (String.isEmpty(dateTimeStr)) {
            return DateTime.now();
        }
        try {
            // Remove 'Z' and parse
            String cleanDate = dateTimeStr.replace('Z', '+0000');
            return DateTime.parse(cleanDate);
        } catch (Exception e) {
            return DateTime.now();
        }
    }
    
    /**
     * Log error with exception details
     */
    private static void logError(String className, String methodName, Exception e) {
        System.debug(LoggingLevel.ERROR, 
            className + '.' + methodName + ': ' + e.getMessage() + ' ' + e.getStackTraceString());
    }
    
    /**
     * Log warning message
     */
    private static void logWarning(String message) {
        System.debug(LoggingLevel.WARN, 'MotiveWebhookReceiver: ' + message);
    }
    
    /**
     * Response DTO for success
     */
    private class SuccessResponse {
        public String status;
        public String message;
        
        SuccessResponse(String status, String message) {
            this.status = status;
            this.message = message;
        }
    }
    
    /**
     * Response DTO for errors
     */
    private class ErrorResponse {
        public String error;
        public String message;
        
        ErrorResponse(String error, String message) {
            this.error = error;
            this.message = message;
        }
    }
}
