/**
 * End-to-end integration test for Load__c data model
 * Tests complete workflow: creation, validation, formula calculations
 */
@isTest
public class LoadDataModel_IntegrationTest {
    
    @TestSetup
    static void setupTestData() {
        Account shipper = new Account(
            Name = 'Test Shipper Inc',
            BillingCountry = 'US',
            BillingState = 'OH'
        );
        insert shipper;
        
        Account receiver = new Account(
            Name = 'Test Receiver LLC',
            BillingCountry = 'US',
            BillingState = 'PA'
        );
        insert receiver;
    }
    
    @isTest
    static void testCompleteLoadLifecycle() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper Inc' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver LLC' LIMIT 1];
        
        // Create load in draft
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(3),
            Pickup_Window_End__c = System.now().addDays(3).addHours(4),
            Estimated_Delivery_DateTime__c = System.now().addDays(5),
            Delivery_Window_Begin__c = System.now().addDays(5),
            Delivery_Window_End__c = System.now().addDays(5).addHours(2),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Flatbed',
            Status__c = 'draft',
            Distance_Miles__c = 350,
            Weight_lbs__c = 18000,
            Billing_Rate__c = 2500.00,
            Carrier_Rate__c = 1800.00,
            Hazmat_Class__c = null,
            Commodity__c = 'Steel Coils'
        );
        
        Test.startTest();
        insert load;
        
        // Verify formulas calculated
        Load__c draftLoad = [SELECT Id, Margin__c, Margin_Percent__c, Cost_Per_Mile__c, Revenue_Per_Mile__c, Status_Label__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals(700.00, draftLoad.Margin__c, 'Margin should be 700.00');
        System.assertEquals(28.00, draftLoad.Margin_Percent__c, 'Margin % should be 28.00');
        System.assertEquals(5.14, draftLoad.Cost_Per_Mile__c, 'Cost per mile should be ~5.14');
        System.assertEquals(7.14, draftLoad.Revenue_Per_Mile__c, 'Revenue per mile should be ~7.14');
        System.assertNotEquals(null, draftLoad.Status_Label__c, 'Status label should have timestamp');
        
        // Transition to posted
        draftLoad.Status__c = 'posted';
        update draftLoad;
        
        Load__c postedLoad = [SELECT Id, Status__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals('posted', postedLoad.Status__c);
        
        // Transition to quoted with rates confirmed
        postedLoad.Status__c = 'quoted';
        update postedLoad;
        
        Load__c quotedLoad = [SELECT Id, Status__c, Billing_Rate__c, Carrier_Rate__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals('quoted', quotedLoad.Status__c);
        System.assertEquals(2500.00, quotedLoad.Billing_Rate__c);
        System.assertEquals(1800.00, quotedLoad.Carrier_Rate__c);
        
        Test.stopTest();
    }
    
    @isTest
    static void testLoadWithHazmat() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper Inc' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver LLC' LIMIT 1];
        
        Load__c hazmatLoad = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(7),
            Pickup_Window_End__c = System.now().addDays(7).addHours(2),
            Estimated_Delivery_DateTime__c = System.now().addDays(9),
            Delivery_Window_Begin__c = System.now().addDays(9),
            Delivery_Window_End__c = System.now().addDays(9).addHours(2),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Tank',
            Status__c = 'draft',
            Distance_Miles__c = 200,
            Weight_lbs__c = 25000,
            Billing_Rate__c = 3000.00,
            Carrier_Rate__c = 2200.00,
            Hazmat_Class__c = 'Class 3 - Flammable Liquid',
            UN_Number__c = 'UN1203'
        );
        
        Test.startTest();
        insert hazmatLoad;
        Test.stopTest();
        
        Load__c insertedHazmat = [SELECT Id, Hazmat_Class__c, UN_Number__c FROM Load__c WHERE Id = :hazmatLoad.Id];
        System.assertEquals('Class 3 - Flammable Liquid', insertedHazmat.Hazmat_Class__c);
        System.assertEquals('UN1203', insertedHazmat.UN_Number__c);
    }
    
    @isTest
    static void testMultipleLoadsWithDifferentMargins() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper Inc' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver LLC' LIMIT 1];
        
        List<Load__c> loads = new List<Load__c>();
        
        // High margin load
        loads.add(new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(1),
            Estimated_Delivery_DateTime__c = System.now().addDays(3),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'draft',
            Distance_Miles__c = 100,
            Weight_lbs__c = 5000,
            Billing_Rate__c = 2000.00,
            Carrier_Rate__c = 800.00
        ));
        
        // Low margin load
        loads.add(new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(2),
            Estimated_Delivery_DateTime__c = System.now().addDays(4),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Flatbed',
            Status__c = 'draft',
            Distance_Miles__c = 300,
            Weight_lbs__c = 20000,
            Billing_Rate__c = 3000.00,
            Carrier_Rate__c = 2850.00
        ));
        
        // Zero margin load
        loads.add(new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(3),
            Estimated_Delivery_DateTime__c = System.now().addDays(5),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Reefer',
            Status__c = 'draft',
            Distance_Miles__c = 250,
            Weight_lbs__c = 15000,
            Billing_Rate__c = 1500.00,
            Carrier_Rate__c = 1500.00
        ));
        
        Test.startTest();
        insert loads;
        Test.stopTest();
        
        List<Load__c> loadList = [SELECT Id, Margin__c, Margin_Percent__c FROM Load__c WHERE Id IN :loads ORDER BY Margin__c DESC];
        System.assertEquals(3, loadList.size());
        System.assertEquals(1200.00, loadList[0].Margin__c, 'Highest margin should be first');
        System.assertEquals(150.00, loadList[1].Margin__c, 'Middle margin second');
        System.assertEquals(0.00, loadList[2].Margin__c, 'Lowest margin last');
    }
    
    @isTest
    static void testOnTimeIndicator() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper Inc' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver LLC' LIMIT 1];
        
        DateTime deliveryWindow = System.now().addDays(5);
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(3),
            Estimated_Delivery_DateTime__c = System.now().addDays(5),
            Delivery_Window_Begin__c = deliveryWindow,
            Delivery_Window_End__c = deliveryWindow.addHours(2),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'draft',
            Distance_Miles__c = 100,
            Weight_lbs__c = 5000,
            Billing_Rate__c = 1000.00,
            Carrier_Rate__c = 700.00,
            Delivery_Window_Actual_Begin__c = null // Not delivered yet
        );
        
        Test.startTest();
        insert load;
        
        Load__c pendingLoad = [SELECT Id, On_Time_Indicator__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals('Pending', pendingLoad.On_Time_Indicator__c, 'Should show Pending before delivery');
        
        // Record actual delivery (on time)
        pendingLoad.Delivery_Window_Actual_Begin__c = deliveryWindow.addHours(1);
        update pendingLoad;
        
        Load__c onTimeLoad = [SELECT Id, On_Time_Indicator__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals('On Time', onTimeLoad.On_Time_Indicator__c, 'Should show On Time');
        
        // Record late delivery
        Load__c lateLoadToUpdate = [SELECT Id FROM Load__c WHERE Id = :load.Id];
        lateLoadToUpdate.Delivery_Window_Actual_Begin__c = deliveryWindow.addHours(4);
        update lateLoadToUpdate;
        
        Load__c lateLoad = [SELECT Id, On_Time_Indicator__c FROM Load__c WHERE Id = :load.Id];
        System.assertEquals('Late', lateLoad.On_Time_Indicator__c, 'Should show Late');
        
        Test.stopTest();
    }
}
