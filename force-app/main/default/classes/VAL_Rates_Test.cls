/**
 * Test class for VAL_Carrier_Rate_Not_Exceeds_Shipper_Rate and VAL_Rates_Cannot_Be_Negative validation rules
 * Tests rate validation logic
 */
@isTest
public class VAL_Rates_Test {
    
    @TestSetup
    static void setupTestData() {
        Account shipper = new Account(Name = 'Test Shipper', BillingCountry = 'US');
        insert shipper;
        
        Account receiver = new Account(Name = 'Test Receiver', BillingCountry = 'US');
        insert receiver;
    }
    
    @isTest
    static void testCarrierRateExceedsShipperRate_ShouldFail() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'draft',
            Distance_Miles__c = 100,
            Weight_lbs__c = 5000,
            Billing_Rate__c = 1000.00,
            Carrier_Rate__c = 1500.00 // Exceeds shipper rate
        );
        
        Test.startTest();
        try {
            insert load;
            System.assert(false, 'Should have failed - carrier rate exceeds shipper rate');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Carrier Rate cannot exceed'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCarrierRateEqualsShipperRate_ShouldPass() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'draft',
            Distance_Miles__c = 100,
            Weight_lbs__c = 5000,
            Billing_Rate__c = 1000.00,
            Carrier_Rate__c = 1000.00
        );
        
        Test.startTest();
        insert load;
        Test.stopTest();
        
        Load__c insertedLoad = [SELECT Id FROM Load__c WHERE Id = :load.Id];
        System.assertNotEquals(null, insertedLoad.Id);
    }
    
    @isTest
    static void testNegativeBillingRate_ShouldFail() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'draft',
            Distance_Miles__c = 100,
            Weight_lbs__c = 5000,
            Billing_Rate__c = -100.00,
            Carrier_Rate__c = 100.00
        );
        
        Test.startTest();
        try {
            insert load;
            System.assert(false, 'Should have failed - negative rate');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('cannot be negative'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testNegativeCarrierRate_ShouldFail() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'draft',
            Distance_Miles__c = 100,
            Weight_lbs__c = 5000,
            Billing_Rate__c = 1000.00,
            Carrier_Rate__c = -100.00
        );
        
        Test.startTest();
        try {
            insert load;
            System.assert(false, 'Should have failed - negative rate');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('cannot be negative'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testZeroRates_ShouldPass() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'draft',
            Distance_Miles__c = 100,
            Weight_lbs__c = 5000,
            Billing_Rate__c = 0.00,
            Carrier_Rate__c = 0.00
        );
        
        Test.startTest();
        insert load;
        Test.stopTest();
        
        Load__c insertedLoad = [SELECT Id FROM Load__c WHERE Id = :load.Id];
        System.assertNotEquals(null, insertedLoad.Id);
    }
}
