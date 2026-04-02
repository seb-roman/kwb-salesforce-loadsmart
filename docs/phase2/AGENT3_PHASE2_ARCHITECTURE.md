# AGENT3 Phase 2: Architecture & Technical Design

**Document Version:** 1.0  
**Created:** 2026-04-02  
**Status:** COMPLETE - Ready for Implementation  
**Flexibility:** ✅ Modular design, easy to extend

---

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    EXCEPTION ENGINE SYSTEM                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐        ┌──────────────────────┐           │
│  │ Custom Metadata  │        │ Scheduled Job        │           │
│  │ ExceptionRules   │        │ (every 5 min)        │           │
│  │ __mdt            │───────→│ Detection Engine     │           │
│  └──────────────────┘        └──────────────────────┘           │
│                                        │                         │
│                                        ▼                         │
│  ┌──────────────────┐        ┌──────────────────────┐           │
│  │ Load__c          │        │ Exception__c         │           │
│  │ Stop__c          │◄───────│ (trigger created)    │           │
│  │ Tracking__c      │        └──────────────────────┘           │
│  │ Driver__c        │                 │                         │
│  └──────────────────┘                 ▼                         │
│                                        │                         │
│  ┌──────────────────────────────────────────────────┐           │
│  │ Exception Trigger                                 │           │
│  │ (after insert)                                    │           │
│  │ Calls: Alert Distribution System                 │           │
│  └──────────────────────────────────────────────────┘           │
│                                        │                         │
│                    ┌───────────────────┼───────────────────┐    │
│                    ▼                   ▼                   ▼    │
│            ┌──────────────┐    ┌──────────────┐   ┌──────────────┐
│            │ Email Alert  │    │ Slack Alert  │   │ SMS Alert    │
│            │ (all users)  │    │ (#ops, crit) │   │ (crit only)  │
│            └──────────────┘    └──────────────┘   └──────────────┘
│                                        │                         │
│                    ┌───────────────────┼───────────────────┐    │
│                    ▼                   ▼                   ▼    │
│         Broker + Dispatcher    Ops Team via Slack  Driver Phone │
│                                                                   │
│  ┌────────────────────────────────────────────────────┐         │
│  │ Exception Dashboard                                 │         │
│  │ - Exception list (filtered, sorted, paginated)     │         │
│  │ - Severity gauge chart                            │         │
│  │ - Type breakdown bar chart                        │         │
│  │ - Acknowledge/Resolve actions                     │         │
│  │ - Auto-refresh every 30 sec                       │         │
│  └────────────────────────────────────────────────────┘         │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. ExceptionDetectionEngine (Apex Class)
**File:** `ExceptionDetectionEngine.cls` (500+ lines)  
**Type:** Schedulable, Batch Processing  
**Execution:** Every 5 minutes via scheduler

#### Responsibilities:
- Load all active exception rules from custom metadata
- Query all active loads (status IN 'IN_TRANSIT', 'AT_PICKUP', 'AT_DELIVERY')
- For each load, check all 8 rule types
- Create Exception__c record if rule triggered
- Deduplicate: skip creation if same exception exists within 1 hour
- Log metrics: exceptions created, rules evaluated

#### Key Methods:

**execute(SchedulableContext context)**
- Entry point for scheduled job
- Wraps detectExceptions() with error handling

**detectExceptions() [Future]**
- Loads rules from metadata
- Queries loads, stops, tracking data
- Builds lookup maps for efficiency
- Calls checkRule() for each rule
- Bulk inserts exceptions

**checkRule(rule, load, stops, tracking)**
- Dispatches to rule-specific checker (switch on rule.ruleType)
- Returns Exception__c if triggered, null otherwise

**Rule Checkers (checkLateArrival, checkMissedPickup, etc.)**
- Implement specific rule logic
- Perform time/distance calculations
- Return Exception__c with description

**isDuplicateException(exception)**
- Queries for same exception in last 1 hour
- Prevents alert spam

#### Data Flow:

```
detectExceptions()
  ├─ loadExceptionRules() → Map<String, ExceptionRule>
  ├─ getActiveLoads() → List<Load__c>
  ├─ getLoadStopsMap() → Map<Id, List<Stop__c>>
  ├─ getLoadTrackingMap() → Map<Id, List<Tracking__c>>
  │
  └─ FOR each load:
      ├─ FOR each rule:
      │   ├─ checkRule() → Exception__c
      │   └─ IF NOT isDuplicate:
      │       └─ Add to exceptions list
      │
      └─ Database.insert(exceptionsToCreate)
```

#### Performance Optimizations:
- ✅ No N+1 queries (bulk loads, stops, tracking in maps)
- ✅ Deduplication via single query per exception
- ✅ @Future annotation allows async execution (non-blocking)
- ✅ Batch processing supports 100+ active loads
- ✅ SOQL queries outside loops

---

### 2. ExceptionAlertDistribution (Apex Class)
**File:** `ExceptionAlertDistribution.cls` (400+ lines)  
**Type:** Utility Class (no state)  
**Execution:** Triggered on Exception__c insert

#### Responsibilities:
- Receive list of new exceptions
- Route alerts based on severity and channel preferences
- Build email, Slack, SMS messages
- Send via @Future methods (non-blocking)
- Handle failures gracefully (no cascade on one alert failure)

#### Alert Routing Matrix:

| Severity | Email | Slack | SMS | Recipients |
|----------|-------|-------|-----|------------|
| Warning | ✅ | ❌ | ❌ | Broker + Dispatcher |
| Alert | ✅ | ❌ | ❌ | Broker + Dispatcher |
| Critical | ✅ | ✅ | ✅ | Broker + Dispatcher + Ops + Driver |

#### Key Methods:

**processAlerts(List<Exception__c> exceptions) [public static]**
- Entry point from ExceptionTrigger
- Routes alerts to appropriate channels
- Calls send methods asynchronously

**buildEmailAlert(exception, load)**
- Creates AlertMessage for email
- Sets recipients: Broker_Rep__c.Email + Dispatcher__c.Email
- Includes load details, exception description, links

**buildSlackAlert(exception, load)**
- Creates AlertMessage for Slack
- Uses webhook URL from custom settings
- Format: :warning: *Critical* Load X - Type Y

**buildSMSAlert(exception, load)**
- Creates AlertMessage for SMS
- Gets phone from Driver__c.Phone
- Short format for mobile display

**sendEmailAlerts(List<AlertMessage>) [@Future]**
- Converts to Messaging.SingleEmailMessage
- Sends via Messaging.sendEmail()
- Logs results

**sendSlackAlerts(List<AlertMessage>)**
- Sends HTTP requests to Slack webhook URL
- Graceful degradation if webhook fails

**sendSMSAlerts(List<AlertMessage>)**
- Sends HTTP requests to SMS provider (Twilio-like)
- Respects phone opt-in flag

#### Configuration:

All sensitive data stored in custom settings (not hardcoded):
- **SlackWebhookURL__c** - Slack webhook for alerts
- **SlackOpsChannel__c** - Target Slack channel
- **SMSAPIKey__c** - API key for SMS provider
- **SMSAPIEndpoint__c** - SMS provider URL

#### Error Handling:
- Try-catch around each channel (email, Slack, SMS)
- Logs but doesn't throw (one channel failure ≠ stop everything)
- Metrics logged per alert sent

---

### 3. ExceptionDashboardController (Apex Class)
**File:** `ExceptionDashboardController.cls` (400+ lines)  
**Type:** Aura Enabled Controller  
**Access:** with sharing (enforce security)

#### Responsibilities:
- Provide dashboard metrics (counts by severity, by type)
- Query exceptions with filtering, sorting, pagination
- Support dashboard actions (acknowledge, resolve)
- Provide filter options for UI dropdowns
- Auto-escalate critical exceptions >2 hours

#### Key Methods:

**getDashboardMetrics() [@AuraEnabled cacheable=false]**
- Aggregate query: COUNT by Severity__c
- Aggregate query: COUNT by Exception_Type__c
- Returns: DashboardMetrics object
  - warningCount, alertCount, criticalCount
  - totalOpenExceptions
  - exceptionsByType (for bar chart)
  - lastUpdated timestamp

**getExceptions(pageNumber, sortField, sortOrder, filters) [@AuraEnabled]**
- Dynamic SOQL with WHERE clause builder
- Supports filtering: severity, type, load name, status
- Sorting: any Exception__c field
- Pagination: 50 per page
- Returns: ExceptionListResult
  - totalRecords, pageSize, currentPage, totalPages
  - List<ExceptionItem> with display properties

**acknowledgeException(exceptionId)**
- Updates Exception__c.Status__c = 'Acknowledged'
- Sets Acknowledged_DateTime__c = now()

**resolveException(exceptionId, reason)**
- Updates Exception__c.Status__c = 'Resolved'
- Sets Resolved_DateTime__c = now()
- Stores reason in Notes__c

**escalateCriticalExceptions(List<Exception__c>)**
- Called during getExceptions()
- Checks if Critical exception is >2 hours old
- If unacknowledged, flags for escalation
- Could trigger management alerts (Phase 2 UAT)

**getFilterOptions()**
- Returns SelectOption lists for UI dropdowns
- Severity: Warning, Alert, Critical
- Type: Dynamic list from Exception__c.Exception_Type__c
- Status: Open, Acknowledged, Resolved

#### Data Structure (Inner Classes):

```apex
class DashboardMetrics {
  Integer warningCount;
  Integer alertCount;
  Integer criticalCount;
  Integer totalOpenExceptions;
  List<ChartDataPoint> exceptionsByType; // For bar chart
  DateTime lastUpdated;
}

class ChartDataPoint {
  String label;   // Exception type
  Integer value;  // Count
}

class ExceptionListResult {
  Integer totalRecords;
  Integer pageSize;
  Integer currentPage;
  Integer totalPages;
  List<ExceptionItem> exceptions;
}

class ExceptionItem {
  String id;
  String loadName;
  String carrierName;
  String shipperName;
  String exceptionType;
  String severity;
  String description;
  DateTime triggeredDateTime;
  DateTime acknowledgedDateTime;
  DateTime resolvedDateTime;
  String status;
  Boolean isAcknowledged;
  Integer minutesSinceTriggered;
  String displayAge; // "45 min", "2 hrs", "1 day"
}
```

#### Query Strategy:
- Aggregate queries for metrics (no large result sets)
- SOQL with WHERE clause builder for filters
- Dynamic sort field (parameterized, not concatenated)
- LIMIT 50 for pagination
- OFFSET for page calculation

---

### 4. ExceptionTrigger (Apex Trigger)
**File:** `ExceptionTrigger.trigger`  
**Execution:** After insert on Exception__c

```apex
trigger ExceptionTrigger on Exception__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        ExceptionAlertDistribution.processAlerts(Trigger.new);
    }
}
```

**Purpose:**
- Wire exception creation to alert distribution
- Non-blocking: ProcessAlerts uses @Future methods
- No synchronous callouts (non-blocking pattern)

---

### 5. Custom Metadata: ExceptionRules__mdt
**Type:** Custom Metadata Type  
**Purpose:** Store all rule configurations

**Fields:**
- `Rule_Type__c` (Text) - LATE_ARRIVAL, MISSED_PICKUP, etc.
- `Threshold_Minutes__c` (Number) - Threshold value
- `Severity__c` (Picklist) - Warning, Alert, Critical
- `Description__c` (Text) - Human-readable description
- `IsActive__c` (Checkbox) - Enable/disable rule

**Records (Pre-loaded):**
- ExceptionRules.LATE_ARRIVAL_30MIN
- ExceptionRules.MISSED_PICKUP_IMMEDIATE
- ExceptionRules.LONG_IDLE_4HOURS
- ExceptionRules.EXCESSIVE_DELAY_1DAY
- ExceptionRules.DRIVER_OFFLINE_30MIN
- ExceptionRules.GEOFENCE_VIOLATION_5MILES
- ExceptionRules.EQUIPMENT_BREAKDOWN_CRITICAL

**Advantage:** Zero hardcoded thresholds, easily configurable

---

## Data Model

### Exception__c (Core Exception Object)

**Key Fields:**
```
Id              - Auto (exception ID)
Load__c         - Lookup to Load__c (required)
Exception_Type__c - LATE_ARRIVAL, MISSED_PICKUP, etc.
Severity__c     - Warning, Alert, Critical
Description__c  - Detailed description with metrics
Triggered_DateTime__c - When rule triggered
Status__c       - Open, Acknowledged, Resolved
Acknowledged_DateTime__c - When user acknowledged
Resolved_DateTime__c - When user resolved
Notes__c        - Resolution notes/comments
```

**Relationships:**
- Load__c → Load__c (parent)
- Can have related records: AlertLog__c, EscalationRecord__c (Phase 2 UAT)

### Load__c (Existing)

**Used Fields:**
- Status__c - IN_TRANSIT, AT_PICKUP, AT_DELIVERY, BROKEN_DOWN
- Pickup_Window_Start__c, Pickup_Window_End__c
- Delivery_Window_Start__c, Delivery_Window_End__c
- Broker_Rep__c - Lookup to Contact (alert recipient)
- Dispatcher__c - Lookup to Contact (alert recipient)
- Driver__c - Lookup to Contact (SMS recipient)
- Route_Geofence_Polygon__c - WGS84 polygon for geofence check
- Current_Location__Latitude/Longitude__s - Geolocation field

### Stop__c (Existing)

**Used Fields:**
- Load__c - Lookup to Load__c
- Type__c - PICKUP, DELIVERY
- Sequence__c - Order in load
- Arrival_DateTime__c - Actual arrival
- Departure_DateTime__c - Actual departure
- Planned_Start__c, Planned_End__c - Scheduled window
- ETA__c - Estimated arrival

### Tracking__c (Existing)

**Used Fields:**
- Load__c - Lookup to Load__c
- Latitude__c, Longitude__c - GPS coordinates
- Event_Type__c - gps, speed_alert, geofence, etc.
- Event_Timestamp__c - When event occurred
- Speed_mph__c, Heading_degrees__c - Vehicle telemetry

---

## Execution Flow

### Scenario: Late Arrival Detected

```
Timeline:
─────────────────────────────────────────

09:00 - Pickup window opens (Load-001)
         └─ Scheduled: 09:00 - 11:00

09:05 - Scheduled job detects no exceptions yet

11:15 - Driver arrives (15 min late)
         └─ Tracking event received via Motive webhook
         └─ Arrival_DateTime__c set to 11:15

11:20 - Scheduled job runs (every 5 min)
         ├─ Loads ExceptionRules from metadata
         │   └─ LATE_ARRIVAL: threshold = 30 min
         ├─ Queries Load-001 status = IN_TRANSIT
         ├─ Loads stops: Pickup stop with:
         │   └─ Planned_End__c = 11:00
         │   └─ Arrival_DateTime__c = 11:15
         ├─ Evaluates LATE_ARRIVAL rule:
         │   └─ 11:15 > 11:00 + 30 min? NO → No exception yet
         │       (15 min late, threshold is 30 min)
         └─ Done, job finishes

11:45 - Driver arrives 45 min late
         └─ Arrival still shows 11:15
         
11:50 - Scheduled job runs again
         ├─ Re-evaluates LATE_ARRIVAL:
         │   └─ 11:15 > 11:00 + 30 min? YES → Exception triggered!
         ├─ Creates Exception__c record:
         │   ├─ Load__c = Load-001
         │   ├─ Exception_Type__c = LATE_ARRIVAL
         │   ├─ Severity__c = Alert
         │   ├─ Description__c = "Late arrival (45 min delay)"
         │   ├─ Triggered_DateTime__c = 11:50
         │   └─ Status__c = Open
         ├─ Inserts exception → ExceptionTrigger fires
         │
         └─ ExceptionTrigger.ExceptionAlertDistribution.processAlerts()
             ├─ Load Load-001 details
             │   ├─ Broker_Rep__c → broker@company.com
             │   └─ Dispatcher__c → dispatcher@company.com
             │
             ├─ buildEmailAlert()
             │   └─ Send email to both recipients
             │
             └─ @Future sendEmailAlerts()
                 └─ Non-blocking, executes async

12:00 - User sees exception in dashboard
         ├─ getDashboardMetrics()
         │   └─ alertCount = 1
         └─ getExceptions(1, null, null, null, null, null, 'Open')
             └─ Returns exception item with:
                 ├─ loadName = Load-001
                 ├─ exceptionType = LATE_ARRIVAL
                 ├─ severity = Alert
                 ├─ description = Late arrival (45 min delay)
                 ├─ triggeredDateTime = 11:50
                 └─ minutesSinceTriggered = 10

12:30 - User clicks "Acknowledge"
         └─ acknowledgeException(exception.id)
             ├─ Status__c = Acknowledged
             └─ Acknowledged_DateTime__c = 12:30

13:00 - User clicks "Resolve" with reason
         └─ resolveException(exception.id, "Driver had mechanical issue")
             ├─ Status__c = Resolved
             ├─ Resolved_DateTime__c = 13:00
             └─ Notes__c = "Driver had mechanical issue"

13:05 - Exception no longer appears in Open list
         ├─ getExceptions() filters by Status__c = 'Open'
         └─ Exception excluded

─────────────────────────────────────────
```

---

## Scalability & Performance

### Batch Sizes
- **Active Loads:** Up to 100,000 loaded per detection job (LIMIT 100000)
- **Exceptions per Load:** Average 2-3 rules trigger per load
- **Expected Exceptions/Run:** ~300-500 per 5-minute cycle for 100k loads

### Query Performance
- **Detection Job Queries:** 4 bulk queries (loads, stops, tracking, dedup check)
- **Dashboard Queries:** 2 aggregate queries + 1 detail query per page load
- **Indexes Required:**
  ```
  Exception__c: (Load__c, Triggered_DateTime__c)
  Exception__c: (Status__c, Severity__c)
  Tracking__c: (Load__c, Event_Timestamp__c)
  Stop__c: (Load__c, Type__c)
  ```

### Governor Limits (per 5-minute job)
| Limit | Typical | Safe Threshold | Notes |
|-------|---------|-----------------|-------|
| Query Rows | 50k | 100k | Bulk data fetching |
| DML Statements | 100 | 200 | Bulk inserts, updates |
| CPU Time | 30s | 40s | Detection logic |
| Callouts | 0 | 100 | Alert distribution async |
| Heap | 100 MB | 200 MB | Maps, lists, objects |

---

## Testing Strategy

### Unit Tests (>80% Coverage)

**ExceptionDetectionEngineTest.cls** (12 tests)
- Test all 8 rule types
- Test deduplication
- Test no false positives
- Test null handling
- Test bulk processing (100+ loads)

**ExceptionAlertDistributionTest.cls** (10 tests)
- Test email routing
- Test Slack routing (critical only)
- Test SMS routing (phone opt-in)
- Test alert formatting
- Test bulk processing

**ExceptionDashboardControllerTest.cls** (12 tests)
- Test metrics aggregation
- Test filtering & sorting
- Test pagination
- Test acknowledge/resolve
- Test escalation logic
- Test empty dashboard

**Total: 34 test cases, Target: >85% code coverage**

---

## Deployment Checklist

### Pre-Deployment
- [ ] Custom metadata records loaded (7 exception rules)
- [ ] Custom fields added to Exception__c
- [ ] Trigger enabled (ExceptionTrigger)
- [ ] Test coverage >85%
- [ ] All 34 tests passing

### Deployment Steps
1. Deploy all Apex classes
2. Deploy custom metadata
3. Deploy trigger
4. Enable scheduled job (every 5 minutes)
5. Test with 100+ sample loads
6. Monitor logs for 24 hours

### Post-Deployment
- [ ] Verify scheduled job executes every 5 min
- [ ] Check exception creation (query Exception__c)
- [ ] Verify alert emails sent (Apex email log)
- [ ] Test dashboard queries respond <5 sec
- [ ] Monitor CPU/query usage

---

## Future Enhancements (Phase 3)

- [ ] Carrier-specific thresholds
- [ ] Custom rule UI (no-code rule creation)
- [ ] Webhook for external system alerts
- [ ] Machine learning: anomaly detection
- [ ] Advanced escalation (auto-call driver)
- [ ] Exception trending & analytics

---

## Related Documents

- **AGENT3_PHASE2_EXCEPTION_RULES.md** - Rule details & thresholds
- **AGENT3_PHASE2_DASHBOARD_SPEC.md** - UI/UX design
- **AGENT3_PHASE2_USER_PREFERENCES.md** - User alert config

---

**Document Owner:** Agent 3  
**Last Updated:** 2026-04-02  
**Status:** Complete, ready for sandbox testing

---

**END OF DOCUMENT**
