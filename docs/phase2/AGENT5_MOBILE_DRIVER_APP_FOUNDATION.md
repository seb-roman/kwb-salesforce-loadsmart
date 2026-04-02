# KWB Logistics — Mobile Driver App Foundation

**Agent:** Agent 5  
**Phase:** Phase 1 Foundation (weeks 4-5), Phase 2 Full Build (weeks 6-9)  
**Status:** Design-Ready (4/3/2026)

---

## Executive Summary

The driver app is a **native mobile application (iOS + Android)** that enables drivers to:
- View assigned loads + delivery details
- Check in at pickup/delivery (timestamp + GPS)
- Capture proof-of-delivery (photo + signature)
- Access shipper/receiver contact info
- View HOS (Hours of Service) status
- Work offline (cache data locally, sync when online)

**Phase 1 Focus:** MVP (minimum viable). Features: login, view load, check-in, POD capture.  
**Phase 2 Expansion:** Geofencing, push notifications, chat with dispatcher, vehicle inspection.

---

## Tech Stack Recommendation

### Option A: React Native (RECOMMENDED)

**Pros:**
- Single codebase (iOS + Android)
- 80% code sharing between platforms
- Faster time-to-market (6 weeks vs 12 weeks for native)
- Hot reload (faster development iteration)
- Large community, many UI libraries (React Native Paper, NativeBase)

**Cons:**
- Slightly lower performance than native (acceptable for this app)
- Fewer advanced features (but not needed for Phase 1)

**Cost:** $60K-80K development

**Recommended if:** KWB wants speed and cost efficiency (likely)

---

### Option B: Flutter

**Pros:**
- Even faster compilation than React Native
- Better performance (Dart VM is fast)
- Excellent UI consistency iOS/Android

**Cons:**
- Smaller ecosystem of Salesforce integrations
- Fewer drivers (labor market)

**Cost:** $70K-90K development

**Recommended if:** Performance is critical (it's not for this app)

---

### Option C: Native iOS + Android

**Pros:**
- Maximum performance
- Access to all native APIs

**Cons:**
- Twice the development cost and time
- Harder to maintain (2 codebases)

**Cost:** $120K-150K development

**Recommended if:** Budget unlimited (not realistic for KWB)

---

### **FINAL RECOMMENDATION: React Native**

**Rationale:**
- Fastest time-to-market (MVP in 6 weeks)
- Lower cost
- Large Salesforce community (many examples)
- Can pivot to Flutter or native later if performance becomes issue

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│ DRIVER APP (React Native)                       │
├─────────────────────────────────────────────────┤
│                                                 │
│ ┌──────────────────────┐  ┌──────────────────┐ │
│ │ UI Layer (Screens)   │  │ State Management │ │
│ │ • Login              │  │ (Redux/Context)  │ │
│ │ • Load List          │  │                  │ │
│ │ • Load Detail        │  │ ┌──────────────┐ │ │
│ │ • Check-in           │  │ │ Offline Cache│ │ │
│ │ • POD Capture        │  │ │ (SQLite/Realm)
│ │                      │  │ └──────────────┘ │ │
│ └──────────────────────┘  └──────────────────┘ │
│                                                 │
│ ┌──────────────────────┐  ┌──────────────────┐ │
│ │ APIs Layer           │  │ Device Services  │ │
│ │ • Salesforce REST    │  │ • GPS            │ │
│ │ • Firebase (auth)    │  │ • Camera         │ │
│ │ • Google Maps        │  │ • File Storage   │ │
│ └──────────────────────┘  └──────────────────┘ │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Backend Services

**Salesforce:**
- REST API (authenticate driver, fetch loads, submit check-ins, upload POD)
- Platform Events (push load assignments in real-time)
- Files API (upload POD photo + signature)

**Firebase:**
- Authentication (phone/email login, MFA)
- Realtime Database (sync load assignments, check-in ACKs)
- Cloud Storage (backup POD uploads)

**Google Maps:**
- Directions API (navigation from app to pickup/delivery)
- Geocoding API (convert GPS → address)

**AWS S3:**
- Store POD images long-term (archived from Salesforce Files after 90 days)

---

## Phase 1 Features (MVP, 6 weeks)

### 1. Driver Authentication

**Login Screen:**
```
┌─────────────────────────┐
│  KWB DRIVER APP         │
├─────────────────────────┤
│                         │
│  Phone: [____________]  │
│  Password: [________]   │
│                         │
│  [Sign In]              │
│                         │
│  Forgot Password?       │
│  [Create Account]       │
│                         │
└─────────────────────────┘
```

**Implementation:**
- Phone number as username (easier for drivers than email)
- 12-char alphanumeric password
- Salesforce OAuth 2.0 flow (drivers login via Salesforce)
- OR Firebase Auth (simpler, non-Salesforce drivers)
- Session token stored locally (valid 24h, auto-refresh)

---

### 2. Load List & Assignment

**Load List Screen:**
```
┌──────────────────────────────────┐
│ MY LOADS                         │
├──────────────────────────────────┤
│ [Assigned]  [In Transit]         │
│                                  │
│ Load: 1068                       │
│ Shipper: Scotts                  │
│ Receiver: Lowe's, Atlanta        │
│ Pickup: Today 9 AM               │
│ Delivery: Tomorrow 2 PM          │
│                                  │
│ ┌──────────────────────────────┐ │
│ │ [View Details]               │ │
│ └──────────────────────────────┘ │
│                                  │
│ Load: 1067                       │
│ Shipper: Home Depot              │
│ Receiver: Miami, FL              │
│ Status: DELIVERED                │
│ [View Details]                   │
│                                  │
└──────────────────────────────────┘
```

**Features:**
- Auto-refresh when new load assigned (Firebase Realtime DB listener)
- Swipe between tabs: Assigned | In Transit | Delivered
- Click load → detail view
- Background worker: check for new assignments every 2 minutes

---

### 3. Load Detail View

```
┌────────────────────────────────────┐
│ Load 1068                          │
├────────────────────────────────────┤
│                                    │
│ PICKUP:                            │
│ Scotts Miracle-Gro                 │
│ 123 Industrial Blvd, Toledo OH     │
│ Window: Today 9 AM - 2 PM          │
│ Phone: (419) 555-1234              │
│ [NAVIGATE]                         │
│ [CALL SHIPPER]                     │
│                                    │
│ DELIVERY:                          │
│ Lowe's Distribution                │
│ 456 Distribution Dr, Atlanta GA    │
│ Window: Tomorrow 12 PM - 4 PM      │
│ Phone: (404) 555-5678              │
│ [NAVIGATE]                         │
│ [CALL RECEIVER]                    │
│                                    │
│ COMMODITY:                         │
│ Mulch/Soil Bags                    │
│ Weight: 42,000 lbs                 │
│                                    │
│ INSTRUCTIONS:                      │
│ "Tarped load. Shipper has dock."   │
│ "Receiver requires appointment."   │
│                                    │
│ [LOAD DETAILS PDF]                 │
│                                    │
│ [CHECK IN AT PICKUP]               │
│                                    │
└────────────────────────────────────┘
```

**Features:**
- Contact numbers (shipper + receiver) visible (no manual lookup)
- [NAVIGATE] → Google Maps deep link (directions to address)
- [CALL] → phone dial (one tap)
- [LOAD DETAILS] → open BOL/rate confirmation PDF (cached locally)
- HOS status indicator (how many hours left: "5h remaining")
- Check-in button at bottom (visible, always accessible)

---

### 4. Check-In at Pickup/Delivery

**Check-In Screen:**
```
┌──────────────────────────────────┐
│ CHECK IN AT PICKUP                │
├──────────────────────────────────┤
│                                  │
│ Load: 1068                       │
│ Location: Scotts Miracle-Gro    │
│ 123 Industrial Blvd              │
│                                  │
│ Current Time: 9:17 AM            │
│ Window: 9 AM - 2 PM ✓            │
│ [On Time]                        │
│                                  │
│ [CHECK IN]  [CANCEL]             │
│                                  │
│ GPS will be recorded with        │
│ check-in timestamp.              │
│                                  │
└──────────────────────────────────┘
```

**On Check-In:**
1. Capture timestamp (user's device time)
2. Capture GPS location (latitude, longitude, accuracy)
3. Post to Salesforce: create Tracking_Update__c record
4. Local storage: mark load as "Pickup_Complete"
5. Notification: "✓ Checked in. Time: 9:17 AM"
6. Sync: if offline, queue check-in → sync when online

**SOQL Record Created:**
```
Tracking_Update__c
  load__c: 1068
  event_type__c: 'arrived_at_pickup'
  event_datetime__c: 2026-03-27T09:17:00Z
  latitude__c: 41.663
  longitude__c: -83.555
  location_geo__c: GEOLOCATION(41.663, -83.555)
  source_system__c: 'driver_app'
  external_event_id__c: UUID (de-dup key)
```

---

### 5. Proof of Delivery (POD) Capture

**POD Screen:**
```
┌──────────────────────────────────┐
│ PROOF OF DELIVERY                 │
├──────────────────────────────────┤
│ Load: 1068                       │
│ Delivery at: Lowe's Distribution │
│                                  │
│ 1. TAKE PHOTO                    │
│ [📷 CAMERA]  [📸 UPLOAD]         │
│ (photo of delivered load)        │
│                                  │
│ Photos added: 1                  │
│ ┌──────────────────────────────┐ │
│ │ [Truck at Lowe's dock]       │ │
│ │ Time: 2:47 PM                │ │
│ │ [Remove] [Add Another]       │ │
│ └──────────────────────────────┘ │
│                                  │
│ 2. SIGNATURE                     │
│ Receiver signature:              │
│ ┌──────────────────────────────┐ │
│ │                              │ │
│ │    [Draw Signature Here]     │ │
│ │                              │ │
│ └──────────────────────────────┘ │
│ [Clear]  [Accept]                │
│                                  │
│ Name (printed): John Smith       │ │
│ Company: Lowe's                  │ │
│ Time: 2:47 PM                    │ │
│                                  │
│ 3. CONDITION                     │
│ Condition: [Good ▼]              │
│ [Good] [Minor Damage] [Refused]  │
│ Notes: ________________          │ │
│                                  │
│ [SUBMIT POD]                     │ │
│                                  │
└──────────────────────────────────┘
```

**Implementation:**
- **Camera:** React Native react-native-camera
- **Photo Upload:** Compress image (80% quality, max 2MB), store locally
- **Signature:** React Native react-native-signature-canvas
- **Offline:** If offline, save POD locally → sync when online
- **Backup:** Save to device storage (SD card) as backup

**On POD Submit:**
1. Compress photo (if not already)
2. Create ContentDocument + ContentVersion in Salesforce
3. Create POD__c record with link to photo + signature
4. Update Load status → "pod_captured"
5. Local notification: "✓ POD submitted"
6. Driver sees "Next: Await dispatch for new load"

---

### 6. HOS (Hours of Service) Status

**HOS Display (on Load Detail view):**
```
HOS Status:
Driving: 6h 15m (out of 11h limit)
On Duty: 8h 30m (out of 14h limit)
Next Reset: 3/28 @ 10:00 AM

⚠️ Caution: 4h 45m remaining before
   mandatory rest break.
```

**Implementation:**
- Fetch ELD data (Motive API, Geotab API)
- Display read-only (no edit capability)
- Warning threshold: if < 5h remain, show warning
- Data synced once per day (not real-time) to save bandwidth

---

### 7. Offline Mode

**What Works Offline:**
- Load list (cached, shows last-synced loads)
- Load detail (full BOL, shipper/receiver info)
- Check-in (timestamp, GPS captured, queued for sync)
- POD capture (photos stored locally, queued)
- Contact info (shipper/receiver phone, address)

**What Requires Online:**
- Fetch new load assignments
- Real-time location tracking (if enabled)
- Download new BOL/rate confirmation (if updated)

**Sync Strategy:**
- Launch app → check online status
- If online: sync all queued check-ins, PODs, tracking events
- If offline: queue operations, show "Pending Sync" badge
- Auto-sync every 5 min if online
- Full sync on app resume (backgrounded → foreground)

**Data Storage:**
- Realm (cross-platform SQLite) for structured data
- React Native File System for photos/PDFs
- AsyncStorage for session tokens, preferences

---

## Phase 2 Features (Weeks 6-9)

### 1. Geofencing

**What:** Auto-detect when driver arrives at/departs pickup/delivery  
**Implementation:** react-native-geolocation + Google Maps Geofence API  
**Behavior:** "You're at Scotts" → auto-pop "Check In?" prompt

### 2. Push Notifications

**What:** "New load assigned" → push notification to driver  
**Implementation:** Firebase Cloud Messaging (FCM)  
**Scenarios:**
- New load assigned: "Load 1069 assigned. Pickup at Scotts, 9 AM tomorrow."
- Exception alert: "Your delivery is 2h late. Call dispatcher?"
- Message from dispatcher: "Mike, customer asking for ETA update."

### 3. Chat with Dispatcher

**What:** Bi-directional messaging (driver ↔ dispatcher)  
**Implementation:** Firebase Realtime DB or Salesforce Chatter API  
**UI:**
```
┌──────────────────────────────────┐
│ DISPATCHER CHAT                  │
├──────────────────────────────────┤
│ Dispatcher: Need ETA update?    │
│ Driver: Arriving 2:30 PM. Traffic│
│ Dispatcher: Receiver confirmed? │
│ Driver: Yep, ready to unload    │
│ [Reply field] [Send]             │
└──────────────────────────────────┘
```

### 4. Vehicle Inspection

**What:** Pre-trip / post-trip inspection checklist  
**Features:**
- Checklist: lights, tires, brakes, coupling, cargo securement
- Take photos of any defects
- Submit inspection report
- Integration with Equipment__c maintenance record

---

## Development Timeline

### Phase 1 (6 weeks, $60K)

| Week | Deliverable |
|------|-------------|
| Week 1 | Project setup (React Native, Firebase config, Salesforce auth) |
| Week 2 | Login screen + auth flow |
| Week 3 | Load list + detail screens (static mockups) |
| Week 4 | Check-in + POD capture (backend integration) |
| Week 5 | Offline sync, testing, bug fixes |
| Week 6 | iOS + Android builds, app store submission, pilot with 5 drivers |

### Phase 2 (4 weeks, additional $20K)

| Week | Feature |
|------|---------|
| Week 7 | Geofencing + push notifications |
| Week 8 | Dispatcher chat |
| Week 9 | Vehicle inspection, performance optimization |
| Week 10 | Full QA, rollout to all drivers |

---

## Testing Strategy

### Unit Tests
- Auth flow (login/logout)
- Offline queue (add check-in, sync when online)
- GPS capture (location accuracy)

### Integration Tests
- End-to-end flow: login → view load → check-in → POD → load syncs to Salesforce
- Offline scenario: app offline → check-in captured → comes online → data syncs

### Device Testing
- iPhone 12 (iOS 15+)
- Samsung Galaxy S21 (Android 12+)
- iPad (7-inch, 10-inch tablets)
- Various network conditions (4G, WiFi, no connection)

### Pilot Program
- Week 6: Release to 5 experienced drivers
- Week 7: Gather feedback, fix critical bugs
- Week 8: Expand to 15 drivers
- Week 9: Rollout to all drivers (50+ total)

---

## Acceptance Criteria (Phase 1)

✅ Driver can login with phone + password  
✅ Driver sees assigned loads (list auto-refreshes)  
✅ Driver can view full load detail (shipper, receiver, commodity)  
✅ Check-in records timestamp + GPS  
✅ POD capture: photo + signature + condition  
✅ POD syncs to Salesforce (createsPOD__c + updates Load)  
✅ Works offline (loads cached, check-in queued)  
✅ Sync on online (all queued data uploads)  
✅ HOS status displayed (read-only)  
✅ iOS + Android builds in app stores  
✅ Tested on 3 devices (2 phones, 1 tablet)  
✅ Pilot with 5 drivers, feedback collected  

---

**Status:** DESIGN-READY (4/3/2026)  
**Estimated Dev Time:** Phase 1 = 6 weeks, Phase 2 = 4 weeks (total 10 weeks)  
**Cost Estimate:** Phase 1 = $60K, Phase 2 = $20K
