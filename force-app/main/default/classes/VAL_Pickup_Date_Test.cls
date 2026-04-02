/**
 * Test class for VAL_Pickup_Date_Not_In_Past validation rule
 * Tests that pickup dates cannot be in the past
 */
@isTest
public class VAL_Pickup_Date_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create test data
        Account shipper = new Account(Name = 'Test Shipper', BillingCountry = 'US');
        insert shipper;
        
        Account receiver = new Account(Name = 'Test Receiver', BillingCountry = 'US');
        insert receiver;
    }
    
    @isTest
    static void testPickupDateInPast_ShouldFail() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(-1),
            Estimated_Delivery_DateTime__c = System.now().addDays(2),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'draft',
            Distance_Miles__c = 100,
            Weight_lbs__c = 5000
        );
        
        Test.startTest();
        try {
            insert load;
            System.assert(false, 'Should have failed validation');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Pickup date cannot be in the past'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testPickupDateToday_ShouldPass() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now(),
            Estimated_Delivery_DateTime__c = System.now().addDays(2),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'draft',
            Distance_Miles__c = 100,
            Weight_lbs__c = 5000
        );
        
        Test.startTest();
        insert load;
        Test.stopTest();
        
        Load__c insertedLoad = [SELECT Id, Pickup_Window_Begin__c FROM Load__c WHERE Id = :load.Id];
        System.assertNotEquals(null, insertedLoad.Id);
    }
    
    @isTest
    static void testPickupDateFuture_ShouldPass() {
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
            Weight_lbs__c = 5000
        );
        
        Test.startTest();
        insert load;
        Test.stopTest();
        
        Load__c insertedLoad = [SELECT Id FROM Load__c WHERE Id = :load.Id];
        System.assertNotEquals(null, insertedLoad.Id);
    }
}
