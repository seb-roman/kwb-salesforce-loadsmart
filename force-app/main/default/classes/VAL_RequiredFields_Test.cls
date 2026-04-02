/**
 * Test class for required field validation rules
 * Tests VAL_Equipment_Type_Required, VAL_Shipper_Required, VAL_Receiver_Required, VAL_Hazmat_UN_Number_Required
 */
@isTest
public class VAL_RequiredFields_Test {
    
    @TestSetup
    static void setupTestData() {
        Account shipper = new Account(Name = 'Test Shipper', BillingCountry = 'US');
        insert shipper;
        
        Account receiver = new Account(Name = 'Test Receiver', BillingCountry = 'US');
        insert receiver;
    }
    
    @isTest
    static void testEquipmentTypeRequired_WhenPosted() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = null, // Missing equipment type
            Status__c = 'posted',
            Distance_Miles__c = 100,
            Weight_lbs__c = 5000
        );
        
        Test.startTest();
        try {
            insert load;
            System.assert(false, 'Should have failed - equipment type required');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Equipment Type is required'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testEquipmentTypeNotRequired_InDraft() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = null,
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
    static void testShipperRequired_WhenPosted() {
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = null,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Van',
            Status__c = 'posted',
            Distance_Miles__c = 100,
            Weight_lbs__c = 5000
        );
        
        Test.startTest();
        try {
            insert load;
            System.assert(false, 'Should have failed - shipper required');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Shipper is required'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testReceiverRequired_WhenPosted() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = shipper.Id,
            Receiver__c = null,
            Equipment_Type__c = 'Van',
            Status__c = 'posted',
            Distance_Miles__c = 100,
            Weight_lbs__c = 5000
        );
        
        Test.startTest();
        try {
            insert load;
            System.assert(false, 'Should have failed - receiver required');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Receiver is required'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testHazmatUNNumberRequired() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Tank',
            Status__c = 'draft',
            Distance_Miles__c = 100,
            Weight_lbs__c = 5000,
            Hazmat_Class__c = 'Class 3',
            UN_Number__c = null // Missing UN number
        );
        
        Test.startTest();
        try {
            insert load;
            System.assert(false, 'Should have failed - UN number required for hazmat');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('UN Number is required'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testHazmatWithUNNumber_ShouldPass() {
        Account shipper = [SELECT Id FROM Account WHERE Name = 'Test Shipper' LIMIT 1];
        Account receiver = [SELECT Id FROM Account WHERE Name = 'Test Receiver' LIMIT 1];
        
        Load__c load = new Load__c(
            Pickup_Window_Begin__c = System.now().addDays(5),
            Estimated_Delivery_DateTime__c = System.now().addDays(7),
            Shipper__c = shipper.Id,
            Receiver__c = receiver.Id,
            Equipment_Type__c = 'Tank',
            Status__c = 'draft',
            Distance_Miles__c = 100,
            Weight_lbs__c = 5000,
            Hazmat_Class__c = 'Class 3',
            UN_Number__c = 'UN1170'
        );
        
        Test.startTest();
        insert load;
        Test.stopTest();
        
        Load__c insertedLoad = [SELECT Id FROM Load__c WHERE Id = :load.Id];
        System.assertNotEquals(null, insertedLoad.Id);
    }
}
