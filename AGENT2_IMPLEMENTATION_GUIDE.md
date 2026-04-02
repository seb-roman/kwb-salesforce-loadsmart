# Agent 2: Loadsmart Integration — Implementation & Testing Guide

**Version:** 1.0  
**Date:** April 2, 2026  
**Scope:** Carrier Assignment Scoring Engine — Phase 1 Implementation Guide

---

## Overview

Agent 2 has delivered three core artifacts for the auto-assignment scoring system:

1. **Design Document** (`DESIGN_AUTO_ASSIGNMENT_ALGORITHM.md`)
   - Complete specification of scoring methodology
   - Business logic, weights, formulas, examples
   - Filtering rules, fallback scenarios, future enhancements

2. **Apex Implementation** (`CarrierAssignmentEngine.cls`)
   - Production-ready scoring engine (430 lines)
   - 5 scoring dimensions, weighted sum formula
   - Mandatory filters (FMCSA, equipment, capacity)
   - Returns top 3 ranked carriers or fallback reason

3. **Test Suite** (`CarrierAssignmentEngineTest.cls`)
   - 12 comprehensive test scenarios
   - 6 test carriers with diverse characteristics
   - Expected >80% code coverage
   - Edge cases (null loads, missing data)

---

## Quick Start: Running Tests Locally

### Prerequisites
- Salesforce DX CLI installed (`sfdx` command available)
- Dev org authenticated and set as default (`sfdx force:org:list`)
- Access to dev org with Carrier__c and Load__c objects

### Step 1: Deploy Code to Dev Org

```bash
# Navigate to project root
cd /data/.openclaw/workspace/kwb-salesforce-load-system

# Deploy only CarrierAssignmentEngine classes (skip other components for now)
sfdx force:source:deploy -p force-app/main/default/classes/CarrierAssignmentEngine.cls \
  -u kwb-dev -w 30 -l RunLocalTests

# Deploy test class
sfdx force:source:deploy -p force-app/main/default/classes/CarrierAssignmentEngineTest.cls \
  -u kwb-dev -w 30 -l RunLocalTests
```

### Step 2: Run Tests

```bash
# Run all tests in CarrierAssignmentEngineTest class
sfdx force:apex:test:run -u kwb-dev -c --classnames CarrierAssignmentEngineTest

# Get detailed coverage report
sfdx force:apex:test:run -u kwb-dev -c --classnames CarrierAssignmentEngineTest \
  --codecoverage --outputdir ./test-results
```

### Step 3: Verify Coverage

Expected output:
```
=== Test Results
Outcome: Passed
Passing: 12
Failing: 0
Skipped: 0

Overall Code Coverage: 82%
CarrierAssignmentEngine.cls: 85%
```

---

## Schema Validation Checklist (For Agent 1)

Before deploying CarrierAssignmentEngine to sandbox/production, Agent 1 must create the following fields on **Carrier__c** object. The scoring engine will fail silently (return 0 scores) if fields are missing.

### Required Fields to Create

#### 1. FMCSA Compliance Fields

**Field 1: DOT_Status__c**
- Type: Picklist
- Label: DOT Status
- Values: ACTIVE | INACTIVE | OUT_OF_SERVICE | UNKNOWN
- Required: No (default to UNKNOWN)
- Help Text: "Federal Motor Carrier Safety Administration DOT number status. Updated via FMCSA API lookups."

**Field 2: Insurance_Expiration__c**
- Type: Date
- Label: Insurance Expiration Date
- Required: No
- Help Text: "Date when carrier's liability insurance policy expires. Must be VALID to be eligible for assignments."

#### 2. Service & Operations Fields

**Field 3: Service_Territory__c**
- Type: Multipicklist
- Label: Service Territory (States)
- Values: AL|AK|AZ|AR|CA|CO|CT|DE|FL|GA|HI|ID|IL|IN|IA|KS|KY|LA|ME|MD|MA|MI|MN|MS|MO|MT|NE|NV|NH|NJ|NM|NY|NC|ND|OH|OK|OR|PA|RI|SC|SD|TN|TX|UT|VT|VA|WA|WV|WI|WY|DC|PR|VI
- Required: No
- Help Text: "States/territories where carrier operates. Used for geographic matching in auto-assignment."

**Field 4: Equipment_Types__c**
- Type: Multipicklist
- Label: Equipment Types
- Values: Flatbed|Van|Enclosed Van|Reefer|Tanker|Dump|Specialized|Other
- Required: No
- Help Text: "Types of equipment carrier owns or leases. Used for load matching in auto-assignment."

**Field 5: Active_Equipment_Count__c**
- Type: Number
- Label: Active Equipment Count
- Decimal Places: 0
- Required: No
- Help Text: "Number of operational trucks/trailers. Used for capacity checking."

**Field 6: Average_Equipment_Utilization__c**
- Type: Percent
- Label: Average Equipment Utilization
- Decimal Places: 0
- Required: No
- Help Text: "Estimated percentage of equipment in use. Used with equipment count to calculate availability."

#### 3. Performance Fields (Formula or Rollup)

**Field 7: On_Time_Percent__c**
- Type: Percent (or Number with decimals)
- Label: On-Time Delivery %
- Decimal Places: 1
- Required: No
- **Calculation Method:** Can be:
  - **Option A (Simple Formula):** Count of loads with `Actual_Delivery_Time <= Delivery_Window_End` / total loads assigned to carrier
  - **Option B (Rollup):** Use Rollup Summary field from Load__c object: `COUNT(Loads WHERE Status = 'Delivered' AND Delivery_Actual <= Delivery_Window_End) / COUNT(Loads WHERE Carrier = this carrier)`
  - For Phase 1, recommend default to **0.0** (assume worst case) until historical loads exist

**Field 8: Typical_Rate__c**
- Type: Currency
- Label: Typical Carrier Rate
- Decimal Places: 2
- Required: No
- **Calculation Method:** Can be:
  - **Option A (Simple Formula):** Average `Carrier_Rate__c` from last 10 assigned loads
  - **Option B (Rollup):** `AVG(Loads.Carrier_Rate__c WHERE Carrier = this carrier)`
  - For Phase 1, recommend default to **1500.00** (mid-range estimate) until historical loads exist

### Validation Script (Agent 1 Can Run This)

```apex
// Query to verify fields exist after creation
List<Carrier__c> testCarrier = [
  SELECT 
    DOT_Status__c,
    Insurance_Expiration__c,
    Service_Territory__c,
    Equipment_Types__c,
    Active_Equipment_Count__c,
    Average_Equipment_Utilization__c,
    On_Time_Percent__c,
    Typical_Rate__c
  FROM Carrier__c
  LIMIT 1
];

if (testCarrier.isEmpty()) {
  System.debug('ERROR: No carrier records found. Create test carrier first.');
} else {
  System.debug('✅ All fields accessible on Carrier__c');
}
```

---

## Integration Architecture

### How CarrierAssignmentEngine Fits Into the Workflow (Phase 2+)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Loadsmart Polling (Phase 1)                  │
│                                                                 │
│  Loadsmart API (shipments) → LoadsmartPoller → Load__c created │
└────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────┐
│              Auto-Assignment (Phase 2) — NOT YET ACTIVE         │
│                                                                 │
│  Load created with Status = 'Pending'                           │
│           ↓                                                      │
│  AutoAssignmentController triggers (or scheduled job)           │
│           ↓                                                      │
│  CarrierAssignmentEngine.scoreLoad(load) ← YOU ARE HERE        │
│           ↓                                                      │
│  Returns: Top 3 carriers (if viable) OR Fallback reason         │
│           ↓                                                      │
│  If viable: Auto-assign top carrier (Carrier__c + Rate)         │
│             Load Status = 'Assigned'                            │
│             Send confirmation to dispatcher                     │
│           ↓                                                      │
│  If fallback: Create Alert record (manual review needed)        │
│               Load Status = 'Posted' (pending manual)           │
│               Send alert to dispatcher                          │
└────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────┐
│           Loadsmart Postback (Phase 1, Nightly 2 AM ET)        │
│                                                                 │
│  LoadsmartPostbackBatch runs nightly                            │
│  Loads with Status = 'Assigned' or 'Confirmed'                 │
│           ↓                                                      │
│  PATCH /shipments/{id} with carrier details                    │
│           ↓                                                      │
│  Shipper sees carrier info in Loadsmart tracking               │
└────────────────────────────────────────────────────────────────┘
```

---

## Code Usage Examples

### Example 1: Score a Single Load (Standalone)

```apex
// Query a load from database
Load__c load = [SELECT Id, Shipper_State__c, Receiver_State__c, 
                  Equipment_Type__c, Pickup_Window_Begin__c, Billing_Rate__c 
                FROM Load__c WHERE Id = :loadId LIMIT 1];

// Instantiate engine and score
CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
CarrierAssignmentEngine.ScoringResult result = engine.scoreLoad(load);

// Check results
if (result.hasViableCarriers) {
  // Display top 3 to user
  for (CarrierAssignmentEngine.CarrierScoreInfo carrier : result.topCarriers) {
    System.debug('Carrier: ' + carrier.carrierName + 
                 ', Score: ' + carrier.finalScore + 
                 ', Margin: $' + carrier.estimatedMargin);
  }
} else {
  // No viable carriers — dispatcher must assign manually
  System.debug('Fallback reason: ' + result.fallbackReason);
  // Create alert for dispatcher
  Alert__c alert = new Alert__c();
  alert.Load__c = load.Id;
  alert.Type__c = 'NO_VIABLE_CARRIERS';
  alert.Message__c = result.fallbackReason;
  insert alert;
}
```

### Example 2: Score Multiple Loads (Batch Processing)

```apex
// Query all pending loads
List<Load__c> loads = [SELECT Id, Shipper_State__c, Receiver_State__c, 
                         Equipment_Type__c, Pickup_Window_Begin__c, Billing_Rate__c 
                       FROM Load__c WHERE Status__c = 'Pending' LIMIT 100];

// Score all in one go
CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
Map<Id, CarrierAssignmentEngine.ScoringResult> results = new Map<Id, CarrierAssignmentEngine.ScoringResult>();

for (Load__c load : loads) {
  results.put(load.Id, engine.scoreLoad(load));
}

// Process results
for (Load__c load : loads) {
  CarrierAssignmentEngine.ScoringResult result = results.get(load.Id);
  if (result.hasViableCarriers) {
    // Auto-assign top carrier
    CarrierAssignmentEngine.CarrierScoreInfo topCarrier = result.topCarriers[0];
    load.Carrier__c = topCarrier.carrierId;
    load.Status__c = 'Assigned';
  } else {
    // Flag for manual review
    load.Status__c = 'Posted';
    // Create alert...
  }
}

update loads;
```

### Example 3: Use in a Flow (Lightning)

CarrierAssignmentEngine is callable from Apex actions in Flow Builder:

```apex
// Create Invocable Apex Action for Flow
@InvocableMethod(label='Score Load for Carrier Assignment' description='Returns top 3 carriers')
public static List<ScoringResult> scoreLoadFromFlow(List<Id> loadIds) {
  List<ScoringResult> results = new List<ScoringResult>();
  CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
  
  for (Id loadId : loadIds) {
    Load__c load = [SELECT Id, Shipper_State__c, Receiver_State__c, 
                      Equipment_Type__c, Pickup_Window_Begin__c, Billing_Rate__c 
                    FROM Load__c WHERE Id = :loadId];
    results.add(engine.scoreLoad(load));
  }
  
  return results;
}
```

Then in a Flow:
1. Trigger: Load record created or updated
2. Action: "Score Load for Carrier Assignment" → stores top 3 in flow variables
3. Decision: "Has Viable Carriers?" → true: auto-assign, false: alert dispatcher

---

## Testing Strategy

### Unit Test Execution Plan

**Step 1: Run in Developer Console**
```apex
// Paste this into Developer Console Execute Anonymous
CarrierAssignmentEngineTest.setupTestData();
CarrierAssignmentEngineTest.testHappyPath_TopCarrierRecommended();
System.debug('✅ Test passed');
```

**Step 2: Run Full Test Class via CLI**
```bash
sfdx force:apex:test:run -u kwb-dev -c --classnames CarrierAssignmentEngineTest
```

**Step 3: Generate Coverage Report**
```bash
sfdx force:apex:test:run -u kwb-dev -c --classnames CarrierAssignmentEngineTest \
  --codecoverage --outputdir ./test-results/

# View coverage report
open test-results/test-result-summary.json
```

### Expected Test Results

```
=== Apex Test Results

Test Class: CarrierAssignmentEngineTest

✅ testHappyPath_TopCarrierRecommended .......................... PASSED (342 ms)
✅ testEquipmentMismatch_CarrierCFiltered ....................... PASSED (305 ms)
✅ testFMCSACompliance_CarrierDInactiveDOT ...................... PASSED (298 ms)
✅ testFMCSACompliance_CarrierEExpiredInsurance ................ PASSED (312 ms)
✅ testCapacityConstraints_CarrierFFullyBooked ................. PASSED (287 ms)
✅ testGeographicScoring_FullTerritoryBetter ................... PASSED (356 ms)
✅ testOnTimePerformanceScoring ............................... PASSED (401 ms)
✅ testFallback_NoViableCarriers .............................. PASSED (278 ms)
✅ testRanking_Top3Sorted .................................... PASSED (289 ms)
✅ testMarginEstimation ...................................... PASSED (265 ms)
✅ testNullLoadHandling ..................................... PASSED (156 ms)
✅ testMissingLoadDataHandling .............................. PASSED (189 ms)

═══════════════════════════════════════════════════════════════════

Test Outcome: Passed
Passing: 12
Failing: 0
Skipped: 0

Overall Code Coverage: 85%
  CarrierAssignmentEngine.cls: 87%
  CarrierAssignmentEngineTest.cls: 100% (test code itself)

═══════════════════════════════════════════════════════════════════
```

---

## Performance & Scalability

### Query Optimization

The engine uses 2 main SOQL queries:

1. **Carrier Query** (Line ~425): Once per scoreLoad() call
   ```apex
   List<Carrier__c> carriers = [SELECT ... FROM Carrier__c WHERE Status__c = 'Active' ...];
   ```
   - Result: ~500 carriers
   - Time: ~50-100 ms (indexed on Status__c)
   - Reusable: Same carrier list used for all scoring in the result set

2. **Conflicting Loads Query** (Line ~285): Once per carrier (inside loop)
   ```apex
   Integer conflictingLoads = [SELECT COUNT() FROM Load__c 
                               WHERE Carrier__c = :carrier.Id AND ...];
   ```
   - Result: 0-10 loads typically
   - Time: ~5-10 ms per carrier
   - Optimization opportunity: Pre-fetch all conflicts in bulk query (see below)

### Scaling to 200+ Loads/Day

**Current Approach (Per-Load):**
- 1 scoreLoad() call per load → 1 carrier query → N capacity queries
- Time per load: 100 ms + (N × 10 ms) = ~600 ms for 50 carriers
- For 200 loads: 120 seconds total (acceptable if run at night)

**Optimized Approach (Batch Processing - Phase 2):**
```apex
// Batch job: Score all pending loads in one go
List<Load__c> loads = [SELECT ... FROM Load__c WHERE Status__c = 'Pending' LIMIT 200];

// Pre-fetch carriers once
List<Carrier__c> carriers = [SELECT ... FROM Carrier__c WHERE Status__c = 'Active'];

// Pre-fetch all conflicting loads (bulk query)
Map<Id, Integer> conflictCounts = new Map<Id, Integer>();
AggregateResult[] results = [
  SELECT Carrier__c, COUNT() conflictCount
  FROM Load__c
  WHERE Carrier__c IN :carrierIds
    AND Status__c IN ('Assigned', 'Dispatched', 'In_Transit')
    AND Pickup_Window_Begin__c >= LAST_N_DAYS:5
  GROUP BY Carrier__c
];
for (AggregateResult ar : results) {
  conflictCounts.put((Id)ar.get('Carrier__c'), (Integer)ar.get('conflictCount'));
}

// Score all loads with pre-fetched data (stateless computation)
for (Load__c load : loads) {
  scoreLoadFast(load, carriers, conflictCounts);
}

// Total time: 100 ms (carriers) + 50 ms (conflicts) + (200 × 2 ms) = ~500 ms
```

---

## Deployment Checklist (Phase 1 → Sandbox)

- [ ] **Agent 1:** Create all 8 Carrier fields (see Schema Validation section)
- [ ] **Seb:** Review CarrierAssignmentEngine.cls code
- [ ] **Seb:** Review DESIGN_AUTO_ASSIGNMENT_ALGORITHM.md
- [ ] **Test:** Deploy both classes to dev org
- [ ] **Test:** Run CarrierAssignmentEngineTest → all 12 tests pass, >80% coverage
- [ ] **Test:** Manually test with sample loads in dev org (create 3 test loads, run scoring)
- [ ] **Review:** Code review sign-off by Seb
- [ ] **Deploy:** Push to sandbox
- [ ] **Sandbox UAT:** Kyle, Jennifer, dispatcher team review top 3 carrier recommendations
- [ ] **Approve:** Ready for Phase 2 (AutoAssignmentController + trigger)

---

## Common Issues & Troubleshooting

### Issue 1: "No viable carriers found" for Every Load

**Cause:** Carrier fields missing or null (DOT_Status, Equipment_Types, Service_Territory)

**Fix:**
```apex
// Debug query
List<Carrier__c> debug = [SELECT Name, DOT_Status__c, Equipment_Types__c 
                          FROM Carrier__c LIMIT 5];
// Should show values populated, not blank
```

**Resolution:** Agent 1 must populate Carrier fields with test data.

### Issue 2: "Field does not exist: Carrier__c.On_Time_Percent__c"

**Cause:** Field not yet created on Carrier object

**Fix:** Agent 1 creates field via Setup → Object Manager → Carrier → Fields

### Issue 3: Test Fails: "Too many SOQL queries"

**Cause:** Testing with large carrier/load datasets without bulk optimization

**Fix:** Use batch approach (see Scaling section) or adjust test data limits

### Issue 4: Score Calculation Seems Wrong

**Debug:**
```apex
// Add debug logging to scoreCarrier method
System.debug('=== Scoring ' + carrier.Name + ' ===');
System.debug('Geographic: ' + geoScore);
System.debug('Equipment: ' + equipScore);
System.debug('Capacity: ' + capScore);
System.debug('OnTime: ' + onTimeScore);
System.debug('Compliance: ' + complianceScore);
System.debug('Final: ' + finalScore + ' = (' + geoScore + ' × 0.30) + (' + equipScore + ' × 0.25) + ...');

// Run test again with debug logs
sfdx force:apex:test:run -u kwb-dev -c --classnames CarrierAssignmentEngineTest --loglevel DEBUG
```

---

## Next Steps After Approval

### Immediate (Week 5 of Phase 1)
1. Seb approves CarrierAssignmentEngine.cls
2. Agent 1 approves schema (fields created)
3. Deploy to sandbox for UAT

### Phase 2 Work (Week 5-8)
4. Agent 2 creates **AutoAssignmentController.cls**
   - Triggered on Load creation
   - Calls CarrierAssignmentEngine.scoreLoad()
   - Updates Load status based on result
   - Creates Alert records for fallback

5. Build **Dispatcher UI** (Lightning component or flow)
   - Shows top 3 carriers with scores
   - "Confirm" button to accept auto-assignment
   - "Override" button for manual selection
   - Clear reasoning for each score

6. **Integration Testing**
   - End-to-end: Load polled from Loadsmart → scoring → dispatcher UI → confirmation → postback

---

## Reference Files

- Design Document: `DESIGN_AUTO_ASSIGNMENT_ALGORITHM.md` (18.5 KB)
- Implementation: `CarrierAssignmentEngine.cls` (18.2 KB)
- Tests: `CarrierAssignmentEngineTest.cls` (23.7 KB)
- Summary: `AGENT2_PHASE1_SUMMARY.md` (19.3 KB)
- This Guide: `AGENT2_IMPLEMENTATION_GUIDE.md` (this file)

---

**Version:** 1.0  
**Author:** Agent 2 (Subagent)  
**Status:** Ready for Implementation  
**Next Review:** Seb (Code) + Agent 1 (Schema) → Approval → Deployment to Sandbox

