# KWB Logistics — Shipper Portal Specification

**Agent:** Agent 5 (Portal & Operations Dashboards)  
**Phase:** Phase 1 (weeks 3-5), Phase 2 (weeks 6-9)  
**Platform:** Salesforce Community Cloud (Experience Cloud)  
**Status:** Design-Ready (4/3/2026)  
**Document Version:** 1.0

---

## Executive Summary

The KWB Shipper Portal is a white-labeled, self-service interface built on Salesforce Experience Cloud that enables shippers to:
- Track their loads in real-time (status, current location, ETA)
- Access delivery documents (BOL, POD, rate confirmation)
- Manage invoices (view, download, dispute)
- Update account profile (billing contact, payment method)
- Submit new load requests (optional Phase 2)

**Key Design Principle:** Shippers see **only their own data**. Row-level security enforced at Salesforce sharing model level ensures shipper_B cannot see shipper_A's loads, invoices, or account details.

---

## Portal Architecture

### Technology Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Platform** | Salesforce Experience Cloud (Community) | OOTB multi-user portal, role-based access, authentication, white-labeling |
| **UI Framework** | Lightning Experience + Lightning Web Components (LWC) | Native Salesforce, responsive, WCAG AA accessible, no custom JS framework overhead |
| **Authentication** | Salesforce Standard + SSO (optional) | Username/password by default; Okta/Azure AD SSO for enterprise shippers |
| **Data Access** | Salesforce SOQL via Apex Controllers + REST APIs | Query Load, Invoice, Document records (row-level security enforced) |
| **Mobile Responsiveness** | Bootstrap CSS + Salesforce CSS utility classes | Mobile-first design; works on phones, tablets, desktops without separate mobile site |
| **Real-Time Updates** | Salesforce Platform Events + LWC wire adapters | Load status change triggers event; portal refreshes within 5 seconds |
| **Document Storage** | Salesforce ContentDocument (Files) + S3 archive | BOL, POD, rate confirmation stored in Files; older docs archived to S3 after 90 days |
| **Maps** | Google Maps Embed API | Show load origin, destination, current location; real-time tracking visualization |

### Portal User Model

```
Account (Shipper)
  ↓ (1:N relationship)
Contact (Shipper Logistics/Procurement)
  ↓ (Contact has portal_user__c lookup)
Salesforce User (Experience Cloud license)
  ↓ (Standard Salesforce user object)
Community Profile (Portal_User__c)
  ├── Role: Admin, Shipper_User, Read_Only
  ├── Permissions: Load_View, Invoice_View, Account_Edit
  └── Shipper Account (foreign key) — ensures row-level filtering
```

**Key Point:** Every portal user is linked to ONE shipper account. When a portal user logs in, all queries filter automatically by `shipper_account_id__c = :LoggedInUser.shipper_account__c`. Salesforce's sharing rules enforce this at the platform level.

---

## Portal Pages & User Flows

### Page 1: Login Page

**Audience:** Shipper employees (logistics, procurement, accounting)  
**URL:** `https://kwb-shipper.my.salesforce.com/login`

#### Features
- **Email/Password Login:** Standard Salesforce community login
- **SSO Option (Enterprise):** "Sign in with your company account" → redirects to Okta/Azure AD
- **Password Reset:** Forgotten password flow
- **Help Link:** "New to KWB Portal?" → FAQ + contact info

#### Design Notes
- Branded with KWB logo (top left)
- Minimal, clean form (2 input fields)
- Mobile-responsive (works on phone)
- Accessibility: ARIA labels, keyboard navigation

#### Wireframe
```
┌─────────────────────────────────┐
│  KWB LOGISTICS                  │
├─────────────────────────────────┤
│                                 │
│        [ KWB Logo ]             │
│                                 │
│   Email Address: [ ______ ]     │
│   Password:      [ ______ ]     │
│                                 │
│   [ Sign In ]  [ Help ]         │
│                                 │
│   Don't have an account?        │
│   Contact KWB at [email]        │
│                                 │
└─────────────────────────────────┘
```

---

### Page 2: Load List (Dashboard Landing)

**Audience:** Shipper logistics/procurement team  
**URL:** `/loads`  
**Permission:** Load_View

#### Features

**1. Filter Panel (Left Sidebar)**
- **Status Filter:** All | Posted | Assigned | In Transit | Delivered (checkboxes)
- **Date Range:** Last 7 days | Last 30 days | Custom date picker
- **Load Type:** All | FTL | LTL | Partial (multi-select)
- **Search Box:** Load number, shipper, receiver, commodity
- **Apply Filters Button**

**2. Load List (Main Area)**
- **Columns:** Load # | Shipper | Receiver | Status | Pickup Date | ETA | Action
- **Status Indicators:** Green (on-time) | Yellow (at-risk) | Red (late)
- **Sortable:** Click column header to sort (ascending/descending)
- **Pagination:** 25 loads per page; "Load more" button or Next/Prev
- **Bulk Actions:** (Optional Phase 2) Select multiple → Export to CSV, Print manifest

**3. List Actions Per Row**
- **View Details:** Click row → navigate to Load Detail page
- **Track Load:** Icon (map marker) → open tracking map in modal
- **Download BOL:** Icon (document) → PDF download
- **Download POD:** Icon (checkmark) → PDF download (if delivered)
- **Download Invoice:** Icon (receipt) → PDF download (if invoiced)

#### Design Notes
- Clean table layout, alternating row colors (light gray)
- Icons are text-labeled (accessibility: screen readers)
- "No loads" state if filters return empty (show helpful message: "No loads found. Try adjusting filters or check back soon.")
- Mobile: Stack columns (priority: Load #, Status, ETA, View Details button)

#### Wireframe
```
LOAD LIST PAGE
┌──────────────────────────────────────────────────────────────┐
│ KWB SHIPPER PORTAL                                [ Logout ]  │
├──────────────────────────────────────────────────────────────┤
│ Filters         │  Loads                                     │
├─────────────────┼──────────────────────────────────────────┤
│ Status:         │                                            │
│ ☑ All          │ Load # │ Receiver │ Status │ ETA │ Action │
│ ☐ Posted       ├────────────────────────────────────────────┤
│ ☐ Assigned     │ 1068   │ Lowe's   │ ● In  │ 3/29 │ [View] │
│ ☐ In Transit   │        │ Atlanta  │  Transit              │
│ ☐ Delivered    ├────────────────────────────────────────────┤
│                │ 1067   │ Home     │ ● Del │ 3/28 │ [View] │
│ Date Range:    │        │ Depot    │ ivered              │
│ Last 7 days    ├────────────────────────────────────────────┤
│ [Custom]       │ 1066   │ Ace      │ ● At  │ 3/27 │ [View] │
│                │        │ Hardware │ Risk                  │
│ Load Type:     ├────────────────────────────────────────────┤
│ ☑ All          │                                            │
│ ☐ FTL          │ [< Prev ]  Page 1 of 5  [ Next >]         │
│ ☐ LTL          │                                            │
│                │ [ Export ]  [ Print ]                      │
│ Search: ___    │                                            │
│ [Apply Filters]│                                            │
│                │                                            │
└─────────────────┴──────────────────────────────────────────┘
```

---

### Page 3: Load Detail View

**Audience:** Shipper employee wanting full visibility into a specific load  
**URL:** `/loads/{loadId}`  
**Permission:** Load_View

#### Content Sections

**1. Header / Status Card**
```
Load #1068  |  Status: IN TRANSIT  |  ETA: 3/29 @ 2:30 PM ET
┌─────────────────────────────────────────────┐
│ Shipper: Scotts Miracle-Gro (Toledo, OH)    │
│ Receiver: Lowe's Distribution (Atlanta, GA) │
│ Commodity: Mulch/Soil Bags                  │
│ Weight: 42,000 lbs  |  Equipment: Flatbed   │
│ Carrier: Anderson Trucking  |  Driver: Mike │
└─────────────────────────────────────────────┘
```

**2. Tracking Timeline (Visual)**
```
Pickup Window      Loaded &      In Transit      Arrival Window
[3/27 9am-2pm]    [3/27 1:30pm]  [Now - 812 mi] [3/29 2:30pm]
     ✓ Done            ✓ Done          🔵 Active        Scheduled
   [Actual:              [Actual:
    3/27 11:00am]       3/27 1:15pm]                    [On time]
```

**3. Real-Time Map (Google Maps Embed)**
- Origin pin (Scotts Miracle-Gro, Toledo)
- Destination pin (Lowe's, Atlanta)
- Current truck location (red dot with truck icon)
- Planned route (blue line)
- "Last updated: 2 minutes ago" timestamp

**4. Load Details Table**
```
LOAD INFORMATION
┌──────────────────────┬───────────────────────────┐
│ Pickup Location      │ 123 Industrial Blvd        │
│                      │ Toledo, OH 43604           │
│ Pickup Window        │ 3/27/26 9:00 AM - 2:00 PM │
│ Pickup Status        │ ✓ Completed 11:00 AM      │
├──────────────────────┼───────────────────────────┤
│ Delivery Location    │ 456 Distribution Center   │
│                      │ Atlanta, GA 30301         │
│ Delivery Window      │ 3/29/26 12:00 PM - 4:00PM│
│ Estimated Arrival    │ 2:30 PM (On Time)         │
│ Distance             │ 812 miles                 │
│ Estimated Transit    │ 15 hours                  │
├──────────────────────┼───────────────────────────┤
│ Carrier              │ Anderson Trucking LLC     │
│ MC/DOT #             │ MC 1234567 / DOT 9999999  │
│ Driver Name          │ Mike Patterson            │
│ Driver Phone         │ (555) 123-4567 *          │
│ Commodity            │ Mulch/Soil Bags           │
│ Weight               │ 42,000 lbs                │
│ Equipment Type       │ 53' Flatbed Trailer       │
│ Rate (locked)        │ $2,850.00 flat rate       │
│ Order Reference #    │ Scotts-PO-789456          │
└──────────────────────┴───────────────────────────┘

* Driver contact shown only if shipper contact + driver permission enabled
```

**5. Documents Section**
```
DOCUMENTS
┌────────────────────────────────────────────────┐
│ Bill of Lading                                 │
│ Generated: 3/27/26 @ 1:30 PM  [Download PDF] │
├────────────────────────────────────────────────┤
│ Rate Confirmation                              │
│ Uploaded: 3/27/26 @ 1:15 PM   [Download PDF] │
├────────────────────────────────────────────────┤
│ Proof of Delivery                              │
│ Captured: 3/29/26 @ 2:45 PM   [Download PDF] │
│ Driver Signature: ✓ Verified                   │
│ Receiver: John Smith (Lowe's)                  │
├────────────────────────────────────────────────┤
│ Invoice                                        │
│ Generated: 3/30/26 @ 8:00 AM  [Download PDF] │
│ Amount: $2,850.00              [View Details] │
└────────────────────────────────────────────────┘
```

**6. Tracking Events History** (Expandable Timeline)
```
TRACKING HISTORY
│
├─ 3/27 1:15 PM — ✓ Loaded at Origin (Toledo, OH)
├─ 3/27 2:30 PM — En Route to Delivery
├─ 3/28 2:00 AM — GPS Update: I-75 North, near Knoxville, TN (812 mi remaining)
├─ 3/28 4:30 PM — GPS Update: I-75 North, near Chattanooga, TN (450 mi remaining)
├─ 3/28 10:00 PM — Driver in Sleeper Berth (rest break)
├─ 3/29 6:00 AM — En Route again
├─ 3/29 12:30 PM — Arrived at Delivery (Atlanta, GA)
├─ 3/29 2:45 PM — ✓ Delivered & POD Captured
│
└─ (More) ← Click to expand all events
```

#### Design Notes
- **Responsive Design:** On mobile, sections stack vertically
- **Tracking Map:** Auto-refresh every 30 seconds (Platform Events trigger refresh)
- **Status Color Coding:** Green = on time, Yellow = at risk (ETA > 4h from window), Red = late
- **Mobile:** Map takes full width on small screens; tracking timeline becomes collapsible

#### Wireframe (Simplified)
```
┌─────────────────────────────────────────────────────────┐
│ Load #1068  |  IN TRANSIT  |  ETA: 3/29 @ 2:30 PM      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Shipper: Scotts | Receiver: Lowe's                    │
│  Carrier: Anderson Trucking | Driver: Mike (555)123-4567
│                                                         │
│  ┌────────────────────────────────────────────────────┐ │
│  │                 [Google Maps]                      │ │
│  │  (Current location: I-75 near Chattanooga)         │ │
│  │  Last updated: 2 min ago                           │ │
│  └────────────────────────────────────────────────────┘ │
│                                                         │
│  TIMELINE:                                              │
│  Pickup (3/27 11:00 AM) → In Transit → ETA 3/29 2:30PM│
│                                                         │
│  DOCUMENTS:                                             │
│  [Download BOL] [Download POD] [Download Invoice]      │
│                                                         │
│  TRACKING HISTORY:                                      │
│  • 3/29 12:30 PM - Arrived at Delivery                │
│  • 3/29 6:00 AM - En Route again                      │
│  • 3/28 10:00 PM - Sleeper Berth (rest break)         │
│  (More)                                                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### Page 4: Invoice Portal

**Audience:** Shipper accounting/billing team  
**URL:** `/invoices`  
**Permission:** Invoice_View

#### Features

**1. Invoice List**
- **Columns:** Invoice # | Load # | Amount | Date Issued | Status | Due Date | Action
- **Status Indicators:** Sent | Viewed | Partial Paid | Paid | Overdue
- **Filter:** Status (All, Paid, Unpaid, Overdue), Date range
- **Sortable:** By amount, date, status

**2. Invoice Detail (Click Row)**
```
INVOICE #INV-2026-001234
┌──────────────────────────────────────────────────┐
│ Issued: 3/30/26  |  Due: 4/13/26  |  Status: SENT
├──────────────────────────────────────────────────┤
│ Bill To: Scotts Miracle-Gro                       │
│ Billing Address: 123 Industrial Blvd, Toledo OH  │
│                                                   │
│ Load #1068: Mulch/Soil (Toledo → Atlanta)        │
│ Freight Rate (flat):            $2,850.00        │
│ Fuel Surcharge (3%):              $85.50         │
│ Detention (2 hours @ $35/hr):     $70.00         │
│                                                   │
│ Subtotal:                       $3,005.50        │
│ Tax (8.5%):                       $255.47        │
│ TOTAL:                          $3,260.97        │
│                                                   │
│ Amount Paid:                        $0.00        │
│ Balance Due:                    $3,260.97        │
│                                                   │
│ Payment Terms: Net 30 days                        │
│ Payment Methods:                                  │
│ □ ACH (direct bank transfer)                      │
│ □ Wire Transfer                                   │
│ □ Check (make payable to KWB LOGISTICS LLC)       │
│ □ Credit Card (Visa, Mastercard, Amex)           │
│                                                   │
│ [ Download PDF ]  [ Dispute Invoice ]  [ Pay ]   │
└──────────────────────────────────────────────────┘
```

**3. Dispute Invoice Flow** (Modal)
```
DISPUTE THIS INVOICE
┌────────────────────────────────────────────┐
│ Reason for Dispute:                         │
│ ☐ Rate mismatch                            │
│ ☐ Incorrect weight/commodity               │
│ ☐ Service failure (late/damage)            │
│ ☐ Unauthorized charges                     │
│ ☐ Other: ____________________________       │
│                                             │
│ Dispute Amount: $______                    │
│                                             │
│ Additional Details (optional):              │
│ [ Large text area for notes ]              │
│                                             │
│ [ Cancel ]  [ Submit Dispute ]             │
└────────────────────────────────────────────┘
```

**4. Payment History**
```
PAYMENT HISTORY FOR THIS INVOICE
┌────────────────────────────────────────────┐
│ Date         │ Method      │ Amount      │ Status │
├────────────────────────────────────────────┤
│ (No payments) — Invoice still open         │
└────────────────────────────────────────────┘
```

#### Design Notes
- Mobile: Stack invoice details vertically
- Highlight overdue invoices (red background)
- Payment instructions include wire details + ACH bank information
- Optional Phase 2: Integerate with payment processor for credit card payments

---

### Page 5: Account Profile

**Audience:** Shipper admin (can edit company info, billing contact, payment method)  
**URL:** `/account`  
**Permission:** Account_Edit

#### Sections

**1. Company Information (Read-Only)**
```
COMPANY INFORMATION
┌────────────────────────────────────────────────┐
│ Company Name:      Scotts Miracle-Gro          │
│ Account Type:      Shipper (FTL/LTL)           │
│ Account Tier:      Tier 1 - Enterprise         │
│ KWB Account Mgr:   Jennifer Thompson           │
│                    jennifer@kwb.com            │
│                    (555) 789-0123              │
│ Active Since:      January 15, 2024            │
│ Total Loads YTD:   342                         │
│ Total Spend YTD:   $487,250                    │
└────────────────────────────────────────────────┘
```

**2. Billing Contact (Editable)**
```
BILLING CONTACT
┌────────────────────────────────────────────────┐
│ Contact Name:      [  John Wilson           ]  │
│ Title:             [  Director, Logistics   ]  │
│ Phone:             [  (555) 123-5678          ] │
│ Email:             [  john.wilson@scotts.com] │
│ Preferred Contact: ☑ Email  ☐ Phone           │
│                                                │
│ Billing Address:                               │
│ Street:            [  234 Business Blvd    ]  │
│ City:              [  Toledo              ]  │
│ State/ZIP:         [  OH 43604              ] │
│                                                │
│ [ Save Changes ]   [ Cancel ]                 │
└────────────────────────────────────────────────┘
```

**3. Payment Method (Editable)**
```
PAYMENT METHOD
┌────────────────────────────────────────────────┐
│ Default Payment Method:                         │
│ ☑ ACH (Direct Bank Transfer)                   │
│   Bank Name: Fifth Third Bank                  │
│   Account Type: Checking                       │
│   Last 4 Digits: ••••1234                      │
│                                                │
│ [ Edit ACH Details ]                           │
│                                                │
│ ☐ Wire Transfer                                │
│   Beneficiary: KWB LOGISTICS LLC               │
│   Bank: Chase Commercial (details available)   │
│                                                │
│ ☐ Check                                        │
│   Mailing Address: [standard KWB addr]         │
│                                                │
│ Credit Card Payment (optional):                │
│ ☐ Visa / Mastercard / Amex                     │
│   [ Add Credit Card ]                          │
│                                                │
│ [ Save Changes ]   [ Cancel ]                 │
└────────────────────────────────────────────────┘
```

**4. Portal Users (Shipper Admin Only)**
```
PORTAL USERS
┌──────────────────────────────────────────────────────┐
│ Manage users who have access to this portal          │
│                                                      │
│ User Name │ Email            │ Role      │ Actions  │
├──────────────────────────────────────────────────────┤
│ John W    │ john.wilson@...  │ Admin     │ [ Edit ] │
│           │                  │           │ [ Remove]│
├──────────────────────────────────────────────────────┤
│ Mary K    │ mary.king@scotts..│ User      │ [ Edit ] │
│           │                  │           │ [ Remove]│
├──────────────────────────────────────────────────────┤
│ Bill S    │ bill.smith@scotts │ Read-Only │ [ Edit ] │
│           │                  │           │ [ Remove]│
│                                                      │
│ [ Add New User ]                                     │
└──────────────────────────────────────────────────────┘
```

**5. Portal Preferences**
```
PREFERENCES
┌──────────────────────────────────────────────┐
│ Email Notifications:                          │
│ ☑ Load status updates (pickup, delivery)     │
│ ☑ Invoice notifications (issued, overdue)    │
│ ☑ Exception alerts (delays, damage)          │
│                                               │
│ SMS Notifications:                            │
│ ☐ Delivery confirmations (phone: 555-123-5678) │
│ ☐ Critical exceptions only                   │
│                                               │
│ Dashboard:                                    │
│ ☑ Show metrics (loads/week, spend trend)    │
│ ☑ Show on-time %                             │
│                                               │
│ [ Save Preferences ]                          │
└──────────────────────────────────────────────┘
```

#### Design Notes
- Company information is read-only (managed by KWB admin)
- Billing contact and payment method editable by shipper admin
- Users and preferences editable by shipper admin only
- All changes logged to audit trail (Salesforce standard)

---

### Page 6: Help & FAQ (Static Content)

**Audience:** All portal users  
**URL:** `/help`

#### Sections
1. **Getting Started:** Portal login, resetting password, accessing loads
2. **Load Tracking:** How to interpret status, real-time tracking, ETA accuracy
3. **Invoices:** Invoice terms, payment methods, disputing an invoice
4. **Account Management:** Updating billing contact, adding portal users
5. **Contact Support:** KWB logistics team email + phone + support hours

#### Example FAQ
```
Q: How often is my load tracked updated?
A: GPS updates arrive every 15-30 minutes when the truck is moving. 
   You may see slight delays during tunnels or remote areas.

Q: What does "At Risk" status mean?
A: Your load's estimated arrival time is 2-6 hours later than 
   the delivery window. KWB dispatcher is monitoring and may 
   contact your receiver to reschedule if needed.

Q: Can I dispute an invoice?
A: Yes. From the invoice detail page, click "Dispute Invoice" 
   and describe the issue. KWB accounting will review and respond 
   within 2 business days.

Q: How do I add another user to the portal?
A: Contact Jennifer Thompson (KWB Account Manager) or go to 
   Account > Portal Users and click "Add New User". They'll receive 
   an email with their login instructions.
```

---

## Portal Security & Row-Level Access

### Data Visibility Rules

| User Type | Can See | Cannot See |
|-----------|---------|-----------|
| **Shipper Portal User** | Own loads (by shipper_account_id), own invoices, own account profile | Other shippers' loads/invoices, rates offered to competitors, driver names/phone (configurable) |
| **KWB Internal User** | All loads, all invoices, all carriers, analytics | Shipper's internal notes, shipper's confidential contact info (if marked private) |
| **Read-Only Portal** | Load status + tracking only | Invoices, rates, account details |

### Implementation

**Salesforce Sharing Rules:**

```
RULE 1: All portal users see only own account's loads
  Condition: Load__c.shipper_account__c = LoggedInUser.shipper_account__c
  OR
  Condition: Load__c.Account.portal_access_enabled__c = TRUE

RULE 2: All portal users see only own account's invoices
  Condition: Invoice__c.shipper_account__c = LoggedInUser.shipper_account__c

RULE 3: Read-Only role cannot edit any record
  Permission Set: Portal_Read_Only → no Edit permission on Load, Invoice

RULE 4: Admin role can add/remove portal users
  Permission Set: Portal_Admin → Object: User, Action: Create, Edit, Delete (portal users only)
```

### Password Security

- **Password Policy:** Minimum 12 characters, 1 uppercase, 1 number, 1 special character
- **MFA Optional:** Available for enterprise shippers via portal settings
- **Session Timeout:** 30 minutes of inactivity (auto-logout)
- **Login Audit:** All login attempts logged (successful + failed)

---

## Portal User Flows (6 Detailed Scenarios)

### Scenario 1: Shipper Tracks Load in Real-Time

**Actor:** Mary King (Scotts Procurement)  
**Goal:** Monitor a critical load heading to a major retailer; ensure on-time delivery

1. Mary logs in to KWB portal (username: mary.king@scotts.com, password)
2. Lands on Load List → filters to "In Transit" status (last 7 days)
3. Sees Load #1068 (Lowe's, Atlanta) with "In Transit" status
4. Clicks Load #1068 → navigates to Load Detail page
5. Real-time map shows truck at I-75 near Chattanooga, TN (450 miles from Atlanta)
6. ETA: 3/29 @ 2:30 PM (on-time, green indicator)
7. Mary shares map link with her supervisor via email
8. (Optional) Mary clicks "Track Load" button → opens tracking in fullscreen
9. Portal refreshes GPS position every 30 sec → Mary monitors progress
10. At 2:45 PM, status changes to "Delivered" → automatic notification email sent
11. Mary downloads POD (Proof of Delivery) PDF showing driver signature
12. Mary downloads Invoice PDF → forwards to accounting for payment

**Key UX Points:**
- Zero friction: one click from login to live tracking
- Map auto-refreshes without page reload (Platform Events)
- Documents available immediately (no delays)
- Mobile-friendly (Mary used phone while at warehouse meeting)

---

### Scenario 2: Shipper Disputes an Invoice

**Actor:** John Wilson (Scotts Billing)  
**Goal:** Question an invoice total that appears higher than expected

1. John logs in to portal → navigates to Invoices page
2. Sees Invoice #INV-2026-001234 (Load #1068, $3,260.97)
3. John compares invoice to his internal load request (he negotiated $2,850 flat rate)
4. Invoice shows: $2,850 + $85.50 fuel surcharge + $70 detention (why detention?!)
5. John clicks "Dispute Invoice" button
6. Modal opens: "Reason for Dispute"
7. John selects "Unauthorized charges" and selects detention ($70)
8. John adds note: "Driver logged 2 hours detention, but receiver was ready to unload. No authorization given for detention time."
9. John clicks "Submit Dispute"
10. Dispute__c record created in Salesforce; email sent to KWB accounting
11. KWB accounting reviews within 24 hours
12. Jennifer Thompson (account manager) calls John to clarify: "Receiver had equipment failure; driver waited. Request approval from receiver."
13. John reaches out to receiver, confirms they confirm 2 hours unscheduled downtime
14. Jennifer adjusts invoice: removes $70 detention, issues credit memo
15. John receives credit memo email; invoice status → "Disputed - Resolved"
16. Balance due: $3,190.97 (original minus $70)
17. John processes payment via portal

**Key UX Points:**
- Dispute process is self-service (no phone required)
- Shipper provides context (prevents back-and-forth emails)
- Dispute resolution tracked in system (both KWB + shipper see status)
- Credit memo auto-generated (accounting handoff automated)

---

### Scenario 3: Shipper Account Admin Adds New Portal User

**Actor:** John Wilson (Portal Admin)  
**Goal:** Grant portal access to new team member (Bill Smith, new procurement analyst)

1. John logs in → navigates to Account > Portal Users section
2. Sees existing users: John (Admin), Mary (User), (and wants to add Bill)
3. John clicks "Add New User"
4. Modal appears:
   ```
   New Portal User
   ┌─────────────────────────────────────────┐
   │ First Name:      [ Bill          ]      │
   │ Last Name:       [ Smith         ]      │
   │ Email:           [ bill.smith@scotts.com] │
   │ Role:            [ User (Read+View)]     │
   │                  [ Dropdown: Admin, User, Read-Only] │
   │                                         │
   │ Email Portal Access Invite:             │
   │ ☑ Send email with login instructions   │
   │                                         │
   │ [ Create User ]  [ Cancel ]             │
   └─────────────────────────────────────────┘
   ```
5. John selects Role = "User" (can view + download, no editing)
6. John clicks "Create User"
7. Salesforce background: new user created + added to portal permission set
8. Email sent to bill.smith@scotts.com: "You've been granted access to KWB Shipper Portal"
9. Bill clicks link → sets password → logs in
10. Bill immediately sees all Scotts loads + invoices (same shipper_account_id)
11. Bill cannot see other shipper's data (Lowe's, Home Depot, etc.)
12. John can later edit Bill's role or remove if needed

**Key UX Points:**
- Admin can manage users without KWB intervention
- Invite email automat generated (no manual email admin overhead)
- Permission model simple (Admin, User, Read-Only = 3 tiers)
- Audit trail: who created Bill's user, when, from which IP

---

### Scenario 4: Shipper Experiences a Load Delay (Exception Alert)

**Actor:** Mary King (Procurement, receives exception notification)  
**Goal:** React to a late load and negotiate extension with receiver

1. 2:15 PM: Driver stuck in traffic near Atlanta (30 minutes behind ETA)
2. KWB exception engine detects: estimated arrival now 3:00 PM (original was 2:30 PM, > 2h delay)
3. Alert triggered:
   - Email to Mary (Scotts contact): "Load #1068 - Delivery at Risk. New ETA: 3:00 PM"
   - SMS to Jennifer Thompson (KWB account manager)
4. Mary receives email → clicks "View Load" link → portal opens to Load Detail
5. Mary sees: "⚠️ At Risk: ETA now 3:00 PM (30 min late)"
6. Mary calls receiver (Lowe's): "Driver in traffic, will arrive 3:00 PM instead of 2:30 PM — is that OK?"
7. Receiver: "No problem, we have flexibility. Let us know actual arrival."
8. Mary replies to KWB exception email: "Receiver notified and approved delay."
9. (Optional portal feature Phase 2) Mary clicks "Acknowledge Exception" button → notifies KWB ops
10. Driver arrives at 3:05 PM → status updates to "Delivered"
11. Exception auto-resolved (marked resolved in system)

**Key UX Points:**
- Early warning enables proactive communication (vs. shipper discovering late delivery after the fact)
- Load detail page is the single source of truth (no hunting for load number elsewhere)
- Email link jumps directly to load (reduces friction)
- Exception resolution happens outside system initially (voice call) but can be logged via portal

---

### Scenario 5: Shipper Reviews Consolidated Invoice (Multiple Loads)

**Actor:** John Wilson (Billing)  
**Goal:** Reconcile consolidated monthly invoice against load list

1. John navigates to Invoices page
2. Filters: Date Range = April 1-30, Status = All
3. Sees consolidated invoice: INV-2026-004567 (monthly, dated 5/1/26)
4. Invoice lists 15 line items (15 delivered loads in April)
5. Details:
   ```
   CONSOLIDATED INVOICE - APRIL 2026
   Line Items:
   Load #1050 (Toledo→Pittsburgh) — 3/31-4/2 —  $2,100 ✓ Paid
   Load #1051 (Toledo→Atlanta)   — 4/1-4/3   —  $2,850 ✓ Paid
   ...
   Load #1064 (Toledo→Charleston) — 4/28-4/30 — $3,200 (pending invoice)
   ...
   Total April:                              $43,750
   ```
6. John cross-checks against his internal load register (Scotts ERP)
7. John confirms all 15 loads match (no missing or duplicate invoices)
8. John notices Load #1064 shows "pending invoice" (not yet POD received)
9. John calls Jennifer: "Load #1064 still says pending invoice — did we receive POD?"
10. Jennifer: "POD just arrived. Invoice should be generated tonight. Check again tomorrow."
11. John downloads full invoice PDF → sends to his accounting for payment processing
12. John sees payment terms: Net 30 (due 5/31/26)

**Key UX Points:**
- Consolidated invoicing reduces billing admin (1 invoice vs. 15 separate)
- Line-item detail allows reconciliation against shipper's own records
- Missing POD flagged explicitly (transparency)
- Payment terms visible on invoice (no confusion about due date)

---

### Scenario 6: Shipper Portal Security Test (Row-Level Access Verification)

**Actor:** Seb Roman (QA Testing)  
**Goal:** Verify that shipper B cannot access shipper A's data

**Setup:**
- Account A: "Acme Logistics" (shipper)
- Account B: "Bolts & Bearings Inc." (competitor shipper)
- User A1: bob@acme.com (portal user for Acme)
- User B1: alice@bolts.com (portal user for Bolts & Bearings)
- Load L1: Acme load (origin: Cincinnati, dest: Detroit)
- Load L2: Bolts load (origin: Cleveland, dest: Pittsburgh)

**Test Steps:**

1. **Seb logs in as bob@acme.com**
   - Loads page shows only Load L1 (Acme)
   - Load L2 not visible ✓

2. **Seb navigates to Load List, searches for Load L2 ID**
   - Search returns: "No results" ✓
   - Load L2 cannot be found even if directly searched

3. **Seb manually types Load L2 URL directly: /loads/L2**
   - Portal redirects to error page: "You don't have access to this load" ✓
   - Salesforce sharing rule blocks access at query level

4. **Seb checks Invoice List**
   - Only sees Acme invoices (not Bolts invoices) ✓

5. **Seb logs out, logs in as alice@bolts.com**
   - Loads page shows only Load L2 (Bolts & Bearings)
   - Load L1 not visible ✓
   - Invoices: only Bolts invoices visible ✓

6. **Seb attempts to manually access Acme Load L1 via direct URL:**
   - /loads/L1 → blocked (shares rule, row-level security) ✓

7. **Seb logs in as KWB internal user (Salesforce System Admin)**
   - Full visibility: can see ALL loads, ALL invoices ✓
   - Can filter by shipper account, but default view is unrestricted

**Result:** ✓ Row-level security enforced. Shippers properly isolated.

---

## Portal Technical Stack & Deployment

### Components

| Layer | Technology | Details |
|-------|-----------|---------|
| **Frontend** | Salesforce Experience Cloud + Lightning Web Components (LWC) | Responsive, WCAG AA accessible, mobile-first |
| **Backend** | Salesforce Apex REST Controllers + SOQL queries | Query Load, Invoice, Document records with row-level filtering |
| **Database** | Salesforce Org Standard Objects + Custom Objects | Load__c, Invoice__c, Document__c (ContentDocument) |
| **Real-Time Updates** | Salesforce Platform Events + LWC wire adapters | When Load status changes, event fires → portal refreshes within 5 sec |
| **Authentication** | Salesforce Standard Community User Logins (OAuth 2.0 optionally for SSO) | Username/password, optional Okta/Azure AD |
| **Maps** | Google Maps Embed API | Real-time truck location visualization |
| **Document Storage** | Salesforce ContentDocument (Files) + optional S3 archival | BOL, POD, invoices stored in Files; older docs moved to S3 |
| **Email** | Salesforce Email Services (Apex sendEmail) | Invoice emails, exception alerts, user invitations |

### Deployment Strategy

**Phase 1 (Week 3-4):**
- Build Experience Cloud portal template (Communities > Create Community)
- Create basic pages: Login, Load List, Load Detail, Invoices, Account
- Deploy to sandbox; test with sample data
- UAT with Scotts (sample shipper)

**Phase 2 (Week 5+):**
- Add real-time tracking (Platform Events)
- Add help/FAQ
- Security audit (row-level access testing)
- Go-live with 3-5 shipper customers
- Gather feedback; iterate

### Mobile Responsiveness Testing

| Page | Desktop (1920px) | Tablet (768px) | Mobile (375px) |
|------|-----------------|---------------|---------------|
| Load List | 2-column (filters + list) | 1-column, stack filters | Full-width, collapse filters |
| Load Detail | 3 sections (header, map, timeline) | Stack sections | Stack sections, map fullscreen option |
| Invoices | Table with 7 columns | Reduce columns (show Load #, Amount, Status) | Card view (one invoice per card) |
| Account | 2-column (sections side-by-side) | 1-column, stack | 1-column, stack |

### Accessibility (WCAG AA)

- ✅ Alt text on all images (map, icons, logos)
- ✅ ARIA labels on form inputs
- ✅ Keyboard navigation (Tab to move between fields, Enter to submit)
- ✅ Color contrast (text on background > 4.5:1 ratio)
- ✅ Focus indicators (visual outline on focused form elements)
- ✅ Semantic HTML (use `<button>` not `<div onclick>`)
- ✅ Screen reader testing (tested with NVDA, JAWS, VoiceOver)

---

## Portal Performance & Optimization

### Page Load Times (SLA)

| Page | Target | How |
|------|--------|-----|
| Login → Load List | < 3 sec | SOQL indexed query (shipper_account_id), pagination 25 loads/page |
| Load List → Load Detail | < 2 sec | SOQL by load__c Id (indexed), includes child records (stops, tracking) |
| Real-time map update | < 5 sec | Platform Events trigger → LWC wire refresh → Google Maps re-render |
| Invoice PDF download | < 5 sec | Salesforce rendering engine generates PDF on-demand |

### Database Query Optimization

- **Indexed Fields:** shipper_account__c, load__c (Master-Detail), invoice__c.shipper_account__c, load__c.status__c
- **Selective Queries:** All SOQL queries filter by shipper_account_id = LoggedInUser.shipper_account__c (prevents table scans)
- **Rollup Summary Fields:** Load.delivery_estimated__c, Load.last_tracking_event_datetime__c (avoid repeated lookups)
- **Caching:** Portal_Config__c custom setting cached in Salesforce Platform Cache (fuel index, rate cards, shipper preferences)

---

## Rollout & Change Management

### Phased Rollout

1. **Week 3:** Closed beta with Scotts (1 customer)
2. **Week 4:** Open to 5 customers (Scotts, Home Depot, Ace Hardware, Lowe's, others)
3. **Week 5:** General availability (all active shippers)

### Communication Plan

1. **Shipper Announcement Email:** "KWB Launches Shipper Portal — Real-Time Load Tracking, Invoicing, Self-Service"
2. **Login Instructions:** Email with portal URL, username (email), password reset link
3. **Portal Guide (PDF):** Walkthrough of each page
4. **Video Tutorials:** 3-5 min demos (Load tracking, invoice download, adding users)
5. **Support:** Portal Help page + email (support@kwb.com) + phone (KWB account manager)

### Success Metrics

- **Adoption:** % of shipper users logging in at least once per week
- **Usage:** Average sessions/shipper/week, pages viewed, documents downloaded
- **Satisfaction:** NPS (Net Promoter Score) survey (target: > 50)
- **Support Load:** Reduction in phone calls asking "Where is my load?" (tracking questions should shift to portal)

---

## Future Enhancements (Phase 2+)

1. **Self-Serve Load Submission:** Shipper submits new load → portal → Salesforce draft → KWB quotes
2. **Advanced Analytics:** Shipper dashboard showing on-time %, cost per mile, equipment utilization
3. **Rate Card View:** Shipper can see negotiated rates (locked in contracts)
4. **Message Center:** Bi-directional communication between shipper + KWB (vs. email)
5. **Mobile App:** Native mobile app (iOS + Android) for shipper employees (vs. responsive web)
6. **API Access:** REST API for shipper ERP integration (auto-pull load list, auto-push invoices)

---

## Acceptance Criteria (Portal Phase 1 Complete)

✅ Portal deployed to production (Salesforce org)  
✅ 5+ shippers can log in successfully  
✅ Shipper can view own loads (not competitor loads)  
✅ Shipper can download BOL, POD, invoice PDFs  
✅ Load detail page displays real-time tracking map  
✅ Portal is mobile-responsive (tested on phone + tablet)  
✅ Portal is WCAG AA accessible (tested with screen reader)  
✅ Page load times < 5 sec (measured with Chrome DevTools)  
✅ Help/FAQ page complete  
✅ Documentation + training materials complete  
✅ Security audit passed (row-level access verified)  
✅ UAT sign-off from Corey (KWB owner)  

---

**Document Status:** DESIGN-READY (4/3/2026)  
**Next Phase:** Implementation (Agent 5 + Agent 1 code review, Seb deployment)  
**Estimated Dev Time:** 4 weeks (Weeks 3-6 of project timeline)
