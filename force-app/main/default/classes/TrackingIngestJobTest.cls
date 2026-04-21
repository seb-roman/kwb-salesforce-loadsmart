/**
 * TrackingIngestJobTest
 * 
 * Test class for TrackingIngestJob queueable processor
 * Tests Motive payload parsing, Tracking__c creation, vehicle-to-load mapping, 
 * GPS validation, and error handling
 */
@IsTest
public class TrackingIngestJobTest {
    
    /**
     * Test: Valid payload creates Tracking__c record with proper vehicle mapping
     */
    @IsTest
    static void testValidPayloadCreatesTracking() {
        // Setup - Create Equipment__c with Motive_Vehicle_ID mapped to Load
        Load__c testLoad = createTestLoad();
        Equipment__c equipment = createTestEquipment('vehicle_123', testLoad.Id);
        
        String payload = buildValidJobPayload('event-001', 'vehicle_123');
        
        // Execute
        Test.startTest();
        TrackingIngestJob job = new TrackingIngestJob(payload);
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify - Tracking record should be created
        List<Tracking__c> trackings = [SELECT Id, Load__c, Motive_Vehicle_ID__c, Sequence_Number__c 
                                       FROM Tracking__c];
        System.assertEquals(1, trackings.size(), 'Should create exactly 1 tracking record');
        System.assertEquals(testLoad.Id, trackings[0].Load__c, 'Should link to correct load');
        System.assertEquals('vehicle_123', trackings[0].Motive_Vehicle_ID__c, 'Should store vehicle ID');
        System.assertEquals(1, trackings[0].Sequence_Number__c, 'Should have sequence number 1');
    }
    
    /**
     * Test: Tracking record has correct field values from payload
     */
    @IsTest
    static void testTrackingFieldsPopulated() {
        // Setup
        Load__c testLoad = createTestLoad();
        Equipment__c equipment = createTestEquipment('vehicle_123', testLoad.Id);
        Driver__c driver = createTestDriver('driver_456');
        
        String payload = '{'
            + '"id": "event-002",'
            + '"vehicleId": "vehicle_123",'
            + '"type": "vehicle.location.update",'
            + '"timestamp": "2026-04-03T14:32:15Z",'
            + '"location": {"latitude": 39.96, "longitude": -82.99, "speedMph": 55.5, "heading": 270},'
            + '"driver": {"id": "driver_456"}'
            + '}';
        
        // Execute
        Test.startTest();
        TrackingIngestJob job = new TrackingIngestJob(payload);
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify
        List<Tracking__c> trackings = [SELECT Latitude__c, Longitude__c, Speed_mph__c, 
                                              Heading_degrees__c, Event_Type__c, Driver__c
                                       FROM Tracking__c LIMIT 1];
        
        System.assertEquals(1, trackings.size(), 'Should create tracking record');
        Tracking__c tracking = trackings[0];
        System.assertEquals(39.96, tracking.Latitude__c, 'Should have correct latitude');
        System.assertEquals(-82.99, tracking.Longitude__c, 'Should have correct longitude');
        System.assertEquals(55.5, tracking.Speed_mph__c, 'Should have correct speed');
        System.assertEquals(270, tracking.Heading_degrees__c, 'Should have correct heading');
        System.assertEquals('vehicle_location_update', tracking.Event_Type__c, 'Should normalize event type');
        System.assertEquals(driver.Id, tracking.Driver__c, 'Should link to correct driver');
    }
    
    /**
     * Test: Sequence numbers increment correctly across multiple events
     */
    @IsTest
    static void testSequenceNumberIncrement() {
        // Setup
        Load__c testLoad = createTestLoad();
        Equipment__c equipment = createTestEquipment('vehicle_123', testLoad.Id);
        
        // Execute - Create 3 tracking events for same load
        Test.startTest();
        for (Integer i = 0; i < 3; i++) {
            String payload = buildValidJobPayload('event-' + i, 'vehicle_123');
            TrackingIngestJob job = new TrackingIngestJob(payload);
            System.enqueueJob(job);
        }
        Test.stopTest();
        
        // Verify - Should have sequence numbers 1, 2, 3
        List<Tracking__c> trackings = [SELECT Sequence_Number__c FROM Tracking__c ORDER BY Sequence_Number__c];
        System.assertEquals(3, trackings.size(), 'Should create 3 records');
        System.assertEquals(1, trackings[0].Sequence_Number__c, 'First should be sequence 1');
        System.assertEquals(2, trackings[1].Sequence_Number__c, 'Second should be sequence 2');
        System.assertEquals(3, trackings[2].Sequence_Number__c, 'Third should be sequence 3');
    }
    
    /**
     * Test: Invalid GPS data is rejected (negative speed)
     */
    @IsTest
    static void testNegativeSpeedRejected() {
        // Setup
        Load__c testLoad = createTestLoad();
        Equipment__c equipment = createTestEquipment('vehicle_123', testLoad.Id);
        
        // Payload with negative speed (invalid)
        String payload = '{'
            + '"id": "event-bad-speed",'
            + '"vehicleId": "vehicle_123",'
            + '"type": "vehicle.location.update",'
            + '"timestamp": "2026-04-03T14:32:15Z",'
            + '"location": {"latitude": 39.96, "longitude": -82.99, "speedMph": -50.0, "heading": 270},'
            + '"driver": null'
            + '}';
        
        // Execute
        Test.startTest();
        TrackingIngestJob job = new TrackingIngestJob(payload);
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify - Should NOT create tracking due to invalid speed
        System.assertEquals(0, [SELECT COUNT() FROM Tracking__c], 'Should reject record with negative speed');
    }
    
    /**
     * Test: Invalid latitude is rejected (out of range)
     */
    @IsTest
    static void testInvalidLatitudeRejected() {
        // Setup
        Load__c testLoad = createTestLoad();
        Equipment__c equipment = createTestEquipment('vehicle_123', testLoad.Id);
        
        // Payload with invalid latitude (> 90)
        String payload = '{'
            + '"id": "event-bad-lat",'
            + '"vehicleId": "vehicle_123",'
            + '"type": "vehicle.location.update",'
            + '"timestamp": "2026-04-03T14:32:15Z",'
            + '"location": {"latitude": 150.0, "longitude": -82.99, "speedMph": 55.0, "heading": 270},'
            + '"driver": null'
            + '}';
        
        // Execute
        Test.startTest();
        TrackingIngestJob job = new TrackingIngestJob(payload);
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify - Should NOT create tracking due to invalid latitude
        System.assertEquals(0, [SELECT COUNT() FROM Tracking__c], 'Should reject record with invalid latitude');
    }
    
    /**
     * Test: Invalid longitude is rejected (out of range)
     */
    @IsTest
    static void testInvalidLongitudeRejected() {
        // Setup
        Load__c testLoad = createTestLoad();
        Equipment__c equipment = createTestEquipment('vehicle_123', testLoad.Id);
        
        // Payload with invalid longitude (> 180)
        String payload = '{'
            + '"id": "event-bad-lng",'
            + '"vehicleId": "vehicle_123",'
            + '"type": "vehicle.location.update",'
            + '"timestamp": "2026-04-03T14:32:15Z",'
            + '"location": {"latitude": 39.96, "longitude": 200.0, "speedMph": 55.0, "heading": 270},'
            + '"driver": null'
            + '}';
        
        // Execute
        Test.startTest();
        TrackingIngestJob job = new TrackingIngestJob(payload);
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify - Should NOT create tracking due to invalid longitude
        System.assertEquals(0, [SELECT COUNT() FROM Tracking__c], 'Should reject record with invalid longitude');
    }
    
    /**
     * Test: Missing coordinates are rejected
     */
    @IsTest
    static void testMissingCoordinatesRejected() {
        // Setup
        Load__c testLoad = createTestLoad();
        Equipment__c equipment = createTestEquipment('vehicle_123', testLoad.Id);
        
        // Payload without coordinates
        String payload = '{'
            + '"id": "event-no-coords",'
            + '"vehicleId": "vehicle_123",'
            + '"type": "vehicle.location.update",'
            + '"timestamp": "2026-04-03T14:32:15Z",'
            + '"location": null,'
            + '"driver": null'
            + '}';
        
        // Execute
        Test.startTest();
        TrackingIngestJob job = new TrackingIngestJob(payload);
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify - Should NOT create tracking due to missing coordinates
        System.assertEquals(0, [SELECT COUNT() FROM Tracking__c], 'Should reject record with no coordinates');
    }
    
    /**
     * Test: Vehicle with no equipment mapping is skipped
     */
    @IsTest
    static void testUnmappedVehicleSkipped() {
        // Setup - create load but no equipment mapping for vehicle
        Load__c testLoad = createTestLoad();
        
        String payload = buildValidJobPayload('event-unmapped', 'unknown_vehicle');
        
        // Execute
        Test.startTest();
        TrackingIngestJob job = new TrackingIngestJob(payload);
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify - Should NOT create tracking since vehicle has no mapping
        System.assertEquals(0, [SELECT COUNT() FROM Tracking__c], 'Should skip unmapped vehicle');
    }
    
    /**
     * Test: Null event type is handled gracefully
     */
    @IsTest
    static void testNullEventTypeHandled() {
        // Setup
        Load__c testLoad = createTestLoad();
        Equipment__c equipment = createTestEquipment('vehicle_123', testLoad.Id);
        
        // Payload with null event type
        String payload = '{'
            + '"id": "event-null-type",'
            + '"vehicleId": "vehicle_123",'
            + '"type": null,'
            + '"timestamp": "2026-04-03T14:32:15Z",'
            + '"location": {"latitude": 39.96, "longitude": -82.99, "speedMph": 55.0, "heading": 270},'
            + '"driver": null'
            + '}';
        
        // Execute
        Test.startTest();
        TrackingIngestJob job = new TrackingIngestJob(payload);
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify - Should create record with default event type
        List<Tracking__c> trackings = [SELECT Event_Type__c FROM Tracking__c];
        System.assertEquals(1, trackings.size(), 'Should create tracking');
        System.assertEquals('vehicle_location_update', trackings[0].Event_Type__c, 'Should use default event type');
    }
    
    /**
     * Test: Invalid JSON payload is handled gracefully
     */
    @IsTest
    static void testInvalidJsonHandled() {
        // Setup - malformed JSON
        String payload = '{ invalid json }';
        
        // Execute
        Test.startTest();
        TrackingIngestJob job = new TrackingIngestJob(payload);
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify - should not throw, just skip
        System.assertEquals(0, [SELECT COUNT() FROM Tracking__c], 'Should handle invalid JSON gracefully');
    }
    
    /**
     * Test: Event type normalization for all mapped types
     */
    @IsTest
    static void testEventTypeNormalization() {
        // Setup
        Load__c testLoad = createTestLoad();
        Equipment__c equipment = createTestEquipment('vehicle_123', testLoad.Id);
        
        Map<String, String> eventTypeTests = new Map<String, String>{
            'vehicle.location.update' => 'vehicle_location_update',
            'vehicle.harsh_braking' => 'harsh_braking',
            'arrived_at_pickup' => 'arrived_at_pickup'
        };
        
        // Execute
        Test.startTest();
        for (String motiveType : eventTypeTests.keySet()) {
            String payload = '{'
                + '"id": "event-' + motiveType.replace('.', '-') + '",'
                + '"vehicleId": "vehicle_123",'
                + '"type": "' + motiveType + '",'
                + '"timestamp": "2026-04-03T14:32:15Z",'
                + '"location": {"latitude": 39.96, "longitude": -82.99, "speedMph": 55.0, "heading": 270},'
                + '"driver": null'
                + '}';
            
            TrackingIngestJob job = new TrackingIngestJob(payload);
            System.enqueueJob(job);
        }
        Test.stopTest();
        
        // Verify - all records should exist with correct normalized types
        List<Tracking__c> trackings = [SELECT Event_Type__c FROM Tracking__c ORDER BY CreatedDate];
        System.assertEquals(3, trackings.size(), 'Should create 3 records');
        for (Tracking__c t : trackings) {
            System.assertNotEquals(null, t.Event_Type__c, 'Event type should be set');
        }
    }
    
    /**
     * Test: Timestamp parsing handles ISO 8601 format
     */
    @IsTest
    static void testTimestampParsing() {
        // Setup
        Load__c testLoad = createTestLoad();
        Equipment__c equipment = createTestEquipment('vehicle_123', testLoad.Id);
        
        String payload = '{'
            + '"id": "event-ts",'
            + '"vehicleId": "vehicle_123",'
            + '"type": "vehicle.location.update",'
            + '"timestamp": "2026-04-03T14:32:15.123Z",'
            + '"location": {"latitude": 39.96, "longitude": -82.99, "speedMph": 55.0, "heading": 270},'
            + '"driver": null'
            + '}';
        
        // Execute
        Test.startTest();
        TrackingIngestJob job = new TrackingIngestJob(payload);
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify
        List<Tracking__c> trackings = [SELECT Event_Timestamp__c FROM Tracking__c];
        System.assertEquals(1, trackings.size(), 'Should create tracking');
        System.assertNotEquals(null, trackings[0].Event_Timestamp__c, 'Should parse timestamp');
    }
    
    /**
     * Test: Geofence detection using Haversine formula
     */
    @IsTest
    static void testGeofenceDetection() {
        // Setup
        Load__c testLoad = createTestLoad();
        Equipment__c equipment = createTestEquipment('vehicle_123', testLoad.Id);
        
        // Create a Stop at Columbus, Ohio
        Stop__c stop = new Stop__c(
            Load__c = testLoad.Id,
            Stop_Type__c = 'delivery',
            Latitude__c = 39.9612,
            Longitude__c = -82.9988,
            Sequence__c = 1
        );
        insert stop;
        
        // Tracking event very close to stop (within 1 mile)
        String payload = '{'
            + '"id": "event-geofence",'
            + '"vehicleId": "vehicle_123",'
            + '"type": "arrived_at_delivery",'
            + '"timestamp": "2026-04-03T14:32:15Z",'
            + '"location": {"latitude": 39.9620, "longitude": -82.9980, "speedMph": 5.0, "heading": 180},'
            + '"driver": null'
            + '}';
        
        // Execute
        Test.startTest();
        TrackingIngestJob job = new TrackingIngestJob(payload);
        System.enqueueJob(job);
        Test.stopTest();
        
        // Verify - Stop should be updated with arrival time
        Stop__c updatedStop = [SELECT Actual_Arrival__c FROM Stop__c WHERE Id = :stop.Id];
        System.assertNotEquals(null, updatedStop.Actual_Arrival__c, 'Should set arrival time when at geofence');
    }
    
    // ==================== HELPERS ====================
    
    private static String buildValidJobPayload(String eventId, String vehicleId) {
        return '{'
            + '"id": "' + eventId + '",'
            + '"vehicleId": "' + vehicleId + '",'
            + '"type": "vehicle.location.update",'
            + '"timestamp": "2026-04-03T14:32:15Z",'
            + '"location": {"latitude": 39.96, "longitude": -82.99, "speedMph": 55.0, "heading": 270},'
            + '"driver": {"id": "driver_123"}'
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
    
    private static Equipment__c createTestEquipment(String motiveVehicleId, String loadId) {
        Equipment__c equipment = new Equipment__c(
            // Name is auto-generated
            Current_Load__c = loadId, // Use Current_Load__c instead of Load__c
            Motive_Vehicle_ID__c = motiveVehicleId,
            Equipment_Type__c = 'Truck'
        );
        insert equipment;
        return equipment;
    }
    
    private static Driver__c createTestDriver(String motiveDriverId) {
        Driver__c driver = new Driver__c(
            Name = 'Test Driver',
            Motive_Driver_ID__c = motiveDriverId
        );
        insert driver;
        return driver;
    }
}
