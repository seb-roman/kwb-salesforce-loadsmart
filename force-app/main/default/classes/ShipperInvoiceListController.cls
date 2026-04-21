/**
 * ShipperInvoiceListController
 * 
 * Apex controller for the Invoice Portal page in the Shipper Portal.
 * Provides invoice list and detail with row-level security.
 * 
 * Features:
 * - Get all invoices for logged-in shipper's account
 * - Filter by status, date range
 * - Get invoice detail with line items
 * - Support for invoice disputes
 * - Pagination support
 * 
 * Author: Agent 5 (Portal Development)
 * Created: April 2, 2026
 */

public with sharing class ShipperInvoiceListController {

    /**
     * Get paginated list of invoices for shipper
     * 
     * @param statusFilter - Invoice status ('All', 'Sent', 'Viewed', 'Paid', 'Overdue')
     * @param dateFrom - Start date (YYYY-MM-DD)
     * @param dateTo - End date (YYYY-MM-DD)
     * @param pageNumber - Page number (1-based)
     * @param pageSize - Records per page (default 25)
     * @return InvoiceListResponse with invoices and pagination
     */
    @AuraEnabled
    public static InvoiceListResponse getInvoices(
        String statusFilter,
        String dateFrom,
        String dateTo,
        Integer pageNumber,
        Integer pageSize
    ) {
        try {
            // SECURITY: Check CRUD access to Invoice__c
            SecurityUtil.enforceAccess(
                SecurityUtil.hasCRUDAccess(Invoice__c.SObjectType, 'READ'),
                'You do not have permission to access invoices'
            );
            
            // SECURITY: Check FLS access to required fields
            List<String> requiredFields = new List<String>{
                'Id', 'Name', 'Shipper_Account__c', 'Total_Amount__c',
                'Status__c', 'Invoice_Date__c', 'Due_Date__c', 'Total_Paid__c',
                'Load__c'
            };
            SecurityUtil.enforceAccess(
                SecurityUtil.hasFieldLevelSecurityAccess(Invoice__c.SObjectType, requiredFields, 'READ'),
                'You do not have permission to access required invoice fields'
            );
            
            // Validate inputs
            if (pageNumber == null || pageNumber < 1) pageNumber = 1;
            if (pageSize == null || pageSize < 1 || pageSize > 100) pageSize = 25;

            // Get shipper account ID
            String shipperAccountId = ShipperLoadListController.getShipperAccountId();
            if (String.isBlank(shipperAccountId)) {
                throw new AuraHandledException('No shipper account found for current user');
            }

            // Build filter WHERE clause
            String filterClause = buildInvoiceFilterWhereClause(statusFilter, dateFrom, dateTo);

            // Build SOQL query
            String query = 'SELECT Id, Name, Shipper_Account__c, Total_Amount__c, ' +
                           'Status__c, Invoice_Date__c, Due_Date__c, Total_Paid__c, ' +
                           'Load__c, Load__r.Name ' +
                           'FROM Invoice__c ' +
                           'WHERE Shipper_Account__c = :shipperAccountId ' + filterClause;

            // Add sorting and pagination
            query += ' ORDER BY Invoice_Date__c DESC ';
            query += ' LIMIT :pageSize OFFSET ' + ((pageNumber - 1) * pageSize);

            List<Invoice__c> invoices = Database.query(query);

            // Get total count with same filter clause
            String countQuery = 'SELECT COUNT() FROM Invoice__c WHERE Shipper_Account__c = :shipperAccountId ' + filterClause;
            Integer totalRecords = Database.countQuery(countQuery);

            // Build response
            InvoiceListResponse response = new InvoiceListResponse();
            response.invoices = invoices;
            response.totalRecords = totalRecords;
            response.pageNumber = pageNumber;
            response.pageSize = pageSize;
            response.totalPages = (totalRecords + pageSize - 1) / pageSize;

            return response;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving invoices: ' + e.getMessage());
        }
    }

    /**
     * Build invoice filter WHERE clause to avoid duplication
     * Validates all filter values to prevent SQL injection
     * 
     * @param statusFilter - Invoice status filter
     * @param dateFrom - Start date
     * @param dateTo - End date
     * @return WHERE clause fragment (empty if no filters)
     */
    private static String buildInvoiceFilterWhereClause(String statusFilter, String dateFrom, String dateTo) {
        String whereClause = '';

        // Handle status filter
        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            // Check if invoice is overdue (special case, not a picklist value)
            if (statusFilter == 'Overdue') {
                whereClause += ' AND Due_Date__c < TODAY AND Status__c != \'Paid\' ';
            } else {
                // Validate status value against picklist
                if (SecurityUtil.isValidPicklistValue(Invoice__c.Status__c, statusFilter)) {
                    whereClause += ' AND Status__c = :statusFilter ';
                }
            }
        }

        // Date filters are safe (Date.valueOf() will throw if invalid)
        if (String.isNotBlank(dateFrom)) {
            Date startDate = Date.valueOf(dateFrom);
            whereClause += ' AND Invoice_Date__c >= :startDate ';
        }
        if (String.isNotBlank(dateTo)) {
            Date endDate = Date.valueOf(dateTo);
            whereClause += ' AND Invoice_Date__c <= :endDate ';
        }

        return whereClause;
    }

    /**
     * Get detailed invoice information
     * 
     * @param invoiceId - The Invoice__c record ID
     * @return InvoiceDetail with invoice and line items
     */
    @AuraEnabled
    public static InvoiceDetail getInvoiceDetail(String invoiceId) {
        try {
            // SECURITY: Check CRUD access to Invoice__c
            SecurityUtil.enforceAccess(
                SecurityUtil.hasCRUDAccess(Invoice__c.SObjectType, 'READ'),
                'You do not have permission to access invoice details'
            );
            
            // SECURITY: Check FLS access to invoice fields
            List<String> invoiceFields = new List<String>{
                'Id', 'Name', 'Shipper_Account__c', 'Total_Amount__c', 'Status__c',
                'Invoice_Date__c', 'Due_Date__c', 'Total_Paid__c', 'Balance_Due__c',
                'Tax_Amount__c', 'Subtotal__c', 'Fuel_Surcharge__c', 'Load__c'
            };
            SecurityUtil.enforceAccess(
                SecurityUtil.hasFieldLevelSecurityAccess(Invoice__c.SObjectType, invoiceFields, 'READ'),
                'You do not have permission to access required invoice fields'
            );

            String shipperAccountId = ShipperLoadListController.getShipperAccountId();

            // Query invoice with row-level security
            List<Invoice__c> invoices = [
                SELECT Id, Name, Shipper_Account__c, Total_Amount__c, Status__c,
                       Invoice_Date__c, Due_Date__c, Total_Paid__c, Balance_Due__c,
                       Tax_Amount__c, Subtotal__c, Fuel_Surcharge__c, Load__c, Load__r.Name
                FROM Invoice__c
                WHERE Id = :invoiceId
                  AND Shipper_Account__c = :shipperAccountId
                LIMIT 1
            ];

            if (invoices.isEmpty()) {
                throw new AuraHandledException('Invoice not found or access denied');
            }

            Invoice__c invoice = invoices[0];

            // Query line items (if InvoiceLineItem__c exists) - graceful error handling
            List<InvoiceLineItem__c> lineItems = new List<InvoiceLineItem__c>();
            try {
                if (SecurityUtil.hasCRUDAccess(InvoiceLineItem__c.SObjectType, 'READ')) {
                    lineItems = [
                        SELECT Id, Description__c, Amount__c, Line_Item_Type__c
                        FROM InvoiceLineItem__c
                        WHERE Invoice__c = :invoiceId
                        ORDER BY CreatedDate ASC
                    ];
                }
            } catch (SObjectException e) {
                System.debug('InvoiceLineItem__c object not accessible: ' + e.getMessage());
            }

            // TODO: Phase 2 - Payment__c not yet deployed
            List<SObject> payments = new List<SObject>();

            InvoiceDetail detail = new InvoiceDetail();
            detail.invoice = invoice;
            detail.lineItems = lineItems;
            detail.payments = payments;

            return detail;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving invoice detail: ' + e.getMessage());
        }
    }

    /**
     * Submit an invoice dispute
     * 
     * SECURITY: Added CRUD/FLS checks before creating dispute record
     * 
     * @param invoiceId - The Invoice__c ID
     * @param reason - Reason for dispute
     * @param amount - Disputed amount
     * @param details - Additional details
     * @return Dispute__c record ID
     */
    // TODO: Phase 2 - submitDisputeRequest (Dispute__c not yet deployed)
    @AuraEnabled
    public static String submitDisputeRequest(
        String invoiceId,
        String reason,
        Decimal amount,
        String details
    ) {
        throw new AuraHandledException('Dispute submission not yet available (Phase 2)');
    }

    /**
     * Get invoice status options
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getInvoiceStatusOptions() {
        List<String> statuses = new List<String>();
        try {
            Schema.DescribeFieldResult fieldResult = Invoice__c.Status__c.getDescribe();
            List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
            
            for (Schema.PicklistEntry entry : picklistEntries) {
                if (entry.isActive()) {
                    statuses.add(entry.getValue());
                }
            }
        } catch (Exception e) {
            System.debug('Error getting status options: ' + e.getMessage());
        }
        return statuses;
    }

    /**
     * Response wrapper for invoice list
     */
    public class InvoiceListResponse {
        @AuraEnabled
        public List<Invoice__c> invoices;
        @AuraEnabled
        public Integer totalRecords;
        @AuraEnabled
        public Integer pageNumber;
        @AuraEnabled
        public Integer pageSize;
        @AuraEnabled
        public Integer totalPages;
    }

    /**
     * Response wrapper for invoice detail
     */
    public class InvoiceDetail {
        @AuraEnabled
        public Invoice__c invoice;
        @AuraEnabled
        public List<InvoiceLineItem__c> lineItems;
        @AuraEnabled
        public List<SObject> payments; // TODO: Phase 2 - Payment__c
    }
}
