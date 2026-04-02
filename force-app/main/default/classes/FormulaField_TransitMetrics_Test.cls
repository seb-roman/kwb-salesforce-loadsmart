/**
 * Test class for Transit and Distance formula fields
 * Tests Transit_Hours__c, Cost_Per_Mile__c, Revenue_Per_Mile__c
 */
@isTest
public class FormulaField_TransitMetrics_Test {
    
    @TestSetup
    static void setupTestData() {
        Account shipper = new Account(Name = 'Test Shipper', BillingCountry = 'US');
        insert shipper;
        
        Account receiver = new Account(Name = 'Test Receiver', BillingCountry = 'US');
        insert receiver;
    }
    
    @isTest
    static void testTransitHoursCalculation() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        DateTime pickupTime = System.now().addDays(5);
        DateTime deliveryTime = pickupTime.addHours(24); // 24 hours later
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = pickupTime,
            Estimated_Delivery_DateTime__c = deliveryTime,
            Pickup_Window_End__c = pickupTime.addHours(2),
            Delivery_Window_Begin__c = deliveryTime,
            Delivery_Window_End__c = deliveryTime.addHours(2),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'draft',
            Distance_Miles__c = 500,
            Weight_lbs__c = 10000,
            Billing_Rate__c = 1000.00,
            Carrier_Rate__c = 700.00
        );
        
        Test.startTest();
        insert load;
        Test.stopTest();
        
        Load__c insertedLoad = [SELECT Id, Transit_Hours__c FROM Load__c WHERE Id = :load.Id];
        System.assertNotEquals(null, insertedLoad.Transit_Hours__c, 'Transit Hours should be calculated');
    }
    
    @isTest
    static void testCostPerMileCalculation() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'draft',
            Distance_Miles__c = 500,
            Weight_lbs__c = 10000,
            Billing_Rate__c = 2000.00,
            Carrier_Rate__c = 1500.00
        );
        
        Test.startTest();
        insert load;
        Test.stopTest();
        
        Load__c insertedLoad = [SELECT Id, Cost_Per_Mile__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals(3.00, insertedLoad.Cost_Per_Mile__c, 'Cost per mile should be 3.00');
    }
    
    @isTest
    static void testRevenuePerMileCalculation() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'draft',
            Distance_Miles__c = 500,
            Weight_lbs__c = 10000,
            Billing_Rate__c = 2000.00,
            Carrier_Rate__c = 1500.00
        );
        
        Test.startTest();
        insert load;
        Test.stopTest();
        
        Load__c insertedLoad = [SELECT Id, Revenue_Per_Mile__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals(4.00, insertedLoad.Revenue_Per_Mile__c, 'Revenue per mile should be 4.00');
    }
    
    @isTest
    static void testCostPerMileWithZeroDistance() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'draft',
            Distance_Miles__c = 0,
            Weight_lbs__c = 10000,
            Billing_Rate__c = 2000.00,
            Carrier_Rate__c = 1500.00
        );
        
        Test.startTest();
        insert load;
        Test.stopTest();
        
        Load__c insertedLoad = [SELECT Id, Cost_Per_Mile__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals(0.00, insertedLoad.Cost_Per_Mile__c, 'Cost per mile should be 0 when distance is 0');
    }
    
    @isTest
    static void testRevenuePerMileWithBlankDistance() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'draft',
            Distance_Miles__c = null,
            Weight_lbs__c = 10000,
            Billing_Rate__c = 2000.00,
            Carrier_Rate__c = 1500.00
        );
        
        Test.startTest();
        insert load;
        Test.stopTest();
        
        Load__c insertedLoad = [SELECT Id, Revenue_Per_Mile__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals(0.00, insertedLoad.Revenue_Per_Mile__c, 'Revenue per mile should be 0 when distance is blank');
    }
}
