# Agent 2: Implementation Notes for Day 3-5 Coding

**Purpose:** Detailed pseudocode and implementation guidance for refactoring CarrierAssignmentEngine.cls with FMCSA metrics.

---

## Overview of Changes

### Current State (Before Day 3)
- Uses `On_Time_Percent__c` for Dimension 4 scoring
- Basic insurance compliance check (expired or not)
- No FMCSA-specific scoring

### Target State (After Day 3)
- Uses FMCSA metrics (CSA + violations + inspections) for Dimension 4
- Granular insurance thresholds with hard filters
- Margin display in CarrierScoreInfo
- Hard filter for critical violations (< 90 days)

---

## Pseudocode: FMCSA Safety Scoring

```apex
/**
 * Score FMCSA Safety Record (Dimension 4, Weight 15%)
 * 
 * Inputs: Carrier__c with FMCSA fields
 * Output: Decimal score (0-100)
 * 
 * Business Logic:
 *   1. Get CSA score (invert: 100 - CSA)
 *   2. Apply penalties for violations (critical -15, serious -8)
 *   3. Apply penalties for high inspection rate
 *   4. Hard filter if critical violation < 90 days
 *   5. Clamp result to 0-100
 */

private Decimal scoreFMCSASafety(Carrier__c carrier) {
    // Step 1: Base score from CSA
    Decimal csaScore = carrier.CSA_Score__c;
    
    if (csaScore == null) {
        // Fallback: use on-time % if FMCSA data unavailable
        return scoreOnTimePerformanceAsInterim(carrier);
    }
    
    // Convert CSA to our scale (invert: lower=better becomes higher=better)
    Decimal csaBaseScore = 100 - csaScore;  // e.g., CSA 35 → 65
    
    // Step 2: Hard filter for critical violations < 90 days
    Integer criticalViolationCount = carrier.Critical_Violations_Count__c != null 
        ? carrier.Critical_Violations_Count__c.intValue() 
        : 0;
    
    if (criticalViolationCount > 0) {
        // Check if any critical violation is less than 90 days old
        // TODO: Query FMCSA_Violation__c junction object to verify dates
        // For now, assume all violations < 90 days if count > 0 (conservative)
        // In production, check violation_date__c < TODAY() - 90 days
        
        // If critical violation found in last 90 days:
        // return null (hard filter)
    }
    
    // Step 3: Penalties for violations
    Integer seriousViolationCount = carrier.Serious_Violations_Count__c != null 
        ? carrier.Serious_Violations_Count__c.intValue() 
        : 0;
    
    Decimal criticalPenalty = criticalViolationCount * 15.0;  // -15 per critical
    Decimal seriousPenalty = seriousViolationCount * 8.0;      // -8 per serious
    
    // Step 4: Penalties for inspection rate
    Integer basicInspections = carrier.BASIC_Inspection_Count__c != null 
        ? carrier.BASIC_Inspection_Count__c.intValue() 
        : 0;
    
    Decimal inspectionPenalty = 0.0;
    if (basicInspections > 5) {
        inspectionPenalty = (basicInspections - 5) * 3.0;  // -3 per inspection over 5
    }
    
    // Step 5: Calculate final FMCSA score
    Decimal fmcsaScore = csaBaseScore - criticalPenalty - seriousPenalty - inspectionPenalty;
    fmcsaScore = Math.max(0.0, fmcsaScore);  // Clamp to 0-100
    fmcsaScore = Math.min(100.0, fmcsaScore);
    
    return fmcsaScore;
}

/**
 * Fallback: Score based on on-time % if FMCSA data unavailable
 */
private Decimal scoreOnTimePerformanceAsInterim(Carrier__c carrier) {
    Decimal onTimePercent = carrier.On_Time_Percent__c;
    
    if (onTimePercent == null) {
        return 50.0;  // Default neutral score
    }
    
    if (onTimePercent >= 98.0) {
        return 100.0;
    } else if (onTimePercent >= 95.0) {
        return 90.0;
    } else if (onTimePercent >= 90.0) {
        return 75.0;
    } else if (onTimePercent >= 85.0) {
        return 50.0;
    } else if (onTimePercent >= 75.0) {
        return 25.0;
    } else {
        return 0.0;
    }
}
```

---

## Pseudocode: Enhanced Insurance Compliance Check

```apex
/**
 * Enhanced Insurance Compliance Check (Dimension 5, Weight 10%)
 * 
 * Hard filters:
 *   - DOT Status != 'ACTIVE'
 *   - Insurance expired (< today)
 *   - Insurance expires < 7 days from today
 * 
 * Warnings:
 *   - Insurance expires in 7-30 days → score 50, flag warning
 * 
 * Normal:
 *   - Insurance valid for > 30 days → score 100
 */

private class InsuranceCheckResult {
    Boolean isEligible;
    Decimal score;
    String reason;
    Boolean hasWarning;
}

private InsuranceCheckResult checkInsuranceCompliance(Carrier__c carrier) {
    InsuranceCheckResult result = new InsuranceCheckResult();
    result.isEligible = true;
    result.score = 100.0;
    result.hasWarning = false;
    
    // Hard Filter 1: DOT Status must be ACTIVE
    if (String.isBlank(carrier.DOT_Status__c) || carrier.DOT_Status__c != 'ACTIVE') {
        result.isEligible = false;
        result.score = 0.0;
        result.reason = 'DOT Status not ACTIVE: ' + (String.isBlank(carrier.DOT_Status__c) 
            ? 'unknown' 
            : carrier.DOT_Status__c);
        return result;
    }
    
    // Check Insurance Expiration
    if (carrier.Insurance_Expiration__c == null) {
        // No expiration date recorded
        result.isEligible = false;
        result.score = 0.0;
        result.reason = 'No insurance expiration date on record';
        return result;
    }
    
    Integer daysUntilExpiration = carrier.Insurance_Expiration__c.daysBetween(System.today());
    
    // Hard Filter 2: Insurance cannot expire in < 7 days
    if (daysUntilExpiration < 7) {
        result.isEligible = false;
        result.score = 0.0;
        result.reason = 'Insurance expires in ' + daysUntilExpiration + ' days (< 7 day threshold)';
        return result;
    }
    
    // Soft Warning: Insurance expires in 7-30 days
    if (daysUntilExpiration <= 30) {
        result.isEligible = true;
        result.score = 50.0;
        result.hasWarning = true;
        result.reason = 'Insurance expiring soon: ' + daysUntilExpiration + ' days';
        return result;
    }
    
    // Normal: Insurance valid for > 30 days
    result.isEligible = true;
    result.score = 100.0;
    result.reason = 'Insurance valid (' + daysUntilExpiration + ' days)';
    return result;
}
```

---

## Pseudocode: Hard Filter for Critical Violations

```apex
/**
 * Check if carrier has critical violation within 90 days
 * 
 * Returns: true if should FILTER OUT, false if eligible
 */

private Boolean hasCriticalViolationWithin90Days(Carrier__c carrier) {
    if (carrier.Critical_Violations_Count__c == null || 
        carrier.Critical_Violations_Count__c == 0) {
        return false;  // No critical violations
    }
    
    // Query FMCSA violations junction object to check violation dates
    // TODO: Implement when FMCSA junction table structure is finalized
    
    List<FMCSA_Violation__c> recentCritical = [
        SELECT Id, Carrier__c, Violation_Type__c, Violation_Date__c
        FROM FMCSA_Violation__c
        WHERE Carrier__c = :carrier.Id
        AND Violation_Type__c IN ('CRITICAL', 'OUT_OF_SERVICE')
        AND Violation_Date__c >= :System.today().addDays(-90)
        LIMIT 1
    ];
    
    return !recentCritical.isEmpty();
}
```

---

## Pseudocode: Margin Calculation

```apex
/**
 * Calculate estimated margin for informational display
 * 
 * Margin = Load.Billing_Rate__c - Carrier.Typical_Rate__c
 * 
 * NOT used in scoring, only displayed to dispatcher
 */

private Decimal estimateMargin(Load__c load, Carrier__c carrier) {
    Decimal billingRate = load.Billing_Rate__c;
    Decimal typicalRate = carrier.Typical_Rate__c;
    
    if (billingRate == null || typicalRate == null) {
        return 0.0;
    }
    
    Decimal margin = billingRate - typicalRate;
    return margin;  // Can be positive (profit) or negative (loss)
}

/**
 * Get margin status for display (informational only)
 */
private String getMarginStatus(Decimal margin) {
    if (margin == null || margin == 0) {
        return 'Unknown';
    }
    
    if (margin >= 500) {
        return 'Healthy: $' + String.valueOf(margin.setScale(2));
    } else if (margin >= 0) {
        return 'Tight: $' + String.valueOf(margin.setScale(2));
    } else {
        return 'Loss: $' + String.valueOf(margin.setScale(2));
    }
}
```

---

## Updated CarrierScoreInfo Wrapper Class

```apex
public class CarrierScoreInfo {
    public Id carrierId;
    public String carrierName;
    public Decimal finalScore;
    
    // Dimension scores
    public Decimal geographicScore;      // (0-100)
    public Decimal equipmentScore;       // (0-100)
    public Decimal capacityScore;        // (0-100)
    public Decimal fmcsaSafetyScore;     // (0-100) ← NEW: replaces onTimeScore
    public Decimal insuranceScore;       // (0-100) ← RENAMED: was complianceScore
    
    // Margin (informational)
    public Decimal estimatedMargin;      // Load_Rate - Carrier_Rate
    public String marginStatus;          // "Healthy", "Tight", "Loss"
    
    // Status & flags
    public String filterReason;          // null if eligible, reason string if filtered
    public Boolean insuranceWarning;     // true if expires in 7-30 days
    
    public CarrierScoreInfo() {
        this.finalScore = 0.0;
        this.estimatedMargin = 0.0;
        this.filterReason = null;
        this.insuranceWarning = false;
    }
}
```

---

## Updated scoreCarrier() Method Flow

```apex
private CarrierScoreInfo scoreCarrier(Load__c load, Carrier__c carrier) {
    CarrierScoreInfo info = new CarrierScoreInfo();
    info.carrierId = carrier.Id;
    info.carrierName = carrier.Name;
    
    // Step 1: Insurance & Compliance Filter (mandatory)
    InsuranceCheckResult insuranceCheck = checkInsuranceCompliance(carrier);
    if (!insuranceCheck.isEligible) {
        info.insuranceScore = insuranceCheck.score;
        info.filterReason = 'Insurance/DOT: ' + insuranceCheck.reason;
        return info;  // Filtered
    }
    info.insuranceScore = insuranceCheck.score;
    info.insuranceWarning = insuranceCheck.hasWarning;
    
    // Step 2: Check for critical violations < 90 days (hard filter)
    if (hasCriticalViolationWithin90Days(carrier)) {
        info.filterReason = 'FMCSA: Critical violation within 90 days';
        info.fmcsaSafetyScore = 0.0;
        return info;  // Filtered — cannot assign
    }
    
    // Step 3: Equipment Filter (mandatory)
    EquipmentCheckResult equipmentCheck = checkEquipmentMatch(load, carrier);
    if (!equipmentCheck.isEligible) {
        info.equipmentScore = equipmentCheck.score;
        info.filterReason = 'Equipment: ' + equipmentCheck.reason;
        return info;  // Filtered
    }
    info.equipmentScore = equipmentCheck.score;
    
    // Step 4: Capacity Filter (mandatory)
    CapacityCheckResult capacityCheck = checkCapacity(load, carrier);
    if (!capacityCheck.isEligible) {
        info.capacityScore = capacityCheck.score;
        info.filterReason = 'Capacity: ' + capacityCheck.reason;
        return info;  // Filtered
    }
    info.capacityScore = capacityCheck.score;
    
    // Step 5: Geography Score (not a filter)
    info.geographicScore = scoreGeography(load, carrier);
    
    // Step 6: FMCSA Safety Score (NEW — replaces on-time)
    info.fmcsaSafetyScore = scoreFMCSASafety(carrier);
    
    // Step 7: Estimated Margin (informational only)
    info.estimatedMargin = estimateMargin(load, carrier);
    info.marginStatus = getMarginStatus(info.estimatedMargin);
    
    // Step 8: Calculate final score with NEW WEIGHTS
    info.finalScore = calculateFinalScore(info);
    
    return info;
}
```

---

## Updated calculateFinalScore() Method

```apex
/**
 * Calculate final score using FMCSA-weighted formula
 * 
 * New weights:
 *   Geography: 0.30
 *   Equipment: 0.25
 *   Capacity: 0.20
 *   FMCSA Safety: 0.15 (was On-Time)
 *   Insurance: 0.10
 */

private Decimal calculateFinalScore(CarrierScoreInfo info) {
    Decimal WEIGHT_GEOGRAPHY = 0.30;
    Decimal WEIGHT_EQUIPMENT = 0.25;
    Decimal WEIGHT_CAPACITY = 0.20;
    Decimal WEIGHT_FMCSA_SAFETY = 0.15;  // ← NEW
    Decimal WEIGHT_INSURANCE = 0.10;      // ← RENAMED
    
    Decimal finalScore = 
        (info.geographicScore * WEIGHT_GEOGRAPHY) +
        (info.equipmentScore * WEIGHT_EQUIPMENT) +
        (info.capacityScore * WEIGHT_CAPACITY) +
        (info.fmcsaSafetyScore * WEIGHT_FMCSA_SAFETY) +  // NEW
        (info.insuranceScore * WEIGHT_INSURANCE);        // NEW
    
    return finalScore;
}
```

---

## Test Class Structure (Day 4)

```apex
@isTest
public class CarrierAssignmentEngineTest {
    
    // Test data setup
    @testSetup
    static void setupTestData() {
        // Create test carriers with various FMCSA profiles:
        // 1. Clean record (CSA 12, no violations)
        // 2. Marginal (CSA 48, 1 critical, 2 serious)
        // 3. Critical violation < 90 days (hard filter)
        // 4. Insurance expired (hard filter)
        // 5. Insurance < 7 days (hard filter)
        // 6. Insurance 7-30 days (warning)
        // 7. Missing FMCSA data (fallback to on-time %)
        
        // Create test loads for various routes
        
        // Create test assignments to calculate On_Time_Percent__c
    }
    
    // ===== FMCSA Safety Scoring Tests =====
    
    @isTest
    static void testExcellentSafetyRecord() {
        // CSA 12, no violations → Score 88+
    }
    
    @isTest
    static void testMarginalSafetyRecord() {
        // CSA 48, 1 critical, 2 serious → Score 20-40
    }
    
    @isTest
    static void testCriticalViolationFilter() {
        // 1 critical violation < 90 days → FILTERED OUT
    }
    
    @isTest
    static void testInspectionRatePenalty() {
        // 9 BASIC inspections → penalty = (9-5)*3 = -12
    }
    
    // ===== Insurance & Compliance Tests =====
    
    @isTest
    static void testInsuranceHardFilter_Expired() {
        // Insurance expired → FILTERED OUT
    }
    
    @isTest
    static void testInsuranceHardFilter_Expiring7Days() {
        // Insurance expires in 4 days → FILTERED OUT
    }
    
    @isTest
    static void testInsuranceWarning_30Days() {
        // Insurance expires in 20 days → Score 50, WARNING flag
    }
    
    @isTest
    static void testInsuranceValid() {
        // Insurance expires in 60 days → Score 100, no warning
    }
    
    @isTest
    static void testDOTStatusInactive() {
        // DOT Status = "INACTIVE" → FILTERED OUT
    }
    
    // ===== Margin Tests =====
    
    @isTest
    static void testMarginCalculation() {
        // Margin = Billing_Rate - Typical_Rate
        // Test positive, zero, negative margins
    }
    
    @isTest
    static void testMarginDisplay() {
        // Healthy (≥$500), Tight, Loss
    }
    
    // ===== Fallback Tests =====
    
    @isTest
    static void testMissingFMCSAData_FallbackToOnTime() {
        // CSA_Score__c is null → use On_Time_Percent__c
        // 96% on-time → Score 90
    }
    
    @isTest
    static void testFMCSAVsOnTime_Comparison() {
        // Same carrier scored with FMCSA and On-Time
        // Verify FMCSA gives more accurate safety assessment
    }
    
    // ===== Integration Tests =====
    
    @isTest
    static void testScoreLoad_TopThreeRecommendations() {
        // Score a load against 7 carriers
        // Verify top 3 are returned in correct order
        // Verify filtered carriers are excluded
    }
    
    @isTest
    static void testFallbackAlert_NoViableCarriers() {
        // All carriers filtered → alert message
        // Verify fallback message explains why
    }
}
```

---

## Key Changes Summary (For Coder)

| Item | Old | New | Impact |
|------|-----|-----|--------|
| **Dimension 4** | On-Time % (15%) | FMCSA Safety (15%) | Query CSA score + violations |
| **Insurance Check** | Basic valid/expired | Granular thresholds (<7 hard, 7-30 warn) | Add daysUntilExpiration logic |
| **Hard Filters** | Equipment only | Equipment + critical violations + insurance | Add violation date check |
| **Margin** | Not displayed | Displayed in CarrierScoreInfo | Add margin calculation |
| **Weights** | Same | Same | Update calculateFinalScore() |
| **Fallback** | On-time only | FMCSA → on-time fallback | Add null check for CSA |

---

## SOQL Queries to Implement

```apex
// Query violations for hard filter check
SELECT Id, Carrier__c, Violation_Type__c, Violation_Date__c
FROM FMCSA_Violation__c
WHERE Carrier__c = :carrier.Id
AND Violation_Type__c IN ('CRITICAL', 'OUT_OF_SERVICE')
AND Violation_Date__c >= :System.today().addDays(-90)
LIMIT 1

// Query overlapping loads for capacity check (existing, no change)
SELECT COUNT()
FROM Load__c
WHERE Carrier__c = :carrier.Id
AND Status__c IN ('Assigned', 'Dispatched', 'In_Transit')
AND Pickup_Window_Begin__c >= :windowStart
AND Pickup_Window_Begin__c < :windowEnd
```

---

## Error Handling & Edge Cases

1. **Missing CSA Score:** Fallback to On_Time_Percent__c
2. **No Insurance Expiration Date:** Hard filter (unknown expiration = high risk)
3. **Null violation counts:** Treat as 0
4. **No FMCSA violation records:** Use violation count fields directly
5. **Division by zero:** Not applicable in this algorithm
6. **Future enhancement:** If FMCSA API integration fails, gracefully fallback to cached data

---

## Code Coverage Targets (Day 4)

- Target: >85% code coverage
- New FMCSA functions: 100% coverage required
- Insurance check: 100% coverage (critical path)
- Fallback logic: 100% coverage (error resilience)
- Test cases: 10+ scenarios

---

**Ready for Day 3-5 Implementation**

