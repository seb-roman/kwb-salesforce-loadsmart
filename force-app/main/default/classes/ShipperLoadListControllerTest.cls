/**
 * ShipperLoadListControllerTest
 * 
 * Unit tests for ShipperLoadListController
 * Target coverage: >80%
 * 
 * Author: Agent 5 (Portal Development)
 * Created: April 2, 2026
 */

@isTest
public class ShipperLoadListControllerTest {

    /**
     * Setup test data: Account + User + Loads
     */
    @testSetup
    static void setupTestData() {
        // Create test account (shipper)
        Account shipper = new Account(
            Name = 'Test Shipper Inc',
            Type = 'Customer'
        );
        insert shipper;

        // Create test contact
        Contact contact = new Contact(
            // AccountId set via ContactId
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john@shipper.com'
        );
        insert contact;

        // Create test user (portal user)
        User portalUser = new User(
            FirstName = 'John',
            LastName = 'Shipper',
            Email = 'john@shipper.com',
            Username = 'john.shipper@shipper.com.portal',
            ContactId = contact.Id,
            // AccountId set via ContactId
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Shipper User' LIMIT 1]?.Id,
            IsActive = true
        );
        insert portalUser;

        // Create test loads
        List<Load__c> loads = new List<Load__c>();
        for (Integer i = 0; i < 35; i++) {
            loads.add(new Load__c(
                Name = 'LOAD-' + (i + 1),
                Shipper__c = shipper.Id,
                Status__c = i < 10 ? 'Posted' : (i < 20 ? 'In Transit' : 'Delivered'),
                Pickup_Date__c = System.today().addDays(-10 + i),
                Estimated_Delivery__c = System.today().addDays(i + 5),
                Load_Type__c = Math.mod(i, 2) == 0 ? 'FTL' : 'LTL',
                Shipper_City__c = 'Columbus',
                Receiver_City__c = 'Atlanta',
                Billing_Rate__c = 2500 + (i * 100),
                Equipment_Type__c = 'Flatbed',
                Weight_lbs__c = 45000,
                Commodity__c = 'General Freight'
            ));
        }
        insert loads;
    }

    /**
     * Test: getShipperAccountId returns correct account ID
     */
    @isTest
    static void testGetShipperAccountId() {
        // Get test user
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            String accountId = ShipperLoadListController.getShipperAccountId();
            Assert.isNotNull(accountId, 'Account ID should not be null');
            Assert.areEqual(testUser.AccountId, accountId, 'Returned account ID should match user account');
        }
        Test.stopTest();
    }

    /**
     * Test: getLoads returns all loads for shipper (no filters)
     */
    @isTest
    static void testGetLoadsNoFilters() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperLoadListController.LoadListResponse response = ShipperLoadListController.getLoads(
                'All',      // statusFilter
                '',         // dateFrom
                '',         // dateTo
                'All',      // loadType
                1,          // pageNumber
                25          // pageSize
            );

            Assert.isNotNull(response, 'Response should not be null');
            Assert.areEqual(25, response.loads.size(), 'Should return 25 loads (first page)');
            Assert.areEqual(35, response.totalRecords, 'Total should be 35 loads');
            Assert.areEqual(2, response.totalPages, 'Total pages should be 2');
            Assert.areEqual(1, response.pageNumber, 'Page number should be 1');
        }
        Test.stopTest();
    }

    /**
     * Test: getLoads with status filter
     */
    @isTest
    static void testGetLoadsWithStatusFilter() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperLoadListController.LoadListResponse response = ShipperLoadListController.getLoads(
                'Posted',   // statusFilter
                '',
                '',
                'All',
                1,
                25
            );

            Assert.isNotNull(response, 'Response should not be null');
            Assert.areEqual(10, response.totalRecords, 'Should return 10 Posted loads');
            
            // Verify all returned loads have Posted status
            for (Load__c load : response.loads) {
                Assert.areEqual('Posted', load.Status__c, 'All loads should be Posted');
            }
        }
        Test.stopTest();
    }

    /**
     * Test: getLoads with load type filter
     */
    @isTest
    static void testGetLoadsWithLoadTypeFilter() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperLoadListController.LoadListResponse response = ShipperLoadListController.getLoads(
                'All',
                '',
                '',
                'FTL',      // loadType filter
                1,
                25
            );

            Assert.isNotNull(response, 'Response should not be null');
            System.assert(response.totalRecords > 0, 'Should return FTL loads');
            
            // Verify all returned loads have FTL type
            for (Load__c load : response.loads) {
                Assert.areEqual('FTL', load.Load_Type__c, 'All loads should be FTL');
            }
        }
        Test.stopTest();
    }

    /**
     * Test: getLoads pagination
     */
    @isTest
    static void testGetLoadsPagination() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            // Get first page
            ShipperLoadListController.LoadListResponse page1 = ShipperLoadListController.getLoads(
                'All', '', '', 'All', 1, 25
            );
            Assert.areEqual(25, page1.loads.size(), 'Page 1 should have 25 loads');

            // Get second page
            ShipperLoadListController.LoadListResponse page2 = ShipperLoadListController.getLoads(
                'All', '', '', 'All', 2, 25
            );
            Assert.areEqual(10, page2.loads.size(), 'Page 2 should have 10 loads');

            // Verify no overlap
            Set<Id> page1Ids = new Map<Id, Load__c>((List<Load__c>)page1.loads).keySet();
            Set<Id> page2Ids = new Map<Id, Load__c>((List<Load__c>)page2.loads).keySet();
            page1Ids.retainAll(page2Ids);
            Assert.areEqual(0, page1Ids.size(), 'Pages should not have overlapping loads');
        }
        Test.stopTest();
    }

    /**
     * Test: getStatusOptions returns valid status values
     */
    @isTest
    static void testGetStatusOptions() {
        Test.startTest();
        List<String> statuses = ShipperLoadListController.getStatusOptions();

        Assert.isNotNull(statuses, 'Status options should not be null');
        System.assert(statuses.size() > 0, 'Should return at least one status option');
        // Verify expected statuses exist
        Assert.isTrue(statuses.contains('Posted'), 'Posted status should exist');
        Assert.isTrue(statuses.contains('In Transit'), 'In Transit status should exist');
        Assert.isTrue(statuses.contains('Delivered'), 'Delivered status should exist');
        Test.stopTest();
    }

    /**
     * Test: getLoadTypeOptions returns valid load type values
     */
    @isTest
    static void testGetLoadTypeOptions() {
        Test.startTest();
        List<String> loadTypes = ShipperLoadListController.getLoadTypeOptions();

        Assert.isNotNull(loadTypes, 'Load type options should not be null');
        System.assert(loadTypes.size() > 0, 'Should return at least one load type');
        // Verify expected load types exist
        Assert.isTrue(loadTypes.contains('FTL'), 'FTL should exist');
        Assert.isTrue(loadTypes.contains('LTL'), 'LTL should exist');
        Test.stopTest();
    }

    /**
     * Test: Row-level security - user cannot see other shipper's loads
     */
    @isTest
    static void testRowLevelSecurity() {
        // Create second shipper and user
        Account shipper2 = new Account(Name = 'Other Shipper Inc');
        insert shipper2;

        Contact contact2 = new Contact(
            // AccountId set via ContactId
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane@othershiper.com'
        );
        insert contact2;

        User user2 = new User(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane@othershiper.com',
            Username = 'jane.smith@othershiper.com.portal',
            ContactId = contact2.Id,
            // AccountId set via ContactId
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Shipper User' LIMIT 1]?.Id,
            IsActive = true
        );
        insert user2;

        // Create load for shipper2
        Load__c load2 = new Load__c(
            Name = 'LOAD-SHIPPER2',
            Shipper__c = shipper2.Id,
            Status__c = 'Posted',
            Pickup_Date__c = System.today(),
            Estimated_Delivery__c = System.today().addDays(5),
            Load_Type__c = 'FTL',
            Shipper_City__c = 'Columbus',
            Receiver_City__c = 'Atlanta',
            Billing_Rate__c = 2500,
            Equipment_Type__c = 'Flatbed',
            Weight_lbs__c = 45000,
            Commodity__c = 'General Freight'
        );
        insert load2;

        // Test with first user
        User testUser1 = [SELECT Id FROM User WHERE Username = 'john.shipper@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser1) {
            ShipperLoadListController.LoadListResponse response = ShipperLoadListController.getLoads(
                'All', '', '', 'All', 1, 50
            );

            // First user should not see second shipper's load
            Boolean foundLoad2 = false;
            for (Load__c load : response.loads) {
                if (load.Id == load2.Id) {
                    foundLoad2 = true;
                    break;
                }
            }
            Assert.isFalse(foundLoad2, 'User should not be able to see other shipper loads');
        }
        Test.stopTest();
    }

    /**
     * Test: Invalid page number defaults to 1
     */
    @isTest
    static void testInvalidPageNumber() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperLoadListController.LoadListResponse response = ShipperLoadListController.getLoads(
                'All', '', '', 'All', -1, 25
            );

            Assert.areEqual(1, response.pageNumber, 'Invalid page number should default to 1');
        }
        Test.stopTest();
    }

    /**
     * Test: Invalid page size defaults to 25
     */
    @isTest
    static void testInvalidPageSize() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperLoadListController.LoadListResponse response = ShipperLoadListController.getLoads(
                'All', '', '', 'All', 1, 0
            );

            Assert.areEqual(25, response.pageSize, 'Invalid page size should default to 25');
        }
        Test.stopTest();
    }
}
