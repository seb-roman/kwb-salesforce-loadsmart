# Agent 5 - Code Review Remediation Checklist

**Reviewed by:** Agent 4 (Billing & Settlement)  
**Review Date:** April 2, 2026  
**Status:** ⚠️ CONDITIONAL APPROVE - Critical fixes required

Use this checklist to track your remediation progress. Check off items as you complete them.

---

## 🔴 PHASE 1: CRITICAL BLOCKERS (Do First - 2-3 hours)

These must be fixed before any production deployment.

### ShipperLoadDetailController.cls

- [ ] **Issue #2.1 - RLS Bypass in getCarrierInfo()**
  - Location: Lines 65-96
  - Fix: Add `AND Shipper_Account__c = :shipperAccountId` to Load query
  - Severity: CRITICAL
  - Estimated time: 15 minutes
  - Verification: Create unit test with 2 shippers, verify RLS enforcement

### shipperLoadList.js

- [ ] **Issue #5.1 - Missing ShowToastEvent Import**
  - Location: Lines 1-5
  - Fix: `import { ShowToastEvent } from 'lightning/platformShowToastEvent';`
  - Severity: CRITICAL
  - Estimated time: 5 minutes
  - Verification: Test error notification on invalid input

### ShipperAccountProfileController.cls

- [ ] **Issue #4.1 - Missing CRUD/FLS on Contact Updates**
  - Location: Lines 76-115 (updateBillingContact method)
  - Fix: Add createable()/updateable() checks and FLS validation for all fields
  - Severity: CRITICAL
  - Estimated time: 30 minutes
  - Verification: Unit test creating/updating contact with limited permissions

- [ ] **Issue #4.2 - Missing CRUD/FLS on PaymentMethod Updates**
  - Location: Lines 117-138 (updatePaymentMethod method)
  - Fix: Add createable()/updateable() checks before insert/update
  - Severity: CRITICAL
  - Estimated time: 30 minutes
  - Verification: Unit test with restricted PaymentMethod__c permissions

**Subtotal Phase 1:** ~90 minutes

---

## 🟠 PHASE 2: HIGH-PRIORITY (Before Release - 3-4 days)

Must be fixed before code can be merged to production branch.

### ShipperLoadListController.cls

- [ ] **Issue #1.1 - SQL Injection Vulnerability**
  - Location: Lines 78-84, 112-118
  - Current: Concatenates user input in dynamic SOQL
  - Fix: Validate status values against picklist before use (or refactor to avoid dynamic SOQL)
  - Severity: HIGH
  - Estimated time: 1-2 hours
  - Verification: Unit test with malformed status input

- [ ] **Issue #1.2 - Missing FLS Checks**
  - Location: Lines 65-74 (getLoads method)
  - Fix: Create helper method `hasFieldAccess()` and call at method start
  - Severity: HIGH
  - Estimated time: 1 hour
  - Verification: Restrict field access in profile, verify AuraHandledException thrown

- [ ] **Issue #1.3 - Missing CRUD Checks**
  - Location: Lines 65-74 (getLoads method)
  - Fix: Add `Load__c.SObjectType.getDescribe().isAccessible()` check
  - Severity: HIGH
  - Estimated time: 30 minutes
  - Verification: Remove Load__c READ permission, verify exception thrown

- [ ] **Issue #1.4 - Query Result Count Duplication** (Optional but recommended)
  - Location: Lines 88-111
  - Fix: Extract filter building logic to separate method
  - Severity: MEDIUM/LOW
  - Estimated time: 1 hour
  - Benefit: Maintainability + prevents sync issues

**Subtotal ShipperLoadListController:** 3.5-5 hours

---

### ShipperLoadDetailController.cls

- [ ] **Issue #2.2 - Missing FLS Checks**
  - Location: Lines 32-58 (getLoadDetail method)
  - Fix: Validate FLS access on all returned fields
  - Severity: HIGH
  - Estimated time: 1 hour
  - Verification: Unit test restricting field access

- [ ] **Issue #2.3 - Missing CRUD Checks**
  - Location: Lines 32-58 (getLoadDetail method)
  - Fix: Add Load__c.SObjectType.getDescribe().isAccessible()
  - Severity: HIGH
  - Estimated time: 30 minutes

- [ ] **Issue #2.4 - Missing Null Safety on Related Objects**
  - Location: Lines 51-63 (Stop__c and Invoice__c queries)
  - Fix: Wrap queries in try-catch for SObjectException
  - Severity: MEDIUM
  - Estimated time: 30 minutes
  - Benefit: Graceful handling if custom objects don't exist

**Subtotal ShipperLoadDetailController:** 2-2.5 hours

---

### ShipperInvoiceListController.cls

- [ ] **Issue #3.1 - Missing FLS Checks**
  - Location: Lines 43-52 (getInvoices method)
  - Fix: Validate FLS access on returned fields
  - Severity: HIGH
  - Estimated time: 1 hour

- [ ] **Issue #3.2 - Missing CRUD Checks**
  - Location: Lines 43-52 (getInvoices method)
  - Fix: Add Invoice__c.SObjectType.getDescribe().isAccessible()
  - Severity: HIGH
  - Estimated time: 30 minutes

- [ ] **Issue #3.3 - Missing FLS on Dispute Creation**
  - Location: Lines 140-155 (submitDisputeRequest method)
  - Fix: Check Dispute__c isCreateable() and field updateability before insert
  - Severity: HIGH
  - Estimated time: 1 hour

- [ ] **Issue #3.4 - Missing FLS on Payment Queries** (Optional)
  - Location: Lines 124-128
  - Fix: Add Payment__c field FLS checks
  - Severity: LOW
  - Estimated time: 30 minutes

**Subtotal ShipperInvoiceListController:** 3-3.5 hours

---

### ShipperAccountProfileController.cls

- [ ] **Issue #4.3 - Unencrypted Sensitive Payment Data**
  - Location: Line 133 (Account_Last_Four__c)
  - Fix: Consider Salesforce Vault or encrypted field for bank data
  - Severity: HIGH
  - Estimated time: 2 hours (design decision + implementation)
  - Note: May require architecture review

- [ ] **Issue #4.4 - Email Validation Missing**
  - Location: Lines 76-115 (updateBillingContact method)
  - Fix: Add regex pattern validation before insert/update
  - Severity: HIGH
  - Estimated time: 30 minutes

- [ ] **Issue #4.5 - Missing FLS on Account Queries**
  - Location: Lines 32-42 (getAccountProfile method)
  - Fix: Validate FLS access on Account fields
  - Severity: HIGH
  - Estimated time: 1 hour

- [ ] **Issue #4.6 - Missing CRUD Check on User Queries**
  - Location: Lines 155-170 (getPortalUsers method)
  - Fix: Add User.SObjectType.getDescribe().isAccessible() check
  - Severity: MEDIUM
  - Estimated time: 30 minutes

**Subtotal ShipperAccountProfileController:** 4.5 hours

---

### shipperLoadList.js

- [ ] **Issue #5.2 - Fix Navigation (window.open won't work)**
  - Location: Line 92 (navigateToLoadDetail method)
  - Current: `window.open('/shipper-portal/load-detail/${loadId}', '_self')`
  - Fix: Use NavigationMixin with proper navigation targets
  - Severity: HIGH
  - Estimated time: 1.5 hours
  - Verification: Test navigation to load detail page works

- [ ] **Issue #5.3 - Fix handleRowAction Implementation**
  - Location: Lines 108-119
  - Current: Expects lightning-datatable but uses HTML table
  - Fix: Either use lightning-datatable OR implement inline button handlers
  - Severity: HIGH
  - Estimated time: 2 hours
  - Verification: Test View/Download buttons work on each row

- [ ] **Issue #5.4 - Add Filter Change Debouncing**
  - Location: Lines 68-87 (filter change handlers)
  - Fix: Add setTimeout debouncing to prevent server spam
  - Severity: HIGH (performance)
  - Estimated time: 1 hour
  - Verification: Observe network tab, confirm no spam on date entry

**Subtotal shipperLoadList.js:** 4.5 hours

---

### Unit Tests (CRITICAL - Zero Coverage for 3 Controllers)

- [ ] **Create ShipperLoadDetailControllerTest**
  - Target: 80%+ code coverage
  - Must include:
    - [ ] Test getLoadDetail() with valid load
    - [ ] Test RLS: user cannot access other shipper's load
    - [ ] Test getCarrierInfo() with and without carrier
    - [ ] Test missing related records (null safety)
    - [ ] Test user without permissions gets error
  - Estimated time: 2 hours
  - Acceptance: Coverage >80%, all critical paths tested

- [ ] **Create ShipperInvoiceListControllerTest**
  - Target: 80%+ code coverage
  - Must include:
    - [ ] Test getInvoices() pagination
    - [ ] Test Overdue filter logic
    - [ ] Test RLS on invoice access
    - [ ] Test submitDisputeRequest() creates record
    - [ ] Test user cannot access other shipper's invoices
  - Estimated time: 2 hours

- [ ] **Create ShipperAccountProfileControllerTest**
  - Target: 80%+ code coverage
  - Must include:
    - [ ] Test getAccountProfile() returns correct account
    - [ ] Test updateBillingContact() creates new contact
    - [ ] Test updateBillingContact() updates existing contact
    - [ ] Test updatePaymentMethod() create and update paths
    - [ ] Test getPortalUsers() returns only portal users
    - [ ] Test RLS on account access
  - Estimated time: 2.5 hours

**Subtotal Tests:** 6.5 hours

---

## 🟡 PHASE 3: MEDIUM PRIORITY (Polish - 2-3 days)

Fix these before QA testing begins.

### shipperLoadList.html & shipperLoadList.js

- [ ] **Issue #5.5 - Fix isEmptyList State Binding**
  - Location: Line 158 (HTML) + JavaScript
  - Fix: Set isEmptyList = true when loads.length === 0
  - Severity: LOW
  - Estimated time: 15 minutes

- [ ] **Issue #6.1 - Add aria-labels to Form Controls**
  - Location: Lines 32-50 (filter inputs)
  - Fix: Add `aria-label="..."` to each select/input
  - Severity: MEDIUM (accessibility)
  - Estimated time: 30 minutes

- [ ] **Issue #6.2 - Add Table Header Associations**
  - Location: Lines 104-131 (table)
  - Fix: Add `scope="col"` to <th>, add `headers="..."` to <td>
  - Severity: MEDIUM (accessibility)
  - Estimated time: 1 hour

- [ ] **Issue #6.3 - Add aria-busy to Loading State**
  - Location: Lines 71-80
  - Fix: Add `aria-busy={isLoading}` to container
  - Severity: MEDIUM (accessibility)
  - Estimated time: 15 minutes

- [ ] **Issue #6.4 - Improve Pagination Accessibility**
  - Location: Lines 149-157
  - Fix: Wrap in <nav>, add aria-labels, use aria-live for page info
  - Severity: MEDIUM (accessibility)
  - Estimated time: 30 minutes

**Subtotal Phase 3 - LWC:** 2.5 hours

---

### ShipperLoadListController.cls (Optional Improvements)

- [ ] Issue #1.4 - Consolidate filter logic (if not done in Phase 2)
  - Estimated time: 1 hour

---

### ShipperAccountProfileController.cls (Optional Improvements)

- [ ] Consideration: Refactor to use Salesforce Vault for payment method storage
  - (This may require broader architecture discussion)

---

## 📋 Final Checklist Before Submission

- [ ] All CRITICAL issues fixed (Phase 1)
- [ ] All HIGH-priority issues fixed (Phase 2)
- [ ] Unit test coverage >80% for all 4 controllers
- [ ] `npm run test` passes (if using Jest)
- [ ] `npm run lint` passes (if using ESLint)
- [ ] Apex test runs: 100% pass, >80% code coverage
- [ ] LWC accessibility audit passed (axe DevTools or similar)
- [ ] Manual testing of all main flows:
  - [ ] Load list pagination works
  - [ ] Filters work (status, date, load type)
  - [ ] Load detail displays with all sections
  - [ ] Invoice list and detail work
  - [ ] Dispute submission works
  - [ ] Account profile updates work
  - [ ] Navigation works on all browsers
- [ ] Mobile testing at 375px, 768px, 1920px viewports
- [ ] All error messages are user-friendly (no Apex stack traces)

---

## 🎯 Submission Checklist

When ready to resubmit for review:

- [ ] Create feature branch: `feature/agent5-portal-review-fixes`
- [ ] Commit message format:
  ```
  fix(portal): resolve critical security issues per Agent 4 code review
  
  - Add RLS check to getCarrierInfo()
  - Add FLS/CRUD checks to all controllers
  - Fix ShowToastEvent import
  - Complete unit test coverage
  
  Fixes: Agent 4 Review - Apr 2, 2026
  ```
- [ ] Push branch and create Pull Request
- [ ] Link this remediation checklist in PR description
- [ ] Tag Agent 4 for re-review
- [ ] Include test coverage metrics in PR

---

## 📞 Questions?

If you need clarification on any issue:
1. Review the detailed explanation in `AGENT4_REVIEW_OF_AGENT5.md`
2. Check the code examples provided in each issue section
3. Request sync with Agent 4 to discuss implementation approach

---

## 🚀 Progress Tracking

As you complete phases, update the status:

**Phase 1 Status:** ⬜ Not Started  
**Phase 2 Status:** ⬜ Not Started  
**Phase 3 Status:** ⬜ Not Started  

**Overall Completion:** 0% (0 / 35 items)

---

**Good luck! You've got this. 💪**

Questions or blockers? Tag Agent 4 for help.
