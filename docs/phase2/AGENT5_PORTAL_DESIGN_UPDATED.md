# AGENT 5: PORTAL & DASHBOARDS — UPDATED DESIGN (COREY'S DECISIONS)

**Last Updated:** April 2, 2026, 1:15 PM ET (Operational decisions locked in)

---

## EXECUTIVE SUMMARY

This is the **UPDATED** Agent 5 design reflecting operational decision from Corey Anderson (April 2, 1:12 PM):

**MAJOR CHANGE:** Portal now includes **BOTH shipper + carrier portals** (not just shipper).

- ✅ Shipper portal (load tracking, invoicing, account management)
- ✅ **NEW: Carrier portal** (load visibility, settlement history, payment status)
- ✅ Ops dashboard (internal KPI tracking)
- ✅ Management dashboard (executive summary)
- ⏳ Mobile driver app (Phase 1 vs Phase 2 TBD — Corey to decide)

---

## PORTAL ARCHITECTURE (UPDATED)

### Overview

**Two Customer-Facing Portals (Same Salesforce Community Cloud instance):**

1. **Shipper Portal** — For shipper customers (e.g., Scotts Miracle-Gro, Lowe's)
   - Load tracking (status, map, ETA)
   - Invoice management (view, download, payment history)
   - Account management (billing contact, payment method)

2. **Carrier Portal** — NEW — For carrier customers (KWB's carrier network)
   - Load assignments (upcoming, in-progress, completed)
   - Settlement history (what KWB owes, payment status)
   - Payment details (ACH account setup, payment schedule)
   - Support (contact KWB dispatcher, file claims)

**Security Model:** 
- Row-level sharing enforced
- Shipper users see only their own loads + invoices
- Carrier users see only their assigned loads + their settlement records
- No cross-visibility (shipper can't see other shippers, carrier can't see other carriers)

---

## SHIPPER PORTAL (UNCHANGED FROM AGENT 5 DESIGN)

### Pages

1. **Load List** — All shipper's loads (filterable by status, date)
   - Status: Posted, Assigned, Dispatched, In-Transit, Delivered, Invoiced
   - Key info: Load #, origin, destination, status, ETA, shipper rate

2. **Load Detail** — Tracking view for specific load
   - Shipper/receiver details
   - Real-time map (origin, destination, current location)
   - Status timeline (posted → delivered)
   - ETA countdown
   - Driver name + contact (if not confidential)
   - Rate confirmation PDF (download)

3. **Invoice Portal** — All invoices from shipper
   - List: Date, invoice #, amount, status (draft, sent, paid)
   - Detail: Line items (freight, fuel, accessorials), total, due date
   - Download PDF
   - Payment status (unpaid, partial, paid)

4. **Account Profile** — Shipper company info
   - Company name, address, billing contact
   - Preferred payment method
   - Billing contact edit (update email, phone)

5. **Help/FAQ** — Self-serve knowledge base
   - How to track a load
   - Invoice questions
   - Contact KWB support

6. **Logout** — Sign out

### Data Security

- Shipper user sees only own loads (row-level sharing: load.shipper_account = portal_user.shipper_account)
- Cannot see competitor shippers' loads
- Cannot download load list (prevents competitive intelligence)
- Portal user limited to read-only operations (no load creation, rate changes, etc.)

---

## CARRIER PORTAL (NEW)

### Purpose

Provide KWB's carrier customers visibility into:
- Loads assigned to them
- Settlement history (earnings, deductions, net payment)
- Payment details (when paid, how paid)
- Support (submit claims, contact dispatcher)

### Pages

1. **Load Assignments** — Loads assigned to carrier
   - Status filters: Pending, Accepted, In-Transit, Delivered, Paid
   - Key info: Load #, shipper, origin, destination, pickup/delivery times, rate
   - Detail page: Full load info + tracking (if in progress)
   - Actions: Accept/Decline bid (Phase 1), Upload POD (Phase 1)

2. **Settlement History** — Weekly/monthly settlements
   - List: Settlement date, period (e.g., "Week of April 1"), total earned, deductions, net payment
   - Detail: Line items (loads, amounts), deductions breakdown, payment method, payment date
   - Example: "Week of April 1: 12 loads, $8,400 earned, -$200 claims, $8,200 ACH paid April 2"

3. **Payment Status** — Upcoming + recent payments
   - Next payment date
   - Recent payment history (last 3-6 months)
   - Payment method (ACH account ending in XXXX)
   - Bank account verification status

4. **Account Profile** — Carrier company info
   - Company name, DOT #, MC #
   - Primary contact
   - Bank account info (for ACH setup)
   - Equipment (what fleet this carrier manages)

5. **Claims/Disputes** — Submit & track issues
   - Claim types: Disputed rate, shortfall, damage claim, detention
   - Status: Submitted, In Review, Approved, Paid
   - History of all claims filed

6. **Support** — Contact KWB
   - Dispatcher contact (phone, email)
   - Help resources
   - Report technical issues

7. **Logout** — Sign out

### Data Security

- Carrier user sees only own loads + own settlements (row-level sharing)
- Cannot see other carriers' loads or earnings
- Cannot see shipper details (origin/destination company names masked on load detail)
- Cannot modify any data (read-only view of assignments + payments)

---

## OPERATIONAL DASHBOARDS (UNCHANGED FROM AGENT 5 DESIGN)

### Ops Dashboard (Internal)

**For:** Dispatchers, operations team

**KPI Cards (10):**
1. Loads by status (gauge: posted, assigned, dispatched, in_transit, delivered)
2. On-time delivery % (KPI: target 95%, actual)
3. Revenue MTD (number card with trend)
4. Average margin $ + % (gauge)
5. Carrier utilization % (bar chart)
6. Top 5 shippers by revenue (bar chart)
7. Top 5 carriers (by on-time %)
8. Exception queue (table: load #, type, severity, age, action)
9. Settlement backlog ($ outstanding, # loads, aging)
10. Fuel price trend (line chart)

**Real-time refresh:** Every 60 seconds

**Drill-down:** Click any card → detail records (e.g., click "In-Transit" → see all in-transit loads)

**Mobile-responsive:** Dashboards work on phone + tablet

### Management Dashboard (Executive)

**For:** Corey, Kyle, Jennifer (executives)

**KPI Cards (8):**
1. Gross profit MTD + trend
2. On-time delivery % (goal vs actual)
3. Revenue per load (average)
4. Margin per load (average)
5. Shipper count (active, new, churned)
6. Carrier count (active, utilization)
7. Growth rate (loads/week, revenue trend)
8. Risk metrics (exceptions, disputes, aged AR)

**5-minute review:** All key metrics visible at a glance

**Mobile-responsive:** Works on all devices

---

## QUESTIONS FOR COREY (FROM AGENT 5)

**10 Strategic Questions** — Corey to answer (will circle up with Jennifer):

1. **Portal priority:** Shipper vs Carrier — which launch first in Phase 1?
   - Option A: Shipper only (Phase 1), add Carrier (Phase 2)
   - Option B: Carrier only (Phase 1), add Shipper (Phase 2)
   - Option C: Both simultaneously (requires longer Phase 1)

2. **Mobile driver app timeline:** Phase 1 or Phase 2?
   - Phase 1: Include in MVP (check-in, POD capture, load view)
   - Phase 2+: Build after Phase 1 stabilizes

3. **Shipper-visible reports:** Which metrics do shippers see?
   - On-time % (how reliable is KWB?)
   - Cost per mile (price transparency?)
   - Load count (volume shipped?)
   - All of above, or limited set?

4. **Carrier settlement visibility:** How detailed?
   - Summary only (total paid, payment date)
   - Detailed (load-by-load breakdown, deductions explained)
   - Both (default summary, expandable detail)

5. **Real-time refresh frequency:** 60 sec, 5 min, or configurable?
   - 60 sec: More responsive, higher server load
   - 5 min: Less responsive, lower load
   - Configurable per user role (ops team = fast, shipper = slower)

6. **Exception visibility:** What do shippers see?
   - All exceptions (late, missed pickup, idle, offline, etc.)
   - Only delivery-critical exceptions (late, missed, offline)
   - No exceptions (shipper only sees final status)

7. **Mobile app platform:** iOS, Android, or cross-platform?
   - React Native (cross-platform, faster to market)
   - Flutter (Google, good performance)
   - Native (iOS + Android separately, best performance)

8. **User authentication:** Salesforce SSO or separate login?
   - Salesforce SSO (shipper/carrier logins via Salesforce)
   - Separate (custom login portals, less integration)
   - Hybrid (SSO for internal, separate for external users)

9. **Claims/disputes workflow:** Full self-serve or require KWB follow-up?
   - Self-serve submission + tracking
   - Submission + KWB approval + tracking
   - Phone/email only (no self-serve)

10. **Reporting exports:** CSV, PDF, or integration?
    - CSV (shipper downloads data)
    - PDF (formatted reports)
    - Tableau/Power BI (real-time dashboards, third-party)
    - All three options available

---

## IMPLEMENTATION PRIORITIES (DAYS 3-5)

### Phase 1 (Weeks 3-5 of project)

**Priority 1 (Weeks 3-4):**
- Shipper portal infrastructure (Community Cloud setup)
- Shipper load list + detail pages (with tracking map)
- Shipper invoice portal (view, download PDF)

**Priority 2 (Weeks 4-5):**
- Carrier portal infrastructure (Community Cloud setup)
- Carrier load assignments + settlement history
- Ops dashboard (10 KPI cards, real-time refresh)

**Priority 3 (Weeks 5+):**
- Management dashboard
- Advanced reports
- Mobile driver app (Phase 1 MVP or defer to Phase 2)

### Phase 2 (Weeks 6-10 of project)

- Mobile driver app (if not Phase 1)
- Claims/disputes workflow
- Advanced reporting + exports
- Tableau/Power BI integration (if requested)

---

## TECHNOLOGY STACK

**Platform:** Salesforce Community Cloud (included in Enterprise license)

**Frontend:**
- Shipper portal: Lightning Web Components (LWC) + Aura
- Carrier portal: Lightning Web Components (LWC) + Aura
- Dashboards: Lightning (included, real-time via Platform Events)

**Backend:**
- Salesforce APIs (REST, metadata, reporting)
- Platform Events (for real-time <5 sec updates)
- Apex (custom logic if needed)

**Security:**
- Row-level sharing (enforces data isolation)
- Field-level security (hide sensitive fields per role)
- Page layouts per portal user role

---

## DATA REQUIREMENTS

**From other agents:**
- Agent 1 (Load, Stop, Driver, Carrier, Equipment schema)
- Agent 2 (Carrier scoring, FMCSA data)
- Agent 3 (Tracking, exceptions, real-time location)
- Agent 4 (Invoice, Settlement, rate card data)

**New requirements for portals:**
- Portal user objects (PortalUser__c, or use standard User + Contact)
- Row-level sharing rules (shipper sees own loads, carrier sees assigned loads)
- Permission sets (portal user, carrier user, shipper user)

---

## OUTSTANDING QUESTIONS FOR SEB

1. **Single Community Cloud or separate instances?** (Shipper + Carrier in one portal instance vs separate?)
2. **Portal user model:** Create custom PortalUser__c or use Salesforce Contact as portal user?
3. **Single sign-on (SSO):** Should portal use Salesforce OAuth or separate identity?
4. **Real-time updates:** Use Platform Events (Seb + Agent 3 collaboration) for <5 sec refresh?
5. **Shipper report visibility:** Should shipper reports show competitor-sensitive metrics (e.g., on-time % could leak info about KWB's reliability)?

---

## BLOCKERS FOR OTHER AGENTS

**From Agent 1 (Schema):**
- Portal user role support needed (may need User role hierarchy updates)

**From Agent 3 (Tracking):**
- Real-time location data via Platform Events (for <5 sec dashboard refresh)
- Exception severity levels (to determine shipper visibility)

**From Agent 4 (Billing):**
- Settlement consolidation (to display in carrier portal)
- Invoice status transitions (to show on shipper portal)

---

**Status:** ✅ Updated with Corey's operational decisions. Ready for Days 3-5 implementation (April 4+).

**Next:** Agent 5 to build portal pages + components implementing this updated design. Corey to answer 10 strategic questions + confirm Phase 1 priorities (shipper vs carrier first).
