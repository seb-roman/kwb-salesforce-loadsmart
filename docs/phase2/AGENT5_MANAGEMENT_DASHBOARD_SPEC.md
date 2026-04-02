# KWB Logistics — Management Dashboard Specification

**Agent:** Agent 5  
**Phase:** Phase 1 (weeks 3-5)  
**Platform:** Salesforce Lightning Dashboard (Executive Edition)  
**Audience:** C-Suite (Corey - Owner, CFO, VP Operations)  
**Status:** Design-Ready (4/3/2026)

---

## Executive Summary

The Management Dashboard (CEO/CFO view) distills KWB's operational health into **6-8 strategic KPIs**. Unlike the Ops Dashboard (action-oriented), the Management Dashboard focuses on **trends, profitability, and risk**.

**Key Principle:** One-page view of business health. Corey should see at a glance: "Are we healthy? Where are the risks?"

---

## Management Dashboard KPIs (8 Cards)

### Card 1: Gross Profit MTD + YTD Trend

**Metric:** (Total Revenue - Total Carrier Costs) with year-over-year comparison  
**Target:** $60K-80K/month ($720K-960K annual)  
**Refresh:** Daily

```
┌─────────────────────────────────┐
│ GROSS PROFIT                    │
│ MTD: $87,150                    │
│ YTD: $641,200                   │
│                                 │
│ Trend vs Last Year:             │
│ MTD +12.5% ($77,450 last year) │
│ YTD  +8.2% ($592,600 last yr)  │
│                                 │
│ ↑ Green: Profit growing         │
└─────────────────────────────────┘
```

**Drill-Down:** Breakdown by shipper, carrier, lane (identify profit drivers)

---

### Card 2: On-Time Delivery % (Goal vs Actual)

**Metric:** Delivery on-time % vs 95% industry target  
**Refresh:** Daily

```
┌─────────────────────────────────┐
│ ON-TIME DELIVERY %              │
│                                 │
│ Goal:    95% ━━━━━━━━━━━        │
│ Actual:  92.4% ━━━━━━━━         │
│                                 │
│ Gap: -2.6% (5 loads late)      │
│                                 │
│ Status: ⚠️ BELOW TARGET        │
│ Action: Review carrier mix     │
└─────────────────────────────────┘
```

---

### Card 3: Revenue Per Load (Average)

**Metric:** Total revenue / Load count (trend over months)  
**Target:** $2,900 per load  
**Refresh:** Daily

```
┌─────────────────────────────────┐
│ REVENUE PER LOAD                │
│ Apr 2026: $3,050                │
│ Mar 2026: $2,950                │
│ Feb 2026: $2,825                │
│                                 │
│ Trend: ↑ +4.1% improving        │
│ (Better mix of high-value loads)│
└─────────────────────────────────┘
```

---

### Card 4: Margin Per Load (Average)

**Metric:** Gross profit / Load count  
**Target:** $425 per load (18% margin %)  
**Refresh:** Daily

```
┌──────────────────────────────────┐
│ MARGIN PER LOAD                  │
│ Apr 2026: $425                   │
│ Mar 2026: $455                   │
│ Feb 2026: $410                   │
│                                  │
│ Trend: ↓ -6.6% declining        │
│ Concern: Carrier rates rising   │
│          (fuel surcharges?)     │
└──────────────────────────────────┘
```

---

### Card 5: Shipper Count (Active, New, Churned)

**Metric:** Active customers with ≥ 1 load in last 90 days  
**Refresh:** Daily

```
┌─────────────────────────────────┐
│ SHIPPER METRICS                 │
│ Active:  28 shippers            │
│ New:     +2 (this quarter)       │
│ Churned: -1 (no loads in 90d)   │
│                                 │
│ Revenue Concentration:          │
│ Top 5: 67% of revenue          │
│ (Diversification: Medium Risk) │
└─────────────────────────────────┘
```

---

### Card 6: Carrier Count (Active, Capacity, Utilization)

**Metric:** Active carriers, total capacity, utilization rate  
**Refresh:** Real-time

```
┌──────────────────────────────────┐
│ CARRIER NETWORK                  │
│ Active: 42 carriers              │
│ Capacity: 380 units available    │
│ Utilization: 78% (optimal)       │
│                                  │
│ Equipment Mix:                   │
│ Flatbed: 82% util (add more?)  │
│ Reefer:  64% util (excess cap)  │
│ Van:     91% util (constraint)  │
└──────────────────────────────────┘
```

---

### Card 7: Growth Rate (Loads/Week, Revenue Trend)

**Metric:** Loads per week (7-day moving average) with trend  
**Refresh:** Daily

```
┌──────────────────────────────────┐
│ GROWTH RATE                      │
│ Loads/Week: 52 (last 4 weeks)   │
│ Trend: ↑ +8% vs prior month    │
│                                  │
│ Revenue/Week: $156K              │
│ Trend: ↑ +5% vs prior month    │
│                                  │
│ Forecast (end of Q2):            │
│ 65 loads/week, $210K/week       │
│ (on track for annual target)    │
└──────────────────────────────────┘
```

---

### Card 8: Risk Metrics (Exceptions, Disputes, Aged AR)

**Metric:** Open exceptions (age & severity), billing disputes, AR aging  
**Refresh:** Real-time

```
┌──────────────────────────────────┐
│ RISK DASHBOARD                   │
│ Open Exceptions: 18              │
│  • Critical: 3 (require action)  │
│  • High: 5                       │
│  • Medium: 10                    │
│                                  │
│ Disputes (active): 2             │
│  • Value: $8,450                │
│  • Avg age: 12 days             │
│                                  │
│ Aged AR (>30 days): $45,200     │
│  • 4 invoices pending payment   │
│  • Top debtor: Scotts ($28K)   │
│                                  │
│ Status: 🟡 MONITOR (acceptable)│
└──────────────────────────────────┘
```

---

## Variance Analysis (Phase 2 Feature)

**What:** Compare actual performance vs. forecast/budget

```
VARIANCE ANALYSIS (April vs Budget)
┌────────────────────────────────────────┐
│ Metric          │ Budget │ Actual │ Var │
├─────────────────┼────────┼────────┼─────┤
│ Revenue MTD     │ $480K  │ $487K  │ +1.5%
│ Gross Profit    │ $85K   │ $87K   │ +2.4%
│ On-Time %       │ 95%    │ 92.4%  │ -2.6%
│ Loads           │ 180    │ 205    │ +13.9%
│ Margin %        │ 18%    │ 17.9%  │ -0.1%
└────────────────────────────────────────┘

Key: On-time performance below target.
     Recommend carrier performance review.
```

---

## Forecasting (Phase 2 Feature)

**What:** Project next 30-90 days based on pipeline

```
FORECAST (MAY-JUNE 2026)
┌──────────────────────────────────┐
│ May Forecast:                    │
│ Expected Loads: 225              │
│ Expected Revenue: $662K          │
│ Expected Profit: $118K           │
│                                  │
│ June Forecast:                   │
│ Expected Loads: 240 (seasonal)   │
│ Expected Revenue: $720K          │
│ Expected Profit: $132K           │
│                                  │
│ Confidence: Medium (±8%)         │
│ (Based on pipeline + historical) │
└──────────────────────────────────┘
```

---

## Dashboard User Flows

### Scenario A: CEO Monthly Review

**Corey opens dashboard (9 AM Monday):**

1. Sees Gross Profit MTD: $87K — on track for $150K month ✓
2. Checks On-Time %: 92.4% — below 95% target, but acceptable
3. Reviews Growth: 52 loads/week, on track for Q2 goals
4. Identifies Risk: Aged AR of $45K (Scotts owes $28K) → makes note
5. Shipper concentration: Top 5 = 67% → discusses diversification with sales
6. Takes action: "Call Scotts about invoice payment" → delegates to Jennifer

**Time to decision:** 5 minutes  
**Result:** Corey knows KWB is healthy, AR issue flagged for follow-up

---

### Scenario B: CFO Cash Flow Review

**CFO reviews on Thursday (end of week):**

1. Gross Profit MTD: $87K ✓
2. Aged AR: $45K overdue — calls accounting to accelerate collections
3. Settlement backlog: $142K pending payment — schedules ACH for Friday
4. Disputes: $8.4K active — escalates high-value dispute to manager

**Time to decision:** 10 minutes  
**Result:** CFO addresses cash flow issues proactively

---

## Dashboard Acceptance Criteria

✅ All 8 KPIs display correct calculations  
✅ Trend lines show YTD vs prior year (correct comparison)  
✅ Dashboard loads in < 3 sec  
✅ Color coding (green/yellow/red) matches target thresholds  
✅ Drill-down to detail records works  
✅ Risk card correctly calculates aged AR, disputes, exceptions  
✅ CEO can view and understand in < 5 minutes  
✅ Refresh updates correctly (variance card shows actual vs budget)  

---

**Status:** DESIGN-READY (4/3/2026)  
**Dev Time:** 2 weeks (simpler than Ops Dashboard, fewer cards, less drill-down)
