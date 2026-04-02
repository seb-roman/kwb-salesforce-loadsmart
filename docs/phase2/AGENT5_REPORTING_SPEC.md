# KWB Logistics — Advanced Reporting Specification

**Agent:** Agent 5  
**Phase:** Phase 2 (weeks 6-9)  
**Platform:** Salesforce Reports + Lightning Components  
**Status:** Design-Ready (4/3/2026)

---

## Executive Summary

Advanced reporting provides **shipper analytics, carrier scorecards, and lane intelligence** beyond operational dashboards. Key users:
- **Shippers:** "How are my shipments performing?" (on-time %, cost trends)
- **Managers:** "Which lanes are profitable?" (margin analysis by lane)
- **Executives:** "Where should we focus next?" (market insights)

**Philosophy:** Pre-built reports for common questions + custom report builder for ad-hoc analysis.

---

## Pre-Built Reports (8 Reports)

### Report 1: Shipper Load Performance

**Audience:** Account managers, shippers (via portal)  
**Purpose:** Shipper health scorecard  
**Format:** Summary + detail table

```
SHIPPER: SCOTTS MIRACLE-GRO (YTD 2026)
┌───────────────────────────────────────────┐
│ Metrics:                                  │
│ • Total Loads: 127                        │
│ • Total Spend: $358,750                   │
│ • Avg Load Value: $2,825                  │
│ • On-Time %: 94.5% (vs KWB target: 95%) │
│ • Claims: 2 (damage)                      │
│ • Dispute Rate: 1 invoice ($450)         │
│ • Churn Risk: Low                         │
│                                           │
│ Load Volume Trend (last 12 weeks):        │
│ Week 1: 12 loads                          │
│ Week 2: 14 loads                          │
│ Week 3: 11 loads                          │
│ ... (uptrend or downtrend?)               │
│                                           │
│ Equipment Mix:                            │
│ • FTL: 80 loads (63%)                     │
│ • LTL: 47 loads (37%)                     │
│ • Avg trailer utilization: 78%            │
│                                           │
│ Top 5 Destinations (by volume):           │
│ 1. Atlanta, GA: 28 loads                  │
│ 2. Miami, FL: 19 loads                    │
│ 3. Jacksonville, FL: 15 loads             │
│ 4. Charlotte, NC: 12 loads                │
│ 5. Nashville, TN: 11 loads                │
└───────────────────────────────────────────┘
```

**Drill-Down:**
- Click shipper name → list of all loads (with status)
- Click lane (e.g., Atlanta) → margin analysis for that lane
- Click "On-Time %" → late loads with reasons

---

### Report 2: Carrier Scorecard

**Audience:** Ops managers, executives  
**Purpose:** Carrier performance ranking  
**Format:** Ranked table with KPIs

```
CARRIER SCORECARD (Last 30 Days, Ranked)

Rank │ Carrier          │ Score │ On-Time│ Claim│ Avg Rate│ Loads
─────┼──────────────────┼───────┼────────┼──────┼─────────┼─────
  1  │ Anderson         │  95   │  98%   │ 0    │ $2,100  │  28
  2  │ Blue Mountain    │  93   │  97%   │ 1    │ $2,150  │  19
  3  │ Crown Logistics  │  88   │  94%   │ 2    │ $1,950  │  31
  4  │ Delta Freight    │  82   │  91%   │ 3    │ $2,050  │  22
  5  │ Elite Carriers   │  78   │  87%   │ 4    │ $1,900  │  18

Performance Details for Top Carrier (Anderson):
• Safety Score (FMCSA): 95 (satisfactory)
• Insurance: Current ($1M cargo, $750K liability)
• Tender Acceptance: 96% (reliable)
• Avg Transit Time: 14.2h (on schedule)
• Driver Quality: 15 drivers, all current certifications
• Recent Issues: None in last 30 days
• Recommendation: Gold Tier — increase allocation
```

**Drill-Down:**
- Click carrier name → view all their loads (with on-time analysis)
- Late loads → identify common issues (weather, shipper delay, etc.)
- Claim history → details of damage/shortage incidents

---

### Report 3: Lane Profitability Analysis

**Audience:** Pricing team, executives  
**Purpose:** Margin analysis by route  
**Format:** Table (origin → destination)

```
LANE PROFITABILITY (YTD 2026)

Lane           │ Loads │ Revenue │ Cost  │ Margin│ Margin%│ Trend
───────────────┼───────┼─────────┼───────┼───────┼────────┼──────
Toledo → Atlanta│  28  │ $72,800 │$58K  │$14.8K│ 20.3%  │ ↑ +2%
Toledo → Miami  │  16  │ $36,800 │$32K  │$4.8K │ 13.0%  │ ↓ -5%
Toledo → Charlotte12  │ $30,600 │$24.5K│$6.1K │ 19.9%  │ ↑ +1%
Toledo → Jacksonville 8│ $21,600 │$18.8K│$2.8K │ 13.0%  │ → 0%
Tampa → Atlanta│  9   │ $25,200 │$19.5K│$5.7K │ 22.6%  │ ↑ +3%
...

Insights:
• Toledo → Miami: Low margin (13%). Recommend rate increase.
• Toledo → Atlanta: Healthy margin (20.3%). Consider volume expansion.
• New Lane Alert: Tampa → Atlanta showing 22.6% margin. Growth opportunity.
```

**Drill-Down:**
- Click lane → list of all loads on that lane (identify outliers)
- Click low-margin load → compare rate vs benchmark (is carrier over-charging?)
- Trend view → margin change over weeks (is lane trending healthier or worse?)

---

### Report 4: Shipper Metrics (Portal-Visible)

**Audience:** Shipper customers (via portal)  
**Purpose:** "How are we doing?" from shipper perspective  
**Format:** Summary + trend chart

```
YOUR PERFORMANCE (Last 90 Days)

Metrics Summary:
• Total Loads: 32
• On-Time %: 96.8% ✓ (vs your target: 95%)
• Avg Cost/Load: $2,850
• Highest Cost: $3,400 (emergency expedite)
• Lowest Cost: $1,950 (LTL consolidation)

On-Time Trend:
Week 1-2: 95.2%
Week 3-4: 98.1%
Week 5-6: 96.4%
Week 7-8: 97.5% (trending well)

Equipment Usage:
• FTL: 24 loads (75%)
• LTL: 8 loads (25%)
• Avg truck utilization: 82%

Top Destination (by volume):
• Atlanta: 12 loads, 100% on-time

Savings Opportunity:
"You have 8 loads going to Jacksonville over next 90 days.
Consider consolidating with LTL. Potential savings: $2,100."
```

---

### Report 5: Invoice Aging Report

**Audience:** Finance/CFO  
**Purpose:** Collections focus  
**Format:** Aged A/R table

```
ACCOUNTS RECEIVABLE AGING

Shipper             │ 0-30  │ 31-60 │ 61-90 │ 90+   │ Total
────────────────────┼───────┼───────┼───────┼───────┼────────
Scotts Miracle-Gro  │$45K  │$2.5K │ —    │ —    │$47.5K
Home Depot          │$22K  │ —    │ —    │ —    │$22K
Ace Hardware        │$8K   │$3K   │ —    │ —    │$11K
Lowe's              │$12K  │$4.5K │$1.2K │ —    │$17.7K
Others              │$15K  │$2K   │ —    │ —    │$17K
TOTAL               │$102K │$12K  │$1.2K │ —    │$115.2K

Collections Action:
1. Call Scotts (1 invoice 31-60 days overdue, $2.5K)
2. Follow up with Lowe's (invoice 61-90 days, $1.2K)
3. Net DSO: 24 days (improving from 28 days last month)
```

---

### Report 6: Fuel Surcharge Impact

**Audience:** Pricing team, finance  
**Purpose:** Understand fuel cost pass-through  
**Format:** Trend analysis

```
FUEL SURCHARGE IMPACT (YTD 2026)

Fuel Price (DAI):
Feb 2026: $3.10/gal
Mar 2026: $3.30/gal (+6.5%)
Apr 2026: $3.44/gal (+4.2%)

KWB Fuel Surcharge Model:
• Shipper FSC: 3% of freight rate (locked at booking)
• Carrier FSC: 3% (separate, variable)
• Spread: 0% (breakeven on fuel risk)

Financial Impact:
• Apr fuel increase: +$0.14/gal vs Mar
• Avg fuel per load: 180 gallons
• Cost increase: $25.20 per load
• At 3% FSC on $2,850 shipper rate = $85.50 FSC
• Gap: -$25.20 (KWB eating fuel cost)

Recommendation:
Raise shipper FSC from 3% → 3.5% (get $99.75 FSC, reducing gap)
OR: Lock fuel pricing with shippers (e.g., no FSC if diesel stays < $3.25)
```

---

### Report 7: Settlement Reconciliation

**Audience:** Finance  
**Purpose:** Verify carrier payments match loads  
**Format:** Exception report

```
SETTLEMENT RECONCILIATION (April 2026)

Total Loads Delivered (April): 205
Total Carrier Costs (April): $410K
Total Settled (April): $408.5K
Variance: -$1.5K (99.6% match) ✓

Unsettled Loads:
• Status "delivered" but settlement not created: 3 loads ($8.2K)
  - Load 1067: Missing POD, settlement pending
  - Load 1068: POD received, settlement pending approval
  - Load 1062: Dispute pending resolution

Carrier Payment Status:
• Anderson: $45.6K settled, paid on 4/15 ✓
• Blue Mountain: $38.2K settled, paid on 4/15 ✓
• Crown: $32.5K settled, paid on 4/16 ✓
• Elite: $19.8K settled, pending approval ⚠️

Action Items:
1. Approve Elite settlement ($19.8K), process ACH today
2. Follow up on Load 1067 POD (3 days overdue)
3. Resolve Load 1062 dispute before settling
```

---

### Report 8: Market Benchmark Report (Phase 2+)

**Audience:** Executives, pricing team  
**Purpose:** Compare KWB rates vs market  
**Format:** Comparison table

```
MARKET BENCHMARK (DAT RateView Data)

Lane            │ KWB Rate │ Market Avg │ Gap   │ Recommendation
────────────────┼──────────┼────────────┼───────┼──────────────
Toledo → Atlanta│  $2,850  │  $2,900    │ -1.7% │ OK (slightly competitive)
Toledo → Miami  │  $2,950  │  $2,875    │ +2.6% │ Reduce rate (competitor offers $2,900)
Toledo → Jacksvl│  $1,850  │  $1,800    │ +2.8% │ Reduce rate OR value-add
Tampa → Atlanta │  $1,950  │  $2,050    │ -4.9% │ RAISE RATE (we're underpriced!)
Memphis → Dallas│  $2,200  │  $2,300    │ -4.3% │ RAISE RATE

Strategic Actions:
1. Raise Tampa → Atlanta to $2,025 (+$75 per load)
2. Reduce Toledo → Miami to $2,875 (-$75 per load)
3. Monitor Jacksonville (high competition)
```

---

## Custom Report Builder (Phase 2)

**What:** Allow users to build their own reports (without needing IT)  
**UI:** Salesforce Reporting UI (native)

**Example Scenario:**
Manager wants: "Which shippers have >2 late loads in last 30 days?"

```
CUSTOM REPORT BUILDER
┌──────────────────────────────────────────┐
│ SELECT: Load__c (object)                 │
├──────────────────────────────────────────┤
│ COLUMNS: shipper, on-time %, load count  │
│ FILTER: status = 'delivered'             │
│       AND pickup_date > LAST_30_DAYS     │
│       AND on_time = FALSE                │
│ GROUP BY: shipper                        │
│ HAVING: COUNT > 2                        │
│ SORT BY: load_count DESC                 │
│                                          │
│ [RUN REPORT]                             │
└──────────────────────────────────────────┘

RESULTS:
Shipper          │ Late Loads
─────────────────┼───────────
Acme Logistics   │ 4
Bolts & Bearings │ 3
Crown Distribut. │ 2 (borderline)
```

---

## Report Export Options

### PDF Export
- Formatted for printing
- Includes charts, branding (KWB logo)
- Email directly to stakeholder

### Excel Export
- Tabular data with raw numbers
- Separate sheets for summary + detail
- Formulas preserved (shipper can create pivot tables)

### CSV Export
- Simple comma-separated
- Max 50K rows
- For data warehouse integration

### Scheduled Email
- Report sent automatically (daily, weekly, monthly)
- Example: "Send shipper performance report to all account managers every Friday 9 AM"

---

## Acceptance Criteria (Phase 2 Complete)

✅ All 8 pre-built reports execute without errors  
✅ Data calculations match manual spot checks  
✅ Reports filter correctly by date range, shipper, carrier  
✅ Drill-down links work (report card → detail records)  
✅ Custom report builder allows non-technical users to create reports  
✅ Export to PDF/Excel/CSV works  
✅ Scheduled email delivery works  
✅ Reports visible to appropriate roles (shipper sees own data only)  
✅ Reports load in < 10 sec (large reports)  
✅ Shipper reports visible in portal  

---

**Status:** DESIGN-READY (4/3/2026)  
**Dev Time:** 3 weeks (Phase 2)
