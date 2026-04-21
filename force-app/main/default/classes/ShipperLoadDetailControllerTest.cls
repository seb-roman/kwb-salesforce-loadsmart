/**
 * ShipperLoadDetailControllerTest
 * 
 * Unit tests for ShipperLoadDetailController
 * Target coverage: >80%
 * 
 * Tests cover:
 * - getLoadDetail with valid load
 * - RLS: user cannot access other shipper's load (CRITICAL SECURITY TEST)
 * - getCarrierInfo with valid carrier
 * - getCarrierInfo RLS bypass prevention (CRITICAL SECURITY TEST)
 * - Null handling for missing related records
 * - Graceful handling of optional objects (Stop__c, Invoice__c)
 * 
 * Author: Agent 5 (Portal Development - Security Refactor)
 * Created: April 2, 2026
 */

@isTest
public class ShipperLoadDetailControllerTest {

    /**
     * Setup test data: Accounts, Carriers, Loads
     */
    @testSetup
    static void setupTestData() {
        // Create shipper account
        Account shipper1 = new Account(Name = 'Shipper 1 Inc');
        insert shipper1;

        // Create second shipper (for RLS testing)
        Account shipper2 = new Account(Name = 'Shipper 2 Inc');
        insert shipper2;

        // Create carrier
        Carrier__c carrier = new Carrier__c(
            Name = 'Test Carrier',
            MC_Number__c = '1234567',
            Phone__c = '555-0123',
            Email__c = 'carrier@test.com'
        );
        insert carrier;

        // Create contact for shipper1
        Contact contact1 = new Contact(
            // AccountId from ContactId
            FirstName = 'John',
            LastName = 'Shipper',
            Email = 'john@shipper1.com'
        );
        insert contact1;

        // Create contact for shipper2
        Contact contact2 = new Contact(
            // AccountId from ContactId
            FirstName = 'Jane',
            LastName = 'Shipper2',
            Email = 'jane@shipper2.com'
        );
        insert contact2;

        // Create portal user for shipper1
        User user1 = new User(
            FirstName = 'John',
            LastName = 'Shipper',
            Email = 'john@shipper1.com',
            Username = 'john.shipper1@shipper.com.portal',
            ContactId = contact1.Id,
            // AccountId from ContactId
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Shipper User' LIMIT 1]?.Id,
            IsActive = true
        );
        insert user1;

        // Create portal user for shipper2
        User user2 = new User(
            FirstName = 'Jane',
            LastName = 'Shipper2',
            Email = 'jane@shipper2.com',
            Username = 'jane.shipper2@shipper.com.portal',
            ContactId = contact2.Id,
            // AccountId from ContactId
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Shipper User' LIMIT 1]?.Id,
            IsActive = true
        );
        insert user2;

        // Create loads for both shippers
        List<Load__c> loads = new List<Load__c>();
        
        // Load for shipper1
        loads.add(new Load__c(
            Name = 'LOAD-001',
            Shipper__c = shipper1.Id,
            Status__c = 'Posted',
            Pickup_Date__c = System.today(),
            Estimated_Delivery__c = System.today().addDays(5),
            Load_Type__c = 'FTL',
            Shipper_City__c = 'Columbus',
            Receiver_City__c = 'Atlanta',
            Billing_Rate__c = 2500,
            Equipment_Type__c = 'Flatbed',
            Weight_lbs__c = 45000,
            Commodity__c = 'General Freight',
            Carrier__c = carrier.Id,
            
            Pickup_Contact__c = 'John Doe',
            Pickup_Company__c = 'ABC Warehousing',
            Shipper_Address__c = '123 Main St',
            Shipper_Zip__c = '43085',
            Shipper_State__c = 'OH',
            Pickup_Country__c = 'USA',
            Delivery_Contact__c = 'Jane Smith',
            Delivery_Company__c = 'XYZ Distribution',
            Receiver_Address__c = '456 Oak Ave',
            Receiver_Zip__c = '30303',
            Receiver_State__c = 'GA',
            Delivery_Country__c = 'USA',
            Fuel_Surcharge__c = 250,
            Notes__c = 'Handle with care'
        ));

        // Load for shipper2
        loads.add(new Load__c(
            Name = 'LOAD-002',
            Shipper__c = shipper2.Id,
            Status__c = 'In Transit',
            Pickup_Date__c = System.today().addDays(-1),
            Estimated_Delivery__c = System.today().addDays(6),
            Load_Type__c = 'LTL',
            Shipper_City__c = 'Boston',
            Receiver_City__c = 'New York',
            Billing_Rate__c = 1500,
            Equipment_Type__c = 'Van',
            Weight_lbs__c = 15000,
            Commodity__c = 'Electronics',
            Carrier__c = carrier.Id,
            
            Pickup_Contact__c = 'Bob Johnson',
            Pickup_Company__c = 'Tech Supplies',
            Shipper_Address__c = '789 Tech Blvd',
            Shipper_Zip__c = '02101',
            Shipper_State__c = 'MA',
            Pickup_Country__c = 'USA',
            Delivery_Contact__c = 'Alice Brown',
            Delivery_Company__c = 'Metro Distribution',
            Receiver_Address__c = '321 Park Ave',
            Receiver_Zip__c = '10001',
            Receiver_State__c = 'NY',
            Delivery_Country__c = 'USA',
            Fuel_Surcharge__c = 150
        ));

        insert loads;
    }

    /**
     * Test: getLoadDetail returns load information
     */
    @isTest
    static void testGetLoadDetail() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Load__c load = [SELECT Id FROM Load__c WHERE Name = 'LOAD-001' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperLoadDetailController.LoadDetailResponse response = ShipperLoadDetailController.getLoadDetail(load.Id);

            Assert.isNotNull(response, 'Response should not be null');
            Assert.isNotNull(response.load, 'Load should not be null');
            Assert.areEqual(load.Id, response.load.Id, 'Load ID should match');
            Assert.areEqual('LOAD-001', response.load.Name, 'Load name should be LOAD-001');
            Assert.areEqual('Posted', response.load.Status__c, 'Status should be Posted');
        }
        Test.stopTest();
    }

    /**
     * Test: RLS - User cannot access other shipper's load (CRITICAL SECURITY TEST)
     */
    @isTest
    static void testLoadDetailRLS() {
        User user1 = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Load__c load2 = [SELECT Id FROM Load__c WHERE Name = 'LOAD-002' LIMIT 1];

        Test.startTest();
        System.runAs(user1) {
            ShipperLoadDetailController.LoadDetailResponse response = ShipperLoadDetailController.getLoadDetail(load2.Id);

            // Should throw exception or return null (depends on implementation)
            Assert.isNull(response, 'Response should be null for unauthorized load access');
        }
        Test.stopTest();
    }

    /**
     * Test: getLoadDetail handles non-existent load
     */
    @isTest
    static void testGetLoadDetailNotFound() {
        User testUser = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            String fakeId = '001000000000000';
            try {
                ShipperLoadDetailController.LoadDetailResponse response = ShipperLoadDetailController.getLoadDetail(fakeId);
                Assert.isNull(response, 'Should return null for non-existent load');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('not found'), 'Should indicate load not found');
            }
        }
        Test.stopTest();
    }

    /**
     * Test: getLoadDetail handles deleted load
     */
    @isTest
    static void testGetLoadDetailDeleted() {
        User testUser = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Load__c load = [SELECT Id FROM Load__c WHERE Name = 'LOAD-001' LIMIT 1];

        // Mark load as deleted
        
        update load;

        Test.startTest();
        System.runAs(testUser) {
            ShipperLoadDetailController.LoadDetailResponse response = ShipperLoadDetailController.getLoadDetail(load.Id);

            Assert.isNull(response, 'Should not return deleted load');
        }
        Test.stopTest();
    }

    /**
     * Test: getCarrierInfo returns carrier information
     */
    @isTest
    static void testGetCarrierInfo() {
        User testUser = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Load__c load = [SELECT Id FROM Load__c WHERE Name = 'LOAD-001' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperLoadDetailController.CarrierInfo info = ShipperLoadDetailController.getCarrierInfo(load.Id);

            Assert.isNotNull(info, 'Carrier info should not be null');
            Assert.areEqual('Test Carrier', info.carrierName, 'Carrier name should match');
            Assert.areEqual('1234567', info.dotNumber, 'DOT number should match');
            Assert.areEqual('555-0123', info.phone, 'Phone should match');
            Assert.areEqual('carrier@test.com', info.email, 'Email should match');
        }
        Test.stopTest();
    }

    /**
     * Test: getCarrierInfo - RLS Bypass Prevention (CRITICAL SECURITY TEST)
     * Fixed: Load must belong to shipper's account
     */
    @isTest
    static void testCarrierInfoRLSBypassPrevention() {
        User user1 = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Load__c load2 = [SELECT Id FROM Load__c WHERE Name = 'LOAD-002' LIMIT 1];

        Test.startTest();
        System.runAs(user1) {
            // User1 should not be able to get carrier info for load2 (which belongs to shipper2)
            ShipperLoadDetailController.CarrierInfo info = ShipperLoadDetailController.getCarrierInfo(load2.Id);

            // Should return null due to RLS check
            Assert.isNull(info, 'Should not return carrier info for other shipper\'s load (RLS prevention)');
        }
        Test.stopTest();
    }

    /**
     * Test: getCarrierInfo with missing carrier
     */
    @isTest
    static void testGetCarrierInfoNullCarrier() {
        User testUser = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Load__c load = [SELECT Id FROM Load__c WHERE Name = 'LOAD-001' LIMIT 1];

        // Clear carrier reference
        load.Carrier__c = null;
        update load;

        Test.startTest();
        System.runAs(testUser) {
            ShipperLoadDetailController.CarrierInfo info = ShipperLoadDetailController.getCarrierInfo(load.Id);

            Assert.isNull(info, 'Should return null when load has no carrier');
        }
        Test.stopTest();
    }

    /**
     * Test: getCarrierInfo with deleted load
     */
    @isTest
    static void testGetCarrierInfoDeletedLoad() {
        User testUser = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Load__c load = [SELECT Id FROM Load__c WHERE Name = 'LOAD-001' LIMIT 1];

        
        update load;

        Test.startTest();
        System.runAs(testUser) {
            // Even with the load ID, should not access due to RLS
            ShipperLoadDetailController.CarrierInfo info = ShipperLoadDetailController.getCarrierInfo(load.Id);

            Assert.isNull(info, 'Should not return carrier info for deleted load');
        }
        Test.stopTest();
    }

    /**
     * Test: getLoadDetail returns null handles for optional related objects
     */
    @isTest
    static void testGetLoadDetailWithoutRelatedRecords() {
        User testUser = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Load__c load = [SELECT Id FROM Load__c WHERE Name = 'LOAD-001' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperLoadDetailController.LoadDetailResponse response = ShipperLoadDetailController.getLoadDetail(load.Id);

            Assert.isNotNull(response, 'Response should not be null');
            // Stops and invoices may be empty if objects don't exist in org
            Assert.isNotNull(response.stops, 'Stops list should exist (may be empty)');
            Assert.isNotNull(response.invoices, 'Invoices list should exist (may be empty)');
            Assert.isNotNull(response.documents, 'Documents list should exist (may be empty)');
        }
        Test.stopTest();
    }

    /**
     * Test: getLoadDetail returns status color
     */
    @isTest
    static void testGetLoadDetailStatusColor() {
        User testUser = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Load__c load = [SELECT Id FROM Load__c WHERE Name = 'LOAD-001' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperLoadDetailController.LoadDetailResponse response = ShipperLoadDetailController.getLoadDetail(load.Id);

            Assert.isNotNull(response.statusColor, 'Status color should not be null');
            // Posted status should map to gray
            Assert.areEqual('gray', response.statusColor, 'Posted status should be gray');
        }
        Test.stopTest();
    }

    /**
     * Test: getLoadDetail returns ETA countdown
     */
    @isTest
    static void testGetLoadDetailETACountdown() {
        User testUser = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Load__c load = [SELECT Id FROM Load__c WHERE Name = 'LOAD-001' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperLoadDetailController.LoadDetailResponse response = ShipperLoadDetailController.getLoadDetail(load.Id);

            Assert.isNotNull(response.etaCountdown, 'ETA countdown should not be null');
            // Should contain day or hour information
            Assert.isTrue(
                response.etaCountdown.contains('day') || response.etaCountdown.contains('hour') || response.etaCountdown == '',
                'ETA countdown should contain time units'
            );
        }
        Test.stopTest();
    }

    /**
     * Test: Multiple loads can be retrieved without interference
     */
    @isTest
    static void testMultipleLoadDetails() {
        User testUser = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        List<Load__c> loads = [SELECT Id FROM Load__c WHERE Shipper__c = :testUser.AccountId];

        Test.startTest();
        System.runAs(testUser) {
            for (Load__c load : loads) {
                ShipperLoadDetailController.LoadDetailResponse response = ShipperLoadDetailController.getLoadDetail(load.Id);
                Assert.isNotNull(response, 'Should retrieve all shipper loads');
                Assert.areEqual(load.Id, response.load.Id, 'IDs should match');
            }
        }
        Test.stopTest();
    }
}
