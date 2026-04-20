# KWB Mobile Driver App — Technical Architecture

**Agent:** Agent 5  
**Date:** April 2, 2026  
**Audience:** Development Team, DevOps  

---

## Table of Contents
1. [System Overview](#system-overview)
2. [Technology Stack](#technology-stack)
3. [Project Structure](#project-structure)
4. [Data Flow Architecture](#data-flow-architecture)
5. [Authentication Flow](#authentication-flow)
6. [Offline Sync Architecture](#offline-sync-architecture)
7. [Module Specifications](#module-specifications)
8. [Build & Deployment](#build--deployment)

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    KWB DRIVER APP SYSTEM                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ React Native Mobile App (iOS + Android)                  │   │
│  │ • UI Layer (Screens)                                     │   │
│  │ • State Management (Redux/Context)                       │   │
│  │ • Local Data Cache (Realm)                               │   │
│  │ • Device Services (GPS, Camera, Notifications)           │   │
│  └──────────────────────────────────────────────────────────┘   │
│         ↓                               ↓                        │
│  ┌──────────────────────┐  ┌──────────────────────────────┐    │
│  │ Salesforce REST API  │  │ Firebase Services            │    │
│  │ • OAuth Login        │  │ • Realtime Database          │    │
│  │ • Load Query         │  │ • Cloud Messaging (Notif)    │    │
│  │ • Check-In Create    │  │ • Cloud Storage              │    │
│  │ • POD Upload         │  │ • Auth (backup)              │    │
│  └──────────────────────┘  └──────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

### Frontend (React Native)
| Layer | Technology | Purpose |
|-------|-----------|---------|
| **UI Framework** | React Native 0.71+ | Cross-platform mobile UI |
| **State Management** | Redux Toolkit | Global state (loads, auth, sync status) |
| **Navigation** | React Navigation | Screen navigation + deep linking |
| **Local Storage** | **Realm** | Offline data cache (structured data) |
| **File Storage** | React Native File System | Photos, signatures, PDFs |
| **Camera** | react-native-camera | Photo capture for POD |
| **Signature** | react-native-signature-canvas | Signature capture |
| **Geolocation** | react-native-geolocation-service | GPS capture |
| **Maps** | react-native-maps | Map display, navigation |
| **HTTP Client** | Axios | API requests (with interceptors) |
| **Async Storage** | @react-native-async-storage | Session tokens, preferences |
| **Dark Mode** | React Native Appearance | Theme switching |

### Backend Services
| Service | Purpose | Configuration |
|---------|---------|---|
| **Salesforce** | CRM, Load data, Auth | OAuth 2.0, REST API v57.0 |
| **Firebase** | Realtime messaging, Auth | Realtime DB, Cloud Messaging, Storage |
| **Google Maps** | Navigation, Geocoding | Maps API, Directions API |
| **AWS S3** | Long-term photo storage | Backup from Salesforce Files |

### Build & Deployment
| Tool | Purpose |
|------|---------|
| **Expo** | Rapid development, OTA updates |
| **Xcode** | iOS build + deployment |
| **Android Studio** | Android build + deployment |
| **Firebase CLI** | Firebase project management |
| **EAS (Expo Application Services)** | Cloud builds for iOS/Android |

---

## Database Technology: Realm vs SQLite (Architectural Decision)

### Why Realm Over SQLite?

This architecture uses **Realm** (not SQLite) for offline data persistence. While both are valid embedded databases for React Native, Realm was specifically chosen for this logistics use case based on the following criteria:

#### 1. **Type Safety & Schema Validation** ✅
- **Realm:** Enforces strict TypeScript schemas at compile-time. All object properties are validated.
- **SQLite:** Raw column types; data validation happens in application code.
- **Impact for KWB:** Prevents data corruption when syncing POD photos, GPS coordinates, and timestamps. Type mismatch errors caught early, not in production.

```typescript
// Realm: Type-safe schema
class Load extends Realm.Object<Load> {
  id!: string;
  loadName!: string;
  pickupLatitude!: number;  // Must be number, always
  timestamp!: Date;          // Must be ISO date, always
}

// SQLite: No type checking
const result = db.query('SELECT * FROM load');
// result.pickupLatitude could be string, number, null—no guarantee
```

#### 2. **Reactive Updates & Live Queries** ✅
- **Realm:** Subscriptions to objects auto-notify listeners when data changes. Perfect for real-time sync status updates.
- **SQLite:** Requires manual polling or observer pattern.
- **Impact for KWB:** When the app syncs a POD to Salesforce, the UI automatically updates without explicit state dispatch. Reduces race conditions during offline → online transitions.

```typescript
// Realm: Reactive
const loads = realm.objects('Load').filtered("status == 'ASSIGNED'");
loads.addListener((obj, changes) => {
  console.log('Loads changed:', changes.insertedIndices);
  // UI automatically re-renders
});

// SQLite: Manual refresh needed
db.query('SELECT * FROM load WHERE status = "ASSIGNED"');
// Dev must manually call setLoads() dispatch to notify UI
```

#### 3. **Built-In Sync Capability** ✅
- **Realm:** Realm Cloud Sync (optional) can sync data bi-directionally with backend.
- **SQLite:** No native sync; must build custom sync layer.
- **Impact for KWB:** Future enhancements (e.g., real-time load assignments) can leverage Realm Sync without architectural changes. Today, manual sync works; tomorrow, automatic sync is available.

#### 4. **Offline Sync Queue Efficiency** ✅
- **Realm:** Transactions are ACID-compliant. Batch operations (e.g., insert 100 PODs) are atomic.
- **SQLite:** Transactions work, but Realm's performance is optimized for React Native (no cross-process overhead).
- **Impact for KWB:** When driver goes offline and captures 5 PODs, all 5 are saved atomically. No partial data loss if app crashes during save.

#### 5. **Better Performance for Complex Queries** ✅
- **Realm:** Indexes are automatic on lookup fields. Queries on related objects (load → check-ins → PODs) are optimized.
- **SQLite:** Indexes must be manually created; JOIN performance depends on query planning.
- **Impact for KWB:** Querying "all PODs for this load in the last 2 hours" is consistently fast even with 1000+ PODs cached locally.

#### 6. **Offline-First Sync Architecture** ✅
- **Realm:** Transactions + reactive updates = ideal for the sync queue pattern used in this app.
  - Queue operations atomically
  - Retry failed operations
  - Notify UI of sync progress in real-time
- **SQLite:** Possible but requires more custom code.

### Trade-offs Acknowledged

| Aspect | Realm | SQLite |
|--------|-------|--------|
| **Learning Curve** | Steeper (new API) | Flatter (familiar SQL) |
| **App Bundle Size** | +2.5 MB | +1 MB |
| **Ecosystem** | Growing, newer | Mature, battle-tested |
| **Cross-Platform Support** | Excellent (iOS, Android, Web) | Excellent (iOS, Android, web) |

**Decision:** The 1.5 MB size increase is acceptable for the benefits of type safety, reactive updates, and built-in sync. Offline logistics is the #1 feature for KWB drivers; Realm is optimized for this use case.

### Implementation Notes

1. **Realm is imported in `src/database/realm.ts`** — single initialization point.
2. **All schemas defined in `src/database/schemas/`** — TypeScript-first.
3. **Realm queries wrapped in `src/database/queries/`** — abstraction layer.
4. **Sync queue uses Realm transactions** — atomic, no partial states.
5. **No hardcoded SQLite references** — all local DB references use Realm interface.

### Future Considerations

- **Realm Sync (Phase 3+):** If real-time sync becomes a requirement, Realm Cloud Sync can be enabled with minimal code changes.
- **Encryption:** Realm supports at-rest encryption; can be enabled via `encryptionKey` in realm config if PII encryption is mandated.

---

## Project Structure

```
kwb-driver-app/
├── src/
│   ├── screens/
│   │   ├── AuthStack/
│   │   │   ├── LoginScreen.tsx
│   │   │   ├── ForgotPasswordScreen.tsx
│   │   │   └── RegisterScreen.tsx
│   │   ├── LoadStack/
│   │   │   ├── LoadListScreen.tsx
│   │   │   ├── LoadDetailScreen.tsx
│   │   │   ├── CheckInScreen.tsx
│   │   │   └── PODScreen.tsx
│   │   └── SettingsStack/
│   │       ├── SettingsScreen.tsx
│   │       ├── ProfileScreen.tsx
│   │       └── CacheManagementScreen.tsx
│   │
│   ├── components/
│   │   ├── LoadCard.tsx
│   │   ├── StatusBadge.tsx
│   │   ├── ContactButton.tsx
│   │   ├── CheckInModal.tsx
│   │   ├── PODPhotoStep.tsx
│   │   ├── PODSignatureStep.tsx
│   │   ├── PODConditionStep.tsx
│   │   ├── HOSStatusBar.tsx
│   │   └── SyncIndicator.tsx
│   │
│   ├── services/
│   │   ├── salesforceService.ts
│   │   │   ├── loginDriver()
│   │   │   ├── fetchLoads()
│   │   │   ├── createCheckIn()
│   │   │   ├── createPOD()
│   │   │   └── uploadPhoto()
│   │   ├── firebaseService.ts
│   │   │   ├── initializeFirebase()
│   │   │   ├── setupNotifications()
│   │   │   ├── listenToLoadAssignments()
│   │   │   └── syncData()
│   │   ├── geolocationService.ts
│   │   │   └── captureGPS()
│   │   ├── storageService.ts
│   │   │   ├── savePhoto()
│   │   │   ├── getPhotos()
│   │   │   └── clearPhotos()
│   │   └── offlineSyncService.ts
│   │       ├── queueOperation()
│   │       ├── syncQueue()
│   │       └── retryFailedOperations()
│   │
│   ├── store/
│   │   ├── slices/
│   │   │   ├── authSlice.ts
│   │   │   ├── loadsSlice.ts
│   │   │   ├── checkInSlice.ts
│   │   │   ├── podSlice.ts
│   │   │   └── syncSlice.ts
│   │   ├── store.ts
│   │   └── hooks.ts
│   │
│   ├── database/
│   │   ├── realm.ts (Realm config)
│   │   ├── schemas/
│   │   │   ├── DriverSchema.ts
│   │   │   ├── LoadSchema.ts
│   │   │   ├── CheckInSchema.ts
│   │   │   ├── PODSchema.ts
│   │   │   └── SyncQueueSchema.ts
│   │   └── queries/
│   │       ├── driverQueries.ts
│   │       ├── loadQueries.ts
│   │       ├── checkInQueries.ts
│   │       └── podQueries.ts
│   │
│   ├── hooks/
│   │   ├── useAuth.ts
│   │   ├── useLoads.ts
│   │   ├── useOfflineSync.ts
│   │   ├── useGPS.ts
│   │   └── usePODCapture.ts
│   │
│   ├── utils/
│   │   ├── validation.ts
│   │   ├── formatting.ts
│   │   ├── imageCompression.ts
│   │   ├── errorHandling.ts
│   │   └── constants.ts
│   │
│   ├── navigation/
│   │   ├── RootNavigator.tsx
│   │   ├── AuthNavigator.tsx
│   │   ├── LoadNavigator.tsx
│   │   └── linking.ts (deep linking config)
│   │
│   ├── theme/
│   │   ├── colors.ts (light + dark)
│   │   ├── spacing.ts
│   │   ├── typography.ts
│   │   └── theme.ts (full theme object)
│   │
│   └── App.tsx (Main entry point)
│
├── __tests__/
│   ├── services/
│   │   ├── salesforceService.test.ts
│   │   ├── offlineSyncService.test.ts
│   │   └── geolocationService.test.ts
│   ├── store/
│   │   ├── authSlice.test.ts
│   │   ├── loadsSlice.test.ts
│   │   └── syncSlice.test.ts
│   ├── utils/
│   │   ├── validation.test.ts
│   │   └── imageCompression.test.ts
│   └── integration/
│       ├── authFlow.test.ts
│       ├── offlineSync.test.ts
│       └── podCapture.test.ts
│
├── .env.example
├── .env.production
├── app.json (Expo config)
├── eas.json (EAS builds config)
├── package.json
├── tsconfig.json
├── babel.config.js
└── README.md
```

---

## Data Flow Architecture

### Load Data Flow

```
┌─────────────────────────────────────────────────┐
│ 1. App Launches                                 │
│    • Check auth token in AsyncStorage           │
│    • If valid: fetch loads from Salesforce      │
│    • If expired: refresh token                  │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 2. Fetch Loads from Salesforce (Online)         │
│    GET /services/data/v57.0/query               │
│    SELECT * FROM Load__c WHERE Assigned_Driver__c = '{driverId}'
│    Response: List of loads (JSON)               │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 3. Cache Loads to Realm                         │
│    → LocalDatabase.insertLoads(loads)           │
│    → Realm: Load collection updated             │
│    → Realm: LoadList index created for queries  │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 4. Sync Redux Store                             │
│    → dispatch(loadSlice.setLoads(loads))        │
│    → Redux store: loads updated                 │
│    → React: all subscribed components re-render │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 5. Display Load List                            │
│    → LoadListScreen reads from Redux            │
│    → Maps loads to LoadCard components          │
│    → User sees list                             │
└──────────────────────────────────────────────────┘

Offline Fallback:
  If offline when loading:
    → Check Realm cache
    → Fetch from Realm (fast)
    → Sync to Redux (display last-cached data)
    → Show "Offline - Data may be stale" badge
    → When online: auto-refresh (30 sec delay)
```

### Check-In Flow

```
┌─────────────────────────────────────────────────┐
│ 1. User Taps "CHECK IN AT PICKUP"               │
│    • LoadDetailScreen dispatches action         │
│    • Show CheckInScreen modal                   │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 2. Capture GPS + Timestamp                      │
│    • Request GPS permission (if needed)         │
│    • Wait for GPS fix (show spinner)            │
│    • Capture: latitude, longitude, accuracy     │
│    • Timestamp: current device time (ISO 8601)  │
└──────────────────┬──────────────────────────────┘
                   ↓
                   ├─→ [OFFLINE]
                   │     └→ Queue to Realm SyncQueue
                   │        (status: pending)
                   │        └→ Continue to step 4
                   │
                   ├─→ [ONLINE]
                   │     └→ POST to Salesforce API
                   │        /sobjects/Check_In__c
                   │        Response: {id, success}
                   │        └→ Continue to step 4
                   ↓
┌─────────────────────────────────────────────────┐
│ 3. Save Check-In to Realm (Local DB)            │
│    • Create CheckIn record                      │
│    • Set synced: true (if API success)          │
│    • Set synced: false (if offline/error)       │
│    • Increment syncAttempts                     │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 4. Update Redux + UI                            │
│    • dispatch(checkInSlice.addCheckIn(...))     │
│    • dispatch(loadsSlice.updateLoadStatus(...)) │
│    • Show toast: "✓ Checked in" or "📌 Queued" │
│    • Close modal                                │
│    • Refresh LoadDetailScreen                   │
└──────────────────────────────────────────────────┘

On App Resume (Offline → Online):
  1. App backgrounded → foreground
  2. CheckNetworkState()
  3. If now online: triggerSync()
  4. Query Realm: SyncQueue where synced = false
  5. For each pending check-in:
     a. POST to Salesforce API
     b. On success: mark synced = true
     c. On failure: increment retryCount, retry in 5 min
  6. Show user: "✓ Synced X check-ins"
```

### POD Capture & Upload Flow

```
┌─────────────────────────────────────────────────┐
│ 1. User Taps "CAPTURE POD"                      │
│    • LoadDetailScreen → PODScreen               │
│    • Step 1: Photo capture                      │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 2. Capture Photo                                │
│    • Camera.takePicture() [react-native-camera]│
│    • Save to FileSystem.DocumentDirectoryPath  │
│    • Show preview to user                       │
│    • User confirms or retakes                   │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 3. Compress Photo                               │
│    • ImageResizer.resize()                      │
│    • Quality: 80%, maxWidth: 1080px             │
│    • Output size: ~1-2 MB                       │
│    • Save compressed to FileSystem              │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 4. Capture Signature                            │
│    • Step 2: Signature canvas                   │
│    • SignatureCanvas.readSignature()            │
│    • Export as PNG (data URI)                   │
│    • Convert to file + save to FileSystem       │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 5. Capture Delivery Condition                   │
│    • Step 3: Condition + notes                  │
│    • User selects: Good/Damage/Refused          │
│    • Optional notes: details about condition    │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 6. Submit POD (Online or Offline)               │
│                                                 │
│    IF ONLINE:                                   │
│    a. Create POD__c record in Salesforce        │
│       POST /sobjects/POD__c                     │
│    b. Upload photo to ContentVersion            │
│       POST /sobjects/ContentVersion             │
│    c. On success: mark synced = true            │
│       Update Load status → DELIVERED            │
│                                                 │
│    IF OFFLINE:                                  │
│    a. Queue to Realm SyncQueue:                 │
│       - operation: 'create_pod'                 │
│       - targetId: loadId                        │
│       - payload: {pod data, photo path}         │
│    b. Queue to SyncQueue:                       │
│       - operation: 'upload_photo'               │
│       - targetId: podId                         │
│       - payload: {photo path, file data}        │
│    c. Mark synced = false                       │
│    d. Show "📌 POD queued"                      │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 7. Refresh UI                                   │
│    • dispatch(podSlice.addPOD(...))             │
│    • Update Load status in Redux                │
│    • Show confirmation screen                   │
│    • After 3 sec: navigate back to Load List    │
└──────────────────────────────────────────────────┘

Offline Sync (When Online):
  1. Query Realm SyncQueue: pending PODs
  2. For each pending POD:
     a. POST POD__c record
     b. Upload photo file (multipart)
     c. On success: mark synced = true, delete from queue
     d. On failure: increment retryCount, queue retry
  3. Show user: "✓ Synced 3 PODs"
```

---

## Authentication Flow

### Salesforce OAuth 2.0

```
┌──────────────────────────────────────────────────────┐
│ 1. User Enters Phone + Password on LoginScreen       │
│    • Input validation: phone format, password length │
└────────────────────┬─────────────────────────────────┘
                     ↓
┌──────────────────────────────────────────────────────┐
│ 2. POST to Salesforce OAuth Endpoint                 │
│    POST https://login.salesforce.com/services/       │
│        oauth2/token                                  │
│                                                      │
│    Body:                                             │
│    - grant_type: "password"                          │
│    - client_id: SALESFORCE_CLIENT_ID                │
│    - client_secret: SALESFORCE_CLIENT_SECRET         │
│    - username: {phone}                               │
│    - password: {password}                            │
└────────────────────┬─────────────────────────────────┘
                     ↓
                     ├─→ [ERROR: Invalid Credentials]
                     │     └→ Show "Login failed" toast
                     │        → Retry
                     │
                     ├─→ [ERROR: Network Error]
                     │     └→ Show "Check connection" toast
                     │        → Retry
                     │
                     ├─→ [SUCCESS]
                     │     └→ Response:
                     │        {
                     │          "access_token": "xxxx",
                     │          "instance_url": "https://...",
                     │          "token_type": "Bearer",
                     │          "expires_in": 86400
                     │        }
                     ↓
┌──────────────────────────────────────────────────────┐
│ 3. Store Credentials Securely                        │
│    • AccessToken → AsyncStorage (encrypted)         │
│    • InstanceUrl → AsyncStorage                      │
│    • TokenExpiresAt → calculated (now + expires_in) │
│    • Driver info → Realm (userId, phone, name)      │
└────────────────────┬─────────────────────────────────┘
                     ↓
┌──────────────────────────────────────────────────────┐
│ 4. Fetch Driver Profile (Optional)                   │
│    GET /services/data/v57.0/query?q=                 │
│        SELECT Id, Name, Phone, License_Number__c    │
│        FROM Contact WHERE Phone = '{phone}'          │
│    → Store in Realm + Redux                          │
└────────────────────┬─────────────────────────────────┘
                     ↓
┌──────────────────────────────────────────────────────┐
│ 5. Setup Firebase Messaging                          │
│    • Get FCM token                                   │
│    • Subscribe to topic: driver_{driverId}          │
│    • POST FCM token to Salesforce (optional)        │
└────────────────────┬─────────────────────────────────┘
                     ↓
┌──────────────────────────────────────────────────────┐
│ 6. Navigate to LoadListScreen                        │
│    • User authenticated ✓                            │
│    • Can now access app features                     │
└──────────────────────────────────────────────────────┘

Token Refresh:
  When API returns 401 (Unauthorized):
    1. Access token expired
    2. Check if refreshToken exists (if using refresh grant)
    3. If yes: POST to refresh endpoint (get new token)
    4. If no: Navigate to LoginScreen (re-authenticate)
    5. Update token in AsyncStorage
    6. Retry original API request with new token

Token Expiry Check:
  On app resume (foreground):
    1. Check TokenExpiresAt vs current time
    2. If token expired: logout + navigate to LoginScreen
    3. If token expires in < 1 hour: preemptively refresh
    4. If token valid: continue (normal operation)
```

---

## Offline Sync Architecture

### Network State Management

```
┌──────────────────────────────────────────────────────┐
│ Network State Detector (Continuous Monitoring)      │
├──────────────────────────────────────────────────────┤
│                                                      │
│ React Native NetInfo + react-native-network-logger  │
│                                                      │
│ Listens for: WiFi, cellular, offline states        │
│                                                      │
│ Triggers:                                            │
│ • Online → Offline: Save pending work, show UI      │
│ • Offline → Online: Start sync queue                │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### Sync Queue Processor

```
┌──────────────────────────────────────────────────────┐
│ Sync Queue Architecture                              │
├──────────────────────────────────────────────────────┤
│                                                      │
│ Realm Table: SyncQueue                               │
│ ┌──────────────────────────────────────────────────┐ │
│ │ id | operation | targetId | payload | status |   │ │
│ ├──────────────────────────────────────────────────┤ │
│ │ 1  | create_ci | load1068 | {...}   | pending |  │ │
│ │ 2  | create_po | pod001   | {...}   | pending |  │ │
│ │ 3  | upload_ph | pod001   | {...}   | pending |  │ │
│ └──────────────────────────────────────────────────┘ │
│                                                      │
│ Processor (background task):                         │
│                                                      │
│ 1. Every 5 min (if online):                          │
│    Query: SyncQueue WHERE status = 'pending'         │
│                                                      │
│ 2. For each pending operation:                       │
│    ┌────────────────────────────────────────────┐   │
│    │ switch(operation):                         │   │
│    │   case 'create_check_in':                  │   │
│    │     POST /sobjects/Check_In__c             │   │
│    │     on success → mark synced=true          │   │
│    │     on error → retry (exp backoff)         │   │
│    │                                            │   │
│    │   case 'create_pod':                       │   │
│    │     POST /sobjects/POD__c                  │   │
│    │     on success → next: upload_photo        │   │
│    │     on error → retry                       │   │
│    │                                            │   │
│    │   case 'upload_photo':                     │   │
│    │     POST /sobjects/ContentVersion (file)   │   │
│    │     on success → mark synced=true          │   │
│    │     on error → retry                       │   │
│    └────────────────────────────────────────────┘   │
│                                                      │
│ 3. Retry Strategy:                                   │
│    - Attempt 1: immediate                           │
│    - Attempt 2: +5 sec                              │
│    - Attempt 3: +15 sec                             │
│    - Attempt 4: +45 sec                             │
│    - Attempt 5: +2 min                              │
│    - Max attempts: 5                                │
│    - After max: mark status='error', alert user     │
│                                                      │
│ 4. User Notification:                               │
│    - Show badge: "3 items pending sync"             │
│    - On sync complete: toast "✓ Synced"             │
│    - On sync error: alert "Sync failed, retrying"   │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### Conflict Resolution

```
Scenario: POD synced to Salesforce, but photo upload failed

Problem:
  - POD record exists in Salesforce (no photo linked)
  - Photo file exists locally (not uploaded)
  - Next app launch: tries to sync again

Solution (Idempotency):
  - Use External_Event_Id__c (UUID) as dedup key
  - Salesforce Platform deduplication rule:
    If External_Event_Id__c exists: update, don't insert
  - Photo upload: check if ContentDocument exists
    If yes: update instead of insert

Implementation:
  const externalPodId = UUID(); // Generate once
  const podData = {
    Load__c: loadId,
    External_Pod_Id__c: externalPodId, // De-dup key
    ...other fields
  };
  
  // Will upsert if external ID already exists
  const response = await upsertPOD(podData, externalPodId);
```

---

## Module Specifications

### Authentication Module (authService)

```typescript
// src/services/salesforceService.ts

export interface LoginResponse {
  accessToken: string;
  instanceUrl: string;
  userId: string;
  expiresIn: number;
}

export async function loginDriver(
  phone: string,
  password: string
): Promise<LoginResponse> {
  // POST to Salesforce OAuth endpoint
  // Return access token + instance URL
  // Store securely in AsyncStorage
}

export async function logoutDriver(): Promise<void> {
  // Clear access token from AsyncStorage
  // Clear Redux state
  // Clear Realm data (optional)
}

export async function refreshAccessToken(): Promise<string> {
  // If using refresh token grant:
  // POST to refresh endpoint, get new access token
  // Update AsyncStorage
  // Return new access token
}

export async function validateToken(): Promise<boolean> {
  // Check if token valid + not expired
  // Return true/false
}
```

### Load Management Module (loadsService)

```typescript
// src/services/salesforceService.ts

export interface Load {
  id: string;
  name: string;
  shipperName: string;
  shipperPhone: string;
  pickupAddress: string;
  pickupDateTime: Date;
  deliveryAddress: string;
  deliveryDateTime: Date;
  status: 'ASSIGNED' | 'IN_TRANSIT' | 'AT_DELIVERY' | 'DELIVERED';
  commodity: string;
  weight: number;
  equipmentType: string;
  specialInstructions: string;
  bolPdfUrl: string;
}

export async function fetchLoads(driverId: string): Promise<Load[]> {
  // SOQL: SELECT * FROM Load__c WHERE Assigned_Driver__c = '{driverId}'
  // Parse response, cache to Realm, return list
}

export async function getLoadDetail(loadId: string): Promise<Load> {
  // SOQL: SELECT * FROM Load__c WHERE Id = '{loadId}'
  // Return full load details
}
```

### Check-In Module (checkInService)

```typescript
// src/services/salesforceService.ts

export interface CheckInData {
  loadId: string;
  eventType: 'pickup' | 'delivery';
  latitude: number;
  longitude: number;
  accuracy: number;
  timestamp: Date;
}

export async function createCheckIn(data: CheckInData): Promise<string> {
  // POST /sobjects/Check_In__c
  // Return check-in ID
  // If offline: queue to Realm SyncQueue
}
```

### POD Module (podService)

```typescript
// src/services/salesforceService.ts

export interface PODData {
  loadId: string;
  photoUri: string;
  signatureUri: string;
  receiverName: string;
  receiverCompany: string;
  condition: 'Good' | 'MinorDamage' | 'Refused' | 'Other';
  notes?: string;
  timestamp: Date;
}

export async function createPOD(data: PODData): Promise<string> {
  // 1. Create POD__c record
  // 2. Upload photo to ContentVersion
  // 3. Link ContentDocument to POD record
  // Return POD ID
  // If offline: queue both operations to Realm
}

export async function uploadPODPhoto(
  podId: string,
  photoUri: string
): Promise<void> {
  // Upload photo file to Salesforce ContentVersion
  // Link to POD record
}
```

### Geolocation Module (gpsService)

```typescript
// src/services/geolocationService.ts

export interface GPSLocation {
  latitude: number;
  longitude: number;
  accuracy: number;
  timestamp: Date;
}

export async function getCurrentLocation(): Promise<GPSLocation> {
  // Use react-native-geolocation-service
  // Request permission if needed
  // Wait for GPS fix (max 30 sec timeout)
  // Validate accuracy (reject if > 100m error)
  // Return location
}

export async function watchPosition(
  callback: (location: GPSLocation) => void
): Promise<void> {
  // Continuous GPS tracking
  // Call callback every ~5 sec with updated location
}
```

### Offline Sync Module (offlineSyncService)

```typescript
// src/services/offlineSyncService.ts

export async function queueOperation(
  operation: string,
  targetId: string,
  payload: any
): Promise<void> {
  // Add to Realm SyncQueue
  // Set status = 'pending'
  // Trigger sync if online
}

export async function syncQueue(): Promise<SyncResult> {
  // Get pending operations from Realm
  // For each operation: execute and update status
  // Return results (success count, error count)
}

export async function retryFailedOperations(): Promise<void> {
  // Query Realm: SyncQueue WHERE status = 'error'
  // For each: increment retryCount, set nextRetryAt
  // Re-queue if retryCount < 5
}

export async function clearSyncQueue(): Promise<void> {
  // Delete all completed operations from queue
  // Keep errors for manual review
}
```

### Push Notifications Module (notificationService)

```typescript
// src/services/firebaseService.ts

export async function setupNotifications(): Promise<void> {
  // Get FCM token
  // Subscribe to topic: driver_{driverId}
  // Setup notification listeners
  // On notification tap: navigate to relevant screen
}

export function onNotificationReceived(
  callback: (notification: any) => void
): void {
  // Listen for incoming notifications
  // Parse and pass to callback
}
```

---

## Build & Deployment

### Development Build

```bash
# Setup
npm install
npm install -g expo-cli

# Configure environment
cp .env.example .env.development
# Edit .env.development with dev credentials

# Start dev server
expo start

# Run on iOS simulator
expo start --ios

# Run on Android emulator
expo start --android

# Run on physical device
expo start --tunnel
# Scan QR code with Expo app
```

### Production Build

```bash
# Install EAS CLI
npm install -g eas-cli

# Configure EAS (first time)
eas build:configure

# Build for iOS
eas build --platform ios --auto-submit

# Build for Android
eas build --platform android --auto-submit

# Submit to App Stores
eas submit --platform ios --latest
eas submit --platform android --latest
```

### Firebase Setup

```javascript
// Create Firebase project
firebase projects:create kwb-driver-app

// Initialize Firebase (interactive)
firebase init

// Add to firebaseConfig.js
export const firebaseConfig = {
  apiKey: "...",
  authDomain: "...",
  projectId: "...",
  storageBucket: "...",
  messagingSenderId: "...",
  appId: "..."
};
```

### Environment Variables

```
# .env.production
SALESFORCE_CLIENT_ID=3MVC...
SALESFORCE_CLIENT_SECRET=1234567890...
SALESFORCE_USERNAME_FIELD=Phone
SALESFORCE_API_VERSION=57.0
SALESFORCE_LOGIN_URL=https://login.salesforce.com

FIREBASE_API_KEY=AIzaSyD...
FIREBASE_PROJECT_ID=kwb-driver-app
FIREBASE_MESSAGING_SENDER_ID=123456789012

GOOGLE_MAPS_API_KEY=AIzaSyD...

APP_VERSION=1.0.0
BUILD_NUMBER=1
ENVIRONMENT=production
```

### CI/CD Pipeline (GitHub Actions)

```yaml
# .github/workflows/build.yml
name: Build & Deploy

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: 18
      
      - name: Install dependencies
        run: npm install
      
      - name: Run tests
        run: npm test
      
      - name: Build iOS
        run: eas build --platform ios
        env:
          EAS_TOKEN: ${{ secrets.EAS_TOKEN }}
      
      - name: Build Android
        run: eas build --platform android
        env:
          EAS_TOKEN: ${{ secrets.EAS_TOKEN }}
```

---

## Testing Strategy

### Unit Tests (React Native Testing Library)

```bash
# Run all tests
npm test

# Run with coverage
npm test -- --coverage

# Run specific test file
npm test src/services/salesforceService.test.ts

# Watch mode
npm test -- --watch
```

### Integration Tests (Detox)

```bash
# Build app for testing
detox build-framework-cache
detox build-ios-framework
detox build-app

# Run E2E tests
detox test
```

### Device Testing Checklist

```
□ iOS simulator (iPhone 12)
□ iOS device (iPhone 14+)
□ Android emulator (Pixel 4a)
□ Android device (Samsung Galaxy S21+)
□ Network conditions: WiFi, 4G, offline
□ Battery saver mode
□ Low storage scenario
□ Force app quit + resume
```

---

## Monitoring & Analytics

### Crashlytics
```javascript
import { crashlytics } from '@react-native-firebase/crashlytics';

// Auto catch uncaught exceptions
crashlytics().onError((error) => {
  console.log('Crashlytics error:', error);
});
```

### Analytics
```javascript
import { analytics } from '@react-native-firebase/analytics';

// Log events
await analytics().logEvent('load_view', {
  loadId: load.id,
  status: load.status
});

await analytics().logEvent('check_in_completed', {
  loadId: load.id,
  eventType: 'pickup'
});
```

### Performance Monitoring
```javascript
import { perf } from '@react-native-firebase/perf';

const trace = await perf().startTrace('load_fetch');
// ... fetch loads ...
await trace.stop();
```

---

This architecture ensures:
✅ Scalable, modular codebase  
✅ Robust offline-first sync  
✅ Secure authentication  
✅ Real-time notifications  
✅ Excellent performance  
✅ Comprehensive testing  
