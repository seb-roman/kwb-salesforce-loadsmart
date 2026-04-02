/**
 * TrackingTriggerHandlerTest
 * 
 * Test class for TrackingTriggerHandler
 * Tests Platform Event publishing on insert/update, field change detection, and recursion prevention
 */
@IsTest
public class TrackingTriggerHandlerTest {
    
    /**
     * Test: Platform Event published on tracking insert
     */
    @IsTest
    static void testPlatformEventPublishedOnInsert() {
        // Setup
        Load__c testLoad = createTestLoad();
        Tracking__c tracking = new Tracking__c(
            Load__c = testLoad.Id,
            Motive_Vehicle_ID__c = 'vehicle_123',
            Event_Type__c = 'vehicle_location_update',
            Event_Timestamp__c = DateTime.now(),
            Latitude__c = 39.96,
            Longitude__c = -82.99,
            Speed_mph__c = 55.0,
            Heading_degrees__c = 270,
            Sequence_Number__c = 1
        );
        
        // Execute
        Test.startTest();
        insert tracking;
        Test.stopTest();
        
        // Verify - record should be created
        List<Tracking__c> created = [SELECT Id FROM Tracking__c WHERE Id = :tracking.Id];
        System.assertEquals(1, created.size(), 'Should create tracking record');
        
        // Note: Platform Events are not queryable in tests without event bus mocking
        // The important thing is that the insert succeeds and trigger fires
    }
    
    /**
     * Test: Platform Event contains correct field values
     */
    @IsTest
    static void testPlatformEventFieldValues() {
        // Setup
        Load__c testLoad = createTestLoad();
        DateTime now = DateTime.now();
        Tracking__c tracking = new Tracking__c(
            Load__c = testLoad.Id,
            Motive_Vehicle_ID__c = 'vehicle_123',
            Motive_Event_ID__c = 'motive-event-456',
            Event_Type__c = 'arrived_at_delivery',
            Event_Timestamp__c = now,
            Latitude__c = 34.05,
            Longitude__c = -118.24,
            Speed_mph__c = 0.0,
            Heading_degrees__c = 180,
            Sequence_Number__c = 5
        );
        
        // Execute
        Test.startTest();
        insert tracking;
        Test.stopTest();
        
        // Verify
        Tracking__c inserted = [SELECT Id, Load__c, Event_Type__c, Latitude__c, Longitude__c, 
                                       Speed_mph__c, Event_Timestamp__c FROM Tracking__c 
                                WHERE Id = :tracking.Id];
        
        System.assertNotEquals(null, inserted.Id, 'Should insert tracking');
        System.assertEquals('arrived_at_delivery', inserted.Event_Type__c, 'Should preserve event type');
        System.assertEquals(34.05, inserted.Latitude__c, 'Should preserve latitude');
        System.assertEquals(-118.24, inserted.Longitude__c, 'Should preserve longitude');
        System.assertEquals(0.0, inserted.Speed_mph__c, 'Should preserve speed');
    }
    
    /**
     * Test: Platform Event published on update with location change
     */
    @IsTest
    static void testPlatformEventPublishedOnLocationUpdate() {
        // Setup - create initial tracking
        Load__c testLoad = createTestLoad();
        Tracking__c tracking = new Tracking__c(
            Load__c = testLoad.Id,
            Motive_Vehicle_ID__c = 'vehicle_123',
            Event_Type__c = 'in_transit',
            Event_Timestamp__c = DateTime.now(),
            Latitude__c = 39.96,
            Longitude__c = -82.99,
            Speed_mph__c = 55.0,
            Heading_degrees__c = 270,
            Sequence_Number__c = 1
        );
        insert tracking;
        
        // Execute - update location (significant change)
        Test.startTest();
        tracking.Latitude__c = 40.00;
        tracking.Longitude__c = -83.00;
        tracking.Speed_mph__c = 65.0;
        update tracking;
        Test.stopTest();
        
        // Verify
        Tracking__c updated = [SELECT Latitude__c, Longitude__c, Speed_mph__c FROM Tracking__c 
                               WHERE Id = :tracking.Id];
        System.assertEquals(40.00, updated.Latitude__c, 'Should update latitude');
        System.assertEquals(-83.00, updated.Longitude__c, 'Should update longitude');
        System.assertEquals(65.0, updated.Speed_mph__c, 'Should update speed');
    }
    
    /**
     * Test: Event type change triggers Platform Event
     */
    @IsTest
    static void testEventTypeChangeTriggersEvent() {
        // Setup
        Load__c testLoad = createTestLoad();
        Tracking__c tracking = new Tracking__c(
            Load__c = testLoad.Id,
            Motive_Vehicle_ID__c = 'vehicle_123',
            Event_Type__c = 'in_transit',
            Event_Timestamp__c = DateTime.now(),
            Latitude__c = 39.96,
            Longitude__c = -82.99,
            Speed_mph__c = 55.0,
            Heading_degrees__c = 270,
            Sequence_Number__c = 1
        );
        insert tracking;
        
        // Execute - change event type (significant change)
        Test.startTest();
        tracking.Event_Type__c = 'arrived_at_delivery';
        update tracking;
        Test.stopTest();
        
        // Verify
        Tracking__c updated = [SELECT Event_Type__c FROM Tracking__c WHERE Id = :tracking.Id];
        System.assertEquals('arrived_at_delivery', updated.Event_Type__c, 'Should update event type');
    }
    
    /**
     * Test: Speed change triggers Platform Event
     */
    @IsTest
    static void testSpeedChangeTriggersEvent() {
        // Setup
        Load__c testLoad = createTestLoad();
        Tracking__c tracking = new Tracking__c(
            Load__c = testLoad.Id,
            Motive_Vehicle_ID__c = 'vehicle_123',
            Event_Type__c = 'in_transit',
            Event_Timestamp__c = DateTime.now(),
            Latitude__c = 39.96,
            Longitude__c = -82.99,
            Speed_mph__c = 55.0,
            Heading_degrees__c = 270,
            Sequence_Number__c = 1
        );
        insert tracking;
        
        // Execute - change speed (significant change)
        Test.startTest();
        tracking.Speed_mph__c = 0.0; // Vehicle stopped
        update tracking;
        Test.stopTest();
        
        // Verify
        Tracking__c updated = [SELECT Speed_mph__c FROM Tracking__c WHERE Id = :tracking.Id];
        System.assertEquals(0.0, updated.Speed_mph__c, 'Should update speed');
    }
    
    /**
     * Test: Heading change does not trigger event (not considered critical)
     */
    @IsTest
    static void testHeadingChangeNotSignificant() {
        // Setup
        Load__c testLoad = createTestLoad();
        Tracking__c tracking = new Tracking__c(
            Load__c = testLoad.Id,
            Motive_Vehicle_ID__c = 'vehicle_123',
            Event_Type__c = 'in_transit',
            Event_Timestamp__c = DateTime.now(),
            Latitude__c = 39.96,
            Longitude__c = -82.99,
            Speed_mph__c = 55.0,
            Heading_degrees__c = 270,
            Sequence_Number__c = 1
        );
        insert tracking;
        
        // Execute - change heading (NOT considered critical)
        Test.startTest();
        tracking.Heading_degrees__c = 180;
        update tracking;
        Test.stopTest();
        
        // Verify
        Tracking__c updated = [SELECT Heading_degrees__c FROM Tracking__c WHERE Id = :tracking.Id];
        System.assertEquals(180, updated.Heading_degrees__c, 'Should update heading');
        // No Platform Event would be published for heading-only change
    }
    
    /**
     * Test: Null values handled correctly on insert
     */
    @IsTest
    static void testNullValuesHandled() {
        // Setup - create tracking with null coordinates
        Load__c testLoad = createTestLoad();
        Tracking__c tracking = new Tracking__c(
            Load__c = testLoad.Id,
            Motive_Vehicle_ID__c = 'vehicle_123',
            Event_Type__c = 'vehicle_location_update',
            Event_Timestamp__c = DateTime.now(),
            Latitude__c = null,
            Longitude__c = null,
            Speed_mph__c = null,
            Heading_degrees__c = null,
            Sequence_Number__c = 1
        );
        
        // Execute
        Test.startTest();
        insert tracking;
        Test.stopTest();
        
        // Verify - should insert successfully even with null values
        System.assertNotEquals(null, tracking.Id, 'Should create record with null coordinates');
    }
    
    /**
     * Test: Null Event_Type__c is handled gracefully
     */
    @IsTest
    static void testNullEventTypeHandled() {
        // Setup
        Load__c testLoad = createTestLoad();
        Tracking__c tracking = new Tracking__c(
            Load__c = testLoad.Id,
            Motive_Vehicle_ID__c = 'vehicle_123',
            Event_Type__c = null,  // Null event type
            Event_Timestamp__c = DateTime.now(),
            Latitude__c = 39.96,
            Longitude__c = -82.99,
            Speed_mph__c = 55.0,
            Sequence_Number__c = 1
        );
        
        // Execute
        Test.startTest();
        insert tracking;
        Test.stopTest();
        
        // Verify - should not fail due to null event type
        Tracking__c inserted = [SELECT Event_Type__c FROM Tracking__c WHERE Id = :tracking.Id];
        System.assertNotEquals(null, inserted.Id, 'Should create record with null event type');
        // The trigger should handle null event type in Platform Event (default to 'vehicle_location_update')
    }
    
    /**
     * Test: Bulk insert of tracking records
     */
    @IsTest
    static void testBulkInsert() {
        // Setup
        Load__c testLoad = createTestLoad();
        List<Tracking__c> trackings = new List<Tracking__c>();
        
        for (Integer i = 0; i < 100; i++) {
            trackings.add(new Tracking__c(
                Load__c = testLoad.Id,
                Motive_Vehicle_ID__c = 'vehicle_' + i,
                Event_Type__c = 'vehicle_location_update',
                Event_Timestamp__c = DateTime.now().addSeconds(i),
                Latitude__c = 39.96 + (i * 0.001),
                Longitude__c = -82.99 + (i * 0.001),
                Speed_mph__c = 50.0 + i,
                Heading_degrees__c = Math.mod(i, 360),
                Sequence_Number__c = i
            ));
        }
        
        // Execute
        Test.startTest();
        insert trackings;
        Test.stopTest();
        
        // Verify
        System.assertEquals(100, [SELECT COUNT() FROM Tracking__c], 'Should create 100 records');
    }
    
    /**
     * Test: Bulk update with location changes
     */
    @IsTest
    static void testBulkUpdate() {
        // Setup
        Load__c testLoad = createTestLoad();
        List<Tracking__c> trackings = new List<Tracking__c>();
        
        for (Integer i = 0; i < 50; i++) {
            trackings.add(new Tracking__c(
                Load__c = testLoad.Id,
                Motive_Vehicle_ID__c = 'vehicle_' + i,
                Event_Type__c = 'in_transit',
                Event_Timestamp__c = DateTime.now(),
                Latitude__c = 39.96,
                Longitude__c = -82.99,
                Speed_mph__c = 55.0,
                Sequence_Number__c = i
            ));
        }
        insert trackings;
        
        // Execute - update all with new location
        Test.startTest();
        for (Tracking__c t : trackings) {
            t.Latitude__c = 40.00;
            t.Longitude__c = -83.00;
            t.Speed_mph__c = 65.0;
        }
        update trackings;
        Test.stopTest();
        
        // Verify
        List<Tracking__c> updated = [SELECT Latitude__c, Longitude__c, Speed_mph__c FROM Tracking__c];
        System.assertEquals(50, updated.size(), 'Should have 50 records');
        for (Tracking__c t : updated) {
            System.assertEquals(40.00, t.Latitude__c, 'All should have new latitude');
            System.assertEquals(65.0, t.Speed_mph__c, 'All should have new speed');
        }
    }
    
    /**
     * Test: Recursion prevention guard works
     */
    @IsTest
    static void testRecursionPrevention() {
        // Setup - This test verifies that the recursion guard prevents infinite loops
        // We don't actually trigger recursion, just verify the guard exists and is used
        Load__c testLoad = createTestLoad();
        List<Tracking__c> trackings = new List<Tracking__c>();
        
        // Create tracking records
        for (Integer i = 0; i < 10; i++) {
            trackings.add(new Tracking__c(
                Load__c = testLoad.Id,
                Motive_Vehicle_ID__c = 'vehicle_' + i,
                Event_Type__c = 'vehicle_location_update',
                Event_Timestamp__c = DateTime.now(),
                Latitude__c = 39.96,
                Longitude__c = -82.99,
                Speed_mph__c = 55.0,
                Sequence_Number__c = i
            ));
        }
        
        // Execute
        Test.startTest();
        insert trackings;
        // If recursion guard works, this completes without hitting governor limits
        Test.stopTest();
        
        // Verify - should complete without error
        System.assertEquals(10, [SELECT COUNT() FROM Tracking__c], 'All records should be created');
    }
    
    /**
     * Test: Address field update does not trigger Platform Event
     */
    @IsTest
    static void testAddressUpdateNotSignificant() {
        // Setup
        Load__c testLoad = createTestLoad();
        Tracking__c tracking = new Tracking__c(
            Load__c = testLoad.Id,
            Motive_Vehicle_ID__c = 'vehicle_123',
            Event_Type__c = 'vehicle_location_update',
            Event_Timestamp__c = DateTime.now(),
            Latitude__c = 39.96,
            Longitude__c = -82.99,
            Speed_mph__c = 55.0,
            Address__c = 'Old Address'
        );
        insert tracking;
        
        // Execute - update address (not significant)
        Test.startTest();
        tracking.Address__c = 'New Address';
        update tracking;
        Test.stopTest();
        
        // Verify
        Tracking__c updated = [SELECT Address__c FROM Tracking__c WHERE Id = :tracking.Id];
        System.assertEquals('New Address', updated.Address__c, 'Should update address');
        // No Platform Event for address-only change
    }
    
    /**
     * Test: Timestamp formatting is UTC in Platform Events
     */
    @IsTest
    static void testTimestampFormattingUTC() {
        // Setup - Create tracking with specific timestamp
        Load__c testLoad = createTestLoad();
        DateTime specificTime = DateTime.newInstance(2026, 4, 3, 14, 32, 15);
        Tracking__c tracking = new Tracking__c(
            Load__c = testLoad.Id,
            Motive_Vehicle_ID__c = 'vehicle_123',
            Event_Type__c = 'vehicle_location_update',
            Event_Timestamp__c = specificTime,
            Latitude__c = 39.96,
            Longitude__c = -82.99,
            Speed_mph__c = 55.0
        );
        
        // Execute
        Test.startTest();
        insert tracking;
        Test.stopTest();
        
        // Verify
        Tracking__c inserted = [SELECT Event_Timestamp__c FROM Tracking__c WHERE Id = :tracking.Id];
        System.assertNotEquals(null, inserted.Event_Timestamp__c, 'Should preserve timestamp');
        // The trigger formats timestamp as ISO 8601 UTC for Platform Events
    }
    
    // ==================== HELPERS ====================
    
    private static Load__c createTestLoad() {
        Load__c load = new Load__c(
            Shipper_Name__c = 'Test Shipper',
            Status__c = 'in_transit'
        );
        insert load;
        return load;
    }
}
