# KWB Loads Management System — Phase 1

**Build Status:** ✅ Complete  
**Deployment Status:** Ready  
**Last Updated:** March 18, 2026

---

## Overview

This Salesforce system replaces the manual Loadsmart → Alvys → manual re-entry workflow with **real-time load creation** and **automated carrier assignment**.

**Architecture:**
```
Loadsmart API (Shipper)
    ↓ (new shipments every 5-10 min via polling)
Salesforce (Load Management)
    ↓ (user assigns carrier + confirms times)
Loadsmart API (update shipment with carrier + load #)
```

**No more:**
- PDF OCR errors (Lowe's 1523 vs. 1525 typos)
- Manual data re-entry (duplicate effort)
- Slow, error-prone workflows

**Yes to:**
- Real-time load visibility in Salesforce
- FMCSA-verified carrier data
- Single source of truth

---

## What's Included

### Custom Objects (2)

**Load__c**
- Auto-generated Load # (LOAD-0000001, etc.)
- Loadsmart Shipment ID (external ID)
- Shipper/Receiver contact + address
- Pickup/Delivery windows (date + time)
- Equipment type, commodity, weight
- Billing rate, carrier assignment, carrier rate
- Margin (auto-calculated: billing - carrier rate)
- Status: Pending → Assigned → Confirmed → Picked Up → Delivered → Invoiced
- Sync status (when pushed back to Loadsmart)

**Carrier__c**
- MC Number (external ID, unique)
- USDOT Number
- Legal name, address, phone
- DOT status (Active/Inactive/Out of Service)
- Insurance status (Valid/Expired/Pending)
- FMCSA verification flag

### Apex Classes (3)

**FMCSACarrierLookup**
- Searchable by MC# or USDOT#
- Calls FMCSA API (federal database)
- Returns: legal name, address, DOT status, insurance status
- Use case: Auto-complete carrier lookup in Salesforce

**LoadsmartPoller** (Scheduled Batch)
- Polls Loadsmart API every 5-10 minutes
- Fetches shipments updated in last X minutes
- Auto-creates Load records with all data
- Prevents duplicates (checks existing Loadsmart Shipment IDs)
- Maps Loadsmart fields → Salesforce Load fields
- TODO: Configure with your Loadsmart credentials

**LoadsmartPostback** (DISABLED - Phase 2)
- Syncs Load data back to Loadsmart (PATCH /shipments)
- Updates: Carrier name, MC#, rate, pickup/delivery scheduled times
- Nightly batch job (not real-time to avoid API thrashing)
- Enable & test in Phase 2 after validating polling

---

## Quick Start

### 1. Deploy to Your Org

```bash
cd /path/to/kwb-salesforce-load-system
sfdx force:source:deploy -u kwb-dev --sourcepath force-app
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed steps.

### 2. Add Loadsmart Credentials

Edit `force-app/main/default/classes/LoadsmartPoller.cls`:
- Line 76: Replace `YOUR_LOADSMART_CLIENT_ID` and `YOUR_LOADSMART_CLIENT_SECRET`
- Redeploy the class

### 3. Schedule the Polling Job

Setup → Apex Classes → `LoadsmartPoller` → Schedule Apex
- Frequency: Every 5 minutes (or customize)
- Or run manually first: `Database.executeBatch(new LoadsmartPoller())`

### 4. Test FMCSA Carrier Lookup

Developer Console → Execute Anonymous:
```java
FMCSACarrierLookup lookup = new FMCSACarrierLookup();
FMCSACarrierLookup.CarrierData data = lookup.searchByMCNumber('1776323');
System.debug(data.legalName + ' - ' + data.dotStatus);
```

---

## Workflow

### User Perspective

**Step 1: New Load Arrives**
- Loadsmart: You accept a bid from a shipper
- Salesforce: ~5-10 min later, Load appears in Salesforce (auto-created via polling)
- Data includes: Shipper, receiver, pickup/delivery times, equipment, rate

**Step 2: Assign Carrier**
- Open the Load in Salesforce
- Search for Carrier (auto-complete from your network)
- FMCSA verification happens on lookup (MC# → verified status)
- Confirm pickup/delivery times (editable if negotiated)

**Step 3: Confirm & Sync**
- Click "Confirm Assignment"
- Load status → "Confirmed"
- (Later) Nightly batch pushes carrier + rate + times back to Loadsmart

---

## Technical Details

### Data Flow: Loadsmart → Salesforce

Loadsmart API Response:
```json
{
  "shipments": [
    {
      "id": "uuid-here",
      "shipment_reference": "ORDER-12345",
      "rate": {"amount": 1500},
      "stops": [
        {
          "type": "pickup",
          "location_name": "Scotts Miracle-Gro",
          "address": "3875 South Elyria Road",
          "city": "Shreve",
          "state": "OH",
          "zipcode": "44676",
          "planned_date": "2026-03-23"
        },
        {
          "type": "delivery",
          "location_name": "Lowe's INC 1525",
          "address": "2000 West Main Street",
          "city": "Troy",
          "state": "OH",
          "zipcode": "45373",
          "planned_date": "2026-03-24"
        }
      ],
      "equipment_type": "DRV",
      "weight": {"value": 23880.20}
    }
  ]
}
```

Maps to Salesforce Load:
- `id` → `Loadsmart_Shipment_ID__c`
- `shipment_reference` → `Order_Number__c`
- `rate.amount` → `Billing_Rate__c`
- `stops[0]` → Shipper address + Pickup window
- `stops[1]` → Receiver address + Delivery window
- `equipment_type` → `Equipment_Type__c`
- `weight.value` → `Weight_lbs__c`

### Rate Limits

**Loadsmart:** 100 req/min for most endpoints
- Polling every 5 min = ~2 calls/day = no problem

**FMCSA:** Public API, no published limits
- ~1 call per carrier lookup
- ~5-10 carriers/day = no problem

### Error Handling

- API timeout: 30 seconds
- Failed API calls: Logged to debug, don't block batch
- Duplicate detection: Checks Loadsmart_Shipment_ID__c before inserting
- Token refresh: Automatic on 401 auth failure

---

## Known Limitations (Phase 1)

- ⚠️ **Post-back disabled** — Can't sync back to Loadsmart yet (code ready, not scheduled)
- ⚠️ **Alvys read-only** — Alvys write endpoints don't exist yet (polling only reads Loadsmart)
- ⚠️ **No e-sign** — Rate confirmation must be sent manually (Phase 2)
- ⚠️ **No POD capture** — Driver POD upload not integrated (Phase 2)
- ⚠️ **No webhooks** — Using polling instead (simpler for Phase 1)

---

## File Structure

```
kwb-salesforce-load-system/
├── force-app/
│   └── main/
│       └── default/
│           ├── objects/
│           │   ├── Load__c/
│           │   │   ├── Load__c.object-meta.xml
│           │   │   └── fields/ (30+ field definitions)
│           │   └── Carrier__c/
│           │       ├── Carrier__c.object-meta.xml
│           │       └── fields/ (8 field definitions)
│           └── classes/
│               ├── FMCSACarrierLookup.cls
│               ├── LoadsmartPoller.cls
│               └── LoadsmartPostback.cls
├── sfdx-project.json
├── DEPLOYMENT.md (← Read this first!)
└── README.md (you are here)
```

---

## Next Steps (Phase 2)

### Post-Back / Data Sync
- [ ] Test LoadsmartPostback with Loadsmart credentials
- [ ] Schedule nightly batch job (PATCH /shipments)
- [ ] Add error handling + retry logic
- [ ] Validate all field mappings

### E-Sign Integration
- [ ] Research DocuSign or alternative
- [ ] Auto-generate Rate Confirmation PDF
- [ ] Send to carrier for signature
- [ ] Track signature status

### POD Capture
- [ ] Build Salesforce mobile form for drivers
- [ ] Upload photo proof of delivery
- [ ] Parse POD data (OCR or manual)
- [ ] Trigger invoicing workflow

### AI Dispatch Suggestions
- [ ] Log carrier performance (on-time %, margin %, geography)
- [ ] Recommend best carrier for new loads
- [ ] Track recommendations vs. actual assignments

---

## Testing Checklist

- [ ] Deploy to dev org successfully
- [ ] Create 2-3 test Carriers with FMCSA verification
- [ ] Run FMCSA lookup — returns correct data
- [ ] Run polling job manually — creates test Load
- [ ] Verify Load has all Loadsmart data populated
- [ ] Assign carrier to test Load
- [ ] Check Margin calculation (should be Billing - Carrier rate)
- [ ] (Phase 2) Test post-back — verify Load syncs to Loadsmart

---

## Support

**Questions?**
- Loadsmart API: https://developer.loadsmart.com/docs/
- FMCSA API: https://mobile.fmcsa.dot.gov/qc/api/v1/
- Salesforce Docs: https://developer.salesforce.com/

---

**Built:** March 18, 2026  
**Status:** Phase 1 Complete, Ready for Deployment  
**Next Review:** After Phase 1 validation in dev org
