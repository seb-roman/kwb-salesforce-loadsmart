# AGENT3 Phase 2: Exception Rules & Thresholds

**Document Version:** 1.0  
**Created:** 2026-04-02  
**Status:** COMPLETE - Ready for Configuration  
**Flexibility:** ✅ All rules stored in custom metadata (ExceptionRules__mdt)

---

## Overview

Phase 2 Exception Engine implements 8 exception rule types with **flexible, configurable thresholds**. All rules are stored in custom metadata (ExceptionRules__mdt), allowing configuration changes without code deployment.

## Rule Types & Thresholds

### 1. LATE_ARRIVAL
**Rule ID:** `LATE_ARRIVAL`  
**Description:** Driver arrives more than threshold minutes after scheduled pickup window end

**Configuration:**
```
Rule_Type__c = 'LATE_ARRIVAL'
Threshold_Minutes__c = 30
Severity__c = 'Alert'
IsActive__c = true
```

**Logic:**
```
IF (arrival_time > pickup_window_end + threshold_minutes)
THEN trigger exception
```

**Example Scenarios:**
- Pickup window: 08:00 - 10:00
- Threshold: 30 minutes
- Actual arrival: 10:45
- Result: ✅ EXCEPTION (45 min late, threshold 30 min)

**Field Dependencies:**
- Load.Pickup_Window_End__c
- Stop.Arrival_DateTime__c

**Severity:** Alert (configurable)  
**Deduplication:** 1 per load per 1 hour

---

### 2. MISSED_PICKUP
**Rule ID:** `MISSED_PICKUP`  
**Description:** No arrival recorded by the end of pickup window

**Configuration:**
```
Rule_Type__c = 'MISSED_PICKUP'
Threshold_Minutes__c = 0
Severity__c = 'Alert'
IsActive__c = true
```

**Logic:**
```
IF (now > pickup_window_end AND arrival_datetime IS NULL)
THEN trigger exception
```

**Example Scenarios:**
- Pickup window: 08:00 - 10:00
- Current time: 11:00
- Arrival: NOT recorded
- Result: ✅ EXCEPTION (1 hour overdue)

**Field Dependencies:**
- Stop.Planned_End__c
- Stop.Arrival_DateTime__c

**Severity:** Alert  
**Deduplication:** 1 per load per 1 hour

---

### 3. LONG_IDLE
**Rule ID:** `LONG_IDLE`  
**Description:** Stop duration (arrival to departure) exceeds threshold minutes

**Configuration:**
```
Rule_Type__c = 'LONG_IDLE'
Threshold_Minutes__c = 240
Severity__c = 'Warning'
IsActive__c = true
```

**Threshold:** 240 minutes = 4 hours  
**Use Case:** Detect excessive dwell time at stops (loading, unloading issues)

**Logic:**
```
IF (departure_datetime - arrival_datetime > threshold_minutes)
THEN trigger exception
```

**Example Scenarios:**
- Stop: Warehouse A
- Arrival: 10:00
- Departure: 14:30 (4.5 hours)
- Threshold: 240 min (4 hours)
- Result: ✅ EXCEPTION (30 min over threshold)

**Field Dependencies:**
- Stop.Arrival_DateTime__c
- Stop.Departure_DateTime__c

**Severity:** Warning → Alert (configurable)  
**Deduplication:** 1 per load per 1 hour

---

### 4. EXCESSIVE_DELAY
**Rule ID:** `EXCESSIVE_DELAY`  
**Description:** Estimated delivery time is more than threshold days later than planned

**Configuration:**
```
Rule_Type__c = 'EXCESSIVE_DELAY'
Threshold_Minutes__c = 1440
Severity__c = 'Alert'
IsActive__c = true
```

**Threshold:** 1440 minutes = 1 day

**Logic:**
```
IF (delivery_eta - delivery_window_end > threshold_minutes)
THEN trigger exception
```

**Example Scenarios:**
- Planned delivery: 2026-04-05
- Current ETA: 2026-04-07 (2 days late)
- Threshold: 1440 min (1 day)
- Result: ✅ EXCEPTION (exceeds 1-day threshold)

**Field Dependencies:**
- Stop.Planned_End__c (delivery window)
- Stop.ETA__c (estimated arrival)

**Severity:** Alert → Critical (for very late deliveries)  
**Deduplication:** 1 per load per 1 hour

---

### 5. DRIVER_OFFLINE
**Rule ID:** `DRIVER_OFFLINE`  
**Description:** No GPS event received for threshold minutes

**Configuration:**
```
Rule_Type__c = 'DRIVER_OFFLINE'
Threshold_Minutes__c = 30
Severity__c = 'Warning'
IsActive__c = true
```

**Threshold:** 30 minutes

**Logic:**
```
IF (now - last_gps_event_timestamp > threshold_minutes)
THEN trigger exception
```

**Example Scenarios:**
- Last GPS event: 10:00 (from Motive webhook)
- Current time: 10:45 (no events for 45 min)
- Threshold: 30 min
- Result: ✅ EXCEPTION (offline for 45 min > 30 min)

**Field Dependencies:**
- Tracking__c.Event_Timestamp__c (latest record)
- Tracking__c.Event_Type__c = 'gps'

**Severity:** Warning → Alert (if critical route)  
**Deduplication:** 1 per load per 1 hour

**Use Cases:**
- Detect device offline (lost signal, battery dead, device off)
- Trigger support call to driver
- In production: escalate to field ops if >60 min offline

---

### 6. GEOFENCE_VIOLATION
**Rule ID:** `GEOFENCE_VIOLATION`  
**Description:** Vehicle GPS location is outside planned delivery route (±threshold miles)

**Configuration:**
```
Rule_Type__c = 'GEOFENCE_VIOLATION'
Threshold_Minutes__c = 5
Severity__c = 'Alert'
IsActive__c = true
```

**Threshold:** 5 miles (repurposed Threshold_Minutes__c field)

**Logic:**
```
IF (distance(gps_location, planned_route) > threshold_miles)
THEN trigger exception
```

**Example Scenarios:**
- Planned route: NYC delivery area
- Route boundary: WGS84 polygon in Load.Route_Geofence_Polygon__c
- Current GPS: 10 miles outside polygon
- Threshold: 5 miles
- Result: ✅ EXCEPTION (10 miles > 5 mile buffer)

**Field Dependencies:**
- Load.Route_Geofence_Polygon__c (WGS84 polygon)
- Tracking__c.Latitude__c, Longitude__c (latest GPS)

**Calculation Method:**
- **Current:** Simplified (placeholder for production)
- **Production:** Implement haversine distance or polygon point-in-polygon test

**Severity:** Alert  
**Deduplication:** 1 per load per 1 hour

**Use Cases:**
- Detect route deviations
- Prevent unplanned stops
- Identify theft/unauthorized diversions

---

### 7. EQUIPMENT_BREAKDOWN
**Rule ID:** `EQUIPMENT_BREAKDOWN`  
**Description:** Load status indicates equipment failure

**Configuration:**
```
Rule_Type__c = 'EQUIPMENT_BREAKDOWN'
Threshold_Minutes__c = 0
Severity__c = 'Critical'
IsActive__c = true
```

**Logic:**
```
IF (load_status = 'BROKEN_DOWN')
THEN trigger exception WITH Severity = Critical
```

**Example Scenarios:**
- Load status: BROKEN_DOWN (manual entry or webhook from dispatch)
- Result: ✅ EXCEPTION (Critical severity → immediate alert)

**Field Dependencies:**
- Load__c.Status__c = 'BROKEN_DOWN'

**Severity:** CRITICAL (always) → triggers immediate alerts  
**Deduplication:** 1 per load per 1 hour

**Escalation:**
- Email: Broker + Dispatcher (immediate)
- Slack: #operations (immediate)
- SMS: Dispatcher (if opted in)
- Auto-escalate if unacknowledged >2 hours

**Use Cases:**
- Vehicle mechanical failure
- Trailer issues
- Immediate intervention needed

---

### 8. CUSTOM_RULES
**Rule ID:** `CUSTOM_[user-defined]`  
**Description:** User-defined exception rules for future UAT

**Status:** Framework in place, awaiting Phase 2 UAT feedback

**Example Custom Rules (Not Yet Implemented):**
```
SPEED_VIOLATION: Current speed > speed_limit
TEMPERATURE_BREACH: Cargo temp > max threshold
UNSCHEDULED_STOP: Stop at unplanned location
LATE_DEPARTURE: Left stop > 30 min after planned
POOR_GPS_SIGNAL: GPS accuracy < 100 meters
DRIVER_FATIGUE: Operating >10 hours without break
```

**How to Add Custom Rules:**
1. Define rule in custom metadata: ExceptionRules__mdt
   - Rule_Type__c = 'CUSTOM_YOUR_RULE_NAME'
   - Threshold_Minutes__c = your_threshold
   - Severity__c = Warning/Alert/Critical
   - IsActive__c = true
   
2. Add detection logic to ExceptionDetectionEngine.checkRule() switch statement
3. Add test case in ExceptionDetectionEngineTest.cls
4. Document in this file under "Custom Rules" section

---

## Configuration in Salesforce

### Metadata Records (ExceptionRules__mdt)

All rules are stored as custom metadata records. To modify thresholds:

1. **Navigate to Setup → Custom Code → Custom Metadata Types → ExceptionRules**

2. **Standard Rules (Pre-loaded):**
   - ExceptionRules.LATE_ARRIVAL_30MIN
   - ExceptionRules.MISSED_PICKUP_IMMEDIATE
   - ExceptionRules.LONG_IDLE_4HOURS
   - ExceptionRules.EXCESSIVE_DELAY_1DAY
   - ExceptionRules.DRIVER_OFFLINE_30MIN
   - ExceptionRules.GEOFENCE_VIOLATION_5MILES
   - ExceptionRules.EQUIPMENT_BREAKDOWN_CRITICAL

3. **To Enable/Disable Rule:**
   - Edit metadata record
   - Toggle IsActive__c (true/false)
   - Deploy to org

4. **To Change Threshold:**
   - Edit metadata record
   - Update Threshold_Minutes__c
   - Example: Change LATE_ARRIVAL from 30 to 45 minutes
   - Deploy to org

5. **To Change Severity:**
   - Edit metadata record
   - Update Severity__c (Warning/Alert/Critical)
   - Affects alert routing immediately

### No Code Changes Required

✅ All thresholds configurable without code changes  
✅ Rules can be enabled/disabled via metadata toggle  
✅ New rules can be added in metadata (logic updates needed)  
✅ Severity levels adjustable per organization needs

---

## Rule Evaluation Order

ExceptionDetectionEngine evaluates rules in this order (all rules run, not short-circuit):

1. LATE_ARRIVAL (pickup timeliness)
2. MISSED_PICKUP (critical delivery issue)
3. LONG_IDLE (logistics efficiency)
4. EXCESSIVE_DELAY (delivery impact)
5. DRIVER_OFFLINE (device/communication)
6. GEOFENCE_VIOLATION (route compliance)
7. EQUIPMENT_BREAKDOWN (vehicle status)
8. CUSTOM_RULES (as defined)

---

## Deduplication Window

**Duration:** 1 hour (60 minutes)

**Rule:** Once an exception is created for a load+rule_type combination, no duplicate exceptions are created for 60 minutes.

**Purpose:** Prevent alert spam while exception remains active

**Example:**
- 10:00: LATE_ARRIVAL exception created for LOAD-001
- 10:15: Driver still late → NO exception (deduplicated)
- 10:45: Driver still late → NO exception (within 1-hour window)
- 11:05: Driver still late → NEW exception (window expired)

**Query:**
```sql
SELECT COUNT() FROM Exception__c
WHERE Load__c = :load_id
AND Exception_Type__c = :rule_type
AND Triggered_DateTime__c > :now.addMinutes(-60)
AND Status__c = 'Open'
```

---

## Performance Considerations

### Detection Engine
- **Frequency:** Every 5 minutes (scheduled job)
- **Batch Size:** 200 loads per execution
- **Expected Throughput:** 1000+ active loads processed every 5 min
- **Query Strategy:** Bulk queries with maps, no N+1 patterns

### Alert Distribution
- **Deduplication Check:** 1 query per exception
- **Async Processing:** Alerts sent via @Future methods (non-blocking)
- **Rate Limiting:** Respect API limits for Slack/SMS callouts

### Database Indexes
Create these indexes for performance:
```
Exception__c.Load__c + Exception__c.Triggered_DateTime__c
Exception__c.Status__c + Exception__c.Severity__c
Tracking__c.Load__c + Tracking__c.Event_Timestamp__c
Stop__c.Load__c + Stop__c.Type__c
```

---

## FAQ

**Q: How do I change LATE_ARRIVAL threshold from 30 to 45 minutes?**  
A: Edit ExceptionRules.LATE_ARRIVAL_30MIN custom metadata record, change Threshold_Minutes__c to 45, deploy.

**Q: Can I disable specific rules without code changes?**  
A: Yes! Edit the metadata record and set IsActive__c = false.

**Q: What if a rule keeps firing (e.g., driver stays late)?**  
A: Deduplication prevents alerts within 1 hour. After 1 hour, a new exception is created if condition still exists.

**Q: How do I add a new rule type?**  
A: 
1. Create ExceptionRules__mdt record with your rule config
2. Add switch case in ExceptionDetectionEngine.checkRule()
3. Implement detection logic
4. Add test cases
5. Deploy

**Q: Are thresholds stored in code or config?**  
A: All in custom metadata (ExceptionRules__mdt). Zero hardcoded thresholds.

**Q: What's the performance impact of adding 100 new rules?**  
A: Each rule adds one comparison per load. For 1000 loads, 100 rules = ~100k comparisons per 5-min cycle. Acceptable.

**Q: How do rule thresholds vary by carrier or shipper?**  
A: Currently single global thresholds. Phase 2 UAT feedback may request carrier-specific rules.

---

## Glossary

| Term | Definition |
|------|-----------|
| **Threshold** | Numeric value that triggers exception (minutes or miles) |
| **Rule Type** | Category of exception (LATE_ARRIVAL, MISSED_PICKUP, etc.) |
| **Severity** | Alert priority level (Warning, Alert, Critical) |
| **Deduplication** | Prevention of duplicate exceptions within 1-hour window |
| **Triggered** | When rule condition became true |
| **Acknowledged** | When user marks exception as reviewed |
| **Resolved** | When exception is closed with resolution notes |
| **Geofence** | WGS84 polygon defining valid delivery area |
| **Window** | Scheduled start/end time for pickup or delivery |
| **ETA** | Estimated time of arrival (future prediction) |

---

## Change Log

| Date | Change | Impact |
|------|--------|--------|
| 2026-04-02 | Initial Phase 2 rules defined | 8 rule types, all thresholds in metadata |
| TBD | UAT feedback integration | Custom rules framework ready |
| TBD | Carrier-specific thresholds | Multi-tenant configuration |

---

## Related Documents

- **AGENT3_PHASE2_ARCHITECTURE.md** - How detection engine works
- **AGENT3_PHASE2_DASHBOARD_SPEC.md** - Dashboard design & queries
- **AGENT3_PHASE2_USER_PREFERENCES.md** - Alert configuration per user

---

**Document Owner:** Agent 3  
**Last Updated:** 2026-04-02  
**Next Review:** After Phase 2 UAT (target: 1 week)

---

**END OF DOCUMENT**
