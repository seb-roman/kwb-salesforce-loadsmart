# Agent 5: Quick Reference — Remaining LWC Components

**Status:** Blueprint for Days 3-4 implementation  
**Components to Build:** 4 (Load Detail, Invoice List, Account Profile, Help/FAQ)  
**Estimated Time:** 4-5 hours  
**Pattern:** Same as shipperLoadList (responsive, accessible, mobile-first)

---

## Component 2: shipperLoadDetail

**Purpose:** Show full load details with tracking, documents, and status

**LWC Files:**
- `shipperLoadDetail.js` (~5,500 bytes)
- `shipperLoadDetail.html` (~8,000 bytes)
- `shipperLoadDetail.css` (~1,000 bytes)
- `shipperLoadDetail.js-meta.xml` (400 bytes)

**Apex Integration:**
- Controller: `ShipperLoadDetailController`
- Methods: `getLoadDetail(loadId)`, `getCarrierInfo(loadId)`
- Queries: Load + Stops + Invoices + ContentDocuments

**Key Sections (HTML):**
```
1. Header Card
   - Load #, Status (with color), ETA countdown
   - Shipper, Receiver, Commodity, Weight, Equipment

2. Real-Time Tracking Map (Phase 2)
   - Google Maps iframe (placeholder for now)
   - Origin, destination, current location pins
   - Route line
   - Last updated timestamp

3. Status Timeline
   - Pickup Window → Actual Pickup
   - In Transit (current location)
   - Delivery Window → Estimated/Actual Delivery
   - Vertical timeline UI

4. Load Details Table
   - Pickup address, company, time window, actual time
   - Delivery address, company, time window, actual time
   - Carrier info, driver name, DOT#
   - Equipment, commodity, weight, rate

5. Documents Section
   - BOL (Bill of Lading) — Download PDF
   - Rate Confirmation — Download PDF
   - POD (Proof of Delivery) — Download PDF
   - Invoice — Link to Invoice Portal

6. Tracking History (Expandable)
   - GPS updates (timestamps, locations)
   - Status changes (Posted → Assigned → In Transit → Delivered)
   - Driver events (break, fuel stop)
   - Expandable/collapsible for mobile

```

**JS Logic:**
```javascript
import { LightningElement, api, wire } from 'lwc';
import getLoadDetail from '@salesforce/apex/ShipperLoadDetailController.getLoadDetail';
import getCarrierInfo from '@salesforce/apex/ShipperLoadDetailController.getCarrierInfo';

export default class ShipperLoadDetail extends LightningElement {
    @api loadId; // Passed from parent or URL param
    @track load = {};
    @track carrierInfo = {};
    @track statusTimeline = [];
    @track isLoading = true;

    @wire(getLoadDetail, { loadId: '$loadId' })
    wiredLoadDetail({ error, data }) {
        if (data) {
            this.load = data.load;
            this.buildStatusTimeline(data.load);
            this.getCarrierDetails();
            this.isLoading = false;
        }
    }

    buildStatusTimeline(load) {
        // Create timeline events from load status
        // Pickup window → actual pickup
        // In transit
        // Delivery window → actual delivery
    }

    getCarrierDetails() {
        // Fetch carrier name, DOT#, phone
    }

    downloadDocument(docType) {
        // Download BOL, POD, rate confirmation
    }

    toggleTrackingHistory() {
        // Expand/collapse tracking events
    }
}
```

**Mobile-First CSS:**
```css
/* Timeline vertical layout on mobile, horizontal on desktop */
.timeline {
    display: flex;
    flex-direction: column;
}

@media (min-width: 768px) {
    .timeline {
        flex-direction: row;
    }
}

/* Map takes full width on mobile */
.tracking-map {
    width: 100%;
    height: 300px;
}

@media (min-width: 768px) {
    .tracking-map {
        height: 400px;
    }
}

/* Responsive table */
.load-details-table {
    overflow-x: auto;
}

@media (max-width: 375px) {
    .load-details-table {
        font-size: 12px;
    }
}
```

---

## Component 3: shipperInvoiceList

**Purpose:** Show shipper's invoices with filtering, detail view, and dispute submission

**LWC Files:**
- `shipperInvoiceList.js` (~5,000 bytes)
- `shipperInvoiceList.html` (~7,500 bytes)
- `shipperInvoiceList.css` (~900 bytes)
- `shipperInvoiceList.js-meta.xml` (400 bytes)

**Apex Integration:**
- Controller: `ShipperInvoiceListController`
- Methods: `getInvoices(...)`, `getInvoiceDetail(invoiceId)`, `submitDisputeRequest(...)`
- Queries: Invoice + InvoiceLineItem + Payment records

**Key Sections:**

```
1. Filter Panel
   - Status: All, Sent, Viewed, Paid, Unpaid, Overdue
   - Date range (from/to)
   - Apply button

2. Invoice List
   - Columns: Invoice #, Load #, Amount, Date Issued, Status, Due Date
   - Status color-coding: Sent (gray), Paid (green), Overdue (red)
   - Sortable by amount, date, status
   - Pagination (25 per page)
   - Row action: "View Details"

3. Detail Modal
   - Invoice header (number, date, due date, status)
   - Bill to: Shipper name, address
   - Line items table (freight, fuel, detention, tax)
   - Subtotal, tax, total
   - Amount paid, balance due
   - Dispute button
   - Download PDF button

4. Dispute Modal
   - Reason dropdown: Rate mismatch, incorrect weight, service failure, etc.
   - Disputed amount
   - Additional details textarea
   - Submit button

5. Payment History (if Invoice__c has Payment records)
   - Date, method, amount, status
```

**JS Logic:**
```javascript
import getInvoices from '@salesforce/apex/ShipperInvoiceListController.getInvoices';
import getInvoiceDetail from '@salesforce/apex/ShipperInvoiceListController.getInvoiceDetail';
import submitDisputeRequest from '@salesforce/apex/ShipperInvoiceListController.submitDisputeRequest';

export default class ShipperInvoiceList extends LightningElement {
    @track invoices = [];
    @track selectedInvoice = null;
    @track showDetailModal = false;
    @track showDisputeModal = false;

    loadInvoices() {
        getInvoices({
            statusFilter: this.statusFilter,
            dateFrom: this.dateFromFilter,
            dateTo: this.dateToFilter,
            pageNumber: this.pageNumber,
            pageSize: 25
        }).then(result => {
            this.invoices = result.invoices;
        });
    }

    handleViewDetails(invoiceId) {
        getInvoiceDetail({ invoiceId }).then(detail => {
            this.selectedInvoice = detail;
            this.showDetailModal = true;
        });
    }

    handleDisputeClick(invoiceId) {
        this.disputeInvoiceId = invoiceId;
        this.showDisputeModal = true;
    }

    submitDispute() {
        submitDisputeRequest({
            invoiceId: this.disputeInvoiceId,
            reason: this.disputeReason,
            amount: this.disputeAmount,
            details: this.disputeDetails
        }).then(result => {
            this.showNotification('Dispute submitted successfully');
            this.showDisputeModal = false;
            this.loadInvoices();
        });
    }

    downloadInvoicePDF(invoiceId) {
        // Generate PDF via Salesforce (Phase 2)
        window.open(`/invoices/${invoiceId}/pdf`);
    }
}
```

---

## Component 4: shipperAccountProfile

**Purpose:** View and edit shipper account details, billing contact, payment method

**LWC Files:**
- `shipperAccountProfile.js` (~5,500 bytes)
- `shipperAccountProfile.html` (~8,000 bytes)
- `shipperAccountProfile.css` (~800 bytes)
- `shipperAccountProfile.js-meta.xml` (400 bytes)

**Apex Integration:**
- Controller: `ShipperAccountProfileController`
- Methods: `getAccountProfile()`, `updateBillingContact(...)`, `updatePaymentMethod(...)`

**Key Sections:**

```
1. Company Information (Read-Only)
   - Company name
   - Account type, tier
   - Account manager name, email, phone
   - Total loads YTD, total spend YTD

2. Billing Contact (Editable)
   - First name, last name
   - Title, phone, email
   - Mailing address (street, city, state, zip, country)
   - Save/Cancel buttons

3. Payment Method (Editable)
   - Default payment type: ACH, Wire, Check, Credit Card
   - Bank details (for ACH): Bank name, last 4 digits
   - Credit card details (if applicable)
   - Save/Cancel buttons

4. Portal Users (Admin Only)
   - Table of users: Name, email, role, actions
   - Add new user button
   - Edit/Remove actions per user

5. Preferences
   - Email notifications: Load status, invoices, exceptions
   - SMS notifications (optional)
   - Dashboard metrics toggle
```

**JS Logic:**
```javascript
import getAccountProfile from '@salesforce/apex/ShipperAccountProfileController.getAccountProfile';
import updateBillingContact from '@salesforce/apex/ShipperAccountProfileController.updateBillingContact';
import updatePaymentMethod from '@salesforce/apex/ShipperAccountProfileController.updatePaymentMethod';

export default class ShipperAccountProfile extends LightningElement {
    @track account = {};
    @track billingContact = {};
    @track paymentMethod = {};
    @track portalUsers = [];
    @track isEditingContact = false;
    @track isEditingPayment = false;

    connectedCallback() {
        this.loadAccountProfile();
    }

    loadAccountProfile() {
        getAccountProfile().then(detail => {
            this.account = detail.account;
            this.billingContact = detail.billingContact;
            this.paymentMethod = detail.paymentMethod;
            this.portalUsers = detail.portalUsers;
        });
    }

    handleEditContact() {
        this.isEditingContact = true;
    }

    handleSaveContact() {
        updateBillingContact({
            contactId: this.billingContact.Id,
            firstName: this.billingContact.FirstName,
            lastName: this.billingContact.LastName,
            // ... other fields
        }).then(result => {
            this.billingContact = result;
            this.isEditingContact = false;
            this.showNotification('Contact updated successfully');
        });
    }

    handleUpdatePaymentMethod() {
        updatePaymentMethod({
            paymentType: this.paymentType,
            bankName: this.bankName,
            accountLastFour: this.accountLastFour
        }).then(result => {
            this.paymentMethod = result;
            this.showNotification('Payment method updated');
        });
    }
}
```

---

## Component 5: shipperHelpFaq

**Purpose:** Static content with FAQs, getting started guide, support contact info

**LWC Files:**
- `shipperHelpFaq.js` (~1,000 bytes) — Minimal logic
- `shipperHelpFaq.html` (~5,000 bytes) — Static content
- `shipperHelpFaq.css` (~600 bytes) — Styling
- `shipperHelpFaq.js-meta.xml` (400 bytes)

**HTML Sections:**

```
1. Getting Started
   - Portal login basics
   - Password reset flow
   - Accessing your loads
   - Finding invoices

2. Load Tracking
   - How to interpret load status
   - Real-time tracking map explained
   - ETA accuracy
   - Delay notifications

3. Invoices & Payments
   - Invoice terms (Net 30)
   - Payment methods (ACH, wire, check)
   - Disputing an invoice
   - Payment reconciliation

4. Account Management
   - Updating billing contact
   - Changing payment method
   - Adding portal users
   - Password security

5. Contact Support
   - KWB Account Manager contact
   - Support email
   - Support hours (Mon-Fri 8am-5pm ET)
   - Escalation process

6. FAQ Accordion
   - Expandable Q&A pairs
   - Search box (optional Phase 2)
```

**JS Logic (Minimal):**
```javascript
export default class ShipperHelpFaq extends LightningElement {
    accordionSections = [
        {
            title: 'How often is my load tracked?',
            content: 'GPS updates every 15-30 minutes when truck is moving...'
        },
        {
            title: 'What does "At Risk" mean?',
            content: 'Your load\'s ETA is 2-6 hours later than delivery window...'
        },
        // ... more FAQs
    ];

    handleAccordionToggle(event) {
        // Expand/collapse accordion item
    }
}
```

---

## Implementation Checklist (Copy-Paste Template)

### Load Detail Component
```
□ shipperLoadDetail.js — Component logic
  □ getLoadDetail() apex call
  □ getCarrierInfo() apex call
  □ buildStatusTimeline() helper
  □ downloadDocument() method
  □ toggleTrackingHistory() method

□ shipperLoadDetail.html — UI template
  □ Header card (Load #, Status, ETA)
  □ Tracking map placeholder
  □ Status timeline (vertical/horizontal)
  □ Load details table
  □ Documents section
  □ Tracking history (collapsible)
  □ Responsive grid layout

□ shipperLoadDetail.css — Responsive styles
  □ Timeline layout (mobile vs desktop)
  □ Map height breakpoints
  □ Table responsive scrolling
  □ Mobile font sizes
  □ Color contrast checks (WCAG AA)

□ shipperLoadDetail.js-meta.xml — Metadata
```

### Invoice List Component
```
□ shipperInvoiceList.js — Component logic
  □ getInvoices() apex call with filters
  □ getInvoiceDetail() for modal
  □ submitDisputeRequest() for dispute
  □ downloadInvoicePDF() method
  □ Pagination logic
  □ Modal open/close handlers

□ shipperInvoiceList.html — UI template
  □ Filter panel (status, date range)
  □ Invoice list table (sortable)
  □ Pagination controls
  □ Detail modal
  □ Dispute modal
  □ Empty state
  □ Loading spinner

□ shipperInvoiceList.css — Responsive styles
  □ Table responsive layout
  □ Modal styling
  □ Status color-coding
  □ Mobile breakpoints

□ shipperInvoiceList.js-meta.xml — Metadata
```

### Account Profile Component
```
□ shipperAccountProfile.js — Component logic
  □ getAccountProfile() apex call
  □ updateBillingContact() save
  □ updatePaymentMethod() save
  □ Edit mode toggles
  □ Form validation
  □ Success/error notifications

□ shipperAccountProfile.html — UI template
  □ Company info card (read-only)
  □ Billing contact form (editable)
  □ Payment method selector (editable)
  □ Portal users table (admin)
  □ Preferences toggles
  □ Form buttons (Save/Cancel)

□ shipperAccountProfile.css — Responsive styles
  □ Card layouts
  □ Form input styles
  □ Mobile-responsive forms
  □ Table styling

□ shipperAccountProfile.js-meta.xml — Metadata
```

### Help/FAQ Component
```
□ shipperHelpFaq.js — Component logic
  □ Accordion toggle logic
  □ Content sections array
  □ (Optional) Search filter

□ shipperHelpFaq.html — Static content
  □ Getting Started section
  □ Load Tracking section
  □ Invoices & Payments section
  □ Account Management section
  □ Contact Support section
  □ FAQ accordion with 10+ Q&As

□ shipperHelpFaq.css — Styling
  □ Accordion styles
  □ Section spacing
  □ Typography
  □ Mobile-responsive

□ shipperHelpFaq.js-meta.xml — Metadata
```

---

## Code Templates (Quick Copy-Paste)

### LWC Meta Template
```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>59.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightning__AppPage</target>
        <target>lightning__RecordPage</target>
        <target>lightning__HomePage</target>
    </targets>
    <description>Shipper Portal - [Component Name]</description>
</LightningComponentBundle>
```

### Responsive Grid Template (HTML)
```html
<div class="slds-grid slds-wrap slds-gutters">
    <div class="slds-col slds-size_1-of-1 slds-medium-size_1-of-2 slds-large-size_1-of-3">
        <!-- Content -->
    </div>
</div>
```

### Form Section Template (HTML)
```html
<div class="slds-form-element">
    <label class="slds-form-element__label" for="field-id">Field Label</label>
    <div class="slds-form-element__control">
        <input type="text" id="field-id" class="slds-input" value={fieldValue} onchange={handleChange} />
    </div>
</div>
```

### Modal Template (HTML)
```html
<template if:true={showModal}>
    <div class="slds-modal slds-fade-in-open">
        <div class="slds-modal__container">
            <div class="slds-modal__header">
                <h2 class="slds-text-heading_medium">Modal Title</h2>
            </div>
            <div class="slds-modal__content slds-p-around_medium">
                <!-- Content -->
            </div>
            <div class="slds-modal__footer">
                <button class="slds-button slds-button_neutral" onclick={handleCancel}>Cancel</button>
                <button class="slds-button slds-button_brand" onclick={handleSubmit}>Submit</button>
            </div>
        </div>
    </div>
    <div class="slds-backdrop slds-backdrop_open"></div>
</template>
```

---

## Testing Checklist (Per Component)

```
Load Detail:
□ Display full load info correctly
□ Show status timeline with correct events
□ Map placeholder displays
□ Documents section lists BOL, POD, invoice
□ Mobile responsive (375px, 768px)
□ Accessibility: ARIA labels, keyboard nav

Invoice List:
□ Filter by status, date range
□ Pagination working
□ Click row opens detail modal
□ Dispute submission opens modal
□ Dispute submission saves to database
□ Download PDF link generated
□ Empty state when no invoices
□ Mobile responsive

Account Profile:
□ Display account info (read-only)
□ Edit billing contact fields
□ Save billing contact to database
□ Update payment method
□ Show portal users (admin only)
□ Edit mode toggle working
□ Mobile responsive

Help/FAQ:
□ All sections display
□ FAQ accordion toggles
□ Links to contact info work
□ Mobile responsive
□ Text contrast meets WCAG AA
```

---

## Estimated Remaining Hours

| Component | JS | HTML | CSS | Meta | Test | Total |
|-----------|----|----|-----|------|------|-------|
| Load Detail | 1h | 1.5h | 0.5h | 0.1h | 0.5h | 3.6h |
| Invoice List | 1h | 1.5h | 0.5h | 0.1h | 0.5h | 3.6h |
| Account Profile | 1h | 1.5h | 0.5h | 0.1h | 0.5h | 3.6h |
| Help/FAQ | 0.5h | 1h | 0.3h | 0.1h | 0.2h | 2.1h |
| **TOTAL** | **3.5h** | **5.5h** | **1.8h** | **0.4h** | **1.7h** | **12.9h** |

**Parallel development possible:** Multiple components can be built simultaneously by separate devs.

---

## Quality Gates (Before Going to Code Review)

```
□ All 4 components deployed to sandbox
□ All unit tests passing (>80% coverage)
□ Manual functional testing complete
□ Mobile responsiveness verified (375px, 768px, 1920px)
□ WCAG AA accessibility verified
  □ Color contrast >4.5:1
  □ Keyboard navigation working
  □ Screen reader compatible
  □ ARIA labels on inputs
□ Row-level security tested
□ No console errors
□ Load times <3 sec (measured)
□ Apex code review checklist completed
```

---

**Next Step:** Pick a component and start building! Recommend Load Detail → Invoice List → Account Profile → Help/FAQ (in priority order).

