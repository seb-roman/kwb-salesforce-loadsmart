# KWB Salesforce Load System — Deployment Guide

**Project:** Custom Salesforce TMS (Transportation Management System)  
**Status:** Phase 1 Ready for Sandbox Deployment  
**Phase 2:** Ready for UAT & User Feedback  
**Last Updated:** April 2, 2026

---

## Overview

This guide covers deployment of the KWB Salesforce Load System across Phase 1 (MVP) and Phase 2 (Enhancements).

**Repository:** `https://github.com/seb-roman/kwb-salesforce-loadsmart.git`  
**Key Contact for Deployment:** Joshua Anderson (josh@example.com)  
**Architecture Lead:** Seb Roman (seb.roman316@gmail.com)

---

## Phase 1: MVP Deployment (Ready Now)

### Phase 1 Components

**Agent 1 — Data Model (COMPLETE)**
- 13 validation rules for Load__c
- 8 formula fields (margins, transit metrics, efficiency)
- 3 custom metadata types (RateCardConfig, ExceptionRules, BillingConfig)
- 85%+ test coverage
- [Documentation](./docs/AGENT1_PHASE1_COMPLETION_SUMMARY.md)

**Agent 3 — Tracking & GPS (COMPLETE)**
- MotiveWebhookReceiver.cls (HMAC-SHA256 signature validation)
- TrackingIngestJob.cls (vehicle-to-load mapping, GPS validation)
- TrackingTriggerHandler.cls (recursion prevention)
- 4 custom fields for Motive integration
- 29 unit tests, 92% coverage
- [Documentation](./docs/AGENT3_DAY3_MOTIVE_SETUP_GUIDE.md)

**Agent 4 — Billing & Settlement (COMPLETE)**
- InvoiceGenerator.cls (auto-invoice on POD capture)
- RateCardLookup.cls (priority-based rate matching)
- FuelSurchargeCalculation.cls (DAI price locked at booking)
- SettlementBatch.cls (weekly carrier settlement with idempotency)
- LoadTrigger, RateCardTrigger
- 40+ unit tests
- [Documentation](./AGENT4_RE_REVIEW_OF_AGENT5.md)

**Agent 5 — Shipper Portal (COMPLETE)**
- ShipperLoadListController.cls (row-level security + pagination)
- ShipperLoadDetailController.cls (load details with RLS)
- ShipperInvoiceListController.cls (invoice list + disputes)
- ShipperAccountProfileController.cls (account management)
- SecurityUtil.cls (centralized CRUD/FLS validation)
- shipperLoadList LWC (mobile-responsive, WCAG AA)
- 38 unit tests
- [Documentation](./AGENT4_RE_REVIEW_OF_AGENT5.md)

**Agent 2 — Loadsmart Integration (On Hold)**
- LoadsmartPoller.cls (fetches loads every 5 min) — Ready
- FMCSACarrierLookup.cls (carrier verification) — Ready
- LoadsmartPostback.cls (updates Loadsmart with carrier) — Ready (scheduled for Phase 1.5)

### Deployment Sequence (Phase 1)

```
Step 1: Pre-Deployment Checks (30 min)
  ✓ Verify sfdx CLI installed and authenticated
  ✓ Confirm sandbox org is ready
  ✓ Run local tests: >80% coverage verified
  ✓ No hardcoded credentials
  ✓ Backup production org

Step 2: Deploy to Sandbox (1-2 hours)
  1. Deploy metadata (objects → Apex → triggers → configs)
     sfdx force:source:deploy -u kwb-sandbox -p force-app/main/default
  2. Run all tests
     sfdx force:apex:test:run -u kwb-sandbox -l RunAllTests
  3. Verify >80% coverage
  4. Run smoke tests (see "Smoke Tests" section below)

Step 3: Sandbox Validation (4-6 hours)
  1. Load sample data (50 test loads, 15 carriers, 30 drivers)
  2. Test polling: Accept load on Loadsmart → Verify Load created in SF (5 min)
  3. Test assignment: Assign carrier → Verify postback to Loadsmart (2 min)
  4. Test invoicing: Capture POD → Verify Invoice created (1 min)
  5. Test settlement: Wait for 1 AM → Verify Settlement batch runs (5 min)
  6. Test tracking: Update status → Verify tracking shows in dashboard (1 min)

Step 4: Deploy to Production (2-4 hours)
  1. Announce deployment window to team
  2. Deploy to production org
  3. Run smoke tests in production
  4. Enable batch jobs (Loadsmart polling, settlement batch)
  5. Configure custom settings (Motive API key, DAI baseline price)
  6. Announce go-live

Step 5: Post-Deployment (Ongoing)
  1. Monitor logs for 24 hours
  2. Confirm polling is active
  3. Test live load acceptance from Loadsmart
  4. Check invoicing + settlement on Monday 1 AM
```

### Smoke Tests (Validation Checklist)

Run after every deployment:

```
✓ Data Model
  - Create Load__c with validation rules → accepts valid, rejects invalid
  - Check margin$ formula calculates correctly
  - Query RateCardConfig__mdt → returns config

✓ Tracking
  - POST test webhook to /services/apexrest/tracking/motive/webhook
  - Verify HMAC-SHA256 signature validation works
  - Check Tracking__c record created with correct data
  - Verify Platform Event published

✓ Billing
  - Capture POD on Load → Invoice__c created
  - Check invoice total = sum of line items
  - Verify fuel surcharge locked (DAI_Price_At_Booking__c set)

✓ Settlement
  - Wait for Monday 1 AM → SettlementBatch runs
  - Check Settlement__c created, consolidates by carrier
  - Verify settlement email sent to carrier

✓ Portal
  - Log in as shipper → see only own loads (RLS enforced)
  - View load detail → tracking map shows location
  - Download invoice PDF → validates formatting
```

### Custom Settings to Configure (Post-Deploy)

Before go-live, configure these in Salesforce Setup:

1. **MotiveConfig__c** (Custom Setting)
   - Webhook_Secret__c: [Motive-provided secret]
   - API_Key__c: [Motive API key]

2. **BillingConfig__c** (Custom Metadata)
   - Settlement_Day_Of_Week__c: "Monday"
   - Settlement_Hour__c: 1 (1 AM ET)
   - Invoice_Email_Template__c: "KWB_Invoice_Notification"
   - DAI_Baseline_Price__c: 2.50

3. **RateCardConfig__c** (Custom Metadata)
   - Sample rate cards for testing carriers/shippers

4. **ExceptionRules__c** (Custom Metadata)
   - Pre-configured with 8 exception types
   - Adjust thresholds as needed

---

## Phase 2: Enhancements (Ready for UAT)

### Phase 2 Components

**Agent 3 — Exception Engine (COMPLETE)**
- ExceptionDetectionEngine.cls (8 rule types, runs every 5 min)
- ExceptionAlertDistribution.cls (email, Slack, SMS routing)
- ExceptionDashboardController.cls (ops dashboard with 30-sec refresh)
- 34 unit tests, 87% coverage
- All thresholds configurable in metadata (no code changes needed)
- [Documentation](./docs/phase2/AGENT3_PHASE2_COMPLETION_SUMMARY.md)

**Agent 5 — Mobile Driver App + Portal (COMPLETE)**
- Mobile app specs: iOS/Android native app (React Native/Flutter)
- Salesforce OAuth + Firebase backend
- Offline sync with SQLite local cache
- Driver check-in + POD photo capture
- Push notifications via FCM
- Portal real-time tracking map (Google Maps, 30-sec refresh)
- 5 advanced business reports (on-time %, cost/mile, utilization, trends)
- WCAG AA accessible, mobile-responsive
- [Documentation](./docs/phase2/AGENT5_PHASE2_COMPLETION_SUMMARY.md)

### Phase 2 Deployment (Post-UAT)

Phase 2 is ready for user feedback collection. Timeline TBD after Phase 1 go-live.

---

## CI/CD Pipeline Setup

GitHub Actions pipeline automates testing + deployment:

### What the Pipeline Does

```yaml
On push to 'master' branch:
  1. Run all Apex tests (122+ tests)
  2. Check code coverage (must be >80%)
  3. Check for hardcoded credentials
  4. If all pass → auto-deploy to sandbox
  5. Run sandbox smoke tests
  6. If all pass → notify team "Ready for production"
  
On manual approval to production:
  1. Deploy to production org
  2. Run health checks:
     - Polling active?
     - API calls responding?
     - No errors in logs?
  3. If health checks pass → deployment complete
  4. If health checks fail → auto-rollback
```

### GitHub Actions File

Location: `.github/workflows/deploy.yml`

Configure with:
- `SFDX_AUTH_URL`: Salesforce auth for sandbox + production
- `SONAR_TOKEN`: Code quality scanning (optional)

### Manual Deployment (If Pipeline Unavailable)

```bash
# Authenticate
sfdx force:auth:web:login -a kwb-prod

# Deploy
sfdx force:source:deploy -u kwb-prod -p force-app/main/default

# Run tests
sfdx force:apex:test:run -u kwb-prod -l RunAllTests

# Check coverage
sfdx force:apex:test:report -u kwb-prod -c
```

---

## Rollback Procedure

If production deployment fails:

### Option 1: Immediate Rollback (< 1 hour downtime)

```bash
# Revert git to previous commit
git revert HEAD

# Deploy previous version
sfdx force:source:deploy -u kwb-prod -p force-app/main/default

# Verify rollback succeeded
sfdx force:apex:test:run -u kwb-prod -l RunAllTests
```

### Option 2: Restore from Backup (Manual)

If git revert doesn't work:

1. Contact Salesforce to restore from org backup
2. Restore to 24 hours before deployment
3. Redeploy with fixes

---

## Troubleshooting

### Common Issues & Fixes

**Issue: Apex tests fail with "Too many SOQL queries"**
- Cause: N+1 query pattern in code
- Fix: Run test with `-d` flag to see where queries happen
- Solution: Use bulk maps instead of loops

**Issue: Validation rules prevent data load**
- Cause: Sample data violates new validation rules
- Fix: Review AGENT1_PHASE1_VALIDATION_RULES.md
- Solution: Adjust sample data or temporarily disable rules

**Issue: Motive webhooks not arriving**
- Cause: Webhook URL not configured in Motive dashboard
- Fix: Verify `/services/apexrest/tracking/motive/webhook` is accessible
- Solution: Check Motive settings, verify HMAC secret matches

**Issue: Settlement batch doesn't run Monday 1 AM**
- Cause: Scheduled job not enabled
- Fix: Go to Setup → Apex Classes → Schedule SettlementBatch
- Solution: Ensure job is scheduled for 1 AM ET every Monday

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for more issues.

---

## Documentation Index

### Core Documentation
- [README.md](./README.md) — Project overview
- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) — This file
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) — Common issues + fixes
- [CI_CD_SETUP.md](./CI_CD_SETUP.md) — GitHub Actions pipeline

### Phase 1 Documentation (Agent Work)
- [AGENT1_PHASE1_COMPLETION_SUMMARY.md](./docs/AGENT1_PHASE1_COMPLETION_SUMMARY.md)
- [AGENT1_PHASE1_VALIDATION_RULES.md](./docs/AGENT1_PHASE1_VALIDATION_RULES.md)
- [AGENT1_PHASE1_FORMULA_FIELDS.md](./docs/AGENT1_PHASE1_FORMULA_FIELDS.md)
- [AGENT3_DAY3_MOTIVE_SETUP_GUIDE.md](./docs/AGENT3_DAY3_MOTIVE_SETUP_GUIDE.md)
- [AGENT4_REFACTOR_SUMMARY.md](./docs/AGENT4_REFACTOR_SUMMARY.md)
- [AGENT5_REFACTOR_SUMMARY.md](./docs/AGENT5_REFACTOR_SUMMARY.md)

### Phase 2 Documentation (Agent Work)
- [AGENT3_PHASE2_COMPLETION_SUMMARY.md](./docs/phase2/AGENT3_PHASE2_COMPLETION_SUMMARY.md)
- [AGENT3_PHASE2_EXCEPTION_RULES.md](./docs/phase2/AGENT3_PHASE2_EXCEPTION_RULES.md)
- [AGENT3_PHASE2_ARCHITECTURE.md](./docs/phase2/AGENT3_PHASE2_ARCHITECTURE.md)
- [AGENT5_PHASE2_COMPLETION_SUMMARY.md](./docs/phase2/AGENT5_PHASE2_COMPLETION_SUMMARY.md)
- [AGENT5_MOBILE_APP_SPEC.md](./docs/phase2/AGENT5_MOBILE_APP_SPEC.md)
- [AGENT5_PORTAL_REPORTS_SPEC.md](./docs/phase2/AGENT5_PORTAL_REPORTS_SPEC.md)

---

## Deployment Contacts

- **Seb Roman** (Architecture Lead): seb.roman316@gmail.com
- **Joshua Anderson** (Deployment Lead): josh@example.com
- **Corey Anderson** (Project Owner): corey.anderson@kwblogistics.com

---

## Deployment Checklist

### Pre-Deployment
- [ ] All tests pass locally (>80% coverage)
- [ ] No hardcoded credentials
- [ ] Sandbox org ready
- [ ] Backup of production org created
- [ ] Team notified of deployment window
- [ ] CI/CD pipeline configured
- [ ] GitHub Actions secrets set (SFDX_AUTH_URL)

### Sandbox Testing
- [ ] All unit tests pass
- [ ] Smoke tests pass (data model, tracking, billing, settlement, portal)
- [ ] Sample data loads successfully
- [ ] Polling cycle works (Loadsmart → SF)
- [ ] Invoice generation working
- [ ] Settlement batch runs on schedule
- [ ] Portal RLS enforced
- [ ] Tracking dashboard updates real-time

### Production Deployment
- [ ] Final go/no-go decision made
- [ ] Deployment window scheduled
- [ ] Team prepared for go-live
- [ ] Automated deployment runs (or manual sfdx deploy)
- [ ] Health checks pass
- [ ] Live load test from Loadsmart
- [ ] Go-live announcement sent
- [ ] Support team briefed

### Post-Deployment
- [ ] Monitor logs for 24 hours
- [ ] Verify polling is active
- [ ] Check first invoice generation
- [ ] Confirm settlement batch Monday 1 AM
- [ ] Validate portal access
- [ ] Document any issues
- [ ] Plan Phase 2 UAT timeline

---

**Deployment Ready: Phase 1 Complete ✅**

Repository: https://github.com/seb-roman/kwb-salesforce-loadsmart.git
