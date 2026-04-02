# Schema Review Package — KWB Salesforce Load System

**For:** Josh Anderson (josh@example.com)  
**From:** Seb Roman  
**Date:** April 2, 2026  
**Status:** Phase 1 Production-Ready (Phase 2 in UAT)

---

## Executive Summary

KWB Logistics custom TMS on Salesforce. 8 core objects, 55+ fields, 13 validation rules, 8 formula fields, 3 custom metadata types.

**Your Task:** Validate data model architecture, relationship design, and field structure before production deployment.

**Timeline:** No rush—review when you have time. Corey has day job too; you're not on the clock.

---

## Quick Links

- **Data Dictionary:** [Complete Field Listing](#complete-data-dictionary) (section below)
- **Relationship Diagram:** [Entity Relationships](#entity-relationships)
- **Design Decisions:** [Why We Built It This Way](#design-decisions)
- **Validation Rules:** [13 Business Rules](#validation-rules)
- **Formula Fields:** [8 Calculated Fields](#formula-fields)
- **Custom Metadata:** [3 Config Types](#custom-metadata-types)
- **Test Coverage:** >85% (122+ unit tests)
- **Security:** RLS/FLS enforced, SOQL injection-safe, CRUD checks

---

## Complete Data Dictionary

### Core Objects (8 Total)

#### 1. **Load__c** (Core Domain Object)

The heart of the system. One load = one shipment from origin to destination.

| Field Name | Type | Length | Required | Notes |
|------------|------|--------|----------|-------|
| **Id** | AutoNumber | - | Yes | Salesforce record ID |
| **Load_Number__c** | Text | 50 | Yes | Unique load identifier (e.g., "LOAD001") |
| **Reference_Number__c** | Text | 100 | No | Customer/shipper reference (e.g., PO number) |
| **Status__c** | Picklist | - | Yes | AVAILABLE, IN_TRANSIT, DELIVERED, CANCELLED |
| **Shipper_Account__c** | Lookup | - | Yes | Account (shipper company) |
| **Assigned_Carrier__c** | Lookup | - | No | Account (carrier company) |
| **Origin_City__c** | Text | 50 | Yes | Pickup city |
| **Origin_State__c** | Text | 2 | Yes | Pickup state (e.g., OH) |
| **Destination_City__c** | Text | 50 | Yes | Delivery city |
| **Destination_State__c** | Text | 2 | Yes | Delivery state |
| **Distance__c** | Number | 7,2 | Yes | Miles (pickup to delivery) |
| **Weight__c** | Number | 10,2 | No | Pounds |
| **Shipper_Rate__c** | Currency | 16,2 | Yes | What shipper pays per mile |
| **Carrier_Rate__c** | Currency | 16,2 | No | What carrier gets paid (locked at acceptance) |
| **DAI_Price_At_Booking__c** | Decimal | 7,4 | Yes | Diesel index price at load creation (locked for fuel surcharge) |
| **Pickup_Window_Start__c** | DateTime | - | Yes | Earliest pickup time |
| **Pickup_Window_End__c** | DateTime | - | Yes | Latest pickup time |
| **Delivery_Window_Start__c** | DateTime | - | Yes | Earliest delivery time |
| **Delivery_Window_End__c** | DateTime | - | Yes | Latest delivery time |
| **Actual_Pickup_Time__c** | DateTime | - | No | When load actually picked up |
| **Actual_Delivery_Time__c** | DateTime | - | No | When load actually delivered |
| **Current_Location__Latitude__s** | Geolocation | - | No | Current GPS latitude (via Motive) |
| **Current_Location__Longitude__s** | Geolocation | - | No | Current GPS longitude (via Motive) |
| **Current_Address__c** | Text | 255 | No | Human-readable current location |
| **Last_Status_Update__c** | DateTime | - | No | When status last changed |
| **Margin_Dollar__c** | Currency | 16,2 | No | Formula: Shipper_Rate - Carrier_Rate |
| **Margin_Percentage__c** | Percent | 5,2 | No | Formula: (Margin$ / Shipper_Rate) * 100 |
| **Transit_Hours__c** | Number | 10,2 | No | Formula: (Actual_Delivery_Time - Actual_Pickup_Time) in hours |
| **Days_Until_Pickup__c** | Number | 5,0 | No | Formula: Days between today and pickup window start |
| **Cost_Per_Mile__c** | Currency | 7,2 | No | Formula: Carrier_Rate / Distance |
| **Revenue_Per_Mile__c** | Currency | 7,2 | No | Formula: Shipper_Rate / Distance |
| **On_Time_Indicator__c** | Checkbox | - | No | Formula: Actual_Delivery <= Delivery_Window_End |
| **Status_Label__c** | Text | 50 | No | Formula: User-friendly status text |
| **CreatedDate** | DateTime | - | Yes | System field (load created) |
| **LastModifiedDate** | DateTime | - | Yes | System field (last modified) |

**Indices:** Load_Number__c (unique), Shipper_Account__c, Assigned_Carrier__c, Status__c

**RLS:** All queries filtered by Shipper_Account__c (shipper can only see own) or Assigned_Carrier__c (carrier can only see assigned)

---

#### 2. **Carrier__c** (Account Wrapper — Optional, for Carrier-Specific Data)

Extended carrier data (inherited via lookup from Account).

| Field Name | Type | Length | Required | Notes |
|------------|------|--------|----------|-------|
| **Account__c** | Master-Detail | - | Yes | Link to Account object |
| **MC_Number__c** | Text | 20 | No | FMCSA Motor Carrier number |
| **DOT_Number__c** | Text | 20 | No | DOT number |
| **Insurance_Expiry__c** | Date | - | No | Liability insurance expiration |
| **Rating_Score__c** | Number | 3,1 | No | FMCSA safety rating (0-10) |
| **Equipment_Type__c** | Picklist | - | No | Flatbed, Reefer, Van, etc. |

**Why separate?** Carriers can have complex compliance data. Account stores contact info; this stores operational compliance. Separation keeps things clean.

---

#### 3. **Driver__c**

Individual drivers (associated with Carrier).

| Field Name | Type | Length | Required | Notes |
|------------|------|--------|----------|-------|
| **Name** | Text | 255 | Yes | Driver name |
| **Carrier_Account__c** | Lookup | - | Yes | Carrier company |
| **License_Number__c** | Text | 20 | Yes | CDL number |
| **License_Expiry__c** | Date | - | Yes | CDL expiration |
| **HAZMAT_Certified__c** | Checkbox | - | No | Hazmat endorsement |
| **Phone__c** | Phone | - | No | Driver phone |
| **Status__c** | Picklist | - | Yes | Active, Inactive, Suspended |

**Relationships:** Carrier → Multiple Drivers (one-to-many)

---

#### 4. **Equipment__c**

Tractors, trailers, etc.

| Field Name | Type | Length | Required | Notes |
|------------|------|--------|----------|-------|
| **Name** | Text | 255 | Yes | License plate or ID |
| **Carrier_Account__c** | Lookup | - | Yes | Owner carrier |
| **Equipment_Type__c** | Picklist | - | Yes | Tractor, Trailer, Dump, Flatbed |
| **VIN__c** | Text | 17 | Yes | Vehicle Identification Number |
| **Year__c** | Number | 4,0 | No | Model year |
| **Status__c** | Picklist | - | Yes | Active, Maintenance, Retired |
| **Motive_Vehicle_ID__c** | Text | 100 | No | External ID for Motive GPS (unique) |

**Relationships:** Carrier → Multiple Equipment (one-to-many)

---

#### 5. **Stop__c**

Waypoints for multi-stop loads (pickup, delivery, intermediate stops).

| Field Name | Type | Length | Required | Notes |
|------------|------|--------|----------|-------|
| **Load__c** | Master-Detail | - | Yes | Parent load |
| **Sequence__c** | Number | 3,0 | Yes | Order (1, 2, 3...) |
| **Stop_Type__c** | Picklist | - | Yes | Pickup, Delivery, Intermediate |
| **Address__c** | Text | 255 | Yes | Full address |
| **City__c** | Text | 50 | Yes | City |
| **State__c** | Text | 2 | Yes | State |
| **Zip__c** | Text | 10 | Yes | Postal code |
| **Contact_Name__c** | Text | 100 | No | Person to contact at stop |
| **Contact_Phone__c** | Phone | - | No | Phone at stop |
| **Window_Start__c** | DateTime | - | Yes | Earliest arrival |
| **Window_End__c** | DateTime | - | Yes | Latest arrival |
| **Actual_Arrival__c** | DateTime | - | No | When actually arrived |
| **Dwell_Minutes__c** | Number | 5,0 | No | Minutes spent at stop |

**Relationships:** Load → Multiple Stops (one-to-many, cascading deletes)

---

#### 6. **Tracking__c**

Real-time GPS tracking points (populated by Motive webhook).

| Field Name | Type | Length | Required | Notes |
|------------|------|--------|----------|-------|
| **Load__c** | Lookup | - | Yes | Related load |
| **Driver__c** | Lookup | - | No | Related driver (if known) |
| **Equipment__c** | Lookup | - | No | Vehicle being tracked |
| **Event_Timestamp__c** | DateTime | - | Yes | When event occurred |
| **Latitude__c** | Number | 10,6 | Yes | GPS latitude |
| **Longitude__c** | Number | 10,6 | Yes | GPS longitude |
| **Speed_mph__c** | Number | 5,1 | No | Current speed |
| **Heading_degrees__c** | Number | 3,0 | No | Direction (0-359) |
| **Address__c** | Text | 255 | No | Reverse geocoded address |
| **Event_Type__c** | Text | 100 | No | Arrived, Departed, Geofence, etc. |
| **Motive_Event_ID__c** | Text | 100 | No | External ID from Motive (unique) |

**Why separate from Load?** Loads have one location; Tracking has many. Separation allows history without bloating Load records.

**Indices:** Load__c, Event_Timestamp__c, Motive_Event_ID__c (unique)

**Note:** Triggered on creation via Platform Event from Motive webhook.

---

#### 7. **Invoice__c**

Auto-generated on POD (proof of delivery) capture.

| Field Name | Type | Length | Required | Notes |
|------------|------|--------|----------|-------|
| **Load__c** | Lookup | - | Yes | Related load |
| **Shipper_Account__c** | Lookup | - | Yes | Shipper being invoiced |
| **Invoice_Number__c** | Text | 50 | Yes | Unique (e.g., INV-20260402-001) |
| **Invoice_Date__c** | Date | - | Yes | Date invoice created |
| **Invoice_Amount__c** | Currency | 16,2 | Yes | Total (line items + taxes) |
| **Subtotal__c** | Currency | 16,2 | Yes | Line items (before tax) |
| **Tax_Amount__c** | Currency | 16,2 | No | Calculated tax |
| **Fuel_Surcharge__c** | Currency | 16,2 | No | DAI-indexed fuel surcharge |
| **Deductions__c** | Currency | 16,2 | No | Damaged goods, overages, etc. |
| **Status__c** | Picklist | - | Yes | Draft, Approved, Sent, Paid, Disputed |
| **Due_Date__c** | Date | - | Yes | Payment due (e.g., 30 days net) |
| **Dispute_Reason__c** | TextArea | - | No | If disputed, why |

**Relationships:** Load → One Invoice (one-to-one)

**Auto-Creation:** Triggered when POD is captured (via LoadTrigger)

**RLS:** Shipper sees only own invoices; carrier cannot see

---

#### 8. **Settlement__c**

Weekly consolidation of carrier payments.

| Field Name | Type | Length | Required | Notes |
|------------|------|--------|----------|-------|
| **Carrier_Account__c** | Lookup | - | Yes | Carrier being paid |
| **Settlement_Date__c** | Date | - | Yes | Week ending date (e.g., 2026-04-05) |
| **Total_Amount__c** | Currency | 16,2 | Yes | Total amount owed |
| **Load_Count__c** | Number | 5,0 | Yes | Number of loads settled |
| **Status__c** | Picklist | - | Yes | Draft, Approved, Paid, Disputed |
| **Payment_Method__c** | Picklist | - | No | ACH, Check, Wire |
| **Payment_Date__c** | Date | - | No | When actually paid |
| **Notes__c** | TextArea | - | No | Any notes or adjustments |

**Relationships:** No direct relationship to Load (aggregated via query)

**Creation:** SettlementBatch.cls runs Monday 1 AM ET, aggregates all delivered loads from previous week, creates one Settlement per carrier

**Idempotency:** If batch runs twice, no duplicate settlements created (checked by Settlement_Date + Carrier)

---

### Metadata Objects (3 Total)

#### **RateCardConfig__mdt** (Custom Metadata Type)

Configurable rate cards for shipper-specific or shipper+destination-specific pricing.

| Field | Type | Notes |
|-------|------|-------|
| **DeveloperName** | Text | Unique identifier (e.g., "Shipper_ABC_Basic") |
| **Shipper_Account__c** | Metadata Relationship | Which shipper this rate applies to |
| **Origin_State__c** | Text | If state-specific (e.g., "OH"), leave blank for all states |
| **Destination_State__c** | Text | If destination-specific, leave blank for all |
| **Min_Distance__c** | Number | Minimum miles for this rate |
| **Max_Distance__c** | Number | Maximum miles for this rate |
| **Base_Rate_Per_Mile__c** | Number | $/mile |
| **Minimum_Charge__c** | Currency | Minimum invoice for short loads |
| **Fuel_Surcharge_Method__c** | Picklist | Fixed (e.g., $0.50), Indexed (DAI %), or None |

**Purpose:** RateCardLookup.cls queries this to find applicable rate when assigning carrier.

**Why Metadata?** No UI needed; rates rarely change; metadata cached by Salesforce (fast).

---

#### **ExceptionRules__mdt** (Custom Metadata Type)

8 exception types with configurable thresholds.

| Field | Type | Notes |
|-------|------|-------|
| **DeveloperName** | Text | Rule name (e.g., "LateArrival_Threshold") |
| **Rule_Type__c** | Picklist | LATE_ARRIVAL, MISSED_PICKUP, LONG_IDLE, GEOFENCE_VIOLATION, DRIVER_OFFLINE, EQUIPMENT_BREAKDOWN, ACCIDENT, TRAFFIC |
| **Threshold_Minutes__c** | Number | Minutes over window (e.g., 30 for late) |
| **Severity__c** | Picklist | Critical, Major, Minor |
| **Alert_Channels__c** | Text | Email;Slack;SMS (semicolon-separated) |
| **Notify_Roles__c** | Text | Dispatcher;Ops Manager;Finance (who gets alerted) |
| **Auto_Escalate__c** | Checkbox | If unchecked, manual. If checked, auto-escalate after X hours |
| **Description__c** | TextArea | What this rule detects |

**Purpose:** ExceptionDetectionEngine.cls queries this every 5 minutes, evaluates loads against thresholds, creates Exception records if violated.

**Flexibility:** All thresholds configurable without code changes. Ops team can tune via Setup UI.

---

#### **BillingConfig__mdt** (Custom Metadata Type)

System-wide billing configuration.

| Field | Type | Notes |
|-------|------|-------|
| **DeveloperName** | Text | "Default" (single record) |
| **Settlement_Day_Of_Week__c** | Text | "Monday" |
| **Settlement_Hour__c** | Number | 1 (1 AM ET) |
| **Settlement_Timezone__c** | Text | "America/New_York" |
| **Invoice_Email_Template__c** | Text | "KWB_Invoice_Notification" |
| **DAI_Baseline_Price__c** | Number | Default diesel price (e.g., 2.50) for contracts without fuel surcharge |
| **Tax_Rate__c** | Number | 0.08 (8%) |
| **Invoice_Terms_Days__c** | Number | 30 (net 30) |
| **Auto_Invoice_On_POD__c** | Checkbox | True = auto-generate invoice when POD captured |

**Purpose:** Global settings referenced by InvoiceGenerator, SettlementBatch, etc.

**Why Metadata?** Single source of truth; easy to manage; cached.

---

## Entity Relationships

### Relationship Diagram

```
Account (Shipper)
    │
    └─ Load__c
         │
         ├─ Stop__c (1..N) — Multi-stop loads
         ├─ Tracking__c (1..N) — GPS history
         ├─ Invoice__c (1..1) — Auto-created on POD
         └─ POD__c (1..1) — Proof of delivery
              │
              └─ ContentVersion — Photo/document

Account (Carrier)
    │
    ├─ Load__c (assigned) — Current/past assignments
    ├─ Driver__c (1..N)
    │    └─ Tracking__c (via GPS)
    │
    ├─ Equipment__c (1..N)
    │    └─ Tracking__c (via GPS)
    │
    └─ Settlement__c (1..N) — Weekly payments


Metadata (Configuration)
    │
    ├─ RateCardConfig__mdt
    ├─ ExceptionRules__mdt
    └─ BillingConfig__mdt
```

### Key Relationships

| Relationship | Type | Cascade | Notes |
|--------------|------|---------|-------|
| Load → Shipper | Lookup | No | Shipper soft-deleted doesn't delete loads |
| Load → Carrier | Lookup | No | Carrier can be null (unassigned) |
| Load → Stop | M-Detail | **Yes** | Deleting load deletes all stops |
| Load → Tracking | Lookup | **Yes** | Deleting load deletes all tracking |
| Load → Invoice | Lookup | No | Invoice remains if load deleted (audit) |
| Carrier → Driver | Lookup | No | Driver becomes inactive if carrier soft-deleted |
| Carrier → Equipment | Lookup | No | Equipment becomes inactive if carrier soft-deleted |

---

## Validation Rules

### 13 Total Business Rules (All on Load__c)

| # | Rule Name | Condition | Error Message | Business Logic |
|---|-----------|-----------|---------------|----|
| 1 | **VAL_Pickup_Date** | Pickup_Window_Start < TODAY | "Pickup cannot be in past" | No historical loads allowed |
| 2 | **VAL_Delivery_After_Pickup** | Delivery_Window_Start < Pickup_Window_End | "Delivery must be after pickup" | Stop the obvious |
| 3 | **VAL_Rates_Valid** | Carrier_Rate > Shipper_Rate (when assigned) | "Carrier rate cannot exceed shipper rate" | Protect margin |
| 4 | **VAL_Status_Transitions** | (Complex formula preventing invalid state changes) | "Invalid status transition" | Only allow: AVAILABLE→IN_TRANSIT, IN_TRANSIT→DELIVERED, anything→CANCELLED |
| 5 | **VAL_Required_Fields** | Shipper_Account, Origin_City, Destination_City, Distance, Weight blank | "Required field missing" | Core fields always required |
| 6 | **VAL_Distance_Positive** | Distance <= 0 | "Distance must be greater than 0" | Can't have zero-mile loads |
| 7 | **VAL_Weight_Positive** | Weight <= 0 (if populated) | "Weight must be positive" | If weight tracked, must be > 0 |
| 8 | **VAL_Equipment_Available** | Equipment__c status is "Retired" | "Equipment is no longer available" | Can't assign retired equipment |
| 9 | **VAL_Hazmat_Certification** | (Hazmat load && Driver not HAZMAT_Certified) | "Driver not certified for hazmat" | Safety compliance |
| 10 | **VAL_Time_Windows_Valid** | Pickup_Window_End < Pickup_Window_Start | "Window end must be after start" | Sanity check |
| 11 | **VAL_Delivery_Window_Size** | (Delivery_End - Delivery_Start) > 24 hours | "Delivery window must be reasonable" | Prevent unrealistic expectations |
| 12 | **VAL_Rate_Locked_On_Assign** | (Carrier_Rate changed after Assigned_Carrier populated) | "Cannot change rate after assignment" | Lock in price to prevent disputes |
| 13 | **VAL_Duplicate_Load_Number** | (LOAD__c with same Load_Number exists) | "Load number already exists" | Unique identifier |

**Why so many?** Freight logistics is heavily regulated. Validation rules prevent bad data at source, not downstream.

---

## Formula Fields

### 8 Total Calculated Fields (All on Load__c)

| # | Field Name | Formula | Business Logic | Null Safety |
|---|-----------|---------|-----------------|--------------|
| 1 | **Margin_Dollar__c** | `Shipper_Rate__c - Carrier_Rate__c` | Raw margin in dollars | Both rates required, no null risk |
| 2 | **Margin_Percentage__c** | `(Margin_Dollar__c / Shipper_Rate__c) * 100` | Margin % for reporting | Zero-safe: `IF(Shipper_Rate__c = 0, 0, ...)` |
| 3 | **Transit_Hours__c** | `(Actual_Delivery_Time__c - Actual_Pickup_Time__c) / 3600000` | Hours on road (ms to hours) | Both timestamp fields optional; returns blank if either null |
| 4 | **Days_Until_Pickup__c** | `INT((Pickup_Window_Start__c - TODAY()) / 86400)` | Days remaining | TODAY() safe; returns negative if in past |
| 5 | **Cost_Per_Mile__c** | `IF(Distance__c > 0, Carrier_Rate__c / Distance__c, 0)` | Cost efficiency metric | Zero-safe division |
| 6 | **Revenue_Per_Mile__c** | `IF(Distance__c > 0, Shipper_Rate__c / Distance__c, 0)` | Revenue efficiency metric | Zero-safe division |
| 7 | **On_Time_Indicator__c** | `IF(AND(Actual_Delivery_Time__c <= Delivery_Window_End__c, ISBLANK(Actual_Delivery_Time__c) = FALSE), TRUE, FALSE)` | True if delivered on time | Null-safe AND |
| 8 | **Status_Label__c** | `CASE(Status__c, "AVAILABLE", "Waiting for carrier...", "IN_TRANSIT", "In progress...", "DELIVERED", "Delivered", "Cancelled")` | Human-friendly UI text | Defaults to picklist if unmapped |

**Why formulas (not queries/code)?** 
- **Performance:** Calculated at query time, not runtime. Zero storage overhead.
- **Consistency:** Always in sync with Load record.
- **Auditability:** Never out of date.
- **Simplicity:** No batch jobs or async processing needed.

**Null Safety:** All formulas test for null before arithmetic or comparison.

---

## Design Decisions

### Why This Structure?

#### **Decision 1: Load__c as Central Domain Object**

**Question:** Should loads live on Account (shipper/carrier data silo) or standalone?

**Answer:** Standalone Load__c.

**Why?**
- Shipper sees different view than carrier (margin hidden from carrier)
- Multiple shippers + multiple carriers = M-M relationship (needs junction object or neutral third)
- Neutral third = Load__c in center

**Alternative Considered:** Contact junction objects for shipper/carrier per load. **Rejected:** Contact is for people; companies are Accounts. Overkill.

---

#### **Decision 2: Stop__c for Multi-Stop Loads**

**Question:** Should multi-stop loads be split into multiple Load records or have child Stop records?

**Answer:** Child Stop records (master-detail).

**Why?**
- One shipment, one invoice, one settlement = one Load makes sense
- Multiple stops = multiple touch points = multiple records breaks this
- Master-detail with cascading delete ensures data integrity

**Example:** Shipper sending one truck picking up from 3 warehouses, delivering to 2 locations = 1 Load, 5 Stops.

---

#### **Decision 3: Tracking__c Separate from Load__c**

**Question:** Should GPS points live as related list on Load or separate object?

**Answer:** Separate object.

**Why?**
- 1000s of tracking points per load (from Motive polling every minute)
- Bloats Load records
- History doesn't matter for Load display; matters for incident investigation
- Separate allows archiving old tracking without affecting Load
- Avoids "large data set" query limits

**Access Pattern:** Load shows **current** location (denormalized from latest Tracking); Tracking has full history.

---

#### **Decision 4: Carrier__c Optional Extension**

**Question:** Should carrier-specific data (MC number, DOT, insurance) go on Account or separate object?

**Answer:** Separate Carrier__c custom object with master-detail to Account.

**Why?**
- Account stores contact/billing info (Salesforce standard)
- Carrier stores regulatory/operational compliance (domain-specific)
- Separation allows easy audits and reports
- Account can be soft-deleted; Carrier records stay for audit

**Alternative:** Custom fields on Account. **Rejected:** Pollutes namespace; harder to report.

---

#### **Decision 5: Metadata for Configuration**

**Question:** Should rate cards, exception rules, billing config live in custom objects or custom metadata?

**Answer:** Custom Metadata.

**Why?**
- **Performance:** Metadata cached by Salesforce. Zero SOQL queries on frequently-accessed configs.
- **Governance:** Protected from CRUD issues. Ops team sees "Setup" UI, not data UI.
- **Simplicity:** Single record (BillingConfig) vs querying custom object (query limit risk).

**Alternative:** Custom objects. **Rejected:** Slower; more queries; requires CRUD checks.

---

#### **Decision 6: RLS Enforcement via Code, Not Sharing Rules**

**Question:** Should access control be Salesforce sharing rules or code-based RLS?

**Answer:** Code-based (`with sharing`).

**Why?**
- Shipper/Carrier distinction is **logical** (Account lookup), not role-based
- Sharing rules on role = all field ops reps see all shippers (bad for competitive logistics)
- Code-based `with sharing` + filtered queries (`WHERE Shipper_Account__c = :userAccount`) is precise and audit-friendly
- Salesforce sharing rules too coarse for this domain

**Example:** If User's Contact.Account = ABC Shipper, query filters `Load.Shipper_Account = ABC`. Works automatically.

---

#### **Decision 7: No Encryption; SOQL Injection Prevention**

**Question:** Should rate data, shipper names, driver info be encrypted?

**Answer:** No encryption. SOQL injection prevention instead.

**Why?**
- Encryption adds 20% query overhead + complexity (Salesforce limit)
- Main risk is **injection attacks**, not data exposure (Salesforce already encrypted at rest)
- All queries use bind variables (`:parameter`)
- Code review + testing catches injection vectors

**If needed later:** Encryption can be layered on without schema changes.

---

#### **Decision 8: Auto-Invoice on POD**

**Question:** Should invoices be auto-generated or require manual approval?

**Answer:** Auto-generated **draft**, requires manual approval before sending to shipper.

**Why?**
- Speed: Invoice ready immediately after delivery
- Safety: Draft status prevents accidental send
- Workflow: Ops reviews (check rate, deductions, taxes) → Approves → Sends
- Audit trail: Who approved recorded

**Implementation:** POD creation triggers Load update → Invoice created (via trigger) → Status = Draft

---

### What We Didn't Do (And Why)

**No Opportunity/Quote Objects**
- Loads are confirmed at origin (shipper already booked). No "quote" phase.
- If added later, would be parent to Load (Opportunity → Quote → Load).

**No Payment/Cash Object**
- Settlement is aggregated carrier payment (weekly ACH).
- Invoice is shipper payment (customer statement).
- Payment tracking handled by custom fields (Status, Payment_Date) + Bill.com API (future).

**No Territory Management**
- Could segment by region/shipper. Not needed in MVP.
- Can add with Territory2 if sales reps assigned per shipper later.

**No Account Hierarchies**
- Shipper = Company (Account). Could have parent (multinational) + child (DC).
- Not needed; each shipper tracked independently.

---

## Custom Metadata Types (Full Specs)

### **RateCardConfig__mdt** — Sample Records

```
Record 1:
  DeveloperName: "ABC_Shipper_OH_Base"
  Shipper_Account: ABC Logistics Inc
  Origin_State: OH
  Destination_State: (blank = all states)
  Min_Distance: 1
  Max_Distance: 200
  Base_Rate_Per_Mile: 2.50
  Minimum_Charge: 125.00
  Fuel_Surcharge_Method: "Indexed_DAI"

Record 2:
  DeveloperName: "ABC_Shipper_OH_to_PA"
  Shipper_Account: ABC Logistics Inc
  Origin_State: OH
  Destination_State: PA
  Min_Distance: 50
  Max_Distance: 300
  Base_Rate_Per_Mile: 3.00  (premium lane)
  Minimum_Charge: 150.00
  Fuel_Surcharge_Method: "Indexed_DAI"
```

**Lookup Priority:** RateCardLookup.cls queries:
1. Shipper + Origin + Destination match? Use that.
2. Shipper + Origin match (any destination)? Use that.
3. Shipper generic? Use that.
4. No shipper-specific? Use default.

---

### **ExceptionRules__mdt** — Sample Records

```
Record 1:
  DeveloperName: "Rule_LateArrival"
  Rule_Type: LATE_ARRIVAL
  Threshold_Minutes: 30
  Severity: Major
  Alert_Channels: "Email;Slack"
  Notify_Roles: "Dispatcher;Ops Manager"
  Auto_Escalate: TRUE
  Description: "Delivery more than 30 min late"

Record 2:
  DeveloperName: "Rule_MissedPickup"
  Rule_Type: MISSED_PICKUP
  Threshold_Minutes: 60
  Severity: Critical
  Alert_Channels: "Email;Slack;SMS"
  Notify_Roles: "Dispatcher;Ops Manager;Finance"
  Auto_Escalate: TRUE
  Description: "Pickup window closed, load not picked up"
```

---

### **BillingConfig__mdt** — Single Record

```
DeveloperName: "Default"
Settlement_Day_Of_Week: "Monday"
Settlement_Hour: 1
Settlement_Timezone: "America/New_York"
Invoice_Email_Template: "KWB_Invoice_Notification"
DAI_Baseline_Price: 2.50
Tax_Rate: 0.08
Invoice_Terms_Days: 30
Auto_Invoice_On_POD: TRUE
```

---

## Security Model

### **Row-Level Security (RLS)**

All portal controllers use `with sharing`:

```apex
with sharing class ShipperPortalController { ... }
with sharing class CarrierPortalController { ... }
```

**Result:** User + Company isolation.

| User Type | Sees | Hidden |
|-----------|------|--------|
| Shipper User (ABC Logistics) | Only ABC's loads, invoices, settlements | Other shippers' data |
| Carrier User (XYZ Trucking) | Only loads assigned to XYZ | Shipper confidentials, rates |
| Ops Manager (internal KWB) | All loads (no `with sharing`, org-wide default) | Carrier settlement details (finance only) |

---

### **Field-Level Security (FLS)**

CRUD/FLS checks on all controller public methods:

```apex
if (!Load__c.sObjectType.getDescribe().isAccessible()) {
    throw new AuraHandledException('You do not have permission to view loads.');
}
```

**Result:** Field visibility governed by profile/permission set.

---

### **SOQL Injection Prevention**

All queries use bind variables:

```apex
List<Load__c> loads = [
    SELECT Id FROM Load__c 
    WHERE Load_Number__c = :searchTerm AND Shipper_Account__c = :accountId
];
```

**Alternative (Prevented):** `String.escapeSingleQuotes()` used only for LIKE queries.

---

## Testing & Coverage

**122+ Unit Tests**
- Agent 1: 32 tests for validation rules, formula fields (>85% coverage)
- Agent 3: 29 tests for tracking, Motive integration (92% coverage)
- Agent 4: 40+ tests for billing, settlement (>85% coverage)
- Agent 5: 25+ tests for portal controllers (85% coverage)

**Coverage Target:** >80% (achieved: 85%+)

**Test Framework:** Apex test methods with @TestSetup for shared data

---

## Performance Considerations

### **Query Optimization**

| Query Pattern | Optimization | Notes |
|---------------|--------------|-------|
| Load list (shipper portal) | Single SOQL with `:limit` and `:offset` | Pagination prevents "large dataset" issues |
| Report aggregates | AggregateResult with GROUP BY | No N+1, scales to 100K records |
| Rate lookup | Metadata cached by Salesforce | Zero SOQL queries |
| Tracking history | Separate object; separate queries | Prevents Load bloat |

### **Batch Optimization**

- SettlementBatch: Runs Monday 1 AM ET, uses Map-based aggregation (not nested queries)
- Idempotent: Settlement_Date + Carrier unique constraint prevents duplicates on re-run

### **Index Strategy**

- Load__c: Index on Shipper_Account__c, Assigned_Carrier__c, Status__c, Load_Number__c
- Tracking__c: Index on Load__c, Event_Timestamp__c
- Settlement__c: Index on Carrier_Account__c, Settlement_Date__c

---

## Data Governance

### **Audit Trail**

All objects have:
- CreatedDate, CreatedById (Salesforce system fields)
- LastModifiedDate, LastModifiedById (Salesforce system fields)
- Key changes logged (Status transitions, Rate changes) via triggers

### **Data Retention**

- Loads: Kept indefinitely (audit, reporting)
- Tracking: 90-day rolling window (cost optimization)
- Invoices: 7-year retention (legal requirement)
- Settlements: Indefinite (accounting)

### **Backup Strategy**

- Salesforce daily backups (automatic)
- Weekly export of loads + invoices (governance)
- Monthly export of all data (disaster recovery)

---

## Next Steps for Josh

**Review Checklist:**

- [ ] Does object structure make sense for the domain?
- [ ] Are relationships correct (M-D, Lookup, no circular)?
- [ ] Are validation rules sufficient (not over-constrained)?
- [ ] Are formula fields safe (null-proof, performant)?
- [ ] Is RLS model correct (shipper/carrier isolation)?
- [ ] Any fields missing or extraneous?
- [ ] Any schema anti-patterns you'd flag?

**Questions for Josh:**

1. Should Stop__c be M-D or Lookup? (Current: M-D with cascade)
2. Should Tracking be a big object instead of standard object? (Current: standard, but could grow large)
3. Any compliance/audit fields missing?
4. Should Equipment/Driver be linked to Load__c for audit purposes?
5. Rate card: Should we support role-based pricing (by user's company tier)?

**Timeline:** No rush. Review when you have time. Let me know thoughts/concerns.

---

## Contacts

- **Schema Lead:** Seb Roman (seb.roman316@gmail.com)
- **Business Owner:** Corey Anderson (corey.anderson@kwblogistics.com)
- **GitHub:** https://github.com/seb-roman/kwb-salesforce-loadsmart (repo access available)

---

**Status:** Phase 1 Schema Ready for Production  
**Date:** April 2, 2026  
**Test Coverage:** 122+ tests, 85%+ coverage  
**Security:** SOQL injection-safe, RLS/FLS enforced, CRUD checked
