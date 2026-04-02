# Agent 5: Day 3 Implementation Plan (April 2-3, 2026)

**Mission:** Set up Community Cloud + Shipper Portal Foundation  
**Target:** 50% complete by EOD April 3  
**Status:** ACTIVE — Implementation Start

---

## Day 3 Deliverables (This Session)

### PHASE 1A: Community Cloud Setup (2 hours)
- ✅ Create Experience Cloud site: "KWB Shipper Portal"
- ✅ Configure community settings (authentication, custom domain)
- ✅ Set up permission sets: Portal_Shipper, Portal_Shipper_Admin, Portal_Read_Only
- ✅ Test community access (verify login works)

### PHASE 1B: Shipper Portal Pages (Foundation) (4 hours)
- ✅ **Page 1 - Load List** (Lightning Component)
  - Apex Controller: LoadListController.cls (query loads by shipper_account)
  - LWC: loadList.js + loadList.html
  - Features: Filterable by status, date; pagination; row-level security
  
- ✅ **Page 2 - Load Detail** (Lightning Component)
  - Apex Controller: LoadDetailController.cls (single load + related records)
  - LWC: loadDetail.js + loadDetail.html
  - Features: Status timeline, real-time map placeholder, documents section
  
- ✅ **Page 3 - Invoice Portal** (Lightning Component)
  - Apex Controller: InvoiceListController.cls (query invoices by shipper)
  - LWC: invoiceList.js + invoiceList.html
  - Features: Invoice list, filter by status/date, download PDF placeholder
  
- ✅ **Page 4 - Account Profile** (Lightning Component)
  - Apex Controller: AccountProfileController.cls (user's account + edit)
  - LWC: accountProfile.js + accountProfile.html
  - Features: Read-only company info, editable billing contact
  
- ✅ **Page 5 - Help/FAQ** (Static Page)
  - Static HTML content

### PHASE 1C: Security & Row-Level Sharing (1 hour)
- ✅ Configure Sharing Rules (shipper sees only own account loads/invoices)
- ✅ Field-Level Security (hide sensitive fields per portal)
- ✅ Permission Set assignments (Shipper, Admin, Read-Only)

### PHASE 1D: Mobile Responsiveness & Accessibility (1 hour)
- ✅ Test on iPhone (375px width)
- ✅ Test on Android tablet (768px width)
- ✅ Verify WCAG AA compliance (colors, fonts, navigation)

### PHASE 1E: Testing & Documentation (1 hour)
- ✅ End-to-end test: Login → view load → download invoice
- ✅ Row-level security test: Verify shipper B cannot see shipper A data
- ✅ Documentation: Component readme, deployment guide

---

## Implementation Approach

### Tech Stack (Confirmed)
- **Platform:** Salesforce Experience Cloud (Community Cloud)
- **UI Framework:** Lightning Web Components (LWC)
- **Backend:** Apex REST Controllers + SOQL
- **Database:** Load__c, Account, Invoice__c (via Agent 4)
- **Real-Time:** Platform Events (Phase 2 integration)
- **Maps:** Google Maps Embed API (Phase 2 integration)

### File Structure (Salesforce DX)
```
force-app/main/default/
├── lwc/
│   ├── loadList/
│   │   ├── loadList.js
│   │   ├── loadList.html
│   │   ├── loadList.css
│   │   └── loadList.js-meta.xml
│   ├── loadDetail/
│   ├── invoiceList/
│   ├── accountProfile/
│   ├── helpFaq/
│   └── ... (all portal components)
├── classes/
│   ├── LoadListController.cls
│   ├── LoadListControllerTest.cls
│   ├── LoadDetailController.cls
│   ├── InvoiceListController.cls
│   ├── AccountProfileController.cls
│   └── ... (all controllers + tests)
├── objects/
│   ├── Load__c/ (Agent 1 schema)
│   ├── Account/ (Salesforce standard)
│   ├── Invoice__c/ (Agent 4 schema)
│   └── ...
├── permissionsets/
│   ├── Portal_Shipper.permissionset-meta.xml
│   ├── Portal_Shipper_Admin.permissionset-meta.xml
│   └── Portal_Read_Only.permissionset-meta.xml
├── sharingRules/
│   ├── Load__c.sharingRules-meta.xml
│   ├── Invoice__c.sharingRules-meta.xml
│   └── ...
└── experiences/
    └── KWB_Shipper_Portal/ (Community Cloud config)
```

### Coding Standards (Production Quality)
- ✅ **Apex:** Controller classes with SOQL injection protection, bulkification, >80% test coverage
- ✅ **LWC:** Reactive wire adapters, CSS utility classes (Salesforce Slds), mobile-first responsive design
- ✅ **Error Handling:** User-friendly error messages, no stack traces exposed to end users
- ✅ **Performance:** Indexed SOQL queries, pagination (25 records/page), caching where appropriate

---

## Key Decisions to Implement

### Decision 1: Community Cloud Instance (Corey, April 2)
- **Approach:** Single Salesforce instance, 2 Community Sites (Shipper + Carrier)
- **Rationale:** Simpler management, shared user base, row-level security enforced at sharing rule level
- **Alternative:** Separate instances (more isolated, higher maintenance)

### Decision 2: Real-Time Tracking (Corey, April 2)
- **Approach:** Platform Events for <5 sec propagation
- **Phase 1:** Platform Events configured (no data flowing yet — waits on Agent 3)
- **Phase 2:** Agent 3 sends tracking events → Portal refreshes via Platform Events

### Decision 3: Authentication (Corey, April 2)
- **Approach:** Salesforce Community Cloud Standard (username/password)
- **Optional:** SSO (Okta/Azure AD) for enterprise shippers
- **Phase 1:** Standard login only; SSO added in Phase 2

### Decision 4: Exports (Corey, April 2)
- **Approach:** NO CSV/Excel exports for external users (data security)
- **Allowed:** Print-to-PDF (browser capability), download individual PDFs (invoice, BOL, POD)
- **Rationale:** Prevents bulk data exfiltration, shipper competitive intelligence protected

---

## Blockers & Risks

| Risk | Impact | Mitigation | Status |
|------|--------|-----------|--------|
| Agent 4 Invoice__c schema not ready | High | Use mock Invoice records + query object schema from Agent 4 when ready | MONITOR |
| Google Maps API key not configured | Medium | Hard-code placeholder map; integrate real maps in Phase 2 | PLAN |
| Community Cloud licenses insufficient | Medium | Use Loadsmart demo org if available; buy additional licenses | CHECK |
| Apex code coverage <80% | High | Write comprehensive unit tests for all controller classes | MITIGATE |
| Mobile responsiveness not tested | Medium | Test on actual devices (iPhone + Android); use Chrome DevTools responsive mode | PLAN |

---

## Success Criteria (Day 3 EOD)

✅ Community Cloud site "KWB Shipper Portal" deployed + accessible  
✅ Login page works with test user credentials  
✅ Load List page displays shipper's own loads (row-level security enforced)  
✅ Load Detail page shows full load info + documents  
✅ Invoice Portal shows shipper's invoices + allows dispute submission  
✅ Account Profile editable (billing contact, payment method)  
✅ Help/FAQ page displays  
✅ Mobile-responsive design tested (iPhone 375px, Tablet 768px)  
✅ WCAG AA accessibility verified (colors, fonts, keyboard navigation)  
✅ End-to-end test passing: Login → view load → download invoice  
✅ Row-level security test passing: Shipper B cannot see Shipper A data  
✅ Code > 80% test coverage (Apex controllers)  
✅ Documentation complete (component README, deployment guide, manual testing checklist)  

---

## Timeline (Day 3: April 2-3)

| Time | Task | Deliverable | Estimated |
|------|------|-----------|-----------|
| 13:47 - 14:30 | Setup + Community Cloud creation | KWB Shipper Portal site live | 45 min |
| 14:30 - 15:30 | Apex Controllers (Load, Invoice, Account) | 3 controllers + tests | 60 min |
| 15:30 - 17:00 | LWC Components (Load List, Detail) | 2 components, responsive | 90 min |
| 17:00 - 18:00 | Invoice + Account components | 2 components | 60 min |
| 18:00 - 19:00 | Row-level sharing + FLS config | Sharing rules deployed | 60 min |
| 19:00 - 19:45 | Testing (mobile, accessibility, security) | Test results documented | 45 min |
| 19:45 - 20:00 | Documentation + handoff | Day 3 summary report | 15 min |

**Total: 8 hours of focused development**

---

## Day 4 Prep (April 3-4)

- Carrier Portal pages (similar structure to Shipper)
- Ops Dashboard (10 KPI cards, internal only)
- Real-time Platform Events integration (once Agent 3 confirms data structure)

## Day 5 Prep (April 4-5)

- Management Dashboard (8 KPIs, executive view)
- Mobile driver app evaluation (Salesforce app vs React Native)
- End-to-end testing (all three portals + mobile)
- UAT readiness

---

**Status:** 🟢 READY TO BUILD  
**Next:** Start Phase 1A (Community Cloud setup)  
**Requester:** Corey Anderson  
**Approval:** Seb Roman (code review), Corey (acceptance)

