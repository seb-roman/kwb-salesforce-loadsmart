# AGENT 5: OPERATIONAL DECISIONS — FINAL (COREY, APRIL 2, 1:32 PM)

---

## PORTAL TIMELINE & SCOPE

**Question 1: Portal priority — which launch first?**

**ANSWER:** ✅ **Ops, Shipper, AND Carrier concurrently**

**Implication:** All three portals develop in parallel (weeks 3-5 Phase 1)
- **Ops Dashboard:** Internal only, full KPI visibility, real-time
- **Shipper Portal:** External (shipper customers), read-only load tracking + invoicing
- **Carrier Portal:** External (carrier customers), read-only assignments + settlements

**No sequential rollout.** All three go live together.

---

## MOBILE DRIVER APP

**Question 2: Phase 1 or Phase 2?**

**ANSWER:** ✅ **Phase 1 — necessary to streamline ops**

**Implication:** Mobile driver app is critical for operations (driver check-ins, POD capture)
- Build in Phase 1 (weeks 3-5, likely weeks 4-5 as secondary priority after portals)
- MVP features: Check-in, POD capture, load view, offline-capable
- Tech stack: Salesforce mobile app (if feasible) OR React Native (iOS + Android)

---

## SHIPPER PORTAL VISIBILITY

**Question 3: Shipper reports — what metrics do shippers see?**

**ANSWER:** Pickup information, delivery information, cost, equipment, carrier transporting load

**Implementation:**
1. **Pickup Info:** Shipper name (already known), address, time window, actual pickup time
2. **Delivery Info:** Receiver name, address, time window, actual delivery time, POD status
3. **Cost:** Rate charged (shipper_rate__c), fuel surcharge, total invoice amount
4. **Equipment:** Equipment type (flatbed, van, reefer, etc.), length if applicable
5. **Carrier:** Carrier name, contact info (optional — may be confidential), DOT # (optional)

**No shipper reports on:**
- Carrier rate (what KWB pays carrier) — confidential
- Margin (shipper profit) — confidential
- Other shippers' loads or rates
- KWB internal metrics

**Adjustments:** Will refine in UAT based on shipper feedback

**Security:** Row-level sharing enforced (shipper sees only own loads)

---

## CARRIER PORTAL VISIBILITY

**Question 4: Carrier portal — what do they see?**

**ANSWER:** What (commodity), where (origin/destination), when (pickup/delivery times), price (rate paid to carrier)

**Implementation:**
1. **What:** Commodity description, weight, units, hazmat/special handling flags
2. **Where:** Origin address + company, destination address + company
3. **When:** Pickup window (begin/end times), delivery window (begin/end times), scheduled times (if confirmed)
4. **Price:** Rate paid to carrier (what KWB is paying them), fuel surcharge breakdown

**No carrier visibility into:**
- Shipper rate (what KWB charges shipper) — confidential
- Shipper name or contact (destination receiver yes, but shipper company masked if sensitive)
- Other carriers' rates or loads
- KWB margin or profitability
- Shippers' business intelligence

**Adjustments:** Will refine in UAT based on carrier feedback

---

## REAL-TIME TRACKING

**Question 5: Real-time refresh frequency?**

**ANSWER:** ✅ **Real-time**

**Implementation:**
- Shipper tracking updates: Real-time (via Platform Events, <5 sec)
- Shipper dashboard refresh: Real-time
- Carrier assignment updates: Real-time
- KPI dashboards (internal ops): Real-time

**Technical approach:** Use Salesforce Platform Events for <5 sec propagation (no polling)

---

## EXCEPTION VISIBILITY

**Question 6: Real-time exception visibility to external users?**

**ANSWER:** Real-time **(depending on cost effectiveness)**

**Interpretation:** 
- **Internal (ops team):** Real-time exception alerts (critical for dispatching)
- **External (shipper/carrier):** Real-time exceptions IF cost-effective, otherwise allow brief latency (5-10 min)
  - Shipper exceptions: Show delivery-critical only (late, missed, offline)
  - Carrier exceptions: Show assignment changes, rate disputes
  - Don't spam external users with noise (internal exceptions = noisy, external = actionable only)

**Cost consideration:** Real-time Platform Events are free; if cost is issue, use 5-min batch instead

---

## MOBILE APP PLATFORM

**Question 7: iOS, Android, or cross-platform?**

**ANSWER:** ✅ **Use Salesforce mobile app if possible. If not, React Native (iOS + Android)**

**Decision Tree:**
1. **Can we use Salesforce mobile app?** (CRM app, custom components via LWC)
   - Pros: No additional development, uses existing Salesforce auth, included in license
   - Cons: Limited customization, may not support offline-first POD capture
   - **Recommendation:** Try Salesforce app first. If limitations hit UAT, pivot to React Native.

2. **If not feasible: React Native (cross-platform)**
   - Covers iOS + Android from single codebase
   - Offline-capable (Firebase sync)
   - Better UX for POD capture (native camera access)
   - Higher dev cost (~30% more than Salesforce app)

**Implementation:** Agent 5 designs for Salesforce app first; React Native as fallback option.

---

## USER AUTHENTICATION

**Question 8: Internal vs external users?**

**ANSWER:** ✅ **External users log into Salesforce Community**

**Auth Model:**
- **Internal users (KWB staff):** Login to Salesforce org directly (username/password or SSO)
- **External users (shipper/carrier customers):** Login to Salesforce Community Cloud (separate login portal, not main Salesforce org)
  - Community uses Contact/Account-based user model
  - Each shipper = Community user (associated to Account)
  - Each carrier = Community user (associated to Carrier Account)
  - No custom authentication needed; use Salesforce's built-in Community SSO

**Security:** Community isolates external users from internal Salesforce data (row-level sharing enforced)

---

## REPORTING & EXPORTS

**Question 10: Reporting for internal vs external?**

**ANSWER:**
- **Internal users:** Standard Salesforce reporting (reports, dashboards, all functionality)
- **External users:** See their data through Community portal access ONLY. No exports.

**Implementation:**
1. **Internal Reports (KWB staff access Salesforce Reports tab):**
   - Full Salesforce reporting (Report Builder, custom reports, scheduled exports)
   - Can export to CSV, Excel, PDF
   - Access to all shipper/carrier data (filtered by role)

2. **External Reports (Shipper/Carrier see Community portal only):**
   - Read-only view of own data (loads, invoices, settlements)
   - No Report Builder access
   - No CSV/PDF export capability (data stays in portal)
   - Print-to-PDF browser capability (shipper can print invoice, but can't bulk export)

**Data Protection:** "That's our data" — external users cannot extract shipper/carrier lists, rates, or competitive intelligence

---

## IMPLEMENTATION PRIORITIES (REVISED)

### Phase 1 (Weeks 3-5)

**Week 3-4: Concurrent Development**
- **Ops Dashboard** (internal): Real-time KPI cards, exception queue, drill-down
- **Shipper Portal** (external): Load list, load detail w/ tracking, invoice portal, account
- **Carrier Portal** (external): Load assignments, settlement history, payment status, support

**Week 4-5: Mobile + Integration**
- **Mobile Driver App** (MVP): Salesforce app or React Native POD capture, check-in, load view
- **Integration testing:** All three portals + mobile app

**Week 5-6: UAT + Adjustments**
- User acceptance testing (shipper + carrier feedback)
- Adjust visibility, UI, based on feedback
- Go-live readiness

### Phase 2+ (Weeks 6-10+)

- Advanced reporting (internal only)
- Claims workflow (carrier portal)
- Mobile app Phase 2 (GPS background, geofencing, push notifications)
- Tableau/Power BI integration (if requested)

---

## IMPLEMENTATION NOTES FOR AGENTS

### Agent 5 (Days 3-5 implementation)

1. **Ops Dashboard:** All 10 KPI cards, real-time refresh, internal users only
   - No external user access
   - Full drill-down capability
   - Lightning components

2. **Shipper Portal (Community Cloud):**
   - Pages: Load list, load detail w/ tracking, invoice portal, account profile, help
   - Visibility: Pickup info, delivery info, cost, equipment, carrier name
   - Security: Row-level sharing (shipper account = portal user account)
   - No exports (portal view only)

3. **Carrier Portal (Community Cloud):**
   - Pages: Load assignments, settlement history, payment status, account profile, claims, support
   - Visibility: What (commodity), where (origin/dest), when (times), price (carrier rate)
   - Security: Row-level sharing (carrier account = portal user account)
   - No exports (portal view only)

4. **Mobile Driver App:**
   - Evaluate Salesforce mobile app first (CRM app with LWC components)
   - If limitations found: Pivot to React Native (iOS + Android)
   - MVP features: Load view, check-in (timestamp + GPS), POD capture (photo), offline-capable

5. **Authentication:**
   - Use Salesforce Community Cloud (included in license)
   - No custom login portal needed
   - Contact/Account-based user model for external users

6. **Reporting:**
   - Internal: Use standard Salesforce Reports (no special work needed)
   - External: No reporting/export capability (portal view only, security by design)

### Outstanding Design Questions for Seb

1. **Salesforce Mobile App viability:** Can we build POD capture + offline-capable in Salesforce app, or must we use React Native?
2. **Community Cloud setup:** Single Community instance with two namespaces (shipper + carrier), or separate Community instances?
3. **Real-time exception visibility:** Cost-effective to use Platform Events for all external users? Or 5-min batch for external, real-time for internal?
4. **Print-to-PDF:** How to enable shipper/carrier to print invoice/settlement to PDF without exporting data?

---

**Status:** ✅ All 10 questions answered. Agent 5 ready for Days 3-5 implementation (April 4+).

**Next:** Seb confirms any final questions, Agent 5 begins coding portals + mobile app MVP.
