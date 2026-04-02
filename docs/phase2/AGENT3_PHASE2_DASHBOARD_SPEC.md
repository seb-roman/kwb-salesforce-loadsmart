# AGENT3 Phase 2: Exception Dashboard Specification

**Document Version:** 1.0  
**Created:** 2026-04-02  
**Status:** COMPLETE - Ready for Lightning Development  
**Target:** <5 sec load time, auto-refresh every 30 sec

---

## Dashboard Overview

The Exception Dashboard provides real-time visibility into active exceptions across all loads. Designed for Operations teams and Load Managers to quickly identify and resolve logistics issues.

## Layout & Components

### Top Section: Metrics & Summary

#### Severity Gauge (Left)
- **Title:** Active Exceptions by Severity
- **Type:** 3-part gauge visualization
- **Data:**
  - Warning count (yellow)
  - Alert count (orange)
  - Critical count (red)
- **Size:** 1/3 of width
- **Refresh:** Every 30 sec
- **Click Action:** Filter list to severity

**Example Display:**
```
Active Exceptions by Severity
┌─────────────────────┐
│  ⚠️  5 Warnings     │
│  🔶 12 Alerts      │
│  🔴  3 Critical    │
│                     │
│  Total: 20 Open     │
└─────────────────────┘
```

#### Exception Breakdown Chart (Right)
- **Title:** Exceptions by Type
- **Type:** Horizontal bar chart
- **Data:** Count of each exception type
  - LATE_ARRIVAL: 8
  - LONG_IDLE: 5
  - MISSED_PICKUP: 3
  - GEOFENCE_VIOLATION: 2
  - DRIVER_OFFLINE: 1
  - EQUIPMENT_BREAKDOWN: 1
- **Size:** 2/3 of width
- **Refresh:** Every 30 sec
- **Click Action:** Filter list to type

**Example Display:**
```
Exceptions by Type
━━━━━━━━━━━━━━━━━━━━━━━
Late Arrival      ████████ 8
Long Idle        █████ 5
Missed Pickup    ███ 3
Geofence         ██ 2
Driver Offline   █ 1
Breakdown        █ 1
```

#### Last Updated
- **Display:** "Last updated: 2026-04-02 14:35:42 EDT"
- **Refresh:** Real-time
- **Action:** Manual refresh button

---

### Middle Section: Filter Bar

#### Filter Controls (Horizontal)
```
┌──────────────────────────────────────────────────────────┐
│ Severity:  [All ▼]    Type:  [All ▼]    Status:  [Open ▼] │
│ Load Name: [_____]    Carrier: [All ▼]  Shipper: [All ▼]  │
│                                          [Reset] [Search] │
└──────────────────────────────────────────────────────────┘
```

**Filters:**
1. **Severity** (dropdown)
   - All Severities
   - Warning
   - Alert
   - Critical

2. **Exception Type** (dropdown)
   - All Types
   - LATE_ARRIVAL
   - MISSED_PICKUP
   - LONG_IDLE
   - EXCESSIVE_DELAY
   - DRIVER_OFFLINE
   - GEOFENCE_VIOLATION
   - EQUIPMENT_BREAKDOWN

3. **Status** (dropdown)
   - Open (default)
   - Acknowledged
   - Resolved
   - All

4. **Load Name** (text search)
   - Type to search: "LOAD-001"
   - Partial matches supported

5. **Carrier** (dropdown)
   - All Carriers
   - Dynamic list from Load__c.Carrier__c

6. **Shipper** (dropdown)
   - All Shippers
   - Dynamic list from Load__c.Shipper__c

**Actions:**
- **[Reset]** - Clear all filters, reload default
- **[Search]** - Apply filters (or press Enter)
- **Auto-filter** - Each control filters immediately

---

### Bottom Section: Exception List

#### Table Layout
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Severity │ Load      │ Type          │ Description              │ Age  │ Actions
├─────────────────────────────────────────────────────────────────────────────┤
│ 🔴 CRIT  │ LOAD-001  │ DRIVER_OFFLINE│ Offline 47 minutes      │ 47m  │ ⋯
│ 🔶 ALERT │ LOAD-002  │ LATE_ARRIVAL  │ Late pickup (60 min)    │ 23m  │ ⋯
│ 🔶 ALERT │ LOAD-003  │ LONG_IDLE     │ Idle 4h 30m at Stop A   │ 2h   │ ⋯
│ ⚠️  WARN  │ LOAD-004  │ MISSED_PICKUP │ No arrival by 11:00     │ 1d   │ ⋯
│ 🔴 CRIT  │ LOAD-005  │ GEOFENCE      │ Location outside route  │ 5m   │ ⋯
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Columns (Sortable):

1. **Severity** (not sortable, colored badge)
   - 🔴 CRITICAL (red)
   - 🔶 ALERT (orange)
   - ⚠️ WARNING (yellow)

2. **Load** (sortable) - Load__c.Name with hyperlink
   - Click to open Load detail page
   - Shows carrier + shipper on hover

3. **Exception Type** (sortable)
   - Human-readable type name
   - Matches Exception__c.Exception_Type__c

4. **Description** (not sortable)
   - Exception__c.Description__c
   - Truncated to ~80 chars with ellipsis
   - Full text on hover

5. **Triggered Time** (sortable, default DESC)
   - Display: "45m ago", "2h 15m ago", "1d 3h ago"
   - Calculation: System.now() - Triggered_DateTime__c
   - Updates automatically on 30-sec refresh

6. **Status** (sortable)
   - Open, Acknowledged, Resolved
   - Resolved rows: slightly faded
   - Acknowledged rows: normal

7. **Actions** (row menu) - Right-aligned buttons

#### Sorting:
- Default: Triggered_DateTime__c DESC (newest first)
- Click column header to sort ASC/DESC
- Sortable columns: Severity, Type, Load, Status, Age
- Indicator: ▲▼ on sorted column

#### Pagination:
- **Rows per page:** 50
- **Navigation:**
  ```
  Showing 1-50 of 142 exceptions
  [< Prev] [1] [2] [3] ... [Next >]
  ```
- **Quick jump:** Jump to page [_5_] [Go]

---

### Row Actions Menu (Right side: ⋯)

#### For Open Exceptions:
```
┌─────────────────────────┐
│ ✓ Acknowledge           │
│ ✓ Resolve (open form)   │
│ 🔗 View Load Detail     │
│ 🔗 View Exception       │
└─────────────────────────┘
```

#### For Acknowledged Exceptions:
```
┌─────────────────────────┐
│ ✓ Resolve (open form)   │
│ ↩️  Reopen              │
│ 🔗 View Load Detail     │
│ 🔗 View Exception       │
└─────────────────────────┘
```

#### For Resolved Exceptions:
```
┌─────────────────────────┐
│ ↩️  Reopen              │
│ 🔗 View Load Detail     │
│ 🔗 View Exception       │
└─────────────────────────┘
```

---

## Modal Dialogs

### Resolve Exception Modal

**Trigger:** User clicks "Resolve" action

```
┌─────────────────────────────────────────────┐
│ Resolve Exception                       [X] │
├─────────────────────────────────────────────┤
│                                             │
│ Load: LOAD-001                              │
│ Type: LATE_ARRIVAL                          │
│ Description: Late arrival (60 min delay)    │
│                                             │
│ Resolution Notes (required):                │
│ [________________________________]          │
│ [                                ]          │
│ [                                ]          │
│                                             │
│ Severity at resolution: ALERT               │
│ Status will change to: RESOLVED             │
│                                             │
│ [Cancel]  [Resolve & Close]                │
│                                             │
└─────────────────────────────────────────────┘
```

**Form Fields:**
- **Load/Type/Description** (read-only, context)
- **Resolution Notes** (textarea, required)
  - Min 10 chars, max 1000 chars
  - Placeholder: "Explain how issue was resolved..."
  - Character counter: "45/1000"
- **Confirmation** (info box)
  - "This will mark as Resolved"
  - "Cannot be undone from this dialog"

**Actions:**
- **[Cancel]** - Close without saving
- **[Resolve & Close]** - Calls resolveException(id, notes)
  - Shows spinner
  - On success: List refreshes, exception removed/grayed out
  - On error: Toast notification with error message

---

### Quick Acknowledge

**Trigger:** User clicks "Acknowledge" action

- **No modal** - One-click action
- **Effect:** Calls acknowledgeException(id)
  - Icon changes from "Open" to "Acknowledged"
  - Status updates immediately
  - Toast: "Exception acknowledged"
- **Behavior:**
  - Updates row in place
  - No dialog
  - Undo not available (by design)

---

## Auto-Refresh Logic

**Frequency:** Every 30 seconds (configurable)

```
Timeline:
00:00 - Dashboard loads
        ├─ getDashboardMetrics()
        ├─ getExceptions(page 1)
        └─ Display renders

00:30 - Auto-refresh timer fires
        ├─ Calls getDashboardMetrics() (quiet refresh)
        ├─ Calls getExceptions(current page)
        ├─ Updates metrics cards
        ├─ Refreshes exception list
        └─ Maintains sort/filter state

01:00 - Another refresh...

[On user action]
- Filter change → Resets to page 1, refreshes
- Sort change → Applies sort, refreshes
- Manual refresh button → Force immediate refresh
```

**Auto-Refresh State Preservation:**
- ✅ Maintains current page number
- ✅ Maintains sort field + direction
- ✅ Maintains all filter selections
- ✅ Maintains scroll position (optional)

**Network Optimization:**
- Use `@AuraEnabled(cacheable=false)` for fresh data
- Batch metric + exception queries where possible
- Handle slow responses gracefully (show stale data until new data arrives)

---

## Performance Requirements

| Metric | Target | Notes |
|--------|--------|-------|
| Initial Load Time | <5 sec | First render |
| Metrics Query | <2 sec | Aggregate queries |
| Exception List Query | <3 sec | 50 rows, all filters |
| Auto-Refresh Time | <2 sec | Background update |
| Filter Application | <3 sec | Dynamic SOQL |
| Row Action (Click) | <1 sec | Modal/action response |

**Optimization Techniques:**
- Cache metrics for 30-60 sec if possible
- Use aggregate queries for counts (fast)
- Pagination prevents large result sets
- Index on Load__c, Status__c, Severity__c

---

## Error Handling

### Query Failures
```
┌──────────────────────────────────────────┐
│ ⚠️ Unable to load exceptions             │
│                                          │
│ The system encountered an error while    │
│ fetching exceptions. Please try again.   │
│                                          │
│ [Retry] [Dismiss]                        │
└──────────────────────────────────────────┘
```

### Action Failures (Acknowledge/Resolve)
```
Toast (top-right):
🔴 Failed to acknowledge exception. 
   Please try again or contact support.
[Dismiss]
```

### Slow Loading
- Show spinner/loading state
- Partial data: Show metrics, hide list until loaded
- Message: "Loading exceptions... This may take a moment"

---

## Accessibility

- ✅ ARIA labels on all interactive elements
- ✅ Keyboard navigation (Tab, Enter, Arrow keys)
- ✅ Color not only indicator (use icons + text)
- ✅ Sufficient contrast (WCAG AA)
- ✅ Focus indicators visible
- ✅ Form labels associated with inputs

---

## Lightning Component Structure

```
ExceptionDashboard (Main Component)
├─ ExceptionMetrics (Metrics Section)
│  ├─ SeverityGauge
│  ├─ ExceptionTypeChart
│  └─ LastUpdatedTimestamp
├─ ExceptionFilters (Filter Bar)
│  ├─ SeverityFilter
│  ├─ TypeFilter
│  ├─ StatusFilter
│  ├─ LoadNameFilter
│  ├─ CarrierFilter
│  ├─ ShipperFilter
│  └─ FilterActions
├─ ExceptionList (Exception Table)
│  ├─ DataTable (lightning-datatable)
│  ├─ Pagination
│  └─ RowActions (menu)
└─ ActionModals
   ├─ ResolveExceptionModal
   └─ ConfirmationModals
```

### Apex Controller
```
ExceptionDashboardController
├─ getDashboardMetrics()
├─ getExceptions()
├─ getFilterOptions()
├─ acknowledgeException()
├─ resolveException()
└─ (helper methods)
```

---

## Testing Checklist

### Functional Tests
- [ ] Load dashboard with no exceptions
- [ ] Load dashboard with 100+ exceptions
- [ ] Filter by severity, type, status
- [ ] Sort by each column
- [ ] Pagination works (prev/next, jump to page)
- [ ] Acknowledge exception
- [ ] Resolve exception with notes
- [ ] Auto-refresh updates metrics
- [ ] Manual refresh works
- [ ] Click load name → opens load detail
- [ ] Click exception → opens exception detail

### Performance Tests
- [ ] Initial load <5 sec
- [ ] Filter application <3 sec
- [ ] Auto-refresh <2 sec
- [ ] Handles 1000+ exceptions gracefully
- [ ] Pagination fast with 50 rows

### Accessibility Tests
- [ ] Keyboard navigation works
- [ ] Screen reader friendly
- [ ] Color + icons (not color-only)
- [ ] Focus visible on all elements

### Browser Testing
- [ ] Chrome 120+
- [ ] Firefox 120+
- [ ] Safari 17+
- [ ] Edge 120+
- [ ] Mobile browsers (iOS Safari, Chrome Mobile)

---

## Future Enhancements

- [ ] Drag-to-resize columns
- [ ] Save filter presets
- [ ] Export to CSV
- [ ] Bulk actions (acknowledge all, resolve multiple)
- [ ] Exception history/timeline view
- [ ] Trend analytics (exceptions over time)
- [ ] Heatmap of exception hotspots
- [ ] AI-powered recommendations

---

## Related Documents

- **AGENT3_PHASE2_EXCEPTION_RULES.md** - What triggers exceptions
- **AGENT3_PHASE2_ARCHITECTURE.md** - Backend implementation
- **AGENT3_PHASE2_USER_PREFERENCES.md** - User alert config

---

**Document Owner:** Agent 3  
**Last Updated:** 2026-04-02  
**Status:** Complete, ready for Lightning development

---

**END OF DOCUMENT**
