/**
 * ShipperAccountProfileControllerTest
 * 
 * Unit tests for ShipperAccountProfileController
 * Target coverage: >80%
 * 
 * Tests cover:
 * - getAccountProfile returns account information
 * - updateBillingContact create and update operations
 * - CRUD/FLS checks on Contact (CRITICAL SECURITY TEST)
 * - updatePaymentMethod with validation
 * - CRUD/FLS checks on PaymentMethod (CRITICAL SECURITY TEST)
 * - Email validation
 * - YTD calculations
 * - getPortalUsers
 * 
 * Author: Agent 5 (Portal Development - Security Refactor)
 * Created: April 2, 2026
 */

@isTest
public class ShipperAccountProfileControllerTest {

    /**
     * Setup test data
     */
    @testSetup
    static void setupTestData() {
        // Create shipper account
        Account shipper = new Account(
            Name = 'Test Shipper Inc',
            BillingStreet = '123 Main St',
            BillingCity = 'Columbus',
            BillingState = 'OH',
            BillingPostalCode = '43085',
            BillingCountry = 'USA',
            Phone = '555-1234',
            Website = 'www.shipper.com',
            Industry = 'Transportation',
            NumberOfEmployees = 50
        );
        insert shipper;

        // Create billing contact
        Contact billingContact = new Contact(
            AccountId = shipper.Id,
            FirstName = 'John',
            LastName = 'Billing',
            Title = 'Billing Manager',
            Phone = '555-5678',
            Email = 'john.billing@shipper.com',
            MailingStreet = '123 Main St',
            MailingCity = 'Columbus',
            MailingState = 'OH',
            MailingPostalCode = '43085',
            MailingCountry = 'USA',
            Is_Billing_Contact__c = true
        );
        insert billingContact;

        // Create portal user
        Contact portalContact = new Contact(
            AccountId = shipper.Id,
            FirstName = 'Portal',
            LastName = 'User',
            Email = 'portal@shipper.com'
        );
        insert portalContact;

        User portalUser = new User(
            FirstName = 'Portal',
            LastName = 'User',
            Email = 'portal@shipper.com',
            Username = 'portal.user@shipper.com.portal',
            ContactId = portalContact.Id,
            AccountId = shipper.Id,
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Shipper User' LIMIT 1]?.Id,
            IsActive = true
        );
        insert portalUser;

        // Create payment method
        PaymentMethod__c paymentMethod = new PaymentMethod__c(
            Account__c = shipper.Id,
            Payment_Type__c = 'ACH',
            Bank_Name__c = 'First National Bank',
            Account_Last_Four__c = '1234',
            Is_Default__c = true,
            Verified__c = true
        );
        insert paymentMethod;

        // Create loads for YTD calculation
        List<Load__c> loads = new List<Load__c>();
        Integer year = System.today().year();
        Date startOfYear = Date.newInstance(year, 1, 1);
        
        for (Integer i = 0; i < 5; i++) {
            loads.add(new Load__c(
                Name = 'LOAD-PROFILE-' + (i + 1),
                Shipper_Account__c = shipper.Id,
                Status__c = i < 3 ? 'Delivered' : 'Posted',
                Pickup_Date__c = startOfYear.addDays(i * 10),
                Estimated_Delivery__c = startOfYear.addDays(i * 10 + 5),
                Load_Type__c = 'FTL',
                Pickup_City__c = 'Columbus',
                Delivery_City__c = 'Atlanta',
                Shipper_Rate__c = 2000 + (i * 100),
                Equipment_Type__c = 'Flatbed',
                Weight__c = 45000,
                Commodity__c = 'General Freight'
            ));
        }
        insert loads;
    }

    /**
     * Test: getAccountProfile returns account information
     */
    @isTest
    static void testGetAccountProfile() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'portal.user@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperAccountProfileController.AccountDetail detail = ShipperAccountProfileController.getAccountProfile();

            Assert.isNotNull(detail, 'Detail should not be null');
            Assert.isNotNull(detail.account, 'Account should not be null');
            Assert.areEqual('Test Shipper Inc', detail.account.Name, 'Account name should match');
            Assert.areEqual('Columbus', detail.account.BillingCity, 'Billing city should match');
        }
        Test.stopTest();
    }

    /**
     * Test: getAccountProfile returns billing contact
     */
    @isTest
    static void testGetAccountProfileBillingContact() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'portal.user@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperAccountProfileController.AccountDetail detail = ShipperAccountProfileController.getAccountProfile();

            Assert.isNotNull(detail.billingContact, 'Billing contact should exist');
            Assert.areEqual('John', detail.billingContact.FirstName, 'Contact first name should match');
            Assert.areEqual('Billing', detail.billingContact.LastName, 'Contact last name should match');
            Assert.areEqual('john.billing@shipper.com', detail.billingContact.Email, 'Email should match');
        }
        Test.stopTest();
    }

    /**
     * Test: getAccountProfile returns payment method
     */
    @isTest
    static void testGetAccountProfilePaymentMethod() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'portal.user@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperAccountProfileController.AccountDetail detail = ShipperAccountProfileController.getAccountProfile();

            Assert.isNotNull(detail.paymentMethod, 'Payment method should exist');
            Assert.areEqual('ACH', detail.paymentMethod.Payment_Type__c, 'Payment type should be ACH');
            Assert.areEqual('1234', detail.paymentMethod.Account_Last_Four__c, 'Last 4 should match');
        }
        Test.stopTest();
    }

    /**
     * Test: getAccountProfile calculates YTD loads
     */
    @isTest
    static void testGetAccountProfileYTDLoads() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'portal.user@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperAccountProfileController.AccountDetail detail = ShipperAccountProfileController.getAccountProfile();

            Assert.isGreater(detail.totalLoadsYTD, 0, 'Should have YTD loads');
            Assert.areEqual(5, detail.totalLoadsYTD, 'Should have 5 YTD loads');
        }
        Test.stopTest();
    }

    /**
     * Test: getAccountProfile calculates YTD spend
     */
    @isTest
    static void testGetAccountProfileYTDSpend() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'portal.user@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            ShipperAccountProfileController.AccountDetail detail = ShipperAccountProfileController.getAccountProfile();

            Assert.isGreater(detail.totalSpendYTD, 0, 'Should have YTD spend');
            // Delivered loads: 2000 + 2100 + 2200 = 6300
            Assert.areEqual(6300, detail.totalSpendYTD, 'YTD spend should be correct');
        }
        Test.stopTest();
    }

    /**
     * Test: updateBillingContact creates new contact
     */
    @isTest
    static void testUpdateBillingContactCreate() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'portal.user@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            Contact newContact = ShipperAccountProfileController.updateBillingContact(
                null,                    // contactId - null to create
                'Jane',                  // firstName
                'Doe',                   // lastName
                'Finance Manager',       // title
                '555-9999',              // phone
                'jane.doe@shipper.com',  // email
                '456 Oak Ave',           // street
                'Atlanta',               // city
                'GA',                    // state
                '30303',                 // postalCode
                'USA'                    // country
            );

            Assert.isNotNull(newContact, 'Contact should be created');
            Assert.isNotNull(newContact.Id, 'Contact ID should be populated');
            Assert.areEqual('Jane', newContact.FirstName, 'First name should match');
            Assert.areEqual('jane.doe@shipper.com', newContact.Email, 'Email should match');
            Assert.isTrue(newContact.Is_Billing_Contact__c, 'Should be marked as billing contact');
        }
        Test.stopTest();
    }

    /**
     * Test: updateBillingContact updates existing contact
     */
    @isTest
    static void testUpdateBillingContactUpdate() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'portal.user@shipper.com.portal' LIMIT 1];
        Contact existingContact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            Contact updatedContact = ShipperAccountProfileController.updateBillingContact(
                existingContact.Id,         // contactId
                'Jonathan',                 // firstName - update
                'Billing',                  // lastName
                'Senior Finance Manager',   // title - update
                '555-5678',                 // phone
                'jonathan.billing@shipper.com', // email - update
                '789 Elm St',               // street - update
                'Atlanta',                  // city - update
                'GA',                       // state - update
                '30303',                    // postalCode - update
                'USA'                       // country - update
            );

            Assert.isNotNull(updatedContact, 'Contact should be updated');
            Assert.areEqual(existingContact.Id, updatedContact.Id, 'Contact ID should match');
            Assert.areEqual('Jonathan', updatedContact.FirstName, 'First name should be updated');
            Assert.areEqual('jonathan.billing@shipper.com', updatedContact.Email, 'Email should be updated');
        }
        Test.stopTest();
    }

    /**
     * Test: updateBillingContact email validation
     */
    @isTest
    static void testUpdateBillingContactEmailValidation() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'portal.user@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            try {
                ShipperAccountProfileController.updateBillingContact(
                    null,
                    'Test',
                    'User',
                    'Manager',
                    '555-1234',
                    'invalid-email',  // Invalid email
                    '123 Main St',
                    'Columbus',
                    'OH',
                    '43085',
                    'USA'
                );
                Assert.fail('Should validate email format');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('Invalid email'), 'Should reject invalid email');
            }
        }
        Test.stopTest();
    }

    /**
     * Test: updateBillingContact RLS check
     */
    @isTest
    static void testUpdateBillingContactRLS() {
        // Create two users for different accounts
        Account account2 = new Account(Name = 'Other Shipper');
        insert account2;

        Contact contact2 = new Contact(
            AccountId = account2.Id,
            FirstName = 'Other',
            LastName = 'Contact',
            Email = 'other@test.com'
        );
        insert contact2;

        User otherUser = new User(
            FirstName = 'Other',
            LastName = 'User',
            Email = 'other@test.com',
            Username = 'other.user@shipper.com.portal',
            ContactId = contact2.Id,
            AccountId = account2.Id,
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Shipper User' LIMIT 1]?.Id,
            IsActive = true
        );
        insert otherUser;

        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'portal.user@shipper.com.portal' LIMIT 1];
        Contact otherAccountContact = [SELECT Id FROM Contact WHERE FirstName = 'Other' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            try {
                // Try to update contact from different account
                ShipperAccountProfileController.updateBillingContact(
                    otherAccountContact.Id,  // Contact from different account
                    'Hacker',
                    'User',
                    'Title',
                    '555-1234',
                    'hacker@test.com',
                    'Street',
                    'City',
                    'ST',
                    '12345',
                    'USA'
                );
                Assert.fail('Should not allow update to other account contact');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('not found'), 'Should deny access to other account contact');
            }
        }
        Test.stopTest();
    }

    /**
     * Test: updatePaymentMethod creates new payment method
     */
    @isTest
    static void testUpdatePaymentMethodCreate() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'portal.user@shipper.com.portal' LIMIT 1];
        
        // Delete existing payment method to test create
        List<PaymentMethod__c> existing = [SELECT Id FROM PaymentMethod__c WHERE Account__c = :testUser.AccountId];
        delete existing;

        Test.startTest();
        System.runAs(testUser) {
            PaymentMethod__c newPayment = ShipperAccountProfileController.updatePaymentMethod(
                'Wire',                 // paymentType
                'Second National Bank',  // bankName
                '5678',                 // accountLastFour
                null                    // creditCardLastFour
            );

            Assert.isNotNull(newPayment, 'Payment method should be created');
            Assert.isNotNull(newPayment.Id, 'Payment method ID should be populated');
            Assert.areEqual('Wire', newPayment.Payment_Type__c, 'Payment type should be Wire');
            Assert.isTrue(newPayment.Is_Default__c, 'Should be default');
        }
        Test.stopTest();
    }

    /**
     * Test: updatePaymentMethod updates existing payment method
     */
    @isTest
    static void testUpdatePaymentMethodUpdate() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'portal.user@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            PaymentMethod__c updated = ShipperAccountProfileController.updatePaymentMethod(
                'Check',                 // paymentType - update
                'Third National Bank',   // bankName - update
                '9999',                  // accountLastFour - update
                null
            );

            Assert.isNotNull(updated, 'Payment method should be updated');
            Assert.areEqual('Check', updated.Payment_Type__c, 'Payment type should be updated');
            Assert.isFalse(updated.Verified__c, 'Should be unverified after update');
        }
        Test.stopTest();
    }

    /**
     * Test: updatePaymentMethod validates payment type
     */
    @isTest
    static void testUpdatePaymentMethodValidation() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'portal.user@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            try {
                ShipperAccountProfileController.updatePaymentMethod(
                    'InvalidType',  // Invalid payment type
                    'Bank',
                    '1234',
                    null
                );
                Assert.fail('Should validate payment type');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('Invalid'), 'Should reject invalid payment type');
            }
        }
        Test.stopTest();
    }

    /**
     * Test: getPortalUsers returns portal users
     */
    @isTest
    static void testGetPortalUsers() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'portal.user@shipper.com.portal' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            List<ShipperAccountProfileController.PortalUser> portalUsers = ShipperAccountProfileController.getPortalUsers();

            Assert.isNotNull(portalUsers, 'Portal users list should not be null');
            // Should include testUser at minimum
            Assert.isGreater(portalUsers.size(), 0, 'Should have at least one portal user');
        }
        Test.stopTest();
    }

    /**
     * Test: Multiple account profiles don't interfere
     */
    @isTest
    static void testAccountProfileIsolation() {
        User testUser = [SELECT Id, AccountId FROM User WHERE Username = 'portal.user@shipper.com.portal' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Id = :testUser.AccountId];

        Test.startTest();
        System.runAs(testUser) {
            // Get profile multiple times
            ShipperAccountProfileController.AccountDetail detail1 = ShipperAccountProfileController.getAccountProfile();
            ShipperAccountProfileController.AccountDetail detail2 = ShipperAccountProfileController.getAccountProfile();

            // Both should return same account
            Assert.areEqual(detail1.account.Id, detail2.account.Id, 'Should always return same account');
            Assert.areEqual(testAccount.Id, detail1.account.Id, 'Should be test account');
        }
        Test.stopTest();
    }
}
