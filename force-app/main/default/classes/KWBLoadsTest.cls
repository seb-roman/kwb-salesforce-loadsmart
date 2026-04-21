/**
 * KWB Loads Test Suite
 * 
 * Simple tests for Phase 1 functionality
 * 
 * Run: Developer Console → Tests → Run Test
 *      Or: sfdx force:apex:test:run -u kwb-dev -c
 */

@isTest
public class KWBLoadsTest {
    
    /**
     * Test FMCSA Carrier Lookup
     */
    @isTest
    public static void testFMCSALookup() {
        FMCSACarrierLookup lookup = new FMCSACarrierLookup();
        
        // This test will fail if FMCSA API is down
        // In production, mock the HTTP response
        FMCSACarrierLookup.CarrierData data = lookup.searchByMCNumber('1776323');
        
        // Basic assertions (may vary based on FMCSA response)
        Assert.isNotNull(data, 'Carrier data should not be null');
        // Assert.isTrue(data.verified, 'Carrier should be verified'); // Uncomment if API working
    }
    
    /**
     * Test Carrier object creation
     */
    @isTest
    public static void testCarrierCreation() {
        Carrier__c carrier = new Carrier__c();
        carrier.Name = 'Test Carrier Inc';
        carrier.MC_Number__c = '1234567';
        carrier.USDOT_Number__c = '7654321';
        carrier.Legal_Name__c = 'Test Carrier Inc';
        carrier.Address__c = '123 Main St';
        carrier.City__c = 'Anytown';
        carrier.State__c = 'OH';
        carrier.Zip__c = '44444';
        carrier.Phone__c = '555-555-5555';
        carrier.DOT_Status__c = 'Active';
        carrier.Insurance_Status__c = 'Valid';
        carrier.FMCSA_Verified__c = true;
        
        insert carrier;
        
        Carrier__c retrieved = [SELECT Id, Name, MC_Number__c FROM Carrier__c WHERE Id = :carrier.Id];
        Assert.areEqual('Test Carrier Inc', retrieved.Name);
        Assert.areEqual('1234567', retrieved.MC_Number__c);
    }
    
    /**
     * Test Load object creation
     */
    @isTest
    public static void testLoadCreation() {
        // Create a test carrier first
        Carrier__c carrier = new Carrier__c();
        carrier.Name = 'Test Carrier';
        carrier.MC_Number__c = '9999999';
        insert carrier;
        
        // Create a test load
        Load__c load = new Load__c();
        load.Loadsmart_Shipment_ID__c = 'test-shipment-uuid-001';
        load.Order_Number__c = 'ORDER-12345';
        load.PO_Number__c = 'PO-67890';
        load.Status__c = 'Pending';
        load.Shipper_Name__c = 'Test Shipper';
        load.Shipper_Address__c = '100 Shipper Ln';
        load.Shipper_City__c = 'Shreveport';
        load.Shipper_State__c = 'LA';
        load.Shipper_Zip__c = '71101';
        load.Receiver_Name__c = 'Test Receiver';
        load.Receiver_Address__c = '200 Receiver Ave';
        load.Receiver_City__c = 'Houston';
        load.Receiver_State__c = 'TX';
        load.Receiver_Zip__c = '77001';
        load.Pickup_Window_Begin__c = DateTime.now().addDays(1);
        load.Pickup_Window_End__c = DateTime.now().addDays(1).addHours(8);
        load.Delivery_Window_Begin__c = DateTime.now().addDays(2);
        load.Delivery_Window_End__c = DateTime.now().addDays(2).addHours(8);
        load.Equipment_Type__c = 'Flatbed';
        load.Commodity__c = 'Mulch/Soil';
        load.Weight_lbs__c = 23880.20;
        load.Billing_Rate__c = 1500.00;
        load.Carrier__c = carrier.Id;
        load.Carrier_Rate__c = 1200.00;
        load.Delivery_Instructions__c = 'Call upon arrival';
        
        insert load;
        
        Load__c retrieved = [
            SELECT 
                Id, 
                Name, 
                Order_Number__c, 
                Billing_Rate__c, 
                Carrier_Rate__c, 
                Margin__c 
            FROM Load__c 
            WHERE Id = :load.Id
        ];
        
        Assert.isNotNull(retrieved.Name, 'Load number should be auto-generated');
        Assert.areEqual('ORDER-12345', retrieved.Order_Number__c);
        Assert.areEqual(1500.00, retrieved.Billing_Rate__c);
        Assert.areEqual(1200.00, retrieved.Carrier_Rate__c);
        Assert.areEqual(300.00, retrieved.Margin__c); // Formula: Billing - Carrier
    }
    
    /**
     * Test Load Status transitions
     */
    @isTest
    public static void testLoadStatusTransition() {
        Load__c load = new Load__c();
        load.Loadsmart_Shipment_ID__c = 'test-shipment-uuid-002';
        load.Order_Number__c = 'ORDER-99999';
        load.Status__c = 'Pending';
        load.Shipper_Name__c = 'Test Shipper';
        load.Shipper_Address__c = '100 Shipper Ln';
        load.Receiver_Name__c = 'Test Receiver';
        load.Receiver_Address__c = '200 Receiver Ave';
        load.Pickup_Window_Begin__c = DateTime.now().addDays(1);
        load.Pickup_Window_End__c = DateTime.now().addDays(1).addHours(8);
        load.Delivery_Window_Begin__c = DateTime.now().addDays(2);
        load.Delivery_Window_End__c = DateTime.now().addDays(2).addHours(8);
        
        insert load;
        
        // Transition to Assigned
        load.Status__c = 'Assigned';
        update load;
        
        Load__c updated = [SELECT Status__c FROM Load__c WHERE Id = :load.Id];
        Assert.areEqual('Assigned', updated.Status__c);
    }
    
    /**
     * Test Loadsmart Sync flag
     */
    @isTest
    public static void testLoadsmartSyncTracking() {
        Load__c load = new Load__c();
        load.Loadsmart_Shipment_ID__c = 'test-shipment-uuid-003';
        load.Order_Number__c = 'ORDER-88888';
        load.Status__c = 'Pending';
        load.Shipper_Name__c = 'Test Shipper';
        load.Shipper_Address__c = '100 Shipper Ln';
        load.Receiver_Name__c = 'Test Receiver';
        load.Receiver_Address__c = '200 Receiver Ave';
        load.Pickup_Window_Begin__c = DateTime.now().addDays(1);
        load.Pickup_Window_End__c = DateTime.now().addDays(1).addHours(8);
        load.Delivery_Window_Begin__c = DateTime.now().addDays(2);
        load.Delivery_Window_End__c = DateTime.now().addDays(2).addHours(8);
        load.Loadsmart_Synced__c = false;
        
        insert load;
        
        // Simulate post-back sync
        load.Loadsmart_Synced__c = true;
        load.Last_Loadsmart_Sync__c = DateTime.now();
        update load;
        
        Load__c synced = [SELECT Loadsmart_Synced__c, Last_Loadsmart_Sync__c FROM Load__c WHERE Id = :load.Id];
        Assert.isTrue(synced.Loadsmart_Synced__c, 'Sync flag should be true');
        Assert.isNotNull(synced.Last_Loadsmart_Sync__c, 'Last sync timestamp should be set');
    }
    
    /**
     * Test unique Loadsmart Shipment ID
     */
    @isTest
    public static void testLoadsmartShipmentIDUnique() {
        Load__c load1 = new Load__c();
        load1.Loadsmart_Shipment_ID__c = 'unique-uuid-only-once';
        load1.Order_Number__c = 'ORDER-11111';
        load1.Status__c = 'Pending';
        load1.Shipper_Name__c = 'Test Shipper';
        load1.Shipper_Address__c = '100 Shipper Ln';
        load1.Receiver_Name__c = 'Test Receiver';
        load1.Receiver_Address__c = '200 Receiver Ave';
        load1.Pickup_Window_Begin__c = DateTime.now().addDays(1);
        load1.Pickup_Window_End__c = DateTime.now().addDays(1).addHours(8);
        load1.Delivery_Window_Begin__c = DateTime.now().addDays(2);
        load1.Delivery_Window_End__c = DateTime.now().addDays(2).addHours(8);
        
        insert load1;
        
        // Try to create duplicate
        Load__c load2 = new Load__c();
        load2.Loadsmart_Shipment_ID__c = 'unique-uuid-only-once'; // Same ID
        load2.Order_Number__c = 'ORDER-22222';
        load2.Status__c = 'Pending';
        load2.Shipper_Name__c = 'Test Shipper 2';
        load2.Shipper_Address__c = '200 Shipper Ln';
        load2.Receiver_Name__c = 'Test Receiver 2';
        load2.Receiver_Address__c = '300 Receiver Ave';
        load2.Pickup_Window_Begin__c = DateTime.now().addDays(1);
        load2.Pickup_Window_End__c = DateTime.now().addDays(1).addHours(8);
        load2.Delivery_Window_Begin__c = DateTime.now().addDays(2);
        load2.Delivery_Window_End__c = DateTime.now().addDays(2).addHours(8);
        
        try {
            insert load2;
            Assert.fail('Should have thrown duplicate external ID error');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('DUPLICATE_EXTERNAL_ID'));
        }
    }
}
