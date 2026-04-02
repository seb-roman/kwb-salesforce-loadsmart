# AGENT3 Phase 2: User Alert Preferences & Configuration

**Document Version:** 1.0  
**Created:** 2026-04-02  
**Status:** COMPLETE - Ready for Settings Implementation  
**Flexibility:** ✅ Per-user, per-channel, per-severity configuration

---

## Overview

Users can customize how they receive exception alerts based on:
- **Severity level** (Warning, Alert, Critical)
- **Delivery channel** (Email, Slack, SMS)
- **Load context** (all loads, specific carriers, specific shippers)
- **Time preferences** (quiet hours, do not disturb)

---

## User Preference Model

All preferences stored in custom setting `ExceptionAlertPreference__c` (list type).

### Fields

**Core Preferences:**

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| User__c | Lookup | Current User | User these prefs apply to |
| Email_Enabled__c | Checkbox | true | Receive emails |
| Slack_Enabled__c | Checkbox | false | Receive Slack messages |
| SMS_Enabled__c | Checkbox | false | Receive SMS (phone opt-in) |
| Phone_Number__c | Phone | null | Phone for SMS alerts |

**Severity Routing:**

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| Email_Warning__c | Checkbox | true | Email for Warning severity |
| Email_Alert__c | Checkbox | true | Email for Alert severity |
| Email_Critical__c | Checkbox | true | Email for Critical severity |
| Slack_Warning__c | Checkbox | false | Slack for Warning severity |
| Slack_Alert__c | Checkbox | false | Slack for Alert severity |
| Slack_Critical__c | Checkbox | true | Slack for Critical severity |
| SMS_Warning__c | Checkbox | false | SMS for Warning severity |
| SMS_Alert__c | Checkbox | false | SMS for Alert severity |
| SMS_Critical__c | Checkbox | true | SMS for Critical severity |

**Quiet Hours:**

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| Quiet_Hours_Enabled__c | Checkbox | false | Enable quiet hours |
| Quiet_Start__c | Time | 22:00 | Quiet hours start time |
| Quiet_End__c | Time | 08:00 | Quiet hours end time |
| Quiet_Suppress_Warning__c | Checkbox | true | Suppress Warning during quiet |
| Quiet_Suppress_Alert__c | Checkbox | false | Suppress Alert during quiet |
| Quiet_Suppress_Critical__c | Checkbox | false | Still alert Critical |

**Filter Preferences:**

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| Alert_All_Carriers__c | Checkbox | true | Alert for all carriers |
| Alert_Specific_Carriers__c | Text (comma-sep) | null | Or specific carriers only |
| Alert_All_Shippers__c | Checkbox | true | Alert for all shippers |
| Alert_Specific_Shippers__c | Text (comma-sep) | null | Or specific shippers only |

---

## Default Alert Routing

### By Severity

**Warning**
- ✅ Email: Yes (to user)
- ❌ Slack: No
- ❌ SMS: No
- **Reason:** Low priority, email sufficient

**Alert**
- ✅ Email: Yes
- ❌ Slack: No (unless configured)
- ❌ SMS: No
- **Reason:** Medium priority, email for documentation

**Critical**
- ✅ Email: Yes
- ✅ Slack: Yes (ops channel)
- ✅ SMS: Yes (if phone provided)
- **Reason:** High priority, multi-channel urgent

### By Role

**Load Manager / Dispatcher**
- ✅ All severities
- ✅ Email + Slack + SMS
- ✅ All loads (all carriers/shippers)
- ✅ No quiet hours

**Broker / Sales Rep**
- ✅ Alert + Critical only (not Warning)
- ✅ Email only (no SMS)
- ✅ Specific shipper loads only
- ✅ Quiet hours: 22:00 - 08:00 EST

**Shipper Account Manager**
- ✅ Critical only
- ✅ Email only
- ✅ Their company's loads only
- ✅ Quiet hours: 18:00 - 09:00 EST

**Driver / Field Ops**
- ✅ Critical only
- ✅ SMS only (immediate notification)
- ✅ Their own vehicle loads only
- ❌ No quiet hours (on-road)

---

## Configuration UI

### User Settings Page

**Location:** `Setup → User Preferences → Exception Alerts`  
(Or Lightning App: `Settings → Notifications → Exception Alerts`)

#### Tab 1: Notification Channels

```
┌─────────────────────────────────────────────────┐
│ Exception Alert Channels                        │
├─────────────────────────────────────────────────┤
│                                                 │
│ ☑ Email Notifications                          │
│   Recipient: [john.doe@company.com]             │
│   Can edit in Salesforce user settings          │
│                                                 │
│ ☐ Slack Notifications                          │
│   Workspace: [Select... ▼]                      │
│   Channel: [@john-doe ▼] (Direct message)      │
│   [ Connect to Slack ]                          │
│                                                 │
│ ☐ SMS Notifications                            │
│   Phone Number: [+1-555-_______]               │
│   Carrier: [Verizon ▼]                         │
│   ☑ I confirm receipt of SMS is allowed        │
│   [ Verify with SMS Code ]                      │
│                                                 │
│ [Save]                                          │
└─────────────────────────────────────────────────┘
```

#### Tab 2: Alert Routing by Severity

```
┌─────────────────────────────────────────────────┐
│ Alert Routing by Severity                       │
├─────────────────────────────────────────────────┤
│                                                 │
│ WARNING SEVERITY                                │
│ ☑ Email  ☐ Slack  ☐ SMS                        │
│                                                 │
│ ALERT SEVERITY                                  │
│ ☑ Email  ☐ Slack  ☐ SMS                        │
│                                                 │
│ CRITICAL SEVERITY                               │
│ ☑ Email  ☑ Slack  ☑ SMS (requires SMS setup)   │
│                                                 │
│ [Save]                                          │
└─────────────────────────────────────────────────┘
```

#### Tab 3: Quiet Hours

```
┌─────────────────────────────────────────────────┐
│ Quiet Hours                                     │
├─────────────────────────────────────────────────┤
│                                                 │
│ ☐ Enable Quiet Hours                           │
│                                                 │
│   When enabled, reduce alert frequency during  │
│   the specified time period.                    │
│                                                 │
│   Start Time: [22:00 ▼]  (24-hour format)      │
│   End Time:   [08:00 ▼]                        │
│   Timezone:   [America/New_York ▼]             │
│                                                 │
│   During Quiet Hours, suppress:                │
│   ☑ Warning alerts                             │
│   ☐ Alert severity alerts                      │
│   ☐ Critical alerts (always deliver)           │
│                                                 │
│   Note: Critical alerts always sent,            │
│         even during quiet hours                │
│                                                 │
│ [Save]                                          │
└─────────────────────────────────────────────────┘
```

#### Tab 4: Load Filters

```
┌─────────────────────────────────────────────────┐
│ Alert Filters                                   │
├─────────────────────────────────────────────────┤
│                                                 │
│ Receive alerts for:                             │
│                                                 │
│ ☑ All Carriers                                 │
│ ☐ Specific Carriers Only                       │
│   [Search and select carriers...]              │
│   ☑ Schneider National                         │
│   ☑ Marten Transport                           │
│                                                 │
│ ☑ All Shippers                                 │
│ ☐ Specific Shippers Only                       │
│   [Search and select shippers...]              │
│   ☑ Walmart                                    │
│   ☑ Amazon Logistics                           │
│                                                 │
│ [Save]                                          │
└─────────────────────────────────────────────────┘
```

---

## API: Reading User Preferences

**Apex Example:**

```apex
// Get current user's exception alert preferences
ExceptionAlertPreference__c prefs = ExceptionAlertPreference__c.getInstance(UserInfo.getUserId());

if (prefs != null) {
    Boolean emailEnabled = prefs.Email_Enabled__c;
    Boolean slackEnabled = prefs.Slack_Enabled__c;
    Boolean smsEnabled = prefs.SMS_Enabled__c;
    
    // Check severity routing
    if (prefs.Email_Alert__c) {
        // Send email for Alert severity
    }
    
    // Check quiet hours
    if (prefs.Quiet_Hours_Enabled__c) {
        Time quietStart = prefs.Quiet_Start__c;
        Time quietEnd = prefs.Quiet_End__c;
        // Apply quiet hours logic
    }
}
```

---

## Alert Distribution Logic (Updated)

### Simplified Routing:

```
On Exception Created:
├─ Load exception data
├─ Load user's ExceptionAlertPreference__c
│
├─ Check Severity (e.g., "Alert")
│  └─ User wants Email_Alert__c? → Send email
│  └─ User wants Slack_Alert__c? → Send Slack
│  └─ User wants SMS_Alert__c? → Send SMS
│
├─ Check Quiet Hours (if enabled)
│  └─ Current time in quiet window?
│     ├─ If Quiet_Suppress_Alert__c = true → Skip
│     ├─ Else → Send
│
├─ Check Load Filters
│  └─ Is load's Carrier in user's alerts?
│  └─ Is load's Shipper in user's alerts?
│     ├─ If no match → Skip
│     ├─ Else → Send
│
└─ Send via selected channels

---

## Configuration Examples

### Example 1: Dispatcher (On-Call)

```
Role: Load Manager/Dispatcher
Timezone: America/Chicago

Settings:
─────────
Email:   ✅ Enabled (all severities)
Slack:   ✅ Enabled (Alert + Critical)
SMS:     ✅ Enabled (Critical only)
Phone:   +1-555-0100

Quiet Hours: ❌ Disabled

Severity Routing:
├─ Warning:  Email only
├─ Alert:    Email + Slack
└─ Critical: Email + Slack + SMS

Load Filters:
├─ All Carriers: ✅
└─ All Shippers: ✅

Result:
─────────
Gets immediate alerts via all 3 channels
No quiet hours (always on-call)
Receives all severity levels
Covers all loads
```

### Example 2: Broker (Business Hours Only)

```
Role: Broker Representative
Timezone: America/New_York

Settings:
─────────
Email:   ✅ Enabled
Slack:   ❌ Disabled
SMS:     ❌ Disabled

Quiet Hours: ✅ Enabled
Start: 18:00 (6 PM)
End: 09:00 (9 AM)
Suppress Warning: ✅
Suppress Alert: ❌
Suppress Critical: ❌

Severity Routing:
├─ Warning:  Email only (suppressed after 6 PM)
├─ Alert:    Email (always)
└─ Critical: Email (always)

Load Filters:
├─ All Carriers: ❌
├─ Specific:
│  ├─ ABC Freight Inc
│  └─ XYZ Logistics
└─ All Shippers: ✅

Result:
─────────
Email only, no SMS/Slack
No alerts after 6 PM except Critical
Covers only 2 preferred carriers
No shipper restrictions
Business hours focused
```

### Example 3: Shipper (Critical Only)

```
Role: Shipper Account Manager
Timezone: America/Los_Angeles

Settings:
─────────
Email:   ✅ Enabled
Slack:   ❌ Disabled
SMS:     ❌ Disabled

Quiet Hours: ✅ Enabled
Start: 20:00 (8 PM)
End: 07:00 (7 AM)
Suppress Warning: ✅
Suppress Alert: ✅
Suppress Critical: ❌

Severity Routing:
├─ Warning:  Email (suppressed 8 PM - 7 AM)
├─ Alert:    Email (suppressed 8 PM - 7 AM)
└─ Critical: Email (always)

Load Filters:
├─ All Carriers: ✅
└─ Specific Shippers:
   └─ Acme Corp (their company)

Result:
─────────
Email only, for own company's loads
Quiet hours suppress non-critical alerts
Critical alerts always delivered
Focused on high-severity issues only
```

---

## Implementation in Alert Distribution

**Updated `ExceptionAlertDistribution.processAlerts()`:**

```apex
public static void processAlerts(List<Exception__c> exceptions) {
    // Load preferences for all affected users
    Map<Id, ExceptionAlertPreference__c> userPrefs = new Map<Id, ExceptionAlertPreference__c>();
    
    // Get all broker/dispatcher/shipper contacts for loads in exceptions
    Set<Id> userIds = getRelevantUserIds(exceptions);
    
    for (Id userId : userIds) {
        ExceptionAlertPreference__c prefs = 
            ExceptionAlertPreference__c.getInstance(userId);
        if (prefs != null) {
            userPrefs.put(userId, prefs);
        }
    }
    
    // Process each exception
    List<AlertMessage> emailAlerts = new List<AlertMessage>();
    List<AlertMessage> slackAlerts = new List<AlertMessage>();
    List<AlertMessage> smsAlerts = new List<AlertMessage>();
    
    for (Exception__c exception : exceptions) {
        // Get user preferences
        ExceptionAlertPreference__c prefs = getUserPreferences(exception);
        
        // Check quiet hours
        if (isInQuietHours(prefs)) {
            if (shouldSuppressSeverity(exception.Severity__c, prefs)) {
                continue; // Skip this alert
            }
        }
        
        // Check load filters
        if (!matchesLoadFilters(exception.Load__c, prefs)) {
            continue; // Skip this alert
        }
        
        // Route to channels based on severity + user preference
        if (prefs.Email_Enabled__c && shouldRouteToEmail(exception.Severity__c, prefs)) {
            emailAlerts.add(buildEmailAlert(exception, load));
        }
        
        if (prefs.Slack_Enabled__c && shouldRouteToSlack(exception.Severity__c, prefs)) {
            slackAlerts.add(buildSlackAlert(exception, load));
        }
        
        if (prefs.SMS_Enabled__c && shouldRouteToSMS(exception.Severity__c, prefs)) {
            smsAlerts.add(buildSMSAlert(exception, load));
        }
    }
    
    // Send via @Future methods (non-blocking)
    if (!emailAlerts.isEmpty()) sendEmailAlerts(emailAlerts);
    if (!slackAlerts.isEmpty()) sendSlackAlerts(slackAlerts);
    if (!smsAlerts.isEmpty()) sendSMSAlerts(smsAlerts);
}
```

---

## Audit & Compliance

**Preferences Tracking:**
- ✅ Created date/time
- ✅ Last modified date/time
- ✅ Modified by (user)
- ✅ Change history in Setup Audit Trail

**Opt-Out Handling:**
- SMS: User must confirm phone + opt-in
- Email: Standard user email (system maintained)
- Slack: Manual workspace connection
- All channels: User can toggle on/off anytime

**Data Privacy:**
- Preferences stored in user's org (not external)
- Phone numbers encrypted at rest
- No personal data in logs (only user IDs)
- GDPR: User can export/delete preferences

---

## FAQ

**Q: Can I disable all alerts?**  
A: Yes, but not recommended for critical systems. You can disable individual channels.

**Q: What happens during quiet hours?**  
A: Critical alerts still delivered. Warning/Alert suppressed based on settings.

**Q: Can I get alerts for specific loads only?**  
A: Currently filters by carrier/shipper. Load-level filters possible in Phase 3.

**Q: Do quiet hours apply to SMS?**  
A: Yes. If SMS enabled and Critical suppressed (unlikely), SMS blocked during quiet hours.

**Q: Can I forward alerts to someone else?**  
A: Not directly. That person must have their own user account + preferences.

**Q: How do I test my alert preferences?**  
A: Create a test exception for a specific load. Check if alert arrives as expected.

**Q: Are preferences backed up?**  
A: Yes, part of standard org backup. Included in data exports.

---

## Related Documents

- **AGENT3_PHASE2_EXCEPTION_RULES.md** - What triggers alerts
- **AGENT3_PHASE2_ARCHITECTURE.md** - How alerts are sent
- **AGENT3_PHASE2_DASHBOARD_SPEC.md** - Where users see exceptions

---

**Document Owner:** Agent 3  
**Last Updated:** 2026-04-02  
**Status:** Complete, ready for custom settings setup

---

**END OF DOCUMENT**
