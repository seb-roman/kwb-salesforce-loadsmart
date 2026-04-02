# KWB Driver App — Setup & Build Guide

**Agent:** Agent 5  
**Target:** iOS 14+ | Android 10+  
**Date:** April 2, 2026

---

## Prerequisites

### System Requirements
- macOS 12+ (for iOS builds) OR Linux/Windows (Android only)
- Node.js 18+ (`node --version`)
- npm 8+ (`npm --version`)
- Xcode 14+ (iOS; requires macOS)
- Android Studio 2021.3+ (Android)
- CocoaPods (iOS dependencies; `sudo gem install cocoapods`)

### Accounts & API Keys
- Salesforce Developer Org (OAuth credentials)
- Firebase Project (authentication + Realtime DB)
- Google Maps API Keys (Maps + Geocoding)
- Apple Developer Account (iOS deployment)
- Google Play Developer Account (Android deployment)

---

## Initial Setup

### 1. Clone & Install Dependencies

```bash
# Clone repository
git clone https://github.com/kwb-logistics/driver-app.git
cd kwb-driver-app

# Install Node dependencies
npm install

# Install Expo CLI globally
npm install -g expo-cli

# (macOS only) Install CocoaPods
sudo gem install cocoapods

# Install iOS native dependencies (macOS)
cd ios && pod install && cd ..
```

### 2. Configure Environment Variables

```bash
# Copy example env file
cp .env.example .env.development

# Edit for development
nano .env.development
```

**Development .env Content:**
```
# Salesforce
SALESFORCE_CLIENT_ID=3MVG...YourClientIdHere...
SALESFORCE_CLIENT_SECRET=1234567890ABCDEF...
SALESFORCE_LOGIN_URL=https://login.salesforce.com

# Firebase
FIREBASE_API_KEY=AIzaSyD...
FIREBASE_PROJECT_ID=kwb-driver-app-dev
FIREBASE_MESSAGING_SENDER_ID=123456789012
FIREBASE_AUTH_DOMAIN=kwb-driver-app-dev.firebaseapp.com

# Google Maps
GOOGLE_MAPS_API_KEY=AIzaSyD...

# App Config
ENVIRONMENT=development
APP_VERSION=1.0.0
```

### 3. Initialize Realm Database

```bash
# Realm is auto-initialized on first app launch
# Schema files located in: src/database/schemas/

# To reset database during development:
# 1. Delete app from simulator/device
# 2. Rebuild and relaunch
```

---

## Development Workflow

### Start Development Server

```bash
# Terminal 1: Start Expo dev server
npm start

# Terminal 2: Run on iOS simulator
npm run ios

# OR: Run on Android emulator
npm run android

# OR: Run on physical device
# Scan QR code with Expo app (iOS/Android)
```

### Hot Reload
```bash
# After code changes:
# Press 'r' in terminal → hot reload
# Press 'R' → full reload
# Press 'w' → open web debugger
# Press 'i' → open iOS
# Press 'a' → open Android
```

### Debug Mode
```bash
# Enable React Native debugger
npm run debug

# Access: http://localhost:8081/debugger-ui
```

---

## Build for iOS

### Simulator Build

```bash
# Build + run on iOS simulator
npm run ios

# Specify device
npm run ios -- --device "iPhone 14"

# Clean build
npm run ios -- --clean
```

### Device Build (Physical iPhone)

```bash
# Build for physical device
eas build --platform ios

# Submit to App Store
eas submit --platform ios

# Status check
eas build:list
```

### Troubleshooting iOS

```bash
# Pod install errors
cd ios && pod install --repo-update && cd ..

# Xcode build errors
cd ios && xcodebuild clean -workspace KwbDriverApp.xcworkspace -scheme KwbDriverApp && cd ..

# Reset simulator
xcrun simctl erase all
```

---

## Build for Android

### Emulator Build

```bash
# Build + run on Android emulator
npm run android

# Ensure emulator is running
android-studio  # Open and start emulator from AVD Manager

# Clean build
npm run android -- --clean
```

### Device Build (Physical Phone)

```bash
# Build for physical device
eas build --platform android

# Submit to Google Play
eas submit --platform android

# Status check
eas build:list
```

### Troubleshooting Android

```bash
# List available emulators
emulator -list-avds

# Start emulator
emulator -avd Pixel_4a_API_31

# Build errors
./gradlew clean
./gradlew build

# Android reverse proxy (debugging)
adb reverse tcp:8081 tcp:8081
```

---

## Firebase Setup

### Create Firebase Project

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Google
firebase login

# Create new project
firebase projects:create kwb-driver-app-dev

# Initialize Realtime Database
firebase database:set / "{}"

# Enable Cloud Messaging (FCM)
# Go to Firebase Console → Cloud Messaging → Get Server Key
```

### Configure Realtime Database Rules

```json
{
  "rules": {
    "driverLoads": {
      "$driverId": {
        ".read": "$driverId === auth.uid",
        ".write": "$driverId === auth.uid"
      }
    },
    "driverLocation": {
      "$driverId": {
        ".read": "$driverId === auth.uid",
        ".write": "$driverId === auth.uid"
      }
    },
    "notifications": {
      "$notificationId": {
        ".read": true,
        ".write": "root.child('adminUids').child(auth.uid).exists()"
      }
    }
  }
}
```

---

## Salesforce Configuration

### Create Connected App

1. **Salesforce Setup:**
   - Go to Setup → Apps → App Manager → New Connected App
   - **Connected App Name:** KWB Driver App (Dev)
   - **API Name:** KWB_Driver_App_Dev
   - **Contact Email:** your@email.com

2. **OAuth Settings:**
   - Enable OAuth Settings: ☑
   - Callback URL: `exp://localhost:19000/--/` (dev) or `kwb-driver-app://auth` (prod)
   - Selected OAuth Scopes:
     - ☑ Access and manage your data (api)
     - ☑ Perform requests on your behalf (refresh_token)
   - Save

3. **Obtain Credentials:**
   - Consumer Key (= SALESFORCE_CLIENT_ID)
   - Consumer Secret (= SALESFORCE_CLIENT_SECRET)
   - Copy to .env file

### Create Custom Objects & Fields

```sql
-- Run in Salesforce Developer Console
-- Or use Setup → Object Manager

-- Load__c (already exists, verify fields)
Field: Assigned_Driver__c (Lookup to Contact)
Field: Status__c (Picklist: ASSIGNED, IN_TRANSIT, AT_DELIVERY, DELIVERED)
Field: Pickup_DateTime__c (DateTime)
Field: Delivery_DateTime__c (DateTime)
Field: Special_Instructions__c (Text)
Field: BOL_PDF_URL__c (URL)

-- Check_In__c (create if missing)
Field: Load__c (Lookup to Load__c)
Field: Driver__c (Lookup to Contact)
Field: Event_Type__c (Picklist: pickup, delivery)
Field: Event_DateTime__c (DateTime)
Field: Latitude__c (Number)
Field: Longitude__c (Number)
Field: Location_Accuracy__c (Number)
Field: Location_Geo__c (Geolocation)
Field: Source_System__c (Text)
Field: External_Event_Id__c (Text - unique, external ID)

-- POD__c (create if missing)
Field: Load__c (Lookup to Load__c)
Field: Driver__c (Lookup to Contact)
Field: Pod_DateTime__c (DateTime)
Field: Photo_Content_Document_Id__c (Text)
Field: Signature_Image_Url__c (URL)
Field: Receiver_Name__c (Text)
Field: Receiver_Company__c (Text)
Field: Delivery_Condition__c (Picklist: Good, MinorDamage, Refused, Other)
Field: Damage_Notes__c (Text Area)
Field: Source_System__c (Text)
Field: External_Pod_Id__c (Text - unique, external ID)
```

### Enable REST API

1. Go to Setup → System Overview
2. Verify REST API is enabled (should be by default)
3. API Version: 57.0

---

## Testing Setup

### Unit Tests

```bash
# Install testing dependencies
npm install --save-dev jest @testing-library/react-native

# Run tests
npm test

# Watch mode
npm test -- --watch

# Coverage report
npm test -- --coverage
```

### Integration Tests

```bash
# Install Detox (E2E testing)
npm install --save-dev detox detox-cli detox-config

# Initialize Detox
detox init -r ios

# Build for testing
detox build-framework-cache
detox build-app -c ios.sim.debug

# Run tests
detox test
```

### Manual Testing on Devices

**Checklist:**
- [ ] Login flow (valid credentials)
- [ ] Login flow (invalid credentials)
- [ ] Load list displays (10+ loads)
- [ ] Load detail displays all info
- [ ] Check-in (with GPS)
- [ ] Check-in offline (queue + sync)
- [ ] POD photo capture (camera)
- [ ] POD signature capture
- [ ] POD upload (offline sync)
- [ ] Settings screen (dark mode, cache clear)
- [ ] Push notification (background)
- [ ] Battery drain test (1+ hour)
- [ ] Low signal test (3G/weak WiFi)
- [ ] App crash recovery

---

## Production Build & Deployment

### Pre-Deployment Checklist

```
□ Update package.json version
□ Create .env.production (with prod credentials)
□ Run full test suite (npm test)
□ Verify Salesforce OAuth settings (prod instance)
□ Verify Firebase project (prod)
□ Update app.json (version, build number)
□ Test on real devices (iOS + Android)
□ Security review (no hardcoded secrets)
□ Performance testing (load time, battery drain)
□ Accessibility audit (WCAG AA)
```

### Build for Production

```bash
# Update app version
npm version patch  # or minor/major

# Ensure production env
export NODE_ENV=production

# Configure Expo for production
eas update:configure

# Build for iOS
eas build --platform ios --profile production

# Build for Android
eas build --platform android --profile production
```

### Submit to App Stores

```bash
# iOS App Store
eas submit --platform ios

# Google Play
eas submit --platform android

# Monitor builds
eas build:list --limit 10
```

---

## Troubleshooting Common Issues

### Build Fails
```bash
# Clear cache + reinstall
npm cache clean --force
rm -rf node_modules
npm install

# Clean build directories
rm -rf ./ios ./android
npm run eject  # (if using managed Expo)

# Rebuild
npm run ios  # or android
```

### Crashes on Launch
```bash
# Check console logs
npm start -- --clear-cache

# Verify env variables
cat .env.development

# Check Realm schema version
# If schema changed: delete app + reinstall
```

### Network/API Errors
```bash
# Check Salesforce credentials
# Verify OAuth token not expired
# Test API endpoint manually:
curl -H "Authorization: Bearer {access_token}" \
  https://{instance}.salesforce.com/services/data/v57.0/query

# Check Firebase project ID matches
# Verify Google Maps API key
```

### GPS Not Working
```bash
# iOS: Verify location permission in Info.plist
# Android: Verify permission in AndroidManifest.xml
# Simulator: Set location manually in settings
# Device: Ensure GPS enabled + location permission granted
```

### Performance Issues
```bash
# Profile with React Native debugger
npm start -- --dev-client

# Use Hermes engine (faster JS execution)
# Measure load time
# Optimize images (use imagemin)
```

---

## Development Best Practices

### Code Style
```bash
# Format code with Prettier
npm run format

# Lint with ESLint
npm run lint

# Fix lint errors
npm run lint -- --fix
```

### Commit Messages
```
feat: Add check-in GPS capture
fix: Correct offline sync retry logic
docs: Update setup guide
refactor: Extract GPS service to separate module
test: Add offline sync unit tests
chore: Update dependencies
```

### Branch Naming
```
feature/check-in-gps
bugfix/offline-sync-retry
docs/setup-guide
hotfix/crash-on-launch
```

### Version Management
```
Version format: MAJOR.MINOR.PATCH
- MAJOR: Breaking changes
- MINOR: New features
- PATCH: Bug fixes

Example: 1.2.3
```

---

## CI/CD with GitHub Actions

Create `.github/workflows/build.yml`:

```yaml
name: Build & Test

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - run: npm install
      - run: npm test -- --coverage
      - run: npm run lint

  build:
    runs-on: macos-latest
    needs: test
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: npm install
      - run: eas build --platform ios
        env:
          EAS_TOKEN: ${{ secrets.EAS_TOKEN }}
```

---

## Support & Documentation

- **React Native Docs:** https://reactnative.dev/docs/getting-started
- **Expo Docs:** https://docs.expo.dev/
- **Firebase Docs:** https://firebase.google.com/docs
- **Salesforce OAuth:** https://developer.salesforce.com/docs/platform/security/content/oauth2_flows
- **Realm Docs:** https://www.mongodb.com/docs/realm/sdk/react-native/

---

**Setup Complete!** 🎉

You're ready to start development. Begin with `npm start` and happy coding!
