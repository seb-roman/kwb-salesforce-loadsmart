# KWB Logistics — Auto-Assignment Scoring Algorithm Design

**Version:** 1.0  
**Date:** April 2, 2026  
**Author:** Agent 2 (Loadsmart Integration & Dispatch)  
**Status:** Ready for Implementation  
**Phase:** Phase 2 (Scoring algorithm begins Phase 1, auto-assignment runs Phase 2)

---

## Executive Summary

The **Auto-Assignment Scoring Algorithm** is the intelligent core of KWB's dispatch system. It automatically evaluates candidate carriers against incoming loads and recommends the best match based on multiple weighted criteria. This document defines the scoring methodology, business logic, fallback rules, and implementation approach.

### Problem Statement

**Manual Carrier Assignment is slow and subjective:**
- Dispatcher must manually search for suitable carriers
- Selection criteria vary by person (fatigue, preference, incomplete information)
- Best carrier for a load may not be obvious (geography + equipment + cost + reliability)
- Missed opportunities: lower-cost carriers that are geographically perfect get passed over
- Delays: assignment takes 5-10 minutes per load instead of instantaneous

**Solution:**
Algorithmic scoring that evaluates **every available carrier** against **every load characteristic** in milliseconds, ranks candidates by suitability, and presents the top 3 with confidence scores. Dispatcher confirms or overrides with one click.

### Expected Business Impact

- **Speed:** Load assignment reduced from 5-10 min (manual) to <1 sec (auto) + dispatcher confirmation
- **Optimization:** Systematic selection improves carrier utilization and margin
- **Compliance:** FMCSA status & insurance auto-validated (no expired carriers assigned)
- **Consistency:** Same logic applied to every load (no human variance)
- **Scale:** Can process 200+ loads/day without adding headcount

---

## Scoring Methodology

### High-Level Overview

**Input:**
- 1 Load record (shipper origin, destination, equipment type, commodity, date window, weight)
- N Carrier records (MC#, DOT#, service territory, equipment capabilities, capacity, performance history)
- FMCSA data (DOT status, insurance status, SAFETYNET violations)

**Process:**
1. **Filter:** Remove ineligible carriers (FMCSA inactive, equipment mismatch, no capacity)
2. **Score:** Evaluate remaining carriers across 6 scoring dimensions (0-100 each)
3. **Weight:** Apply business-defined weights to each dimension
4. **Rank:** Calculate final score = sum(dimension_score × weight), sort descending
5. **Output:** Top 3 carriers with scores, recommendation reason, fallback flag

**Fallback:**
- If 0 eligible carriers found → flag Load for manual review, send alert to dispatcher, stay in "Posted" status

---

## Scoring Dimensions

### 1. Geographic Match (Weight: 30%)

**Purpose:** Prioritize carriers with coverage in the pickup/delivery regions.

**Data Sources:**
- Load: `Shipper_City__c`, `Shipper_State__c`, `Receiver_City__c`, `Receiver_State__c`
- Carrier: `Service_Territory__c` (multiselect picklist: regions served), `Home_Base_City__c`, `Home_Base_State__c`

**Scoring Logic:**

```
IF Carrier.Service_Territory__c contains Load.Shipper_State & Load.Receiver_State:
  base_score = 100  (carrier covers both origin and destination states)
ELSE IF Carrier.Service_Territory__c contains EITHER Load.Shipper_State OR Load.Receiver_State:
  base_score = 75   (carrier covers origin or destination, will deadhead one leg)
ELSE:
  base_score = 0    (no service territory coverage → filter out)

// Optional: Bonus for home base proximity (if geolocation fields available)
IF calculate_distance(Load.Shipper_City, Carrier.Home_Base_City) <= 50 miles:
  proximity_bonus = min(25, distance_penalty)  // up to +25 points
  final_score = base_score + proximity_bonus
ELSE:
  final_score = base_score
```

**Calculation Example:**
- Load: Pickup in OH (Columbus), Delivery in TX (Houston)
- Carrier A: Service Territory = "OH, IN, KY" → base_score = 75 (covers origin, not destination) → ineligible due to long deadhead
- Carrier B: Service Territory = "OH, IN, KY, TX, AR, LA" → base_score = 100 (covers both) → **Eligible, high score**
- Carrier C: Service Territory = "CA, NV, AZ, UT" → base_score = 0 → **Filter out**

---

### 2. Equipment Match (Weight: 25%)

**Purpose:** Match load equipment requirements to carrier's available assets.

**Data Sources:**
- Load: `Equipment_Type__c` (flatbed, van, tanker, reefer, dump, etc.)
- Carrier: `Equipment_Types__c` (multiselect picklist of equipped types)

**Scoring Logic:**

```
IF Load.Equipment_Type__c IN Carrier.Equipment_Types__c:
  score = 100  (perfect match)
ELSE IF Load.Equipment_Type__c == 'Van' AND Carrier.Equipment_Types__c contains 'Flatbed':
  score = 50   (flatbed can carry van loads, but inefficient)
ELSE IF Load.Equipment_Type__c == 'Flatbed' AND Carrier.Equipment_Types__c contains 'Van':
  score = 0    (van cannot carry flatbed loads → filter out)
ELSE:
  score = 0    (no compatible equipment → filter out)
```

**Calculation Example:**
- Load: Equipment = "Flatbed"
- Carrier A: Equipment = ["Flatbed", "Van"] → score = 100 (has flatbed)
- Carrier B: Equipment = ["Van", "Reefer"] → score = 0 (no flatbed → filter out)
- Carrier C: Equipment = ["Flatbed"] → score = 100 (perfect match)

---

### 3. Capacity Check (Weight: 20%)

**Purpose:** Verify carrier has available trucks/equipment for the load date.

**Data Sources:**
- Load: `Weight_lbs__c`, `Pickup_Window_Begin__c`
- Carrier: `Active_Equipment_Count__c`, `Average_Equipment_Utilization__c`

**Scoring Logic:**

```
available_equipment = Carrier.Active_Equipment_Count__c - (Carrier.Average_Equipment_Utilization__c / 100 * Carrier.Active_Equipment_Count__c)

IF available_equipment >= 1:
  // Check if carrier has equipment available on load's pickup date
  conflicting_loads = Query Loads assigned to this Carrier where:
    Pickup_Window_Begin__c overlaps with Load.Pickup_Window_Begin__c ± 2 days
  
  IF conflicting_loads.count < available_equipment:
    score = 100 - (conflicting_loads.count * 5)  // Small penalty per conflict
  ELSE:
    score = 0  (no available equipment on that date → filter out)
ELSE:
  score = 0  (fully utilized → filter out)
```

**Calculation Example:**
- Load: Pickup Date = April 10, 2026
- Carrier A: 5 trucks, 60% utilization = 2 available. Existing loads on April 9-11 = 1. Can fit? Yes. Score = 100 - (1 × 5) = **95**
- Carrier B: 3 trucks, 100% utilization = 0 available. Can fit? No. → **Filter out**
- Carrier C: 10 trucks, 40% utilization = 6 available. Existing loads on April 9-11 = 0. Can fit? Yes. Score = **100**

---

### 4. FMCSA Safety Record (Weight: 15%)

**Purpose:** Prioritize carriers with strong safety performance based on FMCSA Carrier Scorecard metrics.

**Data Sources:**
- FMCSA Carrier Scorecard (from https://fmcsa.dot.gov/safety/safetynet):
  - CSA (Compliance, Safety, Accountability) score (0-100, **lower is better**)
  - Violation history (Violation__c junction object): serious, critical, out-of-service counts
  - Inspection cycles: BASIC violation counts
  - Safety violations: HOS (Hours of Service), hazmat, accident counts
  
- Carrier object links:
  - `FMCSA_Record__c` (lookup to external FMCSA data, if cached)
  - `CSA_Score__c` (number, 0-100, lower is better)
  - `Critical_Violations_Count__c` (count of critical/out-of-service violations, last 2 years)
  - `Serious_Violations_Count__c` (count of serious violations, last 2 years)
  - `BASIC_Inspection_Count__c` (count of BASIC inspections, last 12 months)

**Scoring Logic:**

Since CSA scores are inverted (lower = better), we reverse them for our 0-100 scoring scale (100 = best, 0 = worst):

```
# Step 1: Base score from CSA
csa_score = Carrier.CSA_Score__c (raw value from FMCSA, 0-100, lower=better)
IF csa_score is null or unknown:
  // Fallback: use historical on-time data if FMCSA data unavailable
  csa_score = infer_from_on_time_percent(Carrier.On_Time_Percent__c)

// Convert CSA to our scale (invert: 100 - CSA gives us 0-100 where higher=better)
csa_base_score = 100 - csa_score

# Step 2: Penalty for critical violations
critical_penalty = Carrier.Critical_Violations_Count__c * 15
  // Each critical/out-of-service violation = -15 points
  // Example: 1 critical = -15, 2 critical = -30

# Step 3: Penalty for serious violations
serious_penalty = Carrier.Serious_Violations_Count__c * 8
  // Each serious violation = -8 points
  // Example: 1 serious = -8, 2 serious = -16

# Step 4: Penalty for high inspection rate
high_inspections = Carrier.BASIC_Inspection_Count__c
IF high_inspections > 5 (last 12 months):
  inspection_penalty = (high_inspections - 5) * 3  // -3 points per inspection over 5
ELSE:
  inspection_penalty = 0

# Final Score
fmcsa_score = MAX(0, csa_base_score - critical_penalty - serious_penalty - inspection_penalty)
  // Clamp to 0-100 range

// Safety ceiling: If any critical violation in last 90 days → hard filter
IF Carrier.Critical_Violations_Count__c > 0 AND violation_date < 90_days_ago:
  return null  (FILTER OUT — cannot assign)
```

**Score Bands:**

```
85-100: Excellent safety record (CSA 0-15, no recent violations)
70-84:  Good safety record (CSA 16-30, max 1 serious violation)
55-69:  Acceptable (CSA 31-45, up to 2 serious violations or 1 critical)
40-54:  Marginal (CSA 46-60, multiple violations or high inspection rate)
0-39:   Poor safety record (CSA 61+, multiple critical violations)
```

**Calculation Example:**

**Carrier A (Excellent):**
- CSA Score: 12 → base = 100 - 12 = 88
- Critical Violations: 0 → penalty = 0
- Serious Violations: 0 → penalty = 0
- BASIC Inspections (12mo): 2 → penalty = 0
- **Final Score = 88** ✅ Excellent

**Carrier B (Good):**
- CSA Score: 28 → base = 100 - 28 = 72
- Critical Violations: 0 → penalty = 0
- Serious Violations: 1 (8 months ago) → penalty = -8
- BASIC Inspections: 3 → penalty = 0
- **Final Score = 72 - 8 = 64** ✅ Good

**Carrier C (Marginal):**
- CSA Score: 42 → base = 100 - 42 = 58
- Critical Violations: 0 → penalty = 0
- Serious Violations: 2 → penalty = -16
- BASIC Inspections: 7 (2 over threshold) → penalty = -6
- **Final Score = 58 - 16 - 6 = 36** ⚠️ Poor

**Carrier D (Filtered Out):**
- CSA Score: 65 → base = 100 - 65 = 35
- Critical Violations: 1 (45 days ago, < 90 days) → **HARD FILTER**
- **Result: FILTERED OUT** (cannot assign)

---

### 5. Insurance & Compliance Status (Weight: 10%)

**Purpose:** Automatically validate carrier's DOT status and insurance validity. Insurance has hard filters at critical thresholds.

**Data Sources:**
- Carrier: `DOT_Status__c`, `Insurance_Expiration__c` (from FMCSA lookup)
- Load: `Pickup_Window_Begin__c` (used to check if insurance valid on pickup date)

**Scoring Logic:**

```
compliance_score = 100

# Hard Filter 1: DOT Status must be ACTIVE
IF Carrier.DOT_Status__c != 'ACTIVE':
  // DOT status inactive or unknown → cannot assign
  return null  (FILTER OUT ENTIRELY)

# Hard Filter 2: Insurance must be valid on load pickup date
insurance_days_remaining = Carrier.Insurance_Expiration__c - TODAY()

IF insurance_days_remaining < 0:
  // Expired insurance → cannot assign
  return null  (FILTER OUT ENTIRELY)
  
ELSE IF insurance_days_remaining < 7:
  // Expiring in < 7 days (hard stop) → cannot assign
  return null  (FILTER OUT ENTIRELY)

# Soft Warning: Insurance expiring in 7-30 days
ELSE IF insurance_days_remaining <= 30:
  compliance_score = 50  (warning: will expire soon, but still eligible)
  add_flag = "Insurance_Expiring_Soon"  // Display warning to dispatcher

# Normal: Insurance valid for > 30 days
ELSE:
  compliance_score = 100  (no issues)

RETURN compliance_score
```

**Insurance Thresholds (Approved):**
| Threshold | Status | Action |
|-----------|--------|--------|
| < 7 days | EXPIRED or CRITICAL | **HARD FILTER** — Cannot assign |
| 7-30 days | EXPIRING SOON | Eligible but **WARNING FLAG** displayed to dispatcher |
| > 30 days | VALID | No restrictions |

**Calculation Example:**
- Carrier A: DOT_Status = "ACTIVE", Insurance expires in 45 days → score = **100** ✅
- Carrier B: DOT_Status = "INACTIVE" → **FILTER OUT** (cannot assign)
- Carrier C: DOT_Status = "ACTIVE", Insurance expired 2 months ago → **FILTER OUT** (cannot assign)
- Carrier D: DOT_Status = "ACTIVE", Insurance expires in 5 days → **FILTER OUT** (cannot assign) ❌
- Carrier E: DOT_Status = "ACTIVE", Insurance expires in 20 days → score = **50** ⚠️ (eligible with warning)

---

## Margin Display (Informational — Not in Scoring)

**Purpose:** Show dispatcher the estimated profit margin for each recommended carrier. This helps with rate negotiation and load profitability decisions.

**Data Sources:**
- Load: `Billing_Rate__c` (shipper rate quoted to customer)
- Carrier: `Typical_Rate__c` (average rate this carrier charges, calculated from historical Load records)

**Calculation:**

```
estimated_carrier_rate = Carrier.Typical_Rate__c (rolling average of last 10 loads)
estimated_margin = Load.Billing_Rate__c - estimated_carrier_rate

IF estimated_margin >= 500:
  margin_status = "Healthy: $" + estimated_margin  ✅
ELSE IF estimated_margin >= 0:
  margin_status = "Tight: $" + estimated_margin  ⚠️
ELSE:
  margin_status = "LOSS: $" + estimated_margin + " — Renegotiate required" ❌
```

**Display Format (Example):**

```
Top Recommendation:
  Carrier: ACME Trucking
  Score: 96.3/100
  Margin: Healthy ($500)
  Insurance: Valid (expires 2026-06-15)
  Notes: Excellent safety record, covers full route

2nd Recommendation:
  Carrier: FastFreight Inc.
  Score: 71.4/100
  Margin: Tight ($125)
  Insurance: Expiring soon (2026-04-27) ⚠️
  Notes: Limited capacity; insurance renewal pending

3rd Recommendation:
  Carrier: Regional Haulers
  Score: 68.2/100
  Margin: Loss ($-75)
  Insurance: Valid (expires 2026-08-10)
  Notes: Poor safety record; consider renegotiating rate
```

**Important Notes:**
1. Margin is **not** part of the scoring algorithm because rate negotiation is highly contextual
2. Dispatcher may negotiate different rates before assigning (fuel surcharge, volume discounts, etc.)
3. Margin calculation uses historical average rates; actual negotiated rate may differ
4. If estimated margin is negative or very tight, dispatcher should consider:
   - Negotiating higher shipper rate
   - Finding alternative carrier with lower typical rate
   - Declining unprofitable load

---

## Final Score Calculation

### Formula (FMCSA-Weighted)

```
FINAL_SCORE = 
  (Geographic_Score × 0.30) +
  (Equipment_Score × 0.25) +
  (Capacity_Score × 0.20) +
  (FMCSA_Safety_Score × 0.15) +
  (Insurance_Compliance_Score × 0.10)

Result: 0-100 (100 = best possible match)

Dimensions:
  1. Geography (30%): Service territory coverage of origin/destination states
  2. Equipment (25%): Load equipment type matches carrier's available assets
  3. Capacity (20%): Carrier has available trucks for load's pickup date
  4. FMCSA Safety (15%): CSA score + violation history + inspection rate
  5. Insurance (10%): DOT active + insurance valid (>7 days remaining)
```

### Example Calculation (FMCSA-Based Scoring)

**Load:** 
- Pickup: Columbus, OH
- Delivery: Houston, TX
- Equipment: Flatbed
- Date: April 10, 2026
- Weight: 45,000 lbs
- Billing Rate: $2,000

**Candidate Carriers:**

**Carrier A (Excellent Safety, Top Match):**
- Service Territory: OH, IN, KY, TX, AR, LA ✅
- Equipment: Flatbed, Van ✅
- Equipment Count: 5 trucks, 60% utilized = 2 available ✅
- **FMCSA Safety:** CSA Score 18 → 82 base - 0 critical - 0 serious - 0 inspections = **82** ✅
- DOT Status: ACTIVE ✅
- Insurance: VALID (expires in 60 days) ✅
- Typical Rate: $1,500 (Margin: +$500) ✅

```
Geographic = 100 × 0.30 = 30
Equipment = 100 × 0.25 = 25
Capacity = 95 × 0.20 = 19
FMCSA_Safety = 82 × 0.15 = 12.3
Insurance = 100 × 0.10 = 10
TOTAL = 96.3/100 ✅ TOP RECOMMENDATION
```

**Carrier B (Marginal Safety, Good Coverage):**
- Service Territory: OH, IN, KY, TX, AR, LA ✅
- Equipment: Flatbed, Van ✅
- Equipment Count: 3 trucks, 70% utilized = 0.9 available ❌
- **FMCSA Safety:** CSA Score 48 → 52 base - 15 critical (1) - 8 serious (1) - 6 inspections (8 in 12mo) = **23** ⚠️
- DOT Status: ACTIVE ✅
- Insurance: VALID (expires in 25 days) — WARNING ⚠️
- Typical Rate: $1,450 (Margin: +$550) ✅

```
Geographic = 100 × 0.30 = 30
Equipment = 100 × 0.25 = 25
Capacity = 40 × 0.20 = 8   (very limited availability)
FMCSA_Safety = 23 × 0.15 = 3.45
Insurance = 50 × 0.10 = 5  (expiring soon — warning)
TOTAL = 71.45/100 (2nd choice, with warnings)
Warnings: 1 critical violation; Insurance expires 2026-04-27
```

**Carrier C (Safety Issues, Hard Filter):**
- Service Territory: TX, AR, LA, MS ❌ (doesn't serve OH)
- Equipment: Van, Reefer ❌ (no flatbed)
- **FMCSA Safety:** CSA Score 68, 1 critical violation (35 days ago) → **HARD FILTER** ❌
- DOT Status: ACTIVE ✅
- Insurance: VALID ✅

```
Result: FILTERED OUT
Reason 1: Equipment — need Flatbed, carrier has [Van, Reefer]
Reason 2: FMCSA Safety — critical violation within 90 days (cannot assign)
→ Not eligible
```

**Carrier D (Expired Insurance, Hard Filter):**
- Service Territory: OH, TX ✅
- Equipment: Flatbed ✅
- **DOT Status:** ACTIVE ✅
- **Insurance:** Expires in 4 days → **HARD FILTER** (< 7 days) ❌

```
Result: FILTERED OUT
Reason: Insurance expires in 4 days (2026-04-06) — cannot assign
→ Contact carrier to renew insurance before assigning loads
```

---

## Filtering Logic (Pre-Scoring)

Before scoring, **filter out ineligible carriers immediately:**

1. **FMCSA Status Filter:**
   - DOT Status != "ACTIVE" → remove
   - Insurance Status = "EXPIRED" → remove

2. **Equipment Filter:**
   - Load Equipment Type NOT IN Carrier Equipment Types (with no compatible fallback) → remove

3. **Geography Filter:**
   - Carrier Service Territory covers 0 of 2 load states → remove (optional; can score 0)

4. **Capacity Filter:**
   - Available Equipment < 1 on load's pickup date → remove

5. **Preferred Pool Filter (if shipper has one):**
   - If Shipper Account has "Preferred_Carriers__c" field:
     - If Carrier NOT in preferred pool → score but rank lower (multiply final score by 0.75)
     - Or filter entirely (configurable business rule)

---

## Fallback Logic

### Scenario: No Viable Carriers Found

**Trigger:**
- Scoring algorithm evaluates all carriers
- All carriers filtered out (0 eligible)
- OR all remaining carriers score < 50 (poor matches)

**Action:**
1. Create Load status = "Posted" (not "Assigned")
2. Create Assignment_Status__c = "Manual_Review_Required"
3. Create Alert record:
   - Type = "NO_VIABLE_CARRIERS"
   - Load ID reference
   - Reason = "All carriers filtered: [reasons]"
   - Example: "All carriers filtered: DOT inactive (Carrier A, B), no flatbed equipment (Carrier C, D), no capacity April 10 (Carrier E, F)"
4. Send Alert to Dispatcher:
   - Email: "Load [Load#] requires manual carrier assignment. No automated matches found."
   - Slack notification (if configured)
   - Load detail page shows alert + sorted list of all carriers + reason why filtered
5. Load stays in "Posted" until dispatcher manually assigns
6. Manual assignment bypasses all filters (dispatcher override)

**Example Alert Message:**
```
Load #KWB-001234 — Manual Review Required

Auto-assignment failed. No viable carriers found.

Filtered Carriers:
- Carrier A (ACME LLC): DOT status INACTIVE (not ACTIVE)
- Carrier B (FastFreight Inc): Insurance expired 2026-03-15
- Carrier C (Regional Haulers): Equipment types [Van] but load needs Flatbed
- Carrier D (BigRig Co): 0 available trucks on April 10 (100% utilized)

Recommendation: Check if shipper can accept alternative equipment type, or negotiate with inactive carriers to reinstate DOT status.

Next Steps: Assign manually, or mark as "Hold" pending carrier activation.
```

---

## Preferred Carrier Pool (Optional, Phase 2)

**Business Rule:** Some shippers prefer certain carriers (based on service agreements, volume discounts, trust).

**Implementation:**
1. Add field to Account (Shipper) object: `Preferred_Carriers__c` (multiselect lookup to Carrier)
2. In scoring algorithm:
   ```
   IF Load.Shipper__r.Preferred_Carriers__c != null AND Load.Shipper__r.Preferred_Carriers__c.size > 0:
     IF Carrier IN Load.Shipper__r.Preferred_Carriers__c:
       // No penalty, score normally
     ELSE:
       // Non-preferred carrier: discount score by 25%
       final_score = final_score × 0.75
       (still shows up in top 3, but ranked lower)
   ```
3. Manual assignment always allows any carrier (dispatcher override)

---

## Performance & Scaling

### Algorithm Complexity

- **Time Complexity:** O(N) where N = number of active carriers
- **Space Complexity:** O(N) for scoring results array
- **Expected Runtime:** <100ms for 500 carriers on a typical load

### Optimization Techniques

1. **Caching:** Cache FMCSA lookups (update nightly, not per-load)
2. **Indexing:** Carrier fields indexed: Service_Territory__c, Equipment_Types__c, DOT_Status__c
3. **Batch Scoring:** If scoring 50+ loads, process in parallel batches (Apex Batch API)
4. **Lazy Evaluation:** Filter first (removes ~80% of carriers), then score remaining

### Database Queries Required

Per load:
- 1x Carrier query (all active carriers with required fields)
- 1x FMCSA compliance data (cached, not per-load)
- 1x historical load stats (for on-time %, can cache)
- Total: ~3 queries per load

Batch scoring 50 loads:
- 1x Carrier query (reuse for all loads)
- 50x Load-specific scoring (stateless computation)
- Total: ~2-3 queries shared across batch

---

## Test Scenarios (FMCSA-Focused)

### Test Load Setup
**Load Details:**
- Origin: Columbus, OH (43215)
- Destination: Houston, TX (77001)
- Equipment: Flatbed, 48,000 lbs
- Pickup Date: April 10, 2026
- Billing Rate: $2,200
- Commodity: Steel coils (general)

---

### Scenario 1: Excellent Safety Record (Clean Carrier)
**Carrier:** SafeHaul Inc.
- Service Territory: OH, IN, KY, TX, AR, LA ✅
- Equipment: Flatbed, Van ✅
- Equipment Count: 10 trucks, 50% utilization = 5 available ✅
- **FMCSA Data:**
  - CSA Score: 12 (excellent)
  - Critical Violations: 0
  - Serious Violations: 0
  - BASIC Inspections (12mo): 1
- DOT Status: ACTIVE ✅
- Insurance: Valid (expires 2026-08-15, 135 days) ✅
- Typical Rate: $1,750 (Margin: +$450)

**Scoring:**
```
Geographic: 100 (covers both states)
Equipment: 100 (has flatbed)
Capacity: 100 (5 trucks available, 1 conflicting load = 80% utilization)
FMCSA: 100 - 12 = 88 (no violations, low CSA)
Insurance: 100 (valid for 135 days)

Final = (100×0.30) + (100×0.25) + (100×0.20) + (88×0.15) + (100×0.10)
      = 30 + 25 + 20 + 13.2 + 10 = 98.2/100 ✅ TOP RECOMMENDATION
```

---

### Scenario 2: Marginal Safety Record (Multiple Violations)
**Carrier:** QuickFreight LLC
- Service Territory: OH, TX, AR ✅
- Equipment: Flatbed ✅
- Equipment Count: 3 trucks, 85% utilization = 0.45 available ⚠️
- **FMCSA Data:**
  - CSA Score: 48 (marginal)
  - Critical Violations: 1 (8 months ago)
  - Serious Violations: 2
  - BASIC Inspections (12mo): 9
- DOT Status: ACTIVE ✅
- Insurance: Valid (expires 2026-04-25, 23 days) ⚠️
- Typical Rate: $1,700 (Margin: +$500)

**Scoring:**
```
Geographic: 100 (covers both)
Equipment: 100 (has flatbed)
Capacity: 50 (0.45 available, borderline; penalty for high utilization)
FMCSA: 100 - 48 = 52 base
     - 15 (1 critical) = 37
     - 16 (2 serious) = 21
     - 12 (9 inspections, 4 over threshold × 3) = 9
Insurance: 50 (expires in 23 days, warning)

Final = (100×0.30) + (100×0.25) + (50×0.20) + (9×0.15) + (50×0.10)
      = 30 + 25 + 10 + 1.35 + 5 = 71.35/100 ⚠️ 2nd choice with warnings
```

---

### Scenario 3: Critical Violation (Hard Filter)
**Carrier:** FastRoute Inc.
- Service Territory: OH, KY, TX ✅
- Equipment: Flatbed ✅
- **FMCSA Data:**
  - CSA Score: 65 (poor)
  - **Critical Violations: 1 (45 days ago)** ❌ HARD FILTER
  - Serious Violations: 3
  - BASIC Inspections: 12
- DOT Status: ACTIVE ✅
- Insurance: Valid ✅

**Scoring:**
```
Result: FILTERED OUT — CANNOT ASSIGN
Reason: Critical violation within 90 days (45 days ago)
  This carrier cannot be assigned any loads until violation ages past 90 days
```

---

### Scenario 4: Insurance Expiring (Hard Filter)
**Carrier:** RegionalHaul Co.
- Service Territory: OH, TX, LA ✅
- Equipment: Flatbed ✅
- Equipment Count: 5 trucks, 60% utilization = 2 available ✅
- FMCSA Data: CSA 25, no violations ✅
- DOT Status: ACTIVE ✅
- **Insurance: Expires 2026-04-06 (4 days)** ❌ HARD FILTER

**Scoring:**
```
Result: FILTERED OUT — CANNOT ASSIGN
Reason: Insurance expires in 4 days (<7 days hard threshold)
Action: Contact carrier to renew insurance before assigning
```

---

### Scenario 5: Insurance Expiring Soon (Warning, Still Eligible)
**Carrier:** MidwestLogistics LLC
- Service Territory: OH, IN, KY, TX ✅
- Equipment: Flatbed ✅
- Equipment Count: 8 trucks, 50% utilization = 4 available ✅
- **FMCSA Data:**
  - CSA Score: 32 (good)
  - Critical Violations: 0
  - Serious Violations: 1 (6 months ago)
  - BASIC Inspections: 4
- DOT Status: ACTIVE ✅
- **Insurance: Expires 2026-04-20 (18 days)** ⚠️ Warning

**Scoring:**
```
Geographic: 100
Equipment: 100
Capacity: 95 (4 available, 1 conflicting load = 50% utilization)
FMCSA: 100 - 32 = 68
     - 8 (1 serious) = 60
Insurance: 50 (expires in 18 days, warning)

Final = (100×0.30) + (100×0.25) + (95×0.20) + (60×0.15) + (50×0.10)
      = 30 + 25 + 19 + 9 + 5 = 88/100 ⚠️ Can assign, but alert dispatcher
```

**Display to Dispatcher:**
```
⚠️ WARNING: This carrier's insurance expires 2026-04-20 (18 days)
Action: Verify insurance renewal is pending before assignment
```

---

### Scenario 6: Missing FMCSA Data (Fallback to On-Time %)
**Carrier:** NewPartner Inc. (Recently onboarded, no FMCSA data yet)
- Service Territory: OH, TX ✅
- Equipment: Flatbed ✅
- Equipment Count: 3 trucks, 40% utilization = 1.8 available ✅
- **FMCSA Data:** None (null CSA_Score__c)
- Historical On-Time Percent: 96%
- DOT Status: ACTIVE ✅
- Insurance: Valid ✅

**Scoring (Fallback):**
```
Geographic: 100
Equipment: 100
Capacity: 80 (1.8 available, 1 conflicting load = 67% utilization)
FMCSA: FALLBACK — infer from On_Time %
     Since On_Time = 96%, score = 90 (between 95-98% band)
Insurance: 100

Final = (100×0.30) + (100×0.25) + (80×0.20) + (90×0.15) + (100×0.10)
      = 30 + 25 + 16 + 13.5 + 10 = 94.5/100
      
Note: "Pending FMCSA data validation. Using historical on-time % as interim metric."
```

---

## Test Scenarios (Original)

---

## Future Enhancements (Phase 3+)

1. **ML-Based Scoring:** Replace rule-based weights with ML model trained on historical assignments + outcomes
2. **Real-Time Capacity:** Query carrier's TMS API for live equipment availability (vs. static count)
3. **Dynamic Weights:** Adjust scoring weights based on season, lane demand, shipper priority
4. **Multi-Stop Optimization:** Score carriers for multi-stop loads considering route efficiency
5. **Fuel Optimization:** Factor in fuel prices + lane distance for margin prediction
6. **Carrier Preferences:** If carrier has lane-specific rates, use actual rate vs. typical rate

---

## FMCSA Scoring Matrix (Detailed Mappings)

### CSA Score to 0-100 Scale

FMCSA CSA scores range from 0-100 where **lower is better** (safer). We invert this for our algorithm:

```
FMCSA CSA → Our Score
0-15      → 85-100 (Excellent)
16-30     → 70-84  (Good)
31-45     → 55-69  (Acceptable)
46-60     → 40-54  (Marginal)
61-75     → 25-39  (Poor)
76-100    → 0-24   (Critical)

Formula: Our_Score = MAX(0, 100 - CSA_Score)
```

### Violation Penalties

Each violation type reduces the score based on severity:

```
Violation Type | Severity | Penalty | Notes
---|---|---|---
Out-of-Service (OOS) | Critical | -15 pts each | Immediate disqualification if <90 days old
Critical | Critical | -15 pts each | Major safety issue, hard filter if <90 days
Serious | Major | -8 pts each | Moderate safety concern
Other | Minor | -3 pts each | Minor issues, cumulative impact

Calculation Example:
  Base CSA: 35 → Our_Score = 65
  2 Serious violations → -16
  1 OOS violation → -15
  Final = MAX(0, 65 - 16 - 15) = 34 (Poor)
```

### Inspection Rate Penalties

Frequent inspections indicate higher risk:

```
12-Month BASIC Inspections | Score Impact
---|---
0-2 inspections | No penalty
3-5 inspections | No penalty
6-10 inspections | -3 pts per inspection over 5 (-15 max)
11-20 inspections | -3 pts per inspection over 5 (-45 max)
20+ inspections | -3 pts per inspection over 5, capped at -60 (score floor 0)

Example:
  Carrier has 8 inspections in last 12 months
  Penalty = (8 - 5) × 3 = -9 points
```

---

## Implementation Checklist

- [ ] Create `Carrier_Assignment_Engine.cls` (Apex class)
  - [ ] Filter logic
  - [ ] Score functions (6 dimensions)
  - [ ] Final score calculation
  - [ ] Return ranked list (top 3)

- [ ] Create `Auto_Assignment_Controller.cls` (Apex class)
  - [ ] Trigger on Load creation
  - [ ] Call scoring engine
  - [ ] Update Load status based on results
  - [ ] Create Alert records for fallback
  - [ ] Send notifications

- [ ] Add Load fields (if not already present):
  - [ ] `Assignment_Status__c` (picklist: Auto_Assigned, Manual_Review_Required, Manually_Assigned)
  - [ ] `Carrier_Recommendation_Score__c` (number, 0-100)
  - [ ] `Top_3_Carriers__c` (long text, JSON or formatted)

- [ ] Add Carrier fields (if not already present):
  - [ ] `Service_Territory__c` (multiselect picklist)
  - [ ] `Equipment_Types__c` (multiselect picklist)
  - [ ] `Active_Equipment_Count__c` (number)
  - [ ] `Average_Equipment_Utilization__c` (percent)
  - [ ] **NEW:** `CSA_Score__c` (number 0-100, lower is better)
  - [ ] **NEW:** `Critical_Violations_Count__c` (count of critical/OOS violations, last 2 years)
  - [ ] **NEW:** `Serious_Violations_Count__c` (count of serious violations, last 2 years)
  - [ ] **NEW:** `BASIC_Inspection_Count__c` (count of BASIC inspections, last 12 months)
  - [ ] **DEPRECATED:** `On_Time_Percent__c` (keep for fallback, but replace with FMCSA in primary scoring)
  - [ ] `Typical_Rate__c` (currency, avg of recent assignments)

- [ ] Test scoring engine (5 loads, 5 carriers each)
- [ ] Test fallback logic (no viable carriers scenario)
- [ ] Test FMCSA filtering (active vs. inactive carriers)
- [ ] Achieve >80% code coverage
- [ ] Review with Seb

---

## Sign-Off

- **Author:** Agent 2  
- **Peer Review:** Agent 1 (schema validation)  
- **Code Review:** Seb Roman  
- **Status:** Ready for Apex Implementation

---

**Next Step:** Implement `CarrierAssignmentEngine.cls` based on scoring logic above.
