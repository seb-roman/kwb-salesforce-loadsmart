/**
 * ShipperInvoiceListControllerTest
 * 
 * Unit tests for ShipperInvoiceListController
 * Target coverage: >80%
 * 
 * Tests cover:
 * - getInvoices with various filters
 * - RLS: user cannot access other shipper's invoices
 * - Overdue detection logic
 * - getInvoiceDetail with line items and payments
 * - submitDisputeRequest with proper validation
 * - Pagination
 * 
 * Author: Agent 5 (Portal Development - Security Refactor)
 * Created: April 2, 2026
 */

@isTest
public class ShipperInvoiceListControllerTest {

    /**
     * Setup test data: Accounts, Invoices, Payments, Disputes
     */
    @testSetup
    static void setupTestData() {
        // Create shipper accounts
        Account shipper1 = new Account(Name = 'Shipper 1 Inc', Industry = 'Transportation');
        insert shipper1;

        Account shipper2 = new Account(Name = 'Shipper 2 Inc', Industry = 'Logistics');
        insert shipper2;

        // Create contacts
        Contact contact1 = new Contact(
            AccountId = shipper1.Id,
            FirstName = 'John',
            LastName = 'Shipper',
            Email = 'john@shipper1.com'
        );
        insert contact1;

        Contact contact2 = new Contact(
            AccountId = shipper2.Id,
            FirstName = 'Jane',
            LastName = 'Shipper2',
            Email = 'jane@shipper2.com'
        );
        insert contact2;

        // Create portal users
        User user1 = new User(
            FirstName = 'John',
            LastName = 'Shipper',
            Email = 'john@shipper1.com',
            Username = 'john.shipper1@shipper.com.portal',
            ContactId = contact1.Id,
            AccountId = shipper1.Id,
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Shipper User' LIMIT 1]?.Id,
            IsActive = true
        );
        insert user1;

        User user2 = new User(
            FirstName = 'Jane',
            LastName = 'Shipper2',
            Email = 'jane@shipper2.com',
            Username = 'jane.shipper2@shipper.com.portal',
            ContactId = contact2.Id,
            AccountId = shipper2.Id,
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Shipper User' LIMIT 1]?.Id,
            IsActive = true
        );
        insert user2;

        // Create loads for invoices to reference
        List<Load__c> loads = new List<Load__c>();
        loads.add(new Load__c(
            Name = 'LOAD-INV-001',
            Shipper_Account__c = shipper1.Id,
            Status__c = 'Delivered',
            Pickup_Date__c = System.today().addDays(-10),
            Estimated_Delivery__c = System.today().addDays(-5),
            Load_Type__c = 'FTL',
            Pickup_City__c = 'Columbus',
            Delivery_City__c = 'Atlanta',
            Shipper_Rate__c = 2500,
            Equipment_Type__c = 'Flatbed',
            Weight__c = 45000,
            Commodity__c = 'General Freight'
        ));
        loads.add(new Load__c(
            Name = 'LOAD-INV-002',
            Shipper_Account__c = shipper2.Id,
            Status__c = 'Delivered',
            Pickup_Date__c = System.today().addDays(-5),
            Estimated_Delivery__c = System.today(),
            Load_Type__c = 'LTL',
            Pickup_City__c = 'Boston',
            Delivery_City__c = 'New York',
            Shipper_Rate__c = 1500,
            Equipment_Type__c = 'Van',
            Weight__c = 15000,
            Commodity__c = 'Electronics'
        ));
        insert loads;

        // Create invoices for shipper1
        List<Invoice__c> invoices = new List<Invoice__c>();
        invoices.add(new Invoice__c(
            Name = 'INV-001',
            Shipper_Account__c = shipper1.Id,
            Load__c = loads[0].Id,
            Invoice_Amount__c = 2750,
            Subtotal__c = 2500,
            Tax_Amount__c = 250,
            Fuel_Surcharge__c = 0,
            Invoice_Status__c = 'Paid',
            Issue_Date__c = System.today().addDays(-15),
            Due_Date__c = System.today().addDays(-8),
            Total_Paid__c = 2750,
            Balance_Due__c = 0
        ));
        invoices.add(new Invoice__c(
            Name = 'INV-002',
            Shipper_Account__c = shipper1.Id,
            Load__c = loads[0].Id,
            Invoice_Amount__c = 2750,
            Subtotal__c = 2500,
            Tax_Amount__c = 250,
            Fuel_Surcharge__c = 0,
            Invoice_Status__c = 'Sent',
            Issue_Date__c = System.today().addDays(-5),
            Due_Date__c = System.today().addDays(10),
            Total_Paid__c = 0,
            Balance_Due__c = 2750
        ));
        // Overdue invoice
        invoices.add(new Invoice__c(
            Name = 'INV-003',
            Shipper_Account__c = shipper1.Id,
            Load__c = loads[0].Id,
            Invoice_Amount__c = 2750,
            Subtotal__c = 2500,
            Tax_Amount__c = 250,
            Fuel_Surcharge__c = 0,
            Invoice_Status__c = 'Sent',
            Issue_Date__c = System.today().addDays(-30),
            Due_Date__c = System.today().addDays(-5), // Past due date
            Total_Paid__c = 0,
            Balance_Due__c = 2750
        ));

        // Invoice for shipper2
        invoices.add(new Invoice__c(
            Name = 'INV-004',
            Shipper_Account__c = shipper2.Id,
            Load__c = loads[1].Id,
            Invoice_Amount__c = 1650,
            Subtotal__c = 1500,
            Tax_Amount__c = 150,
            Fuel_Surcharge__c = 0,
            Invoice_Status__c = 'Viewed',
            Issue_Date__c = System.today().addDays(-3),
            Due_Date__c = System.today().addDays(7),
            Total_Paid__c = 0,
            Balance_Due__c = 1650
        ));

        insert invoices;

        // Create payment record for first invoice
        Payment__c payment = new Payment__c(
            Invoice__c = invoices[0].Id,
            Payment_Date__c = System.today().addDays(-8),
            Amount__c = 2750,
            Payment_Method__c = 'ACH'
        );
        insert payment;
    }

    /**
     * Test: getInvoices returns all invoices
     */
    @isTest
    static void testGetInvoicesAll() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperInvoiceListController.InvoiceListResponse response = ShipperInvoiceListController.getInvoices(
                'All',          // statusFilter
                '',             // dateFrom
                '',             // dateTo
                1,              // pageNumber
                25              // pageSize
            );

            Assert.isNotNull(response, 'Response should not be null');
            Assert.areEqual(3, response.totalRecords, 'Should return 3 invoices for shipper1');
            Assert.areEqual(1, response.totalPages, 'Should be 1 page');
        }
        Test.stopTest();
    }

    /**
     * Test: getInvoices with status filter
     */
    @isTest
    static void testGetInvoicesWithStatusFilter() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperInvoiceListController.InvoiceListResponse response = ShipperInvoiceListController.getInvoices(
                'Paid',         // statusFilter
                '',
                '',
                1,
                25
            );

            Assert.isNotNull(response, 'Response should not be null');
            Assert.areEqual(1, response.totalRecords, 'Should return 1 paid invoice');
            Assert.areEqual('Paid', response.invoices[0].Invoice_Status__c, 'Invoice should be paid');
        }
        Test.stopTest();
    }

    /**
     * Test: getInvoices detects overdue invoices
     */
    @isTest
    static void testGetInvoicesOverdueDetection() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperInvoiceListController.InvoiceListResponse response = ShipperInvoiceListController.getInvoices(
                'Overdue',      // statusFilter - special case
                '',
                '',
                1,
                25
            );

            Assert.isNotNull(response, 'Response should not be null');
            Assert.areEqual(1, response.totalRecords, 'Should return 1 overdue invoice');
            Assert.areEqual('INV-003', response.invoices[0].Name, 'Should be INV-003');
        }
        Test.stopTest();
    }

    /**
     * Test: getInvoices with date range filter
     */
    @isTest
    static void testGetInvoicesWithDateFilter() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperInvoiceListController.InvoiceListResponse response = ShipperInvoiceListController.getInvoices(
                'All',
                System.today().addDays(-10).format(),  // dateFrom
                System.today().format(),               // dateTo
                1,
                25
            );

            Assert.isNotNull(response, 'Response should not be null');
            // Should include INV-002 and INV-003 (issued within date range)
            Assert.isGreater(response.totalRecords, 0, 'Should return invoices within date range');
        }
        Test.stopTest();
    }

    /**
     * Test: RLS - User cannot access other shipper's invoices
     */
    @isTest
    static void testGetInvoicesRLS() {
        User user1 = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Invoice__c invoice4 = [SELECT Id FROM Invoice__c WHERE Name = 'INV-004' LIMIT 1];

        Test.startTest();
        System.runAs(user1) {
            ShipperInvoiceListController.InvoiceListResponse response = ShipperInvoiceListController.getInvoices(
                'All', '', '', 1, 25
            );

            // User1 should not see invoice4 (belongs to shipper2)
            Boolean foundInvoice4 = false;
            for (Invoice__c inv : response.invoices) {
                if (inv.Id == invoice4.Id) {
                    foundInvoice4 = true;
                }
            }
            Assert.isFalse(foundInvoice4, 'User should not access other shipper invoices');
        }
        Test.stopTest();
    }

    /**
     * Test: getInvoiceDetail returns complete invoice information
     */
    @isTest
    static void testGetInvoiceDetail() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Invoice__c invoice = [SELECT Id FROM Invoice__c WHERE Name = 'INV-001' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperInvoiceListController.InvoiceDetail detail = ShipperInvoiceListController.getInvoiceDetail(invoice.Id);

            Assert.isNotNull(detail, 'Detail should not be null');
            Assert.isNotNull(detail.invoice, 'Invoice should not be null');
            Assert.areEqual(invoice.Id, detail.invoice.Id, 'Invoice ID should match');
            Assert.areEqual(2750, detail.invoice.Invoice_Amount__c, 'Amount should be 2750');
        }
        Test.stopTest();
    }

    /**
     * Test: getInvoiceDetail returns payment history
     */
    @isTest
    static void testGetInvoiceDetailPayments() {
        User testUser = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Invoice__c invoice = [SELECT Id FROM Invoice__c WHERE Name = 'INV-001' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperInvoiceListController.InvoiceDetail detail = ShipperInvoiceListController.getInvoiceDetail(invoice.Id);

            Assert.isNotNull(detail.payments, 'Payments list should exist');
            Assert.areEqual(1, detail.payments.size(), 'Should have 1 payment');
            Assert.areEqual(2750, detail.payments[0].Amount__c, 'Payment amount should be 2750');
        }
        Test.stopTest();
    }

    /**
     * Test: getInvoiceDetail RLS check
     */
    @isTest
    static void testGetInvoiceDetailRLS() {
        User user1 = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Invoice__c invoice4 = [SELECT Id FROM Invoice__c WHERE Name = 'INV-004' LIMIT 1];

        Test.startTest();
        System.runAs(user1) {
            try {
                ShipperInvoiceListController.InvoiceDetail detail = ShipperInvoiceListController.getInvoiceDetail(invoice4.Id);
                Assert.isNull(detail, 'Should not return invoice detail for other shipper');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('not found'), 'Should indicate access denied');
            }
        }
        Test.stopTest();
    }

    /**
     * Test: submitDisputeRequest creates dispute record
     */
    @isTest
    static void testSubmitDisputeRequest() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Invoice__c invoice = [SELECT Id FROM Invoice__c WHERE Name = 'INV-002' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            String disputeId = ShipperInvoiceListController.submitDisputeRequest(
                invoice.Id,
                'Incorrect Amount',
                500.00,
                'Invoice amount does not match PO'
            );

            Assert.isNotNull(disputeId, 'Dispute ID should be returned');
            
            // Verify dispute was created
            List<Dispute__c> disputes = [
                SELECT Id, Status__c, Dispute_Reason__c, Disputed_Amount__c
                FROM Dispute__c
                WHERE Invoice__c = :invoice.Id
            ];
            Assert.areEqual(1, disputes.size(), 'Should create 1 dispute');
            Assert.areEqual('New', disputes[0].Status__c, 'Dispute status should be New');
            Assert.areEqual('Incorrect Amount', disputes[0].Dispute_Reason__c, 'Reason should match');
            Assert.areEqual(500.00, disputes[0].Disputed_Amount__c, 'Amount should match');
        }
        Test.stopTest();
    }

    /**
     * Test: submitDisputeRequest RLS check
     */
    @isTest
    static void testSubmitDisputeRequestRLS() {
        User user1 = [SELECT Id FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];
        Invoice__c invoice4 = [SELECT Id FROM Invoice__c WHERE Name = 'INV-004' LIMIT 1];

        Test.startTest();
        System.runAs(user1) {
            try {
                ShipperInvoiceListController.submitDisputeRequest(
                    invoice4.Id,
                    'Wrong Amount',
                    500.00,
                    'Test dispute'
                );
                Assert.fail('Should not allow dispute for other shipper invoice');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('not found'), 'Should deny access');
            }
        }
        Test.stopTest();
    }

    /**
     * Test: Pagination works correctly
     */
    @isTest
    static void testGetInvoicesPagination() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'john.shipper1@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            // Page 1
            ShipperInvoiceListController.InvoiceListResponse page1 = ShipperInvoiceListController.getInvoices(
                'All', '', '', 1, 2
            );
            Assert.areEqual(2, page1.invoices.size(), 'Page 1 should have 2 invoices');
            Assert.areEqual(2, page1.totalPages, 'Should have 2 pages total');

            // Page 2
            ShipperInvoiceListController.InvoiceListResponse page2 = ShipperInvoiceListController.getInvoices(
                'All', '', '', 2, 2
            );
            Assert.areEqual(1, page2.invoices.size(), 'Page 2 should have 1 invoice');
        }
        Test.stopTest();
    }

    /**
     * Test: getInvoiceStatusOptions returns valid statuses
     */
    @isTest
    static void testGetInvoiceStatusOptions() {
        Test.startTest();
        List<String> statuses = ShipperInvoiceListController.getInvoiceStatusOptions();

        Assert.isNotNull(statuses, 'Status options should not be null');
        Assert.isGreater(statuses.size(), 0, 'Should return status options');
        Test.stopTest();
    }

    /**
     * Test: Empty invoice list
     */
    @isTest
    static void testGetInvoicesEmpty() {
        // Create user with no invoices
        Account emptyShipper = new Account(Name = 'Empty Shipper Inc');
        insert emptyShipper;

        Contact emptyContact = new Contact(
            AccountId = emptyShipper.Id,
            FirstName = 'Empty',
            LastName = 'User',
            Email = 'empty@test.com'
        );
        insert emptyContact;

        User emptyUser = new User(
            FirstName = 'Empty',
            LastName = 'User',
            Email = 'empty@test.com',
            Username = 'empty.user@shipper.com.portal',
            ContactId = emptyContact.Id,
            AccountId = emptyShipper.Id,
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Shipper User' LIMIT 1]?.Id,
            IsActive = true
        );
        insert emptyUser;

        Test.startTest();
        System.runAs(emptyUser) {
            ShipperInvoiceListController.InvoiceListResponse response = ShipperInvoiceListController.getInvoices(
                'All', '', '', 1, 25
            );

            Assert.isNotNull(response, 'Response should not be null');
            Assert.areEqual(0, response.totalRecords, 'Should have no invoices');
            Assert.areEqual(0, response.invoices.size(), 'Should return empty list');
        }
        Test.stopTest();
    }
}
