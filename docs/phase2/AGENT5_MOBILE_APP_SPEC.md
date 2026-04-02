# KWB Logistics — Mobile Driver App: Complete Feature Specification

**Agent:** Agent 5  
**Phase:** Phase 2 Full Build (Days 1-4)  
**Tech Stack:** React Native + Firebase + Salesforce  
**Target Platforms:** iOS 14+ | Android 10+  
**Date:** April 2, 2026

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Feature Overview](#feature-overview)
3. [User Flows](#user-flows)
4. [Data Models](#data-models)
5. [API Specifications](#api-specifications)
6. [UI/UX Specifications](#uiux-specifications)
7. [Technical Requirements](#technical-requirements)
8. [Offline Mode Specification](#offline-mode-specification)
9. [Security Requirements](#security-requirements)
10. [Performance Targets](#performance-targets)
11. [Testing Strategy](#testing-strategy)

---

## Executive Summary

The KWB Driver App is a mobile-first solution that empowers drivers to:
- **View assigned loads** with complete pickup/delivery details
- **Check in** at pickup and delivery locations (GPS + timestamp)
- **Capture proof of delivery** (POD) via photo + signature
- **Access emergency contact** information (1-tap calling)
- **Monitor HOS status** (hours of service remaining)
- **Work offline** with automatic sync when reconnected
- **Receive push notifications** for load assignments and exceptions

**MVP Scope (Phase 2):** Login, load list, load detail, check-in, POD capture, offline sync

---

## Feature Overview

### 1. Driver Authentication
**Goal:** Secure driver login with Salesforce backend

**Features:**
- Phone number + password login
- Salesforce OAuth 2.0 integration (drivers login via Salesforce)
- Password reset (email-based)
- Auto-session refresh (token valid 24h)
- Logout + session invalidation

**Success Criteria:**
- ✅ Login works on slow 3G networks
- ✅ Session token persisted locally
- ✅ Auto-logout after 24h inactivity
- ✅ Password reset email arrives within 2 min

---

### 2. Load Assignment & List
**Goal:** Driver sees all assigned loads with status summary

**Features:**
- **Load List Screen:**
  - Tab filters: Assigned | In Transit | Delivered
  - Each load card shows: Load #, Shipper, Receiver, Pickup Time, Delivery Time
  - Status badge: "PENDING PICKUP" | "IN TRANSIT" | "AT DELIVERY" | "POD PENDING"
  - Pull-to-refresh (manual)
  - Auto-refresh every 2 minutes (background)
  - Pagination (25 loads per page)

- **Real-Time Assignment:**
  - Firebase Realtime DB listener: watch for new loads
  - Push notification: "Load 1069 assigned! Pickup at Scotts, 9 AM tomorrow"
  - Auto-add to list (no manual refresh needed)

- **Load Status States:**
  - ASSIGNED: Driver accepted load, pending pickup
  - IN_TRANSIT: Driver checked in at pickup, en route to delivery
  - AT_DELIVERY: Driver arrived at delivery location
  - POD_PENDING: Driver waiting to capture POD
  - DELIVERED: POD captured, load complete

**Success Criteria:**
- ✅ List loads within 2 sec
- ✅ New assignment appears in list within 3 sec
- ✅ Can scroll through 100+ loads without lag
- ✅ Pull-to-refresh works offline (shows cached loads)

---

### 3. Load Detail
**Goal:** Driver views full load information before pickup

**Features:**
- **Pickup Section:**
  - Shipper company name
  - Pickup address (street, city, state, zip)
  - Pickup window (date + time range)
  - Contact name + phone number
  - [NAVIGATE] button (Google Maps deep link)
  - [CALL SHIPPER] button (one-tap phone dial)

- **Delivery Section:**
  - Receiver company name
  - Delivery address
  - Delivery window (date + time range)
  - Contact name + phone number
  - [NAVIGATE] button
  - [CALL RECEIVER] button

- **Cargo Section:**
  - Commodity description
  - Weight
  - Dimensions (if applicable)
  - Special handling instructions (e.g., "Fragile", "Hazmat")
  - Equipment type (e.g., "53ft dry van", "flatbed")

- **Documents:**
  - Bill of Lading (BOL) PDF
  - Rate confirmation PDF
  - Shipper reference # (for tracking)

- **HOS Status Bar:**
  - Driving hours remaining (e.g., "6h 15m remaining")
  - On-duty hours remaining
  - Next reset time (e.g., "Tomorrow 10 AM")
  - Warning if <5h remaining

- **Special Instructions:**
  - Pickup notes (e.g., "Shipper has dock", "Requires appointment")
  - Delivery notes (e.g., "Receiver requires ID", "Unload time ~2h")

- **Action Buttons:**
  - [CHECK IN AT PICKUP] (if status = ASSIGNED)
  - [CHECK IN AT DELIVERY] (if status = IN_TRANSIT)
  - [CAPTURE POD] (if status = AT_DELIVERY)

**Success Criteria:**
- ✅ Load detail loads within 1 sec
- ✅ All contact buttons work (navigate, call)
- ✅ PDF documents open in app viewer
- ✅ Works offline (cached from load list)

---

### 4. Check-In Workflow
**Goal:** Driver checks in at pickup/delivery with GPS + timestamp

**Screens:**

**A. Pre-Check-In Confirmation:**
```
┌─────────────────────────────────────┐
│ CHECK IN AT PICKUP                  │
├─────────────────────────────────────┤
│ Load: 1068                          │
│ Location: Scotts Miracle-Gro        │
│ Address: 123 Industrial Blvd        │
│                                     │
│ Current Time: 9:17 AM               │
│ Pickup Window: 9 AM - 2 PM          │
│ Status: ✓ ON TIME                   │
│                                     │
│ GPS will be recorded with this      │
│ check-in. Permission required.      │
│                                     │
│ [CHECK IN]  [CANCEL]                │
│                                     │
└─────────────────────────────────────┘
```

**B. Check-In Process:**
1. User taps [CHECK IN]
2. App requests GPS location (if not enabled, prompt user)
3. Wait for GPS fix (show spinner, "Acquiring location...")
4. Once GPS ready, timestamp + location captured
5. Create Check_In__c record in Salesforce
6. Show confirmation: "✓ Checked in at 9:17 AM"
7. Update load status locally (PICKUP_COMPLETE if pickup, or AT_DELIVERY if delivery)
8. Auto-navigate to Load Detail or POD capture screen

**Data Captured:**
```
Check_In__c (Salesforce)
  Load__c: 1068
  Event_Type__c: 'pickup' | 'delivery'
  Event_DateTime__c: 2026-03-27T09:17:00Z
  Latitude__c: 41.663
  Longitude__c: -83.555
  Location_Accuracy__c: 10.5 (meters)
  Source_System__c: 'driver_app'
  External_Event_Id__c: UUID (de-dup)
  
Local Cache (Realm)
  loadId: 1068
  checkInPickup: { timestamp, latitude, longitude, synced: false }
  checkInDelivery: null (pending)
```

**Offline Handling:**
- If offline: capture GPS + timestamp locally, queue for sync
- Show: "📌 Check-in queued. Will sync when online."
- When online: auto-sync check-in to Salesforce

**Success Criteria:**
- ✅ GPS captures within 5 seconds (85% of time)
- ✅ Check-in syncs to Salesforce within 10 sec (if online)
- ✅ If offline, check-in saved locally + syncs when online
- ✅ No data loss (even if app crashes during sync)
- ✅ User can see pending check-ins until synced

---

### 5. Proof of Delivery (POD) Capture
**Goal:** Driver captures photo + signature + condition of delivery

**POD Screen Flow:**

**Step 1: Photo Capture**
```
┌──────────────────────────────────┐
│ PROOF OF DELIVERY - PHOTO        │
├──────────────────────────────────┤
│ Load: 1068                       │
│                                  │
│ 1. Take Photo                    │
│ [📷 TAKE PHOTO]  [📸 UPLOAD]     │
│ (or select from photo library)   │
│                                  │
│ Photos Attached:                 │
│ ┌──────────────────────────────┐ │
│ │ [Truck at Lowe's dock]       │ │
│ │ Time: 2:47 PM                │ │
│ │ Size: 1.2 MB                 │ │
│ │ [Remove]                     │ │
│ └──────────────────────────────┘ │
│                                  │
│ [NEXT] [SKIP]                    │
│                                  │
└──────────────────────────────────┘
```

**Step 2: Signature Capture**
```
┌──────────────────────────────────┐
│ PROOF OF DELIVERY - SIGNATURE    │
├──────────────────────────────────┤
│ 2. Receiver Signature            │
│ ┌──────────────────────────────┐ │
│ │                              │ │
│ │   [Draw Signature Here]      │ │
│ │                              │ │
│ │                              │ │
│ │                              │ │
│ └──────────────────────────────┘ │
│ [Clear Signature]                │
│                                  │
│ Name (typed): John Smith         │ │
│ Company: Lowe's                  │ │
│ Time: 2:47 PM                    │ │
│                                  │
│ [NEXT]                           │
│                                  │
└──────────────────────────────────┘
```

**Step 3: Delivery Condition**
```
┌──────────────────────────────────┐
│ PROOF OF DELIVERY - CONDITION    │
├──────────────────────────────────┤
│ 3. Delivery Status               │
│                                  │
│ Condition: [Good ▼]              │
│ • Good                           │ │
│ • Minor Damage                   │ │
│ • Refused                        │ │
│ • Other                          │ │
│                                  │
│ Notes (optional):                │
│ [Two small dents on pallet] ___  │ │
│                                  │
│ [SUBMIT POD]                     │ │
│                                  │
└──────────────────────────────────┘
```

**Data Captured:**
```
POD__c (Salesforce)
  Load__c: 1068
  Pod_DateTime__c: 2026-03-27T14:47:00Z
  Photo_Content_Document_Id__c: (reference to uploaded file)
  Signature_Image_Url__c: (reference to signature PNG)
  Receiver_Name__c: 'John Smith'
  Receiver_Company__c: 'Lowe's'
  Delivery_Condition__c: 'Good' | 'Minor Damage' | 'Refused' | 'Other'
  Damage_Notes__c: 'Two small dents on pallet'
  Source_System__c: 'driver_app'
  External_Pod_Id__c: UUID

ContentDocument (Salesforce Files)
  Title: 'POD_1068_photo_2026-03-27.jpg'
  Body: (binary image data, ~500KB after compression)
  LinkedEntity: Load__c:1068

Local Cache (Realm)
  loadId: 1068
  pod: {
    photo: { uri, size, timestamp },
    signature: { uri, timestamp },
    condition: 'Good',
    notes: 'Two small dents on pallet',
    synced: false
  }
```

**Implementation Details:**

**A. Photo Capture:**
- Use react-native-camera (cross-platform)
- Resolution: 1080p (balance quality + file size)
- Auto-compress: JPEG 80% quality (~1.2 MB)
- Store locally: FileSystem.DocumentDirectoryPath
- Allow camera + photo library upload

**B. Signature Capture:**
- Use react-native-signature-canvas
- Canvas size: 300x150 px
- Export as PNG (transparent background)
- Signature captured as data URI, converted to file

**C. Offline Handling:**
- All photos + signature stored locally
- POD queued for sync when offline
- When online: upload photos to Salesforce Files, create POD record
- Progress indicator: "Uploading POD (3/4)..."

**Success Criteria:**
- ✅ Photo capture works in low light (with flash)
- ✅ Photo compresses to <1.5 MB
- ✅ Signature captured cleanly (no lag)
- ✅ POD syncs to Salesforce within 30 sec (if online)
- ✅ If offline, POD queued + syncs when online
- ✅ User can add multiple photos (if needed)

---

### 6. HOS (Hours of Service) Tracker
**Goal:** Driver sees real-time HOS status

**Display:**
```
HOS Status:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Driving: 6h 15m (out of 11h limit)
[==========░░░░░░░░░░░░░░] 57%

On-Duty: 8h 30m (out of 14h limit)
[==============░░░░░░░░░░░] 61%

Next Reset: Tomorrow 10:00 AM

⚠️ Warning: 4h 45m remaining before
   mandatory rest period.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Data Source:**
- Fetch from Motive API OR Geotab API (depending on ELD provider)
- Cache locally (refresh once per day, or on-demand)
- Display read-only (no edit capability)

**Integration:**
- Background job: fetch HOS data every 4 hours
- Show warning if <5h driving remaining
- Alert: "Approaching HOS limit. Plan rest break."

**Success Criteria:**
- ✅ HOS data displays on load detail screen
- ✅ Warnings appear if approaching limit
- ✅ Data updates every 4 hours (not real-time, to save bandwidth)

---

### 7. Offline Mode
**Goal:** App fully functional without internet connection

**Cached Data:**
- Load list (all loads assigned to driver)
- Load details (shipper, receiver, commodity, documents)
- Contact information (all shipper/receiver details)
- HOS status (last fetched)

**Operations Queued When Offline:**
- Check-in (timestamp + GPS captured, synced on reconnect)
- POD submission (photos + signature stored, synced on reconnect)
- Status updates (load status changes, synced on reconnect)

**Sync Strategy:**
```
┌──────────────────────────────────────┐
│ Offline Sync Flow                    │
├──────────────────────────────────────┤
│                                      │
│ App Detects: Online Status Changed   │
│        ↓                             │
│ Fetch Pending Operations (from Realm)│
│        ↓                             │
│ Upload in Order:                     │
│   1. Check-ins (smallest)            │
│   2. POD metadata                    │
│   3. POD photos (largest)            │
│        ↓                             │
│ On Success: Mark "synced: true"      │
│ On Failure: Retry in 5 min           │
│        ↓                             │
│ User Notification: "✓ Synced"        │
│                                      │
└──────────────────────────────────────┘
```

**Retry Logic:**
- Retry up to 3 times
- Exponential backoff: 5s, 15s, 45s
- Show user: "Sync failed. Retrying..."
- If all retries fail: show "Pending" badge, retry every 5 min

**Data Storage (Realm):**
```
Schema:
- Driver (userId, phone, name, authToken)
- Load (loadId, shipper, receiver, status, etc.)
- CheckIn (loadId, eventType, timestamp, latitude, longitude, synced)
- POD (loadId, photoUri, signatureUri, condition, notes, synced)
- SyncQueue (operation, loadId, timestamp, status, retryCount)
```

**Success Criteria:**
- ✅ App fully functional offline (no blank screens)
- ✅ Check-ins captured offline, synced on reconnect
- ✅ POD photos stored locally, synced on reconnect
- ✅ No data loss (even if app killed during sync)
- ✅ User can see pending operations (badge/indicator)

---

### 8. Push Notifications
**Goal:** Driver receives real-time alerts for loads + exceptions

**Notification Types:**

| Event | Title | Body |
|-------|-------|------|
| Load Assigned | Load 1069 Assigned | Pickup at Scotts, 9 AM tomorrow. Delivery: Lowe's, 2 PM. |
| Load Updated | Load 1068 Updated | Pickup moved to 10 AM. Receiver confirmed unload time ~2h. |
| Exception Alert | Delivery 2h Late | You're 2 hours behind schedule. Call dispatcher? |
| Dispatcher Message | Message from Mike | "Can you provide ETA? Receiver asking." |
| HOS Warning | HOS Limit Approaching | You have 4 hours driving remaining. Plan a break. |

**Implementation:**
- Firebase Cloud Messaging (FCM)
- App must subscribe to FCM topic: `driver_{driverId}`
- Salesforce: Create platform event on load assignment
- Serverless function (Firebase Cloud Function): listen to event, send FCM message

**Notification Permissions:**
- On first launch: request notification permission
- User can disable notifications in settings
- Do not spam (max 1 notification per hour per load)

**Success Criteria:**
- ✅ Notification arrives within 5 seconds of event
- ✅ Tapping notification opens relevant load
- ✅ Notifications work in background (app not running)
- ✅ Clear, actionable messages

---

### 9. Settings & Profile
**Goal:** Driver manages account preferences

**Settings Screen:**
```
┌─────────────────────────────────┐
│ SETTINGS                        │
├─────────────────────────────────┤
│ PROFILE                         │
│ Name: John Smith                │
│ Phone: (614) 555-1234           │
│ License #: DL1234567            │
│ Vehicle: 2020 Volvo VNL         │
│                                 │
│ PREFERENCES                     │
│ ☑ Push Notifications Enabled    │ │
│ ☑ Location Services Enabled     │ │
│ ☐ Dark Mode                     │ │
│ Theme: [Light ▼]                │ │
│                                 │
│ DATA & CACHE                    │
│ Cache Size: 245 MB              │
│ [Clear Cache]                   │ │
│ Last Sync: 2 min ago            │ │
│ [Sync Now]                      │ │
│                                 │
│ ACCOUNT                         │
│ [Change Password]               │ │
│ [Logout]                        │ │
│                                 │
└─────────────────────────────────┘
```

**Features:**
- View profile (name, phone, license, vehicle)
- Enable/disable notifications
- Dark mode toggle
- Cache management (view size, clear)
- Force sync
- Change password
- Logout

**Success Criteria:**
- ✅ Settings persist across app restart
- ✅ Dark mode toggle immediately changes theme
- ✅ Cache clear removes local loads (user warned first)

---

### 10. Dark Mode
**Goal:** Reduce eye strain during night driving

**Implementation:**
- React Native Appearance API
- Colors defined in theme files (light + dark)
- Button: toggle in Settings
- Default: system preference (if available)

**Colors (Dark Mode):**
- Background: #1a1a1a
- Surface: #2a2a2a
- Text: #f0f0f0
- Primary: #4a9eff
- Danger: #ff6b6b

**Success Criteria:**
- ✅ All screens render correctly in dark mode
- ✅ No white text on white (accessibility)
- ✅ Toggle works immediately

---

## User Flows

### Flow 1: New Driver - First Login
```
Start
  ↓
[Login Screen]
  ↓
Enter Phone + Password
  ↓
Tap "Sign In"
  ↓
Salesforce OAuth Flow
  ↓
Request Permissions (Location, Camera, Notifications)
  ↓
[Load List Screen]
  ↓
End
```

### Flow 2: View Load & Check-In at Pickup
```
[Load List]
  ↓
Tap Load #1068
  ↓
[Load Detail Screen]
  ↓
Tap [CHECK IN AT PICKUP]
  ↓
[Check-In Confirmation]
  ↓
Tap [CHECK IN]
  ↓
Capture GPS + Timestamp
  ↓
Create Check_In__c in Salesforce
  ↓
Show "✓ Checked in"
  ↓
Auto-navigate back to [Load Detail]
  ↓
Show "Status: IN_TRANSIT"
  ↓
End
```

### Flow 3: Capture POD After Delivery
```
[Load Detail]
  ↓
Tap [CAPTURE POD]
  ↓
[POD Screen - Photo Step]
  ↓
Take Photo of Delivered Load
  ↓
Tap [NEXT]
  ↓
[POD Screen - Signature Step]
  ↓
Draw Receiver Signature
  ↓
Enter Receiver Name
  ↓
Tap [NEXT]
  ↓
[POD Screen - Condition Step]
  ↓
Select Delivery Condition (Good/Damage/Refused)
  ↓
Add Optional Notes
  ↓
Tap [SUBMIT POD]
  ↓
Create POD__c Record + Upload Photo to Salesforce
  ↓
Show "✓ POD Submitted"
  ↓
Update Load Status → DELIVERED
  ↓
End
```

### Flow 4: Offline Check-In → Online Sync
```
[Load Detail - Offline]
  ↓
Tap [CHECK IN AT PICKUP]
  ↓
[Check-In Confirmation]
  ↓
Tap [CHECK IN]
  ↓
Capture GPS + Timestamp
  ↓
App detects: No internet
  ↓
Queue Check_In to Realm (synced: false)
  ↓
Show "📌 Check-in queued"
  ↓
[Later: Device comes online]
  ↓
App detects: Online
  ↓
Auto-sync Check_In to Salesforce
  ↓
Mark "synced: true" in Realm
  ↓
Show "✓ Synced"
  ↓
End
```

---

## Data Models

### Driver (Salesforce Contact)
```
Field               | Type      | Notes
────────────────────|───────────|──────────────────
Id                  | String    | Salesforce ID
Phone               | String    | Phone number (unique)
FirstName           | String    | First name
LastName            | String    | Last name
Title               | String    | Job title
Email               | String    | Email address
License_Number__c   | String    | Driver's license #
Vehicle__c          | Lookup    | Link to Equipment__c
Active__c           | Boolean   | Is driver active
Date_Hired__c       | Date      | Hire date
```

### Load__c (Salesforce Custom Object)
```
Field                    | Type      | Notes
─────────────────────────|───────────|────────────────────────
Id                       | String    | Salesforce ID
Name                     | String    | Load # (e.g., "1068")
Shipper_Account__c       | Lookup    | Link to Account (shipper)
Receiver_Account__c      | Lookup    | Link to Account (receiver)
Pickup_City__c           | String    | City
Pickup_State__c          | String    | State
Pickup_PostalCode__c     | String    | Zip
Pickup_Address__c        | String    | Full address
Pickup_ContactName__c    | String    | Contact person
Pickup_Phone__c          | String    | Contact phone
Pickup_DateTime__c       | DateTime  | Window start
Pickup_DateTime_End__c   | DateTime  | Window end
Pickup_ConfirmedAt__c    | DateTime  | When driver confirmed
Delivery_City__c         | String    | City
... (similar for Delivery)
Status__c                | Picklist | ASSIGNED|IN_TRANSIT|AT_DELIVERY|DELIVERED
Commodity__c             | String    | What's being shipped
Weight__c                | Number    | Weight in lbs
Equipment_Type__c        | String    | 53ft Dry Van, Flatbed, etc.
Assigned_Driver__c       | Lookup    | Link to Contact (driver)
Shipper_Rate__c          | Currency | Rate offered to carrier
Shipper_Reference__c     | String    | Shipper's tracking #
Special_Instructions__c  | Text      | Any special notes
BOL_PDF_URL__c           | String    | Link to BOL document
Is_Deleted__c            | Boolean   | Soft delete flag
Created_DateTime__c      | DateTime  | When load was created
```

### Check_In__c (Custom Object)
```
Field                    | Type      | Notes
─────────────────────────|───────────|────────────────────────
Id                       | String    | Salesforce ID
Load__c                  | Lookup    | Link to Load__c
Driver__c                | Lookup    | Link to Contact (driver)
Event_Type__c            | Picklist | 'pickup' | 'delivery'
Event_DateTime__c        | DateTime  | When check-in occurred
Latitude__c              | Number    | GPS latitude
Longitude__c             | Number    | GPS longitude
Location_Accuracy__c     | Number    | GPS accuracy in meters
Location_Geo__c          | Geolocation | Salesforce geolocation field
Source_System__c         | String    | 'driver_app'
External_Event_Id__c     | String    | UUID (de-dup key)
Synced_At__c             | DateTime  | When synced from app
```

### POD__c (Custom Object)
```
Field                     | Type      | Notes
──────────────────────────|───────────|────────────────────────
Id                        | String    | Salesforce ID
Load__c                   | Lookup    | Link to Load__c
Pod_DateTime__c           | DateTime  | When POD captured
Photo_Content_Document_Id | String    | Link to Salesforce file
Signature_Image_Url__c    | String    | URL to signature image
Receiver_Name__c          | String    | Person who signed
Receiver_Company__c       | String    | Company/location
Delivery_Condition__c     | Picklist | Good|MinorDamage|Refused|Other
Damage_Notes__c           | Text      | Details if damaged
Driver__c                 | Lookup    | Link to Contact (driver)
Source_System__c          | String    | 'driver_app'
External_Pod_Id__c        | String    | UUID (de-dup key)
Synced_At__c              | DateTime  | When synced from app
```

---

## API Specifications

### 1. Salesforce OAuth 2.0 Integration

**Endpoint:** `https://login.salesforce.com/services/oauth2/token`

**Request:**
```
POST /services/oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=password
&client_id={CONSUMER_KEY}
&client_secret={CONSUMER_SECRET}
&username={phone_number}
&password={password}
```

**Response:**
```json
{
  "access_token": "00Dxx0000000000!AQcAQH...",
  "instance_url": "https://kwb.salesforce.com",
  "id": "https://login.salesforce.com/id/00Dxx0000000000/005xx000001SJ1AAM",
  "token_type": "Bearer",
  "issued_at": "1617298765000",
  "signature": "bU+R...",
  "scope": "api",
  "expires_in": 86400
}
```

**Implementation (React Native):**
```javascript
const loginDriver = async (phone, password) => {
  const payload = {
    grant_type: 'password',
    client_id: SALESFORCE_CLIENT_ID,
    client_secret: SALESFORCE_CLIENT_SECRET,
    username: phone,
    password: password
  };
  
  const response = await fetch('https://login.salesforce.com/services/oauth2/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(payload).toString()
  });
  
  const json = await response.json();
  // Store access_token + instance_url in AsyncStorage
  // Set Authorization header for future API calls
  return { accessToken: json.access_token, instanceUrl: json.instance_url };
}
```

---

### 2. Fetch Driver Loads

**Endpoint:** `GET {instance_url}/services/data/v57.0/query`

**Request:**
```
GET /services/data/v57.0/query?q=SELECT+Id,Name,Shipper_Account__c,Pickup_City__c,...
Authorization: Bearer {access_token}
```

**SOQL Query:**
```sql
SELECT 
  Id, Name, Shipper_Account__c, Receiver_Account__c,
  Pickup_Address__c, Pickup_City__c, Pickup_State__c, Pickup_Phone__c,
  Pickup_DateTime__c, Pickup_DateTime_End__c,
  Delivery_Address__c, Delivery_City__c, Delivery_Phone__c,
  Delivery_DateTime__c, Delivery_DateTime_End__c,
  Status__c, Commodity__c, Weight__c, Equipment_Type__c,
  Shipper_Rate__c, Special_Instructions__c, BOL_PDF_URL__c
FROM Load__c
WHERE Assigned_Driver__c = '{driverId}'
  AND Status__c IN ('ASSIGNED', 'IN_TRANSIT', 'AT_DELIVERY')
ORDER BY Pickup_DateTime__c ASC
LIMIT 1000
```

**Response:**
```json
{
  "totalSize": 5,
  "done": true,
  "records": [
    {
      "attributes": {
        "type": "Load__c",
        "url": "/services/data/v57.0/sobjects/Load__c/a01xx0000000001AAA"
      },
      "Id": "a01xx0000000001AAA",
      "Name": "1068",
      "Shipper_Account__c": "a01xx0000000001AAA",
      "Pickup_City__c": "Toledo",
      ...
    }
  ]
}
```

---

### 3. Create Check-In Record

**Endpoint:** `POST {instance_url}/services/data/v57.0/sobjects/Check_In__c`

**Request:**
```json
POST /services/data/v57.0/sobjects/Check_In__c
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "Load__c": "a01xx0000000001AAA",
  "Driver__c": "003xx0000000001AAA",
  "Event_Type__c": "pickup",
  "Event_DateTime__c": "2026-03-27T09:17:00Z",
  "Latitude__c": 41.663,
  "Longitude__c": -83.555,
  "Location_Accuracy__c": 10.5,
  "Location_Geo__c": {
    "latitude": 41.663,
    "longitude": -83.555
  },
  "Source_System__c": "driver_app",
  "External_Event_Id__c": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response:**
```json
{
  "id": "a03xx0000000001AAA",
  "success": true,
  "created": true
}
```

---

### 4. Create POD Record + Upload Photo

**Step A: Create POD Record**
```json
POST /services/data/v57.0/sobjects/POD__c
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "Load__c": "a01xx0000000001AAA",
  "Driver__c": "003xx0000000001AAA",
  "Pod_DateTime__c": "2026-03-27T14:47:00Z",
  "Receiver_Name__c": "John Smith",
  "Receiver_Company__c": "Lowe's",
  "Delivery_Condition__c": "Good",
  "Damage_Notes__c": "None",
  "Source_System__c": "driver_app",
  "External_Pod_Id__c": "650e8400-e29b-41d4-a716-446655440001"
}
```

**Step B: Upload Photo (ContentDocument)**
```
POST /services/data/v57.0/sobjects/ContentVersion
Authorization: Bearer {access_token}
Content-Type: multipart/form-data

FormData:
  Title: "POD_1068_photo_2026-03-27.jpg"
  VersionData: (binary image)
  FirstPublishLocationId: {podRecordId} (from Step A)
```

---

### 5. Firebase Realtime Database - Load Assignment

**Database Path:**
```
/driverLoads/{driverId}/
  {loadId}: {
    "id": "a01xx0000000001AAA",
    "name": "1068",
    "shipper": "Scotts",
    "receiver": "Lowe's, Atlanta",
    "pickupTime": 1617298765000,
    "deliveryTime": 1617385165000,
    "status": "ASSIGNED"
  }
```

**Listener (React Native):**
```javascript
import { getDatabase, ref, onValue } from 'firebase/database';

const dbRef = ref(database, `/driverLoads/${driverId}`);
onValue(dbRef, (snapshot) => {
  const loads = snapshot.val();
  // Update load list when new assignment arrives
  updateLoadList(loads);
});
```

---

## UI/UX Specifications

### Color Palette
| Element | Light Mode | Dark Mode |
|---------|-----------|-----------|
| Background | #ffffff | #1a1a1a |
| Surface | #f5f5f5 | #2a2a2a |
| Primary Text | #000000 | #f0f0f0 |
| Secondary Text | #666666 | #b0b0b0 |
| Primary Button | #4a9eff | #4a9eff |
| Success | #28a745 | #66bb6a |
| Warning | #ff9800 | #ffb74d |
| Danger | #dc3545 | #ff6b6b |
| Border | #e0e0e0 | #3a3a3a |

### Typography
- **Headline 1:** 32px, bold, primary text
- **Headline 2:** 24px, semibold, primary text
- **Body Text:** 16px, regular, primary text
- **Small Text:** 12px, regular, secondary text
- **Button Text:** 14px, semibold, white

### Spacing
- **Padding (default):** 16px
- **Margin (default):** 16px
- **Card spacing:** 12px
- **Button height:** 48px (touch-friendly)

### Responsive Design
- **Mobile (375px-600px):** Single column, full-width buttons
- **Tablet (600px-1024px):** Two-column layout where applicable
- **Landscape:** Adjust spacing, optimize for smaller height

### Accessibility (WCAG AA)
- Minimum text size: 14px
- Color contrast ratio: 4.5:1 (normal text), 3:1 (large text)
- Button minimum size: 44x44px (touch targets)
- All buttons: clear labels (no icon-only buttons)
- Icons: paired with text labels
- Form fields: associated labels

---

## Technical Requirements

### React Native Configuration
```json
{
  "name": "kwb-driver-app",
  "version": "1.0.0",
  "dependencies": {
    "react": "^18.2.0",
    "react-native": "^0.71.0",
    "@react-native-async-storage/async-storage": "^1.17.0",
    "@react-native-camera-roll/camera-roll": "^5.0.0",
    "@react-native-firebase/app": "^17.0.0",
    "@react-native-firebase/auth": "^17.0.0",
    "@react-native-firebase/database": "^17.0.0",
    "@react-native-firebase/messaging": "^17.0.0",
    "react-native-camera": "^4.2.0",
    "react-native-geolocation-service": "^5.3.0",
    "react-native-maps": "^1.3.1",
    "react-native-signature-canvas": "^4.4.0",
    "realm": "^12.0.0",
    "axios": "^1.4.0"
  }
}
```

### Firebase Configuration
```javascript
// firebase.config.js
export const firebaseConfig = {
  apiKey: "AIzaSyDxxxxxxxxxx",
  authDomain: "kwb-driver-app.firebaseapp.com",
  projectId: "kwb-driver-app",
  storageBucket: "kwb-driver-app.appspot.com",
  messagingSenderId: "123456789012",
  appId: "1:123456789012:android:abcdef1234567890"
};

// Initialize Firebase
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getDatabase } from 'firebase/database';
import { getMessaging } from 'firebase/messaging';

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const database = getDatabase(app);
export const messaging = getMessaging(app);
```

### Salesforce Configuration
```javascript
// salesforce.config.js
export const SALESFORCE_CLIENT_ID = 'process.env.SALESFORCE_CLIENT_ID';
export const SALESFORCE_CLIENT_SECRET = 'process.env.SALESFORCE_CLIENT_SECRET';
export const SALESFORCE_USERNAME_FIELD = 'Phone'; // Use phone as username
```

### API Base URLs
```javascript
export const API_ENDPOINTS = {
  SALESFORCE_LOGIN: 'https://login.salesforce.com/services/oauth2/token',
  SALESFORCE_API: '{instance_url}/services/data/v57.0',
  GOOGLE_MAPS_API: 'https://maps.googleapis.com/maps/api',
  GOOGLE_GEOCODE_API: 'https://maps.googleapis.com/maps/api/geocode/json'
};
```

---

## Offline Mode Specification

### Realm Database Schema
```javascript
export const DriverSchema = {
  name: 'Driver',
  primaryKey: 'userId',
  properties: {
    userId: 'string',
    phone: 'string',
    name: 'string',
    accessToken: 'string',
    instanceUrl: 'string',
    tokenExpiresAt: 'date'
  }
};

export const LoadSchema = {
  name: 'Load',
  primaryKey: 'id',
  properties: {
    id: 'string',
    name: 'string',
    shipperName: 'string',
    receiverName: 'string',
    pickupAddress: 'string',
    pickupPhone: 'string',
    pickupDateTime: 'date',
    deliveryAddress: 'string',
    deliveryPhone: 'string',
    deliveryDateTime: 'date',
    status: 'string',
    commodity: 'string',
    weight: 'int',
    equipmentType: 'string',
    specialInstructions: 'string',
    bolPdfUrl: 'string',
    cachedAt: 'date'
  }
};

export const CheckInSchema = {
  name: 'CheckIn',
  primaryKey: 'id',
  properties: {
    id: 'string',
    loadId: 'string',
    eventType: 'string', // 'pickup' | 'delivery'
    timestamp: 'date',
    latitude: 'double',
    longitude: 'double',
    accuracy: 'double',
    externalEventId: 'string',
    synced: 'bool',
    syncAttempts: 'int',
    lastSyncError: 'string?'
  }
};

export const PODSchema = {
  name: 'POD',
  primaryKey: 'id',
  properties: {
    id: 'string',
    loadId: 'string',
    photoUri: 'string',
    signatureUri: 'string',
    receiverName: 'string',
    condition: 'string',
    notes: 'string?',
    timestamp: 'date',
    externalPodId: 'string',
    synced: 'bool',
    syncAttempts: 'int',
    lastSyncError: 'string?'
  }
};
```

### Sync Queue Management
```javascript
// Track pending operations
export const SyncQueueSchema = {
  name: 'SyncQueue',
  properties: {
    id: 'string', // UUID
    operation: 'string', // 'create_check_in' | 'create_pod' | 'upload_photo'
    targetId: 'string', // loadId or podId
    payload: 'string', // JSON stringified
    createdAt: 'date',
    status: 'string', // 'pending' | 'syncing' | 'success' | 'error'
    retryCount: 'int',
    lastError: 'string?',
    nextRetryAt: 'date?'
  }
};

// Sync Process
async function syncPendingOperations() {
  const realm = await getRealm();
  const queue = realm.objects('SyncQueue').filtered("status = 'pending'");
  
  for (const operation of queue) {
    try {
      await executeOperation(operation);
      realm.write(() => {
        operation.status = 'success';
      });
    } catch (error) {
      realm.write(() => {
        operation.retryCount += 1;
        operation.status = 'error';
        operation.lastError = error.message;
        operation.nextRetryAt = new Date(Date.now() + Math.pow(2, operation.retryCount) * 5000); // Exponential backoff
      });
    }
  }
}
```

---

## Security Requirements

### Data Protection
- All API calls use HTTPS (TLS 1.2+)
- Session tokens stored in secure AsyncStorage (encrypted on device)
- Sensitive data (access token, GPS) NOT logged
- OAuth 2.0 for Salesforce authentication (no storing passwords)
- JWT tokens include exp claim (auto-logout after 24h)

### Permissions
- Location: Requested on first load detail view
- Camera: Requested on first POD screen
- Notifications: Requested on app launch
- Contact/Phone: Built-in (standard phone dial)

### API Security
- All requests include Authorization header: `Bearer {access_token}`
- Requests include User-Agent: `KWB-DriverApp/1.0`
- Implement certificate pinning (prevent MITM attacks)
- Rate limit API calls (max 100 requests/minute)

### Data Validation
- Phone number validation: 10 digits, US format
- GPS accuracy: reject if > 100 meters error
- Photo file size: max 5 MB (enforced before upload)
- Signature data: validate format before saving

---

## Performance Targets

### Load Times
- App startup: < 3 seconds
- Login: < 5 seconds (on fast 4G)
- Load list fetch: < 2 seconds (cached locally)
- Load detail: < 1 second
- Check-in: < 10 seconds (including GPS capture)
- POD submission: < 30 seconds (if online)

### Memory Usage
- App baseline: < 80 MB
- Load list (25 items): < 20 MB
- With POD photos (5 photos): < 200 MB

### Battery Impact
- Idle (app backgrounded): < 1% per hour
- Driving (GPS + background sync): < 5% per hour

### Network Usage
- Load list: ~200 KB
- Check-in submission: ~5 KB
- POD submission: ~500 KB (photo), ~10 KB (metadata)

---

## Testing Strategy

### Unit Tests
- Auth flow (login/logout, token refresh)
- Load list filtering + pagination
- Offline queue (add, sync, retry)
- GPS capture + accuracy validation
- Photo compression + upload
- Signature capture

### Integration Tests
- End-to-end: Login → View Load → Check-in → POD → Sync
- Offline: offline check-in → online sync
- Network failure: retry on timeout
- App background: background sync on resume

### E2E Tests (Manual + Automation)
- Real iOS device (iPhone 12+)
- Real Android device (Samsung Galaxy S21+)
- Various network conditions (3G, 4G, WiFi, offline)
- Real Salesforce org (dev or sandbox)

### Performance Tests
- Load list: 1000+ loads (pagination)
- POD photo: multiple uploads in sequence
- Offline mode: 100+ pending operations

---

## Success Criteria

✅ Builds on iOS simulator + Android emulator  
✅ Builds on real iOS device (iPhone 12+)  
✅ Builds on real Android device (Samsung Galaxy S21+)  
✅ Driver can login with phone + password  
✅ Driver sees assigned loads (list auto-refreshes)  
✅ Driver can view full load detail  
✅ Check-in captures GPS + timestamp  
✅ POD captures photo + signature  
✅ POD syncs to Salesforce (linked to Load)  
✅ Works offline (loads cached, operations queued)  
✅ Sync works when coming online  
✅ No data loss (even if app crashes)  
✅ HOS status displays  
✅ Dark mode works  
✅ All buttons are touch-friendly (44x44px minimum)  
✅ WCAG AA compliance (color contrast, labels)  
✅ Unit tests > 80% coverage  
✅ Integration tests pass  
✅ Manual testing on real devices passes  
