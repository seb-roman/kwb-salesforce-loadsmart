# KWB Loads Management — Phase 1 Deployment

**Version:** 1.0.0  
**Date:** March 18, 2026  
**Status:** Ready for Deployment  
**Target Org:** kwb-dev (Platform Starter licenses + 1 Enterprise admin)

---

## Prerequisites

1. **Salesforce CLI** installed on your local machine
   - Verify: `sfdx --version`
   - If not installed: https://developer.salesforce.com/tools/sfdxcli

2. **Dev Org authenticated locally**
   - Run: `sfdx force:auth:web:login -a kwb-dev`
   - (You should have already done this)

3. **Loadsmart API credentials ready**
   - Client ID: `YOUR_CLIENT_ID`
   - Client Secret: `YOUR_CLIENT_SECRET`
   - (You'll add these to Apex code after deployment for testing)

4. **FMCSA API access** (public, no credentials needed)
   - Already configured in `FMCSACarrierLookup.cls`

---

## What Gets Deployed

**Custom Objects:**
- `Load__c` — Freight loads with 30+ fields
- `Carrier__c` — Freight carriers with FMCSA verification

**Apex Classes:**
- `FMCSACarrierLookup` — Search carriers by MC# or USDOT# from FMCSA
- `LoadsmartPoller` — Scheduled polling job (pulls shipments from Loadsmart every 5-10 min)
- `LoadsmartPostback` — (DISABLED) Code to push Load data back to Loadsmart

---

## Deployment Steps

### Step 1: Download This Package

The SFDX project is in: `/data/.openclaw/workspace/kwb-salesforce-load-system/`

### Step 2: Deploy to Your Dev Org

From your local terminal (in the project root):

```bash
sfdx force:source:deploy -u kwb-dev --sourcepath force-app
```

**Expected output:**
```
Deploying...
Deploy ID: 0Af...
Status: Succeeded
Deployed: 2 custom objects, 3 Apex classes, 30 custom fields
```

### Step 3: Verify Custom Objects Created

In Salesforce:
1. Setup → Objects and Fields → Custom Objects
2. Should see: `Load`, `Carrier`
3. Click each → Fields tab → Verify 30+ fields exist

### Step 4: Configure Loadsmart Credentials

**CRITICAL: Set credentials BEFORE using polling**

Edit file: `force-app/main/default/classes/LoadsmartPoller.cls`

Find line ~76:
```java
String clientId = 'YOUR_LOADSMART_CLIENT_ID';
String clientSecret = 'YOUR_LOADSMART_CLIENT_SECRET';
```

Replace with your actual Loadsmart credentials:
```java
String clientId = 'abc123xyz789';
String clientSecret = 'your-secret-key-here';
```

Then redeploy:
```bash
sfdx force:source:deploy -u kwb-dev --sourcepath force-app/main/default/classes/LoadsmartPoller.cls
```

### Step 5: Schedule the Polling Job (OPTIONAL - Phase 1)

The polling job is built but NOT scheduled by default.

To schedule it (once Loadsmart credentials are set):

1. In Salesforce, go to: **Setup → Apex Classes**
2. Find: `LoadsmartPoller`
3. Click: **Schedule Apex**
4. **Job Name:** `Loadsmart Polling - Every 5 Minutes`
5. **Apex Class:** `LoadsmartPoller`
6. **Frequency:** Hourly, Daily, or Weekly (pick one)
7. **Time:** When to start (suggest off-peak, e.g., 12:00 AM)
8. **Repeat:** Every 5 minutes (or customize)
9. Click: **Save**

### Step 6: Test FMCSA Carrier Lookup

In Salesforce **Developer Console** (Ctrl+K → Developer Console):

1. **Execute Anonymous:**
```java
FMCSACarrierLookup lookup = new FMCSACarrierLookup();
FMCSACarrierLookup.CarrierData data = lookup.searchByMCNumber('1776323');
System.debug('Carrier: ' + data.legalName + ', Status: ' + data.dotStatus);
```

2. Check **Debug Output** — should see:
```
Carrier: KWB LOGISTICS LLC, Status: ACTIVE
```

If you see "Carrier not found" or 404, the MC number doesn't exist in FMCSA (use a real number for testing).

### Step 7: Test Polling Job

1. In Salesforce, go to: **Setup → Apex Scheduled Jobs** (if scheduled)
2. Find: `Loadsmart Polling...`
3. Click: **Run Now** (if not yet scheduled, create a manual test)

In **Developer Console**, execute:
```java
LoadsmartPoller poller = new LoadsmartPoller();
Database.executeBatch(poller);
```

Check **Debug Logs** for:
- "Created X loads from Loadsmart"
- "Loadsmart API error: [error code]"
- "Failed to obtain access token"

---

## Post-Back Testing (LATER - Phase 2)

The **LoadsmartPostback** class is included but DISABLED.

When ready to test syncing Load data back to Loadsmart:

1. Edit: `force-app/main/default/classes/LoadsmartPostback.cls`
2. Add your Loadsmart credentials (same as polling)
3. Verify all field mappings with Loadsmart API docs
4. Test in dev org first:
   ```java
   LoadsmartPostback postback = new LoadsmartPostback();
   postback.syncLoadToLoadsmart([load ID]);
   ```
5. Check Load record: `Loadsmart_Synced__c` should be checked ✓

---

## Troubleshooting

### "Deploy failed: Insufficient access to entity"
- Check: Org must allow Platform Starter users to access custom objects
- Fix: Platform Starter licenses in Production Org?

### "Loadsmart API error: 401 Unauthorized"
- Check: Client ID and Secret are correct
- Fix: Re-verify credentials in LoadsmartPoller.cls

### "FMCSA lookup returns no data"
- Check: MC# or USDOT# exists in FMCSA
- Test: Use a real carrier (e.g., MC 1776323 from your testing)
- Note: FMCSA API can be slow — 10sec timeout may occasionally fail

### "LoadsmartPoller shows 0 loads created"
- Check: Are there actually new shipments in Loadsmart?
- Check: Loadsmart API accessible from your org IP?
- Check: Debug logs for error details

---

## Phase 2 Roadmap

**Post-Back / PATCH /shipments:**
- Scheduled batch job (nightly 2 AM sync)
- Error handling + retry logic
- Webhook verification (optional, not Phase 1)

**E-Sign Integration:**
- Docusign/similar for rate confirmation signatures
- Auto-send to carrier on load confirmation

**POD Capture:**
- Driver mobile app for photo upload
- OCR to extract delivery confirmation

**AI Dispatch Suggestions:**
- Look at carrier history (on-time %, margin %, zones)
- Recommend best carrier for new load

---

## Support

- **Loadsmart API:** https://developer.loadsmart.com/docs/
- **FMCSA API:** https://mobile.fmcsa.dot.gov/qc/api/v1/
- **Salesforce Docs:** https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/quickstart.htm

---

**Deployment Status:** ✅ Ready  
**Next Step:** Run `sfdx force:source:deploy` from your terminal
