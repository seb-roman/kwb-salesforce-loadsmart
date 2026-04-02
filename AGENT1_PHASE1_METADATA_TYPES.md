# AGENT 1: Phase 1 - Custom Metadata Types Documentation

**Created:** April 2, 2026  
**Agent:** Agent 1 (Data Model Architect)  
**Status:** ✅ COMPLETE

---

## Summary

Three custom metadata type definitions created to support configuration management for KWB Load System. Metadata types provide admin-configurable, code-free settings for rate cards, exception rules, and billing configuration.

---

## Custom Metadata Type 1: RateCardConfig__mdt

**Purpose:** Store baseline freight rates and surcharge percentages for different equipment types and time periods.

**Label:** Rate Card Configuration  
**Plural Label:** Rate Card Configurations  
**API Name:** RateCardConfig__mdt  
**Visibility:** Public

### Fields

| Field Name | API Name | Type | Precision/Length | Required | Description |
|------------|----------|------|------------------|----------|-------------|
| Baseline DAI Price | Baseline_DAI_Price__c | Number | 8.2 | No | Baseline DAI (Dedicated Autonomous Interaction) price per mile |
| Fuel Surcharge Percent | Fuel_Surcharge_Percent__c | Number | 5.2 | No | Fuel surcharge percentage applied to base rates (e.g., 2.50) |
| Effective Date | Effective_Date__c | Date | - | No | Date when the rate card becomes effective |
| Expiry Date | Expiry_Date__c | Date | - | No | Date when the rate card expires |
| Equipment Type | Equipment_Type__c | Text | 50 | No | Equipment type this rate applies to (Van, Flatbed, Reefer, Tank) |
| Active | Active__c | Checkbox | - | No | Whether this rate card configuration is currently active |

### Sample Data

```
Name: Standard_Rates_2026
Equipment_Type__c: Van
Baseline_DAI_Price__c: 1.85
Fuel_Surcharge_Percent__c: 2.50
Effective_Date__c: 2026-01-01
Expiry_Date__c: 2026-12-31
Active__c: true

Name: Flatbed_Rates_2026
Equipment_Type__c: Flatbed
Baseline_DAI_Price__c: 2.15
Fuel_Surcharge_Percent__c: 3.00
Effective_Date__c: 2026-01-01
Expiry_Date__c: 2026-12-31
Active__c: true

Name: Reefer_Premium_2026
Equipment_Type__c: Reefer
Baseline_DAI_Price__c: 2.75
Fuel_Surcharge_Percent__c: 4.00
Effective_Date__c: 2026-01-01
Expiry_Date__c: 2026-12-31
Active__c: true
```

### Use Cases

1. **Rate Engine (Phase 2+):** Agent 2 (Loadsmart Integration) can query RateCardConfig to calculate initial shipper quote
2. **Fuel Surcharge Auto-Updates:** Finance team updates Fuel_Surcharge_Percent daily without code deployment
3. **Equipment-Based Pricing:** Different rates for Van vs. Flatbed vs. Reefer vs. Tank
4. **Seasonal Rate Adjustments:** Activate/deactivate rates based on Effective/Expiry dates
5. **Carrier Rate Setting:** Determine carrier rates based on equipment and base price

### Deployment Example

```apex
// Apex code (Phase 2) to query rate card
RateCardConfig__mdt rateCard = [
    SELECT Baseline_DAI_Price__c, Fuel_Surcharge_Percent__c
    FROM RateCardConfig__mdt
    WHERE Equipment_Type__c = :equipmentType
    AND Active__c = true
    AND Effective_Date__c <= TODAY()
    AND (Expiry_Date__c >= TODAY() OR Expiry_Date__c = null)
    LIMIT 1
];

Decimal basePrice = rateCard.Baseline_DAI_Price__c;
Decimal surchargePercent = rateCard.Fuel_Surcharge_Percent__c ?? 0;
Decimal finalRate = basePrice * (1 + (surchargePercent / 100));
```

---

## Custom Metadata Type 2: ExceptionRules__mdt

**Purpose:** Define business rules that trigger exception handling in the Load system (late deliveries, high costs, etc.).

**Label:** Exception Rules  
**Plural Label:** Exception Rules  
**API Name:** ExceptionRules__mdt  
**Visibility:** Public

### Fields

| Field Name | API Name | Type | Precision/Length | Required | Description |
|------------|----------|------|------------------|----------|-------------|
| Rule Name | Rule_Name__c | Text | 100 | No | Name of the exception rule (e.g., "Late Delivery > 4 Hours") |
| Threshold | Threshold__c | Number | 8.2 | No | Numeric threshold value that triggers exception |
| Severity | Severity__c | Picklist | - | No | Severity level: Critical, High, Medium, Low |
| Enabled | Enabled__c | Checkbox | - | No | Whether this exception rule is currently active |
| Description | Description__c | LongTextArea | 500 | No | Description of when this exception rule applies |

### Picklist Values: Severity__c
- Critical (requires immediate action)
- High (requires action within 24 hours)
- Medium (requires action within 48 hours)
- Low (informational only)

### Sample Data

```
Name: Late_Delivery_4hrs
Rule_Name__c: Late Delivery > 4 Hours
Threshold__c: 4
Severity__c: High
Enabled__c: true
Description__c: Triggers when actual delivery is more than 4 hours after estimated delivery window

Name: Late_Delivery_24hrs
Rule_Name__c: Late Delivery > 24 Hours
Threshold__c: 24
Severity__c: Critical
Enabled__c: true
Description__c: Triggers when actual delivery is more than 24 hours late. Requires management escalation.

Name: Low_Margin_10pct
Rule_Name__c: Low Margin < 10%
Threshold__c: 10
Severity__c: Medium
Enabled__c: true
Description__c: Triggers when margin % is less than 10%. May indicate low profitability.

Name: Cost_Overrun_20pct
Rule_Name__c: Cost Overrun > 20%
Threshold__c: 20
Severity__c: High
Enabled__c: true
Description__c: Triggers when actual carrier cost exceeds estimated by more than 20%.
```

### Use Cases

1. **Automated Exception Detection:** Batch job queries ExceptionRules to determine which loads need exceptions created
2. **Customer Service:** Customer service team can modify thresholds without code deployment
3. **Escalation Routing:** Different severities route exceptions to different teams
4. **Trending Analysis:** Identify which rules trigger most frequently (KPI dashboard)
5. **Seasonal Adjustments:** Temporarily enable/disable rules during peak seasons

### Deployment Example

```apex
// Apex code (Phase 2) to evaluate exception rules
List<ExceptionRules__mdt> rules = [
    SELECT Rule_Name__c, Threshold__c, Severity__c
    FROM ExceptionRules__mdt
    WHERE Enabled__c = true
];

for (ExceptionRules__mdt rule : rules) {
    if (rule.Rule_Name__c.contains('Late')) {
        if (load.Hours_Late__c > rule.Threshold__c) {
            createException(load, rule);
        }
    }
}
```

---

## Custom Metadata Type 3: BillingConfig__mdt

**Purpose:** Store system-wide billing and settlement configuration without hardcoding values.

**Label:** Billing Configuration  
**Plural Label:** Billing Configurations  
**API Name:** BillingConfig__mdt  
**Visibility:** Public

### Fields

| Field Name | API Name | Type | Precision/Length | Required | Description |
|------------|----------|------|------------------|----------|-------------|
| Invoice Email Template | Invoice_Email_Template__c | Text | 100 | No | Email template name used for invoice delivery |
| Settlement Day Of Week | Settlement_Day_Of_Week__c | Picklist | - | No | Day of week when settlements are processed |
| Payment Methods | Payment_Methods__c | Text | 200 | No | Allowed payment methods (comma-separated: ACH, Wire, Check) |
| Default Invoice Days | Default_Invoice_Days__c | Number | 3.0 | No | Default number of days allowed for payment (e.g., 30) |
| Late Payment Penalty Percent | Late_Payment_Penalty_Percent__c | Number | 5.2 | No | Percentage penalty applied to late payments (e.g., 1.50) |
| Minimum Invoice Amount | Minimum_Invoice_Amount__c | Currency | 12.2 | No | Minimum invoice amount for billing (e.g., $25.00) |
| Active | Active__c | Checkbox | - | No | Whether this billing configuration is active |

### Picklist Values: Settlement_Day_Of_Week__c
- Monday
- Tuesday
- Wednesday
- Thursday
- Friday
- Saturday
- Sunday

### Sample Data

```
Name: Standard_Billing_2026
Invoice_Email_Template__c: Invoice_Template_v2
Settlement_Day_Of_Week__c: Friday
Payment_Methods__c: ACH, Wire, Check
Default_Invoice_Days__c: 30
Late_Payment_Penalty_Percent__c: 1.50
Minimum_Invoice_Amount__c: 25.00
Active__c: true

Name: Premium_Billing_2026
Invoice_Email_Template__c: Premium_Invoice_Template
Settlement_Day_Of_Week__c: Wednesday
Payment_Methods__c: ACH, Wire
Default_Invoice_Days__c: 15
Late_Payment_Penalty_Percent__c: 2.00
Minimum_Invoice_Amount__c: 100.00
Active__c: false (future use)
```

### Use Cases

1. **Invoice Generation (Phase 2+):** Billing module queries BillingConfig to determine template, settlement day, and minimum amount
2. **Finance Configuration:** Finance team updates payment terms without developer involvement
3. **Late Payment Enforcement:** Automated late fee calculation based on configured penalty percentage
4. **Email Routing:** Invoice template can be swapped by changing single metadata record
5. **Multi-Tenant Billing:** Different billing configurations for different customer segments (if scaled to multi-tenant)

### Deployment Example

```apex
// Apex code (Phase 2) to generate invoices
BillingConfig__mdt config = [
    SELECT Invoice_Email_Template__c, Default_Invoice_Days__c, Minimum_Invoice_Amount__c
    FROM BillingConfig__mdt
    WHERE Active__c = true
    LIMIT 1
];

if (load.Total_Shipper_Charge__c >= config.Minimum_Invoice_Amount__c) {
    Invoice__c invoice = new Invoice__c(
        Load__c = load.Id,
        Due_Date__c = TODAY().addDays(Integer.valueOf(config.Default_Invoice_Days__c))
    );
    insert invoice;
    sendInvoiceEmail(invoice, config.Invoice_Email_Template__c);
}
```

---

## Metadata Type Comparison

| Aspect | RateCardConfig__mdt | ExceptionRules__mdt | BillingConfig__mdt |
|--------|-------------------|-------------------|------------------|
| **Primary Use** | Rate pricing | Exception detection | Billing settings |
| **Uniqueness** | Per equipment type | Per exception type | System-wide |
| **Update Frequency** | Daily/Weekly | Monthly | Quarterly |
| **Records Count** | 4-6 active | 8-12 active | 1-2 active |
| **Phase** | 2+ | 2+ | 2+ |

---

## Deployment Steps

### 1. Create Metadata Type Definitions (DONE ✅)
```bash
sfdx force:source:push -u kwb-dev
# Deploys: RateCardConfig.md-meta.xml, ExceptionRules.md-meta.xml, BillingConfig.md-meta.xml
```

### 2. Load Sample Data (Manual via UI or Apex)
```apex
// Insert sample RateCardConfig records
List<RateCardConfig__mdt> rates = new List<RateCardConfig__mdt>{
    new RateCardConfig__mdt(
        DeveloperName = 'Standard_Rates_2026',
        Label = 'Standard Rates 2026',
        Equipment_Type__c = 'Van',
        Baseline_DAI_Price__c = 1.85,
        Fuel_Surcharge_Percent__c = 2.50,
        Effective_Date__c = Date.newInstance(2026, 1, 1),
        Active__c = true
    )
};
// Note: CustomMetadata insert via Apex is not supported.
// Use Salesforce CLI or Setup UI to create sample records.
```

### 3. Deploy Code That Uses Metadata
Code in Phase 2 can safely reference these types.

---

## Testing

### Metadata Type Tests (Unit Tests)

```apex
@isTest
public class BillingConfig_Test {
    @isTest
    static void testBillingConfigQuery() {
        Test.startTest();
        BillingConfig__mdt config = [
            SELECT Default_Invoice_Days__c, Minimum_Invoice_Amount__c
            FROM BillingConfig__mdt
            WHERE Active__c = true
            LIMIT 1
        ];
        Test.stopTest();
        
        System.assertNotEquals(null, config.Default_Invoice_Days__c);
    }
}
```

**Test Coverage:** Metadata retrieval and field validation

---

## Maintenance & Governance

### Who Can Modify Metadata Records?
- **Finance Team:** Can update BillingConfig__mdt (with approval)
- **Operations Team:** Can update RateCardConfig__mdt (with monthly review)
- **Support Lead:** Can enable/disable ExceptionRules__mdt

### Approval Workflow (Recommended)
1. Change requested via Slack/Email with justification
2. 2-day review window by system owner
3. Change deployed to sandbox for 1-week testing
4. Final approval and production deployment on Friday

### Audit Trail
All metadata changes are tracked in Setup > Metadata Audit Trail (Salesforce native).

---

## References

- **Created by:** Agent 1 (Data Model Architect)
- **Phase:** 1 - Data Model Foundation
- **XML Locations:**
  - force-app/main/default/customMetadata/RateCardConfig.md-meta.xml
  - force-app/main/default/customMetadata/ExceptionRules.md-meta.xml
  - force-app/main/default/customMetadata/BillingConfig.md-meta.xml

---

**Status:** ✅ READY FOR SANDBOX DEPLOYMENT

**Last Updated:** April 2, 2026 by Agent 1
