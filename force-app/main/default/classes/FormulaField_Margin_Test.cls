/**
 * Test class for Margin formula fields (Margin__c and Margin_Percent__c)
 * Tests calculation of dollar margin and percentage margin
 */
@isTest
public class FormulaField_Margin_Test {
    
    @TestSetup
    static void setupTestData() {
        Account shipper = new Account(Name = 'Test Shipper', BillingCountry = 'US');
        insert shipper;
        
        Account receiver = new Account(Name = 'Test Receiver', BillingCountry = 'US');
        insert receiver;
    }
    
    @isTest
    static void testMarginCalculation_StandardCase() {
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
            Carrier_Rate__c = 700.00
        );
        
        Test.startTest();
        insert load;
        Test.stopTest();
        
        Load__c insertedLoad = [SELECT Id, Margin__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals(300.00, insertedLoad.Margin__c, 'Margin should be 300.00');
    }
    
    @isTest
    static void testMarginPercentCalculation() {
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
            Carrier_Rate__c = 700.00
        );
        
        Test.startTest();
        insert load;
        Test.stopTest();
        
        Load__c insertedLoad = [SELECT Id, Margin_Percent__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals(30.00, insertedLoad.Margin_Percent__c, 'Margin % should be 30.00');
    }
    
    @isTest
    static void testMarginPercentWithZeroBillingRate() {
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
            Carrier_Rate__c = 700.00
        );
        
        Test.startTest();
        insert load;
        Test.stopTest();
        
        Load__c insertedLoad = [SELECT Id, Margin_Percent__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals(0.00, insertedLoad.Margin_Percent__c, 'Margin % should be 0 when billing rate is zero');
    }
    
    @isTest
    static void testMarginZeroWhenRatesEqual() {
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
        
        Load__c insertedLoad = [SELECT Id, Margin__c, Margin_Percent__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals(0.00, insertedLoad.Margin__c, 'Margin should be 0');
        System.assertEquals(0.00, insertedLoad.Margin_Percent__c, 'Margin % should be 0');
    }
    
    @isTest
    static void testLargeMarginPercentage() {
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
            Billing_Rate__c = 2000.00,
            Carrier_Rate__c = 500.00
        );
        
        Test.startTest();
        insert load;
        Test.stopTest();
        
        Load__c insertedLoad = [SELECT Id, Margin_Percent__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals(75.00, insertedLoad.Margin_Percent__c, 'Margin % should be 75.00');
    }
}
