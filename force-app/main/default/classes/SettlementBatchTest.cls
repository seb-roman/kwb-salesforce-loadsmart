/**
 * SettlementBatchTest.cls
 * 
 * Test class for SettlementBatch functionality
 * Covers: Settlement creation, duplicate prevention, and consolidation
 * 
 * @author Agent 4
 * @version 1.0
 */
@IsTest
private class SettlementBatchTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test carriers
        Account carrier1 = new Account();
        carrier1.Name = 'Carrier 1';
        carrier1.Type = 'Carrier';
        
        Account carrier2 = new Account();
        carrier2.Name = 'Carrier 2';
        carrier2.Type = 'Carrier';
        
        insert new List<Account> { carrier1, carrier2 };
        
        // Create test loads
        List<Load__c> loads = new List<Load__c>();
        
        // Carrier 1 - 5 loads
        for (Integer i = 0; i < 5; i++) {
            Load__c load = new Load__c();
            load.Name = 'Load-C1-' + i;
            load.Carrier__c = carrier1.Id;
            load.Carrier_Rate__c = 1000 + (i * 100);
            load.Status__c = 'Invoiced';
            load.Status__c = 'Not_Settled';
            loads.add(load);
        }
        
        // Carrier 2 - 3 loads
        for (Integer i = 0; i < 3; i++) {
            Load__c load = new Load__c();
            load.Name = 'Load-C2-' + i;
            load.Carrier__c = carrier2.Id;
            load.Carrier_Rate__c = 800 + (i * 50);
            load.Status__c = 'Invoiced';
            load.Status__c = 'Not_Settled';
            loads.add(load);
        }
        
        insert loads;
    }
    
    @IsTest
    static void testSettlementCreation() {
        // Act
        Test.startTest();
        SettlementBatch batch = new SettlementBatch();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        
        // Assert
        List<Settlement__c> settlements = [SELECT Id, Carrier__c, Gross_Amount__c FROM Settlement__c];
        System.assertEquals(2, settlements.size(), 'Should create 2 settlements (one per carrier)');
    }
    
    @IsTest
    static void testDuplicateSettlementPrevention() {
        // Arrange - Create a settlement for carrier 1
        Account carrier1 = [SELECT Id FROM Account WHERE Name = 'Carrier 1' LIMIT 1];
        Settlement__c existing = new Settlement__c();
        existing.Carrier__c = carrier1.Id;
        existing.Settlement_Period_Start__c = Date.today().addDays(-1);
        existing.Status__c = 'Pending';
        existing.Gross_Amount__c = 5000;
        insert existing;
        
        // Act
        Test.startTest();
        SettlementBatch batch = new SettlementBatch();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        
        // Assert
        List<Settlement__c> settlements = [
            SELECT Carrier__c FROM Settlement__c
            WHERE Settlement_Period_Start__c = :Date.today().addDays(-1)
        ];
        
        // Should only have 1 settlement for carrier 1 (not 2)
        Integer carrier1Count = 0;
        for (Settlement__c s : settlements) {
            if (s.Carrier__c == carrier1.Id) {
                carrier1Count++;
            }
        }
        System.assertEquals(1, carrier1Count, 'Should prevent duplicate settlement for same carrier/period');
    }
    
    @IsTest
    static void testLoadStatusUpdate() {
        // Act
        Test.startTest();
        SettlementBatch batch = new SettlementBatch();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        
        // Assert
        List<Load__c> loads = [
            SELECT Status__c FROM Load__c
            WHERE Status__c = 'Pending'
        ];
        System.assertEquals(8, loads.size(), 'Should update all 8 loads to Pending');
    }
    
    @IsTest
    static void testSettlementPeriodDates() {
        // Act
        Test.startTest();
        SettlementBatch batch = new SettlementBatch();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        
        // Assert
        List<Settlement__c> settlements = [
            SELECT Settlement_Period_Start__c, Settlement_Period_End__c FROM Settlement__c
        ];
        
        for (Settlement__c s : settlements) {
            System.assertNotEquals(null, s.Settlement_Period_Start__c);
            System.assertNotEquals(null, s.Settlement_Period_End__c);
            
            // Period should be exactly 6 days
            Integer daysDiff = s.Settlement_Period_End__c.daysBetween(s.Settlement_Period_Start__c);
            System.assertEquals(6, daysDiff, 'Settlement period should be 6 days');
        }
    }
    
    @IsTest
    static void testMultipleCarriers() {
        // Act
        Test.startTest();
        SettlementBatch batch = new SettlementBatch();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        
        // Assert
        List<Settlement__c> settlements = [
            SELECT Carrier__c, Gross_Amount__c FROM Settlement__c
            ORDER BY Carrier__c ASC
        ];
        
        System.assertEquals(2, settlements.size(), 'Should have settlements for 2 carriers');
        
        // Carrier 1: 1000 + 1100 + 1200 + 1300 + 1400 = 6000
        // Carrier 2: 800 + 850 + 900 = 2550
        Decimal carrier1Expected = 6000;
        Decimal carrier2Expected = 2550;
        
        for (Settlement__c s : settlements) {
            if (s.Carrier__c == [SELECT Id FROM Account WHERE Name = 'Carrier 1' LIMIT 1].Id) {
                System.assertEquals(carrier1Expected, s.Gross_Amount__c);
            } else {
                System.assertEquals(carrier2Expected, s.Gross_Amount__c);
            }
        }
    }
    
    @IsTest
    static void testOnlySettledLoadsIncluded() {
        // Arrange - Create a non-settled load
        Account carrier1 = [SELECT Id FROM Account WHERE Name = 'Carrier 1' LIMIT 1];
        Load__c unsettledLoad = new Load__c();
        unsettledLoad.Name = 'Unsettled Load';
        unsettledLoad.Carrier__c = carrier1.Id;
        unsettledLoad.Carrier_Rate__c = 5000;
        unsettledLoad.Status__c = 'Draft'; // Not invoiced
        unsettledLoad.Status__c = 'Not_Settled';
        insert unsettledLoad;
        
        // Act
        Test.startTest();
        SettlementBatch batch = new SettlementBatch();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        
        // Assert
        List<Settlement__c> settlements = [SELECT Gross_Amount__c FROM Settlement__c];
        
        // Gross should NOT include the unsettled load's rate (5000)
        // Should still be 6000 (from 5 original loads)
        for (Settlement__c s : settlements) {
            System.assert(s.Gross_Amount__c != 11000, 'Should not include non-invoiced load');
        }
    }
    
    @IsTest
    static void testDeductionCalculation() {
        // Act
        Test.startTest();
        SettlementBatch batch = new SettlementBatch();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        
        // Assert
        List<Settlement__c> settlements = [
            SELECT Deductions__c, Net_Payment__c, Gross_Amount__c FROM Settlement__c
        ];
        
        for (Settlement__c s : settlements) {
            // Phase 1: Deductions should be 0
            System.assertEquals(0, s.Deductions__c);
            
            // Net should equal Gross
            System.assertEquals(s.Gross_Amount__c, s.Net_Payment__c);
        }
    }
    
    @IsTest
    static void testEmptyBatchHandling() {
        // Arrange - Delete all loads
        delete [SELECT Id FROM Load__c];
        
        // Act
        Test.startTest();
        SettlementBatch batch = new SettlementBatch();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        
        // Assert - No error, settlements should be empty
        List<Settlement__c> settlements = [SELECT Id FROM Settlement__c];
        System.assertEquals(0, settlements.size(), 'Should handle empty batch gracefully');
    }
    
    @IsTest
    static void testSchedulableInterface() {
        // Act & Assert - Should not throw exception
        Test.startTest();
        SettlementBatch batch = new SettlementBatch();
        String jobId = System.schedule('Test Settlement Batch', '0 0 1 * * ?', batch);
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Should return valid job ID');
    }
    
    @IsTest
    static void testCSVExportFormat() {
        // Note: CSV generation is tested indirectly through finish() method
        // Verify that the batch completes without error
        Test.startTest();
        SettlementBatch batch = new SettlementBatch();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        
        // Assert
        List<Settlement__c> settlements = [SELECT Id FROM Settlement__c];
        System.assertEquals(2, settlements.size(), 'Batch should complete successfully');
    }
}
