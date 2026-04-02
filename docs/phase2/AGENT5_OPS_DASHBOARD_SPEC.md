# KWB Logistics — Operations Dashboard Specification

**Agent:** Agent 5 (Portal & Operations Dashboards)  
**Phase:** Phase 1 (weeks 3-5), Phase 2 (weeks 6-9)  
**Platform:** Salesforce Lightning Dashboard  
**Audience:** KWB Internal Operations Team (Dispatchers, Managers, Account Managers)  
**Status:** Design-Ready (4/3/2026)  
**Document Version:** 1.0

---

## Executive Summary

The KWB Operations Dashboard is the internal command center for load management and real-time visibility. It provides:
- **10 KPI cards** with real-time metrics (refreshed every 60 seconds)
- **Drill-down capability** (click card → see detailed records)
- **Mobile-responsive** (works on dispatcher's phone in the warehouse)
- **Exception focus** (flag problems early before they become disasters)
- **Margin visibility** (understand profitability per load)

**Key Principle:** One dashboard, instant visibility. No more "Where are the loads?" — answer: look at the dashboard.

---

## Dashboard Architecture

### Technology Stack

| Component | Technology | Details |
|-----------|-----------|---------|
| **Platform** | Salesforce Lightning Dashboard | Native Salesforce, no additional licenses |
| **Data Source** | SOQL queries (filtered by load status, date, metrics) | Lightning reports feed dashboard cards |
| **Real-Time Refresh** | Salesforce Platform Events (Load status changes trigger refresh) | Auto-refresh every 60 sec |
| **Drill-Down** | Dynamic links (click card → opens filtered list or detail record) | No page navigation required (stays in context) |
| **Mobile** | Responsive layout (single column on mobile, multi-column on desktop) | Same dashboard on phone, tablet, desktop |
| **Permissions** | Based on role (Dispatcher sees own queue, Manager sees all loads) | Role-based dashboard access |

### Dashboard User Groups

| Role | Loads Visible | Actions |
|------|--------------|---------|
| **Dispatcher** | Unassigned + assigned to their carriers | View, assign, handle exceptions |
| **Ops Manager** | All loads | View all, report to leadership |
| **Account Manager** | Loads for assigned shippers only | View shipper-specific loads, resolve issues |
| **CFO/Finance** | All loads (for margin analysis) | View profitability, revenue trends |

---

## Dashboard Layout (10 KPI Cards)

### Card 1: Loads by Status (Gauge Chart)

**Purpose:** Visual snapshot of load pipeline health  
**Metric Calculated:** Count of loads in each status (posted, assigned, dispatched, in_transit, delivered, exception)  
**Refresh Interval:** Every 60 sec

#### Design
```
┌─────────────────────────────────────────────┐
│ LOADS BY STATUS (Today)                     │
├─────────────────────────────────────────────┤
│                                             │
│   Posted   Assigned  Dispatched  In Transit │
│     ↓         ↓          ↓          ↓       │
│    [12]      [38]       [45]       [52]    │
│                                             │
│   Delivered  Exception  Total               │
│      ↓         ↓         ↓                  │
│     [84]       [3]      [234]               │
│                                             │
│ [View Posted Loads]  [View Exceptions]     │
└─────────────────────────────────────────────┘
```

**Drill-Down:**
- Click "Posted" → filters Load List to status = 'posted' (loads waiting for carrier)
- Click "Exception" → filters to status = 'exception' (requires dispatcher action)
- Click "In Transit" → maps view (all in-transit loads on map)

**SOQL Query:**
```sql
SELECT COUNT(Id), status__c 
FROM Load__c 
WHERE pickup_date__c = TODAY() 
GROUP BY status__c
```

---

### Card 2: On-Time Delivery % (KPI Card with Target)

**Purpose:** Track service quality against shipper expectations  
**Metric:** Percentage of loads delivered on or before scheduled delivery window  
**Target:** 95% (industry standard for 3PL)  
**Refresh Interval:** Every 60 sec  
**Calculation:** Loads delivered on time / Total loads delivered (last 30 days)

#### Design
```
┌─────────────────────────────────────────────┐
│ ON-TIME DELIVERY %                          │
│ (Last 30 Days)                              │
├─────────────────────────────────────────────┤
│                                             │
│         92.4%                               │
│      ↓ (vs. Target)                         │
│        95%  TARGET                          │
│                                             │
│  Status: ⚠️  BELOW TARGET (-2.6%)           │
│                                             │
│  84 on-time | 7 late | 1 damage exception  │
│                                             │
│ [View Late Loads]  [Trend (7 days)]        │
└─────────────────────────────────────────────┘
```

**Color Coding:**
- Green (≥ 95%): Target met
- Yellow (90-94%): Warning
- Red (< 90%): Critical

**Drill-Down:**
- Click "View Late Loads" → list of loads delivered after window (with reason)
- Click "Trend" → line chart showing daily on-time % over last 7 days

**SOQL Query:**
```sql
SELECT COUNT(CASE WHEN delivery_actual__c <= delivery_date__c THEN 1 END) as on_time,
       COUNT(Id) as total
FROM Load__c
WHERE status__c = 'delivered'
  AND delivery_actual__c >= DATE_VALUE(:LAST_90_DAYS)
```

---

### Card 3: Revenue MTD (Number Card with Trend)

**Purpose:** Quick revenue visibility  
**Metric:** Total shipper charges in current month (Month-to-Date)  
**Refresh Interval:** Every 60 sec  
**Calculation:** SUM(shipper_rate) for loads delivered this month

#### Design
```
┌─────────────────────────────────────────────┐
│ REVENUE MTD                                 │
├─────────────────────────────────────────────┤
│                                             │
│       $487,250                              │
│                                             │
│   ↑ +8.2% vs Last Month ($450,100)         │
│                                             │
│   Pace: $650K projected end of month       │
│   (based on daily average)                  │
│                                             │
│ [View Details]  [Forecast]                 │
└─────────────────────────────────────────────┘
```

**Trend Arrow:**
- Green ↑: revenue increasing vs. prior month
- Red ↓: revenue decreasing vs. prior month
- Gray →: flat

**Drill-Down:**
- Click "Details" → revenue breakdown by shipper (top 10)
- Click "Forecast" → revenue projection through end of month

**SOQL Query:**
```sql
SELECT SUM(shipper_rate__c + fuel_surcharge__c) as mtd_revenue
FROM Load__c
WHERE CALENDAR_MONTH(pickup_date__c) = CALENDAR_MONTH(TODAY())
  AND CALENDAR_YEAR(pickup_date__c) = CALENDAR_YEAR(TODAY())
```

---

### Card 4: Average Margin $ + % (Gauge + Number)

**Purpose:** Track profitability per load  
**Metric:** (Shipper Rate - Carrier Rate) and margin %  
**Target Margin:** 18% (industry benchmark for flatbed brokerage)  
**Refresh Interval:** Every 60 sec  
**Calculation:** (Total Shipper Charges - Total Carrier Costs) / Total Shipper Charges

#### Design
```
┌─────────────────────────────────────────────┐
│ AVERAGE MARGIN (MTD)                        │
├─────────────────────────────────────────────┤
│                                             │
│   Margin $:  $425 per load                 │
│   Margin %:  16.2%                          │
│   ↓ (Target: 18%)                           │
│                                             │
│  Total Margin MTD: $87,150 on 205 loads    │
│                                             │
│  Lowest Margin Load:  9.2% ($275)          │
│  Highest Margin Load: 28.5% ($1,050)       │
│                                             │
│ [View Low Margin Loads]  [Trend]           │
└─────────────────────────────────────────────┘
```

**Status Indicator:**
- Green: Margin ≥ 18% target
- Yellow: 15-17% (warning)
- Red: < 15% (investigate)

**Drill-Down:**
- Click "Low Margin Loads" → list loads with margin < 15% (identify unprofitable lanes)
- Click "Trend" → margin % chart over last 30 days (are margins declining?)

**SOQL Query:**
```sql
SELECT AVG(gross_margin__c) as avg_margin,
       AVG(margin_percent__c) as avg_margin_pct,
       SUM(gross_margin__c) as total_margin,
       COUNT(Id) as load_count
FROM Load__c
WHERE pickup_date__c >= LAST_N_DAYS(30)
  AND status__c = 'completed'
```

---

### Card 5: Carrier Utilization % (Bar Chart)

**Purpose:** Understand carrier capacity and demand balance  
**Metric:** (Active loads assigned) / (Total available carrier units) = utilization %  
**Target:** 80-85% (optimal utilization; avoid overheating carriers)  
**Refresh Interval:** Every 60 sec

#### Design
```
┌─────────────────────────────────────────────┐
│ CARRIER UTILIZATION %                       │
├─────────────────────────────────────────────┤
│ Equipment Type:  Util% | Capacity | Active │
├─────────────────────────────────────────────┤
│ Flatbed           82%  │  180 units │ 148 │
│ ▓▓▓▓▓▓▓▓▓░         (Optimal)               │
├─────────────────────────────────────────────┤
│ Reefer            64%  │  45 units  │  29 │
│ ▓▓▓▓▓▓░░░░         (Below Target)         │
├─────────────────────────────────────────────┤
│ Van               91%  │  120 units │ 109 │
│ ▓▓▓▓▓▓▓▓▓░         (High - May Need More) │
├─────────────────────────────────────────────┤
│ Tanker            55%  │  30 units  │  17 │
│ ▓▓▓▓░░░░░░         (Low Demand)            │
│                                             │
│ [Recruit Reefer]  [Optimize Van]           │
└─────────────────────────────────────────────┘
```

**Color Coding:**
- Green (80-85%): Optimal
- Yellow (70-79%, 85-95%): Caution
- Red (< 70%, > 95%): Action required (shortage or excess)

**Drill-Down:**
- Click "Recruit Reefer" → list of available reefer carriers (opportunity)
- Click equipment type → assigned loads for that equipment

**SOQL Query:**
```sql
SELECT 
  Carrier__r.equipment_type__c,
  COUNT(CASE WHEN status__c IN ('assigned', 'dispatched', 'in_transit') THEN 1 END) as active_loads,
  Carrier__r.total_units__c as capacity
FROM Load__c
GROUP BY Carrier__r.equipment_type__c
```

---

### Card 6: Top 5 Shippers by Revenue (Horizontal Bar Chart)

**Purpose:** Identify revenue concentration and key accounts  
**Metric:** Total revenue per shipper (YTD)  
**Refresh Interval:** Every 60 sec

#### Design
```
┌─────────────────────────────────────────────┐
│ TOP 5 SHIPPERS (YTD Revenue)                │
├─────────────────────────────────────────────┤
│                                             │
│ Scotts Miracle-Gro     $287,500            │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓        (42%)               │
│                                             │
│ Home Depot             $156,250            │
│ ▓▓▓▓▓▓▓░               (23%)               │
│                                             │
│ Ace Hardware           $98,750             │
│ ▓▓▓▓░░░░               (14%)               │
│                                             │
│ Lowe's                 $67,500             │
│ ▓▓░░░░░░               (10%)               │
│                                             │
│ Ace Building Supply    $45,000             │
│ ▓░░░░░░░               (7%)                │
│                                             │
│ [Risk: 67% from Top 2] [Diversify]         │
└─────────────────────────────────────────────┘
```

**Alert:**
- If top 2 shippers > 60% revenue: flag concentration risk
- If any shipper has no loads in last 30 days: churn alert

**Drill-Down:**
- Click shipper bar → view all shipper's loads YTD
- Click "Diversify" → list of prospects (opportunities) to reduce concentration

**SOQL Query:**
```sql
SELECT shipper_account__r.name,
       SUM(shipper_rate__c + fuel_surcharge__c) as revenue,
       COUNT(Id) as load_count
FROM Load__c
WHERE pickup_date__c >= DATE_TRUNC('year')
GROUP BY shipper_account__c
ORDER BY revenue DESC
LIMIT 5
```

---

### Card 7: Top 5 Carriers (Ranked by On-Time %)

**Purpose:** Identify best-performing carriers (vs. problem carriers)  
**Metric:** On-time delivery % per carrier (last 30 days)  
**Refresh Interval:** Every 60 sec

#### Design
```
┌─────────────────────────────────────────────┐
│ TOP 5 CARRIERS (On-Time %)                  │
│ (Last 30 Days)                              │
├─────────────────────────────────────────────┤
│                                             │
│ Rank │ Carrier Name      │ On-Time% │ Loads│
├──────┼──────────────────┼──────────┼──────┤
│  1   │ Anderson Trucking │  98%     │  28  │
│  2   │ Blue Mountain     │  97%     │  19  │
│  3   │ Crown Logistics   │  94%     │  31  │
│  4   │ Delta Freight     │  91%     │  22  │
│  5   │ Elite Carriers    │  87%     │  18  │
│                                             │
│ ⚠️ Below 85%: [Delta (91%), Elite (87%)]   │
│ 🔴 Probation Needed: Elite (87%)            │
│                                             │
│ [Review Elite Issues]  [Rotate Out?]       │
└─────────────────────────────────────────────┘
```

**Status Indicators:**
- Green: ≥ 95% (Gold tier)
- Yellow: 85-94% (Silver tier, monitor)
- Red: < 85% (Probation, reduce allocation)

**Drill-Down:**
- Click carrier name → view all their loads (identify patterns)
- Click "Review Elite Issues" → list of late deliveries, reasons, resolution status
- Click "Rotate Out?" → reassign Elite's pending loads to better-performing carrier

**SOQL Query:**
```sql
SELECT 
  Carrier__r.name,
  COUNT(CASE WHEN delivery_actual__c <= delivery_date__c THEN 1 END) as on_time,
  COUNT(Id) as total,
  COUNT(CASE WHEN delivery_actual__c <= delivery_date__c THEN 1 END) * 100.0 / COUNT(Id) as on_time_pct
FROM Load__c
WHERE pickup_date__c >= LAST_N_DAYS(30)
  AND status__c IN ('delivered', 'pod_captured')
GROUP BY Carrier__c
ORDER BY on_time_pct DESC
LIMIT 5
```

---

### Card 8: Exception Queue (Table, Sortable)

**Purpose:** Fast access to problems requiring immediate attention  
**Metric:** All active exceptions (not yet resolved)  
**Sort By:** Severity (descending), Age (descending)  
**Refresh Interval:** Every 60 sec  
**Configurable Alert Thresholds:**
- Critical: ETA > 8h late OR damage reported OR load missing
- High: ETA 4-8h late OR driver offline > 1h OR mechanical breakdown
- Medium: ETA 2-4h late OR shipper not ready for pickup
- Low: ETA 0-2h late OR documentation missing

#### Design
```
┌────────────────────────────────────────────────────────────┐
│ EXCEPTION QUEUE (ACTIVE)                         [Refresh] │
├────────────────────────────────────────────────────────────┤
│                                                            │
│ ⚠️ CRITICAL (3)   🔶 HIGH (5)   🟡 MEDIUM (8)   ℹ️ LOW (2) │
│                                                            │
│ Load # │ Exception Type │ Severity │ Age    │ Action      │
├────────┼────────────────┼──────────┼────────┼─────────────┤
│ 1052   │ Late (4h 30m)  │ 🔴 Crit  │ 4h 32m │ [Escalate]  │
│        │ Expected: 2 PM │          │        │ [Call Shpr] │
│        │ Est. Now: 6 PM │          │        │ [Reassign?] │
├────────┼────────────────┼──────────┼────────┼─────────────┤
│ 1051   │ Geofence Viol  │ 🔴 Crit  │ 3h 15m │ [Investigate]
│        │ Off-route 85mi │          │        │ [Call Driver]│
├────────┼────────────────┼──────────┼────────┼─────────────┤
│ 1049   │ Delay (6h 20m) │ 🔶 High  │ 2h 45m │ [Monitor]   │
│        │ Driver rest    │          │        │ [ETA Check] │
├────────┼────────────────┼──────────┼────────┼─────────────┤
│ 1045   │ Missing POD    │ 🟡 Med   │ 8h     │ [Contact Dr]│
│        │ Delivered 12pm │          │        │ [Re-scan]   │
├────────┼────────────────┼──────────┼────────┼─────────────┤
│ 1043   │ Shipper Not Rdy│ 🟡 Med   │ 20m    │ [Call Shpr] │
│        │ Scheduled 8 AM │          │        │ [Reschedule]│
│                                                            │
│ Showing 5 of 18 exceptions  [ Load More ]                 │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**Quick Actions:**
- **[Escalate]:** Alert to ops manager (SMS/email)
- **[Investigate]:** Dispatcher starts investigation ticket
- **[Call Driver/Shipper]:** Suggested phone call list
- **[Resolve]:** Mark exception as resolved (auto-closes)
- **[Reassign]:** Reassign load to different carrier

**Mobile View:**
```
Exception #1052 (CRITICAL)
Load: 1052
Type: Late (4h 30m)
Age: 4h 32m
[Call Driver]  [Resolve]
```

**Drill-Down:**
- Click Load # → open Load Detail page (full context)
- Click "Escalate" → creates Task assigned to ops manager with exception details
- Sorting: Click "Severity" header to sort by severity; "Age" to sort by how long exception has been open

---

### Card 9: Settlement Backlog (Numbers + List)

**Purpose:** Track unpaid carrier settlements (cash flow impact)  
**Metric:** (Total settlement amount pending approval) + (count of unsettled loads)  
**Refresh Interval:** Every 60 sec

#### Design
```
┌──────────────────────────────────────────────────┐
│ SETTLEMENT BACKLOG                               │
├──────────────────────────────────────────────────┤
│                                                  │
│ Pending Approval:  $187,500 (67 loads)          │
│ Pending Payment:   $142,250 (51 loads)          │
│ Total Backlog:     $329,750 (118 loads)         │
│                                                  │
│ Days Outstanding (Avg): 6.2 days                │
│ (Target: < 3 days from delivery)                │
│                                                  │
│ Top 5 Carriers Owed:                            │
│ 1. Anderson Trucking:  $45,600                  │
│ 2. Blue Mountain:      $38,200                  │
│ 3. Crown Logistics:    $32,450                  │
│ 4. Delta Freight:      $28,100                  │
│ 5. Elite Carriers:     $19,750                  │
│                                                  │
│ [ Approve All ]  [ View Pending ]  [ Pay Now ]  │
└──────────────────────────────────────────────────┘
```

**Color Coding:**
- Green: Backlog < $100K
- Yellow: $100K - $250K (getting behind)
- Red: > $250K (urgent — pay carriers!)

**Drill-Down:**
- Click "Approve All" → approve all pending settlements (batch action)
- Click "View Pending" → list of settlements waiting for manager approval
- Click "Pay Now" → trigger ACH payment batch (sync to payment processor)

**SOQL Query:**
```sql
SELECT COUNT(Id) as load_count,
       SUM(net_payment__c) as total_amount,
       status__c
FROM Settlement__c
WHERE status__c IN ('pending_pod', 'ready_for_approval', 'approved')
  AND load__r.delivery_actual__c IS NOT NULL
GROUP BY status__c
```

---

### Card 10: Fuel Price Trend (Line Chart, Indexed)

**Purpose:** Monitor fuel cost impact on margins  
**Metric:** Diesel fuel price (DAI index) over last 30 days  
**Calculation:** (Current price - Base price 30 days ago) as % change  
**Refresh Interval:** Daily (fuel prices update once/day)

#### Design
```
┌─────────────────────────────────────────────────┐
│ FUEL PRICE TREND (DAI Index, Last 30 Days)     │
│                                                 │
│ Price:  $3.44/gal (today)                       │
│ Change: ↑ +4.2% vs 30 days ago ($3.30)          │
│                                                 │
│   3.50 ┤         ╭─╮                            │
│   3.45 ┤        ╱   ╲    ╭─╮                   │
│   3.40 ┤   ╭───╯     ╰──╱ ╰─────╮             │
│   3.35 ┤  ╱                     ╰──╮           │
│   3.30 ┤─╯                         ╰─          │
│   3.25 ┤                                        │
│         └─────────────────────────────────     │
│         3/5   3/10   3/15   3/20   3/25   3/30 │
│                                                 │
│ Fuel Surcharge Impact:                          │
│ • Margin impact: -$2.10 per load (at 3% FSC) │
│ • MTD impact: -$431 across 205 loads           │
│ • Recommendation: Consider raising fuel       │
│   surcharge from 3% → 3.5%                    │
│                                                 │
│ [ View by Carrier ]  [ Adjust Surcharge ]      │
└─────────────────────────────────────────────────┘
```

**Intelligence Added:**
- Auto-calculate margin impact based on fuel surcharge model
- Recommend FSC adjustment if fuel prices spike
- Trend: Is fuel trending up or down?

**Drill-Down:**
- Click "View by Carrier" → fuel surcharge impact by carrier type (DAI vs. EIA vs. included)
- Click "Adjust Surcharge" → rate card editor (Phase 2 feature)

---

## Dashboard Refresh Strategy

### Real-Time Refresh (Every 60 seconds)

When a Load status changes (e.g., picked up, delivered, exception), Salesforce fires a Platform Event:

```
Load__c status changed from 'assigned' to 'dispatched'
  ↓
Platform Event: Load_Status_Changed__e
  ↓
Lightning Dashboard subscribes to event
  ↓
Dashboard SOQL queries re-execute
  ↓
KPI cards update in real-time (< 5 sec)
```

**Why 60 seconds?** Faster refresh (every 5 sec) would exceed Salesforce API throttles. 60 sec is the practical sweet spot: updates feel real-time, doesn't exceed governor limits.

### Scheduled Refresh (Daily)

Fuel index (Card 10) updates once per day (fuel prices set nightly by DAI):

```
9 PM ET: DAI publishes new fuel price
  ↓
Salesforce scheduled job fetches DAI API
  ↓
Fuel_Index__c record updated
  ↓
Dashboard Card 10 fetches new value at next refresh
```

---

## Dashboard Mobile Responsiveness

### Desktop (1920px)

```
┌──────────────────────────────────────────────────────────────┐
│ KWB OPERATIONS DASHBOARD                      [Last Refresh] │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│ [ Card 1: Loads by Status ]  [ Card 2: On-Time % ]          │
│ [ Card 3: Revenue MTD ]       [ Card 4: Avg Margin ]         │
│ [ Card 5: Carrier Util ]      [ Card 6: Top 5 Shippers ]    │
│ [ Card 7: Top 5 Carriers ]    [ Card 8: Exception Queue ]   │
│ [ Card 9: Settlement ]        [ Card 10: Fuel Price ]        │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Tablet (768px)

```
┌─────────────────────────────────────────┐
│ KWB OPS DASHBOARD                       │
├─────────────────────────────────────────┤
│ [ Card 1: Loads ]  [ Card 2: On-Time% ] │
│ [ Card 3: Revenue] [ Card 4: Margin ]   │
│ [ Card 5: Carrier] [ Card 6: Top Ship] │
│ [ Card 7: Top Car] [ Card 8: Excep ]   │
│ [ Card 9: Settle ] [ Card 10: Fuel ]   │
└─────────────────────────────────────────┘
```

### Mobile (375px)

```
┌──────────────────────────────┐
│ KWB OPS DASHBOARD     [Menu] │
├──────────────────────────────┤
│ [ Card 1: Loads by Status  ] │
│ [ Card 2: On-Time %        ] │
│ [ Card 3: Revenue MTD      ] │
│ [ Card 4: Avg Margin       ] │
│ [ Card 5: Carrier Util     ] │
│ [ Card 6: Top Shippers     ] │
│ [ Card 7: Top Carriers     ] │
│ [ Card 8: Exception Queue  ] │
│ [ Card 9: Settlement       ] │
│ [ Card 10: Fuel Price      ] │
└──────────────────────────────┘
```

**Mobile UX:**
- Single column layout (full width)
- Cards stack vertically
- Font size enlarged (readable on small screens)
- Numbers large and bold (quick scanning)
- Drill-down links obvious (blue, underlined)
- Horizontal scroll for large tables (Card 8)

---

## Dashboard Access Control

### Salesforce Role-Based Access

| Role | Dashboard Access | Cards Visible | Data Scope |
|------|-----------------|---------------|-----------|
| **Dispatcher** | Yes | All 10 | Own assigned carriers only |
| **Ops Manager** | Yes | All 10 | All loads |
| **Account Manager** | Yes | Cards 1-4, 8 (filtered) | Own shipper accounts only |
| **CFO/Finance** | Yes | Cards 3, 4, 9 | Margin + settlement focus |
| **Shipper (Portal User)** | No | N/A | (Shipper portal only, different dashboard) |

**Implementation:** Apex controller filters SOQL queries based on logged-in user's role:

```apex
public class OpsMetricsController {
    public List<Load__c> getLoads() {
        String userRole = UserInfo.getUserRoleId();
        String userId = UserInfo.getUserId();
        
        if (userRole.contains('Dispatcher')) {
            // Filter to dispatcher's assigned carriers
            return [SELECT Id, Name, status__c FROM Load__c 
                    WHERE assigned_carrier__r.assigned_dispatcher__c = :userId];
        } else if (userRole.contains('Account_Manager')) {
            // Filter to account manager's accounts
            return [SELECT Id, Name, status__c FROM Load__c 
                    WHERE shipper_account__r.owner__c = :userId];
        } else if (userRole.contains('Manager')) {
            // All loads
            return [SELECT Id, Name, status__c FROM Load__c];
        }
    }
}
```

---

## Dashboard Performance & Optimization

### Query Optimization

All SOQL queries use indexed fields for selectivity:

| Query | Indexed Fields | Selectivity |
|-------|----------------|-------------|
| Card 1 (Status count) | status__c (picklist, indexed) | < 5% (highly selective) |
| Card 2 (On-Time %) | pickup_date__c, status__c | < 10% (selective) |
| Card 3 (Revenue) | pickup_date__c (date, indexed) | < 20% (selective enough) |
| Card 8 (Exception queue) | status__c = 'exception', age | < 2% (very selective) |

**Result:** Each query executes in < 500 ms (Salesforce query planner optimizes for indexed fields).

### Caching Strategy

High-volume queries (Card 5, 6, 7) are cached for 5 minutes:

```apex
// Cache: top shippers
Cache.OrgPartition myPartition = Cache.getPartition('local.OrgCache');
List<TopShippers> shippers = (List<TopShippers>) myPartition.get('top_shippers_ytd');
if (shippers == null) {
    // Query to database (expensive)
    shippers = getTopShippersFromDatabase();
    // Cache for 5 minutes
    myPartition.put('top_shippers_ytd', shippers, 300);
}
return shippers;
```

**Benefit:** Dashboard loads in < 2 seconds (most data comes from cache).

---

## Dashboard KPI Definitions

### Metric 1: On-Time Delivery %

**Definition:** Loads where actual_delivery_time ≤ scheduled_delivery_window_end_time  
**Calculation:** Count(on_time_loads) / Count(total_loads_delivered)  
**Period:** Last 30 days  
**Target:** 95%  
**Review Frequency:** Daily

### Metric 2: Average Margin $

**Definition:** (Shipper Rate + Fuel Surcharge + Accessorials) - (Carrier Rate + Carrier Fuel + Carrier Accessorials)  
**Calculation:** SUM(gross_margin) / COUNT(loads)  
**Period:** Current month  
**Target:** $400-500 per load  
**Review Frequency:** Daily

### Metric 3: Carrier Utilization %

**Definition:** Active assigned loads / Available carrier equipment capacity  
**Calculation:** COUNT(loads with status in ['assigned', 'dispatched', 'in_transit']) / SUM(carrier equipment units)  
**Period:** Real-time (current moment)  
**Target:** 80-85%  
**Review Frequency:** Real-time

### Metric 4: Revenue Per Load (MTD)

**Definition:** Total revenue / Load count  
**Calculation:** SUM(shipper_rate + fuel surcharge) / COUNT(loads)  
**Period:** Current month  
**Target:** $2,800-3,200  
**Review Frequency:** Daily

### Metric 5: Exception Rate

**Definition:** Loads with active exceptions  
**Calculation:** COUNT(loads with status = 'exception') / COUNT(total loads)  
**Period:** Last 7 days  
**Target:** < 2%  
**Review Frequency:** Real-time

---

## Dashboard Drill-Down Examples

### Example 1: On-Time Delivery → Late Loads List

**Start:** Card 2 shows "92.4% (Below Target)"  
**Click:** "View Late Loads" button  
**Result:** Filtered list view opens:

```
LATE LOADS (LAST 30 DAYS)
Load # │ Receiver  │ Scheduled │ Actual │ Late By │ Reason
────────┼───────────┼───────────┼────────┼─────────┼────────
1041   │ Lowe's    │ 3/20 4 PM │ 6 PM  │ 2 hours │ Traffic
1038   │ Home      │ 3/18 2 PM │ 5 PM  │ 3 hours │ Breakdown
1035   │ Ace       │ 3/16 12am │ 2 PM  │ 2 hours │ Receiver Delay
1029   │ Scotts    │ 3/12 11am │ 4 PM  │ 5 hours │ Weather
1023   │ Lowe's    │ 3/9  3 PM │ 6 PM  │ 3 hours │ Traffic
...
```

**Drill-Down Further:** Click load #1041 → opens Load Detail page (full context: tracking map, documents, etc.)

### Example 2: Low Margin Loads → Identify Unprofitable Lane

**Start:** Card 4 shows "$425 avg margin" (below target)  
**Click:** "View Low Margin Loads" button  
**Result:** List of loads with margin < $300:

```
LOW MARGIN LOADS (< $300)
Load # │ Shipper │ Origin │ Dest  │ Rate │ Carrier Cost │ Margin │ Margin %
────────┼─────────┼────────┼───────┼──────┼──────────────┼────────┼────────
1058   │ Scotts  │ Toledo │ Miami │ $2,950 │ $2,625 │ $325 │ 11%
1056   │ Scotts  │ Toledo │ Miami │ $2,850 │ $2,600 │ $250 │  9%
1055   │ Scotts  │ Toledo │ Miami │ $2,900 │ $2,675 │ $225 │  8%
...
```

**Insight:** Toledo→Miami loads all low margin. Lane data aggregated:

```
TOLEDO → MIAMI LANE ANALYSIS
Total Loads (90 days): 12
Avg Shipper Rate: $2,850
Avg Carrier Rate: $2,625 (92% of shipper rate!)
Avg Margin: $225 (7.8%)
Recommendation: Raise shipper rate to $3,100 (+8.8%) OR 
                reduce carrier rate through negotiation.
```

---

## Dashboard Deployment & Go-Live

### Phase 1 Deployment (Week 3-4)

1. **Week 3:** Build dashboard with 5 core KPIs (Cards 1-4, 8)
2. **Test:** Run against sandbox data (100 test loads)
3. **Review:** Seb + Ops Manager feedback
4. **Deploy:** Move to production (Friday end-of-day to minimize impact)

### Phase 2 Deployment (Week 5+)

1. **Week 5:** Add remaining KPIs (Cards 5-7, 9-10)
2. **Enhancements:** Add drill-down, exception workflow actions
3. **Mobile Testing:** Test on dispatcher phone/tablet
4. **Training:** 1-hour walkthrough for ops team

### Training Plan

- **Dashboard Overview:** 15 min (what is each card, how to read it)
- **Drill-Down Demo:** 15 min (click card, filter data, take action)
- **Mobile Access:** 5 min (dashboard on phone)
- **Questions & Support:** 15 min (Q&A, troubleshooting)

**Delivered By:** Seb Roman or KWB Ops Manager  
**Attendees:** Dispatchers, Ops Manager, Account Managers  
**When:** Friday end of deployment week (30 min meeting)

---

## Dashboard Acceptance Criteria (Phase 1 Complete)

✅ All 10 KPI cards display correct calculations  
✅ Cards refresh every 60 seconds (verified with timestamp)  
✅ Drill-down links work (card → filtered list)  
✅ Exception queue updated in real-time (test with manual exception creation)  
✅ Dashboard loads in < 5 sec (measured on 3G network simulation)  
✅ Mobile-responsive (tested on iPhone 12, iPad, Android tablet)  
✅ All users can view (no security errors)  
✅ Dispatcher sees only own loads (role-based filtering works)  
✅ No SOQL governor limit hits (check logs)  
✅ Documentation complete (how to read each card, drill-down examples)  
✅ Team trained & able to action exceptions from dashboard  
✅ UAT sign-off from Ops Manager  

---

**Document Status:** DESIGN-READY (4/3/2026)  
**Next Phase:** Implementation (Agent 3 + Seb deployment)  
**Estimated Dev Time:** 3 weeks (Weeks 3-5 of project timeline)
