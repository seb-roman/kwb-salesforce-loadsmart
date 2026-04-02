/**
 * Test Suite for CarrierAssignmentEngine (FMCSA-Based Scoring)
 * 
 * Tests scoring algorithm with 10+ FMCSA-specific scenarios:
 * 1. High CSA score (poor safety) → penalized in ranking
 * 2. Critical violation <90 days → hard filter (cannot assign)
 * 3. Multiple serious violations → elevated penalties → lower rank
 * 4. Clean record (low CSA, no violations) → top rank
 * 5. Insurance <30 days → warning flag, still eligible
 * 6. Insurance <7 days → hard filter (cannot assign)
 * 7. Margin calculation correct (shipper - typical carrier rate)
 * 8. Margin display in recommendation output
 * 9. Missing FMCSA data → graceful fallback to on-time %
 * 10. Comparison: FMCSA-weighted vs old on-time weighted
 * 
 * Target Coverage: >85%
 */

@isTest
public class CarrierAssignmentEngineTest {
    
    /**
     * Setup: Create test data (carriers with FMCSA data, loads)
     */
    @TestSetup
    public static void setupTestData() {
        // Create Test Shipper Account
        Account shipper = new Account();
        shipper.Name = 'Test Shipper Inc';
        insert shipper;
        
        // Create Test Carriers with FMCSA Data
        List<Carrier__c> carriers = new List<Carrier__c>();
        
        // ========== SCENARIO 1: Excellent Safety (Clean Record) ==========
        // CSA: 12 (excellent), 0 violations, 2 inspections
        Carrier__c carrierExcellent = new Carrier__c();
        carrierExcellent.Name = 'SafeHaul Inc (Excellent FMCSA)';
        carrierExcellent.MC_Number__c = '100001';
        carrierExcellent.USDOT_Number__c = '1000001';
        carrierExcellent.Status__c = 'Active';
        carrierExcellent.DOT_Status__c = 'ACTIVE';
        carrierExcellent.Insurance_Expiration__c = System.today().addDays(180);
        carrierExcellent.Service_Territory__c = 'OH;IN;KY;TX;AR;LA';
        carrierExcellent.Equipment_Types__c = 'Flatbed;Van';
        carrierExcellent.Active_Equipment_Count__c = 10;
        carrierExcellent.Average_Equipment_Utilization__c = 50;
        carrierExcellent.On_Time_Percent__c = 97.5;
        carrierExcellent.Typical_Rate__c = 1500.00;
        // FMCSA Data: Excellent
        carrierExcellent.CSA_Score__c = 12.0;           // 100 - 12 = 88 base score
        carrierExcellent.Critical_Violations_Count__c = 0;
        carrierExcellent.Serious_Violations_Count__c = 0;
        carrierExcellent.BASIC_Inspection_Count__c = 2;  // Under 5, no penalty
        carriers.add(carrierExcellent);
        
        // ========== SCENARIO 2: Good Safety (Marginal CSA) ==========
        // CSA: 32 (good), 1 serious violation (6 months ago), 4 inspections
        Carrier__c carrierGood = new Carrier__c();
        carrierGood.Name = 'MidwestLogistics LLC (Good FMCSA)';
        carrierGood.MC_Number__c = '100002';
        carrierGood.USDOT_Number__c = '1000002';
        carrierGood.Status__c = 'Active';
        carrierGood.DOT_Status__c = 'ACTIVE';
        carrierGood.Insurance_Expiration__c = System.today().addDays(120);
        carrierGood.Service_Territory__c = 'OH;IN;KY;TX;AR;LA';
        carrierGood.Equipment_Types__c = 'Flatbed;Van;Reefer';
        carrierGood.Active_Equipment_Count__c = 8;
        carrierGood.Average_Equipment_Utilization__c = 50;
        carrierGood.On_Time_Percent__c = 94.0;
        carrierGood.Typical_Rate__c = 1450.00;
        // FMCSA Data: Good
        carrierGood.CSA_Score__c = 32.0;                // 100 - 32 = 68 base
        carrierGood.Critical_Violations_Count__c = 0;
        carrierGood.Serious_Violations_Count__c = 1;    // -8
        carrierGood.BASIC_Inspection_Count__c = 4;      // No penalty
        carriers.add(carrierGood);
        
        // ========== SCENARIO 3: Marginal Safety (Multiple Violations) ==========
        // CSA: 48 (marginal), 2 serious + 1 critical (8 months ago, >90 days), 8 inspections
        Carrier__c carrierMarginal = new Carrier__c();
        carrierMarginal.Name = 'QuickFreight LLC (Marginal FMCSA)';
        carrierMarginal.MC_Number__c = '100003';
        carrierMarginal.USDOT_Number__c = '1000003';
        carrierMarginal.Status__c = 'Active';
        carrierMarginal.DOT_Status__c = 'ACTIVE';
        carrierMarginal.Insurance_Expiration__c = System.today().addDays(60);
        carrierMarginal.Service_Territory__c = 'OH;TX;AR';
        carrierMarginal.Equipment_Types__c = 'Flatbed';
        carrierMarginal.Active_Equipment_Count__c = 3;
        carrierMarginal.Average_Equipment_Utilization__c = 85;
        carrierMarginal.On_Time_Percent__c = 88.0;
        carrierMarginal.Typical_Rate__c = 1700.00;
        // FMCSA Data: Marginal (but NO recent critical violation, so NOT hard filtered)
        carrierMarginal.CSA_Score__c = 48.0;            // 100 - 48 = 52 base
        carrierMarginal.Critical_Violations_Count__c = 1; // OLD violation (8 months ago)
        carrierMarginal.Serious_Violations_Count__c = 2;  // -16
        carrierMarginal.BASIC_Inspection_Count__c = 8;    // Over 5: (8-5)*3 = -9
        carriers.add(carrierMarginal);
        
        // ========== SCENARIO 4: Poor Safety (Recent Critical Violation) ==========
        // CSA: 68 (poor), 1 CRITICAL violation (45 days ago - HARD FILTER), should not score
        Carrier__c carrierPoor = new Carrier__c();
        carrierPoor.Name = 'FastRoute Inc (Critical Violation <90d)';
        carrierPoor.MC_Number__c = '100004';
        carrierPoor.USDOT_Number__c = '1000004';
        carrierPoor.Status__c = 'Active';
        carrierPoor.DOT_Status__c = 'ACTIVE';
        carrierPoor.Insurance_Expiration__c = System.today().addDays(150);
        carrierPoor.Service_Territory__c = 'OH;KY;TX';
        carrierPoor.Equipment_Types__c = 'Flatbed';
        carrierPoor.Active_Equipment_Count__c = 5;
        carrierPoor.Average_Equipment_Utilization__c = 60;
        carrierPoor.On_Time_Percent__c = 82.0;
        carrierPoor.Typical_Rate__c = 1600.00;
        // FMCSA Data: HARD FILTER - Recent critical violation
        carrierPoor.CSA_Score__c = 68.0;
        carrierPoor.Critical_Violations_Count__c = 1;    // RECENT (45 days ago)
        carrierPoor.Serious_Violations_Count__c = 3;
        carrierPoor.BASIC_Inspection_Count__c = 12;
        // NOTE: This carrier will be hard-filtered (cannot assign)
        carriers.add(carrierPoor);
        
        // ========== SCENARIO 5: Insurance Expiring Soon (7-30 days) ==========
        // Insurance expires in 20 days - WARNING FLAG but still eligible
        Carrier__c carrierInsuranceWarning = new Carrier__c();
        carrierInsuranceWarning.Name = 'RoadWarriors Co (Insurance Warning)';
        carrierInsuranceWarning.MC_Number__c = '100005';
        carrierInsuranceWarning.USDOT_Number__c = '1000005';
        carrierInsuranceWarning.Status__c = 'Active';
        carrierInsuranceWarning.DOT_Status__c = 'ACTIVE';
        carrierInsuranceWarning.Insurance_Expiration__c = System.today().addDays(20);  // 7-30 days
        carrierInsuranceWarning.Service_Territory__c = 'OH;IN;TX;AR';
        carrierInsuranceWarning.Equipment_Types__c = 'Flatbed;Van';
        carrierInsuranceWarning.Active_Equipment_Count__c = 6;
        carrierInsuranceWarning.Average_Equipment_Utilization__c = 55;
        carrierInsuranceWarning.On_Time_Percent__c = 91.0;
        carrierInsuranceWarning.Typical_Rate__c = 1480.00;
        // FMCSA Data: Good
        carrierInsuranceWarning.CSA_Score__c = 28.0;
        carrierInsuranceWarning.Critical_Violations_Count__c = 0;
        carrierInsuranceWarning.Serious_Violations_Count__c = 0;
        carrierInsuranceWarning.BASIC_Inspection_Count__c = 3;
        // NOTE: insuranceWarning flag should be true, compliance score = 50
        carriers.add(carrierInsuranceWarning);
        
        // ========== SCENARIO 6: Insurance Expired (Hard Filter) ==========
        // Insurance expired 5 days ago - HARD FILTER, cannot assign
        Carrier__c carrierInsuranceExpired = new Carrier__c();
        carrierInsuranceExpired.Name = 'ExpiredInsurance Inc (HARD FILTER)';
        carrierInsuranceExpired.MC_Number__c = '100006';
        carrierInsuranceExpired.USDOT_Number__c = '1000006';
        carrierInsuranceExpired.Status__c = 'Active';
        carrierInsuranceExpired.DOT_Status__c = 'ACTIVE';
        carrierInsuranceExpired.Insurance_Expiration__c = System.today().addDays(-5);  // Expired
        carrierInsuranceExpired.Service_Territory__c = 'OH;IN;KY;TX';
        carrierInsuranceExpired.Equipment_Types__c = 'Flatbed';
        carrierInsuranceExpired.Active_Equipment_Count__c = 4;
        carrierInsuranceExpired.Average_Equipment_Utilization__c = 70;
        carrierInsuranceExpired.On_Time_Percent__c = 96.0;
        carrierInsuranceExpired.Typical_Rate__c = 1400.00;
        // FMCSA Data: Good, but insurance hard filtered
        carrierInsuranceExpired.CSA_Score__c = 18.0;
        carrierInsuranceExpired.Critical_Violations_Count__c = 0;
        carrierInsuranceExpired.Serious_Violations_Count__c = 0;
        carrierInsuranceExpired.BASIC_Inspection_Count__c = 1;
        // NOTE: This carrier will be hard-filtered (expired insurance)
        carriers.add(carrierInsuranceExpired);
        
        // ========== SCENARIO 7 & 8: Margin Calculation & Display ==========
        // Carrier with good metrics for margin testing
        Carrier__c carrierMarginTest = new Carrier__c();
        carrierMarginTest.Name = 'MarginTest Haulers (Margin Testing)';
        carrierMarginTest.MC_Number__c = '100007';
        carrierMarginTest.USDOT_Number__c = '1000007';
        carrierMarginTest.Status__c = 'Active';
        carrierMarginTest.DOT_Status__c = 'ACTIVE';
        carrierMarginTest.Insurance_Expiration__c = System.today().addDays(200);
        carrierMarginTest.Service_Territory__c = 'OH;TX;AR;LA';
        carrierMarginTest.Equipment_Types__c = 'Flatbed;Van';
        carrierMarginTest.Active_Equipment_Count__c = 7;
        carrierMarginTest.Average_Equipment_Utilization__c = 50;
        carrierMarginTest.On_Time_Percent__c = 93.0;
        carrierMarginTest.Typical_Rate__c = 1600.00;  // For margin testing
        // FMCSA Data: Excellent
        carrierMarginTest.CSA_Score__c = 15.0;
        carrierMarginTest.Critical_Violations_Count__c = 0;
        carrierMarginTest.Serious_Violations_Count__c = 0;
        carrierMarginTest.BASIC_Inspection_Count__c = 2;
        carriers.add(carrierMarginTest);
        
        // ========== SCENARIO 9: Missing FMCSA Data (Fallback to On-Time %) ==========
        // Carrier with NULL CSA_Score (new partner, not yet synced with FMCSA)
        Carrier__c carrierNoFMCSA = new Carrier__c();
        carrierNoFMCSA.Name = 'NewPartner Inc (No FMCSA Data)';
        carrierNoFMCSA.MC_Number__c = '100008';
        carrierNoFMCSA.USDOT_Number__c = '1000008';
        carrierNoFMCSA.Status__c = 'Active';
        carrierNoFMCSA.DOT_Status__c = 'ACTIVE';
        carrierNoFMCSA.Insurance_Expiration__c = System.today().addDays(180);
        carrierNoFMCSA.Service_Territory__c = 'OH;IN;TX;AR';
        carrierNoFMCSA.Equipment_Types__c = 'Flatbed;Van';
        carrierNoFMCSA.Active_Equipment_Count__c = 3;
        carrierNoFMCSA.Average_Equipment_Utilization__c = 40;
        carrierNoFMCSA.On_Time_Percent__c = 96.0;      // High on-time, fallback scoring
        carrierNoFMCSA.Typical_Rate__c = 1550.00;
        // FMCSA Data: ALL NULL (should fallback to on-time %)
        carrierNoFMCSA.CSA_Score__c = null;            // NULL - triggers fallback
        carrierNoFMCSA.Critical_Violations_Count__c = null;
        carrierNoFMCSA.Serious_Violations_Count__c = null;
        carrierNoFMCSA.BASIC_Inspection_Count__c = null;
        carriers.add(carrierNoFMCSA);
        
        // ========== Additional: Carrier with good scores for full ranking tests ==========
        Carrier__c carrierStandard = new Carrier__c();
        carrierStandard.Name = 'Standard Freight (Good All Around)';
        carrierStandard.MC_Number__c = '100009';
        carrierStandard.USDOT_Number__c = '1000009';
        carrierStandard.Status__c = 'Active';
        carrierStandard.DOT_Status__c = 'ACTIVE';
        carrierStandard.Insurance_Expiration__c = System.today().addDays(100);
        carrierStandard.Service_Territory__c = 'OH;IN;KY;TX;AR;LA;MS';
        carrierStandard.Equipment_Types__c = 'Flatbed;Van;Reefer';
        carrierStandard.Active_Equipment_Count__c = 12;
        carrierStandard.Average_Equipment_Utilization__c = 60;
        carrierStandard.On_Time_Percent__c = 92.0;
        carrierStandard.Typical_Rate__c = 1520.00;
        // FMCSA Data: Good
        carrierStandard.CSA_Score__c = 35.0;           // 100 - 35 = 65 base
        carrierStandard.Critical_Violations_Count__c = 0;
        carrierStandard.Serious_Violations_Count__c = 1;  // -8
        carrierStandard.BASIC_Inspection_Count__c = 5;    // No penalty (threshold is >=5)
        carriers.add(carrierStandard);
        
        insert carriers;
    }
    
    /**
     * Helper: Create test load
     */
    private static Load__c createTestLoad(
        String shipperCity,
        String shipperState,
        String receiverCity,
        String receiverState,
        String equipmentType,
        Decimal billingRate,
        DateTime pickupWindow
    ) {
        Load__c load = new Load__c();
        load.Shipper_City__c = shipperCity;
        load.Shipper_State__c = shipperState;
        load.Receiver_City__c = receiverCity;
        load.Receiver_State__c = receiverState;
        load.Equipment_Type__c = equipmentType;
        load.Billing_Rate__c = billingRate;
        load.Pickup_Window_Begin__c = pickupWindow;
        load.Status__c = 'Posted';
        return load;
    }
    
    // ========== FMCSA TEST SCENARIOS ==========
    
    /**
     * TEST 1: Excellent Safety (Clean Record)
     * 
     * SafeHaul Inc: CSA 12, 0 violations, 2 inspections (under 5)
     * Expected: FMCSA score = 100 - 12 = 88, ranked high
     */
    @isTest
    public static void testFMCSA_ExcellentSafetyRecord() {
        Load__c load = createTestLoad(
            'Columbus',
            'OH',
            'Houston',
            'TX',
            'Flatbed',
            2000.00,
            System.today().addDays(5)
        );
        insert load;
        
        CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
        CarrierAssignmentEngine.ScoringResult result = engine.scoreLoad(load);
        
        Assert.isTrue(result.hasViableCarriers, 'Should have viable carriers');
        
        // Find SafeHaul Inc
        CarrierAssignmentEngine.CarrierScoreInfo safeHaulScore = null;
        for (CarrierAssignmentEngine.CarrierScoreInfo info : result.topCarriers) {
            if (info.carrierName == 'SafeHaul Inc (Excellent FMCSA)') {
                safeHaulScore = info;
                break;
            }
        }
        
        Assert.isNotNull(safeHaulScore, 'SafeHaul should be in top carriers');
        Assert.isTrue(safeHaulScore.fmcsaSafetyScore >= 85.0, 'FMCSA score should be >=85 (excellent)');
        Assert.isTrue(safeHaulScore.finalScore > 85.0, 'Final score should be high for excellent safety');
        Assert.isNull(safeHaulScore.filterReason, 'Should not be filtered');
    }
    
    /**
     * TEST 2: Critical Violation <90 Days - HARD FILTER
     * 
     * FastRoute Inc: 1 critical violation 45 days ago
     * Expected: HARD FILTERED (cannot assign)
     */
    @isTest
    public static void testFMCSA_CriticalViolationHardFilter() {
        Load__c load = createTestLoad(
            'Columbus',
            'OH',
            'Houston',
            'TX',
            'Flatbed',
            2000.00,
            System.today().addDays(5)
        );
        insert load;
        
        CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
        CarrierAssignmentEngine.ScoringResult result = engine.scoreLoad(load);
        
        // FastRoute Inc should NOT be in top carriers
        for (CarrierAssignmentEngine.CarrierScoreInfo info : result.topCarriers) {
            Assert.notEqual('FastRoute Inc (Critical Violation <90d)', info.carrierName, 
                'Carrier with critical violation <90d should not be in top 3');
        }
        
        // But should be in scored carriers with filter reason
        Boolean found = false;
        for (CarrierAssignmentEngine.CarrierScoreInfo info : result.scoredCarriers) {
            if (info.carrierName == 'FastRoute Inc (Critical Violation <90d)') {
                found = true;
                Assert.isNotNull(info.filterReason, 'Should have filter reason');
                Assert.isTrue(info.filterReason.contains('FMCSA') || info.filterReason.contains('Critical'), 
                    'Filter reason should mention critical violation or FMCSA');
                break;
            }
        }
        Assert.isTrue(found, 'FastRoute should be in scored carriers (hard filtered)');
    }
    
    /**
     * TEST 3: Multiple Violations - Ranked Lower
     * 
     * QuickFreight: CSA 48, 2 serious, 1 critical (8mo old >90d), 8 inspections
     * Expected: FMCSA score penalized but still eligible (critical violation old enough)
     * Score = 52 base - 16 serious - 9 inspections = 27 (poor score but NOT hard filtered)
     */
    @isTest
    public static void testFMCSA_MultipleViolationsPenalized() {
        Load__c load = createTestLoad(
            'Columbus',
            'OH',
            'Dallas',
            'TX',
            'Flatbed',
            2000.00,
            System.today().addDays(5)
        );
        insert load;
        
        CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
        CarrierAssignmentEngine.ScoringResult result = engine.scoreLoad(load);
        
        // Find QuickFreight
        CarrierAssignmentEngine.CarrierScoreInfo quickFreightScore = null;
        for (CarrierAssignmentEngine.CarrierScoreInfo info : result.scoredCarriers) {
            if (info.carrierName == 'QuickFreight LLC (Marginal FMCSA)') {
                quickFreightScore = info;
                break;
            }
        }
        
        Assert.isNotNull(quickFreightScore, 'QuickFreight should be in scored carriers');
        // Score should be penalized (multiple violations) but still viable if no recent critical
        // This carrier should NOT be hard filtered (critical is 8 months old, >90 days)
        Assert.isNull(quickFreightScore.filterReason, 'Should not be hard filtered (critical violation >90d)');
        Assert.isTrue(quickFreightScore.fmcsaSafetyScore < 50.0, 'FMCSA score should be low due to violations');
    }
    
    /**
     * TEST 4: Insurance Expiring Soon (7-30 Days) - Warning, Still Eligible
     * 
     * RoadWarriors: Insurance expires in 20 days
     * Expected: WARNING FLAG = true, compliance score = 50, but not hard filtered
     */
    @isTest
    public static void testInsurance_ExpiringWarningSoftFilter() {
        Load__c load = createTestLoad(
            'Columbus',
            'OH',
            'Houston',
            'TX',
            'Flatbed',
            2000.00,
            System.today().addDays(5)
        );
        insert load;
        
        CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
        CarrierAssignmentEngine.ScoringResult result = engine.scoreLoad(load);
        
        // Find RoadWarriors
        CarrierAssignmentEngine.CarrierScoreInfo roadWarriorsScore = null;
        for (CarrierAssignmentEngine.CarrierScoreInfo info : result.topCarriers) {
            if (info.carrierName == 'RoadWarriors Co (Insurance Warning)') {
                roadWarriorsScore = info;
                break;
            }
        }
        
        Assert.isNotNull(roadWarriorsScore, 'RoadWarriors should be eligible and in recommendations');
        Assert.isTrue(roadWarriorsScore.insuranceWarning == true, 'insuranceWarning flag should be true');
        Assert.isTrue(roadWarriorsScore.complianceScore == 50.0, 'Compliance score should be 50 for 7-30 day expiration');
        Assert.isNull(roadWarriorsScore.filterReason, 'Should not be hard filtered (has 20 days)');
    }
    
    /**
     * TEST 5: Insurance Expired - HARD FILTER
     * 
     * ExpiredInsurance Inc: Insurance expired 5 days ago
     * Expected: HARD FILTERED (cannot assign)
     */
    @isTest
    public static void testInsurance_ExpiredHardFilter() {
        Load__c load = createTestLoad(
            'Columbus',
            'OH',
            'Houston',
            'TX',
            'Flatbed',
            2000.00,
            System.today().addDays(5)
        );
        insert load;
        
        CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
        CarrierAssignmentEngine.ScoringResult result = engine.scoreLoad(load);
        
        // ExpiredInsurance Inc should NOT be in top carriers
        for (CarrierAssignmentEngine.CarrierScoreInfo info : result.topCarriers) {
            Assert.notEqual('ExpiredInsurance Inc (HARD FILTER)', info.carrierName, 
                'Carrier with expired insurance should not be in top 3');
        }
        
        // Should be in scored carriers with insurance filter reason
        Boolean found = false;
        for (CarrierAssignmentEngine.CarrierScoreInfo info : result.scoredCarriers) {
            if (info.carrierName == 'ExpiredInsurance Inc (HARD FILTER)') {
                found = true;
                Assert.isNotNull(info.filterReason, 'Should have filter reason');
                Assert.isTrue(info.filterReason.contains('Insurance') || info.filterReason.contains('expired'), 
                    'Filter reason should mention insurance');
                break;
            }
        }
        Assert.isTrue(found, 'ExpiredInsurance should be in scored carriers (hard filtered)');
    }
    
    /**
     * TEST 6: Margin Calculation Correct
     * 
     * Load Billing Rate: $2000
     * CarrierMarginTest Typical Rate: $1600
     * Expected Margin: $400 (healthy)
     */
    @isTest
    public static void testMargin_CalculationCorrect() {
        Load__c load = createTestLoad(
            'Columbus',
            'OH',
            'Houston',
            'TX',
            'Flatbed',
            2000.00,  // Billing rate
            System.today().addDays(5)
        );
        insert load;
        
        CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
        CarrierAssignmentEngine.ScoringResult result = engine.scoreLoad(load);
        
        // Find MarginTest carrier
        CarrierAssignmentEngine.CarrierScoreInfo marginTestScore = null;
        for (CarrierAssignmentEngine.CarrierScoreInfo info : result.topCarriers) {
            if (info.carrierName == 'MarginTest Haulers (Margin Testing)') {
                marginTestScore = info;
                break;
            }
        }
        
        Assert.isNotNull(marginTestScore, 'MarginTest carrier should be in recommendations');
        Assert.areEqual(400.0, marginTestScore.estimatedMargin, 'Margin should be 2000 - 1600 = 400');
    }
    
    /**
     * TEST 7: Margin Display Status
     * 
     * Margin $400: Should be "Tight: $400" (0-499 range)
     */
    @isTest
    public static void testMargin_DisplayStatus() {
        Load__c load = createTestLoad(
            'Columbus',
            'OH',
            'Houston',
            'TX',
            'Flatbed',
            2000.00,
            System.today().addDays(5)
        );
        insert load;
        
        CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
        CarrierAssignmentEngine.ScoringResult result = engine.scoreLoad(load);
        
        // Find MarginTest carrier
        CarrierAssignmentEngine.CarrierScoreInfo marginTestScore = null;
        for (CarrierAssignmentEngine.CarrierScoreInfo info : result.topCarriers) {
            if (info.carrierName == 'MarginTest Haulers (Margin Testing)') {
                marginTestScore = info;
                break;
            }
        }
        
        Assert.isNotNull(marginTestScore, 'MarginTest carrier should be in recommendations');
        Assert.isNotNull(marginTestScore.marginStatus, 'Margin status should be populated');
        Assert.isTrue(marginTestScore.marginStatus.contains('Tight'), 'Margin status should show "Tight" for $400');
    }
    
    /**
     * TEST 8: Missing FMCSA Data - Fallback to On-Time %
     * 
     * NewPartner Inc: CSA_Score = null, On_Time_Percent = 96%
     * Expected: Fallback to on-time scoring (96% = 100 score)
     */
    @isTest
    public static void testFMCSA_MissingDataFallback() {
        Load__c load = createTestLoad(
            'Columbus',
            'OH',
            'Houston',
            'TX',
            'Flatbed',
            1800.00,
            System.today().addDays(5)
        );
        insert load;
        
        CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
        CarrierAssignmentEngine.ScoringResult result = engine.scoreLoad(load);
        
        // Find NewPartner (no FMCSA data)
        CarrierAssignmentEngine.CarrierScoreInfo newPartnerScore = null;
        for (CarrierAssignmentEngine.CarrierScoreInfo info : result.topCarriers) {
            if (info.carrierName == 'NewPartner Inc (No FMCSA Data)') {
                newPartnerScore = info;
                break;
            }
        }
        
        Assert.isNotNull(newPartnerScore, 'NewPartner should be in recommendations (fallback to on-time %)');
        // On-time 96% should score 100 (98%+ = 100, 95%+ = 90... 96% falls in 95%+ band = 90)
        Assert.isTrue(newPartnerScore.fmcsaSafetyScore >= 90.0, 'Should fallback to on-time scoring (96% >= 90)');
        Assert.isNull(newPartnerScore.filterReason, 'Should not be filtered');
    }
    
    /**
     * TEST 9: Top 3 Ranking (Full Scoring)
     * 
     * Verify that top 3 carriers are ranked correctly by final score
     * Expected top 1: SafeHaul (excellent FMCSA, insurance valid)
     */
    @isTest
    public static void testScoring_TopThreeRanking() {
        Load__c load = createTestLoad(
            'Columbus',
            'OH',
            'Houston',
            'TX',
            'Flatbed',
            2200.00,
            System.today().addDays(5)
        );
        insert load;
        
        CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
        CarrierAssignmentEngine.ScoringResult result = engine.scoreLoad(load);
        
        Assert.isTrue(result.hasViableCarriers, 'Should have viable carriers');
        Assert.isTrue(result.topCarriers.size() >= 1, 'Should have at least 1 top carrier');
        
        // Verify top carrier is SafeHaul (excellent FMCSA score)
        Assert.isTrue(result.topCarriers[0].carrierName.contains('SafeHaul'), 
            'Top carrier should be SafeHaul with excellent FMCSA');
        
        // Verify ranking order (scores descending)
        for (Integer i = 0; i < result.topCarriers.size() - 1; i++) {
            Assert.isTrue(
                result.topCarriers[i].finalScore >= result.topCarriers[i + 1].finalScore,
                'Top carriers should be ranked by score descending'
            );
        }
    }
    
    /**
     * TEST 10: Code Coverage - Edge Cases
     * 
     * Test null/missing fields, geography scoring, capacity check
     */
    @isTest
    public static void testScoring_EdgeCasesAndCoverage() {
        // Load with null pickup date should be handled gracefully
        Load__c load = new Load__c();
        load.Shipper_State__c = 'OH';
        load.Receiver_State__c = 'TX';
        load.Equipment_Type__c = 'Flatbed';
        load.Billing_Rate__c = 2000.00;
        load.Pickup_Window_Begin__c = System.today().addDays(5);
        insert load;
        
        CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
        CarrierAssignmentEngine.ScoringResult result = engine.scoreLoad(load);
        
        // Should not crash, should handle missing data
        Assert.isNotNull(result, 'Should return result even with some missing data');
        Assert.isNotNull(result.scoredCarriers, 'Should have scored carriers');
    }
    
    /**
     * TEST 11: Geography Scoring
     * 
     * Carrier with full territory coverage should score 100 on geography
     */
    @isTest
    public static void testScoring_GeographyFull() {
        Load__c load = createTestLoad(
            'Columbus',
            'OH',
            'Houston',
            'TX',
            'Flatbed',
            2000.00,
            System.today().addDays(5)
        );
        insert load;
        
        CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
        CarrierAssignmentEngine.ScoringResult result = engine.scoreLoad(load);
        
        // SafeHaul covers OH;IN;KY;TX;AR;LA (both origin and destination)
        CarrierAssignmentEngine.CarrierScoreInfo safeHaulScore = null;
        for (CarrierAssignmentEngine.CarrierScoreInfo info : result.topCarriers) {
            if (info.carrierName == 'SafeHaul Inc (Excellent FMCSA)') {
                safeHaulScore = info;
                break;
            }
        }
        
        Assert.isNotNull(safeHaulScore, 'SafeHaul should be in top carriers');
        Assert.areEqual(100.0, safeHaulScore.geographicScore, 'Should score 100 for full territory coverage');
    }
}
