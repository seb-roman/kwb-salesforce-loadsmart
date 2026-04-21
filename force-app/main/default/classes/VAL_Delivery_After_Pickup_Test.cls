/**
 * Test class for VAL_Delivery_After_Pickup validation rule
 * Tests that delivery date must be after pickup date
 */
@isTest
public class VAL_Delivery_After_Pickup_Test {
    
    @TestSetup
    static void setupTestData() {
        Account shipper = new Account(Name = 'Test Shipper', BillingCountry = 'US');
        insert shipper;
        
        Account receiver = new Account(Name = 'Test Receiver', BillingCountry = 'US');
        insert receiver;
    }
    
    @isTest
    static void testDeliveryBeforePickup_ShouldFail() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        DateTime pickupTime = System.now().addDays(5);
        DateTime deliveryTime = pickupTime.addDays(-1); // Before pickup
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = pickupTime,
            Estimated_Delivery_DateTime__c = deliveryTime,
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
            System.assert(e.getMessage().contains('must be after'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testDeliveryAtPickupTime_ShouldFail() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        DateTime deliveryTime = System.now().addDays(5);
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = deliveryTime,
            Estimated_Delivery_DateTime__c = deliveryTime, // Same time
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
            System.assert(e.getMessage().contains('must be after'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testDeliveryAfterPickup_ShouldPass() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        DateTime pickupTime = System.now().addDays(5);
        DateTime deliveryTime = pickupTime.addDays(2);
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = pickupTime,
            Estimated_Delivery_DateTime__c = deliveryTime,
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
    
    @isTest
    static void testNullDeliveryDate_ShouldPass() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = null, // No delivery date
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
