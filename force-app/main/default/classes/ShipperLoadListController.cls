/**
 * ShipperLoadListController
 * 
 * Apex controller for the Load List page in the Shipper Portal.
 * Provides filtered load queries with row-level security enforcement.
 * 
 * Features:
 * - Get all loads for logged-in shipper (row-level security via Account lookup)
 * - Filter by status, date range, load type
 * - Pagination support (25 records per page)
 * - Indexed SOQL queries for performance
 * 
 * Author: Agent 5 (Portal Development)
 * Created: April 2, 2026
 */

public with sharing class ShipperLoadListController {
    
    /**
     * Get shipper account ID for logged-in user
     * This ensures row-level security: shipper only sees own account's loads
     */
    @AuraEnabled(cacheable=true)
    public static String getShipperAccountId() {
        try {
            User currentUser = [
                SELECT AccountId 
                FROM User 
                WHERE Id = :UserInfo.getUserId() 
                LIMIT 1
            ];
            return currentUser.AccountId;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to determine shipper account: ' + e.getMessage());
        }
    }

    /**
     * Get paginated list of loads for shipper
     * 
     * @param statusFilter - Comma-separated statuses (e.g., 'Posted,Assigned,In Transit')
     *                      or 'All' for no status filter
     * @param dateFrom - Start date for load filter (YYYY-MM-DD)
     * @param dateTo - End date for load filter (YYYY-MM-DD)
     * @param loadType - Load type filter ('All', 'FTL', 'LTL', 'Partial')
     * @param pageNumber - Page number (1-based)
     * @param pageSize - Records per page (default 25)
     * @return LoadListResponse with loads and pagination info
     */
    @AuraEnabled
    public static LoadListResponse getLoads(
        String statusFilter,
        String dateFrom,
        String dateTo,
        String loadType,
        Integer pageNumber,
        Integer pageSize
    ) {
        try {
            // SECURITY: Check CRUD access to Load__c
            SecurityUtil.enforceAccess(
                SecurityUtil.hasCRUDAccess(Load__c.SObjectType, 'READ'),
                'You do not have permission to access loads'
            );
            
            // SECURITY: Check FLS access to required fields
            List<String> requiredFields = new List<String>{
                'Id', 'Name', 'Shipper_Account__c', 'Pickup_City__c', 'Delivery_City__c',
                'Status__c', 'Pickup_Date__c', 'Estimated_Delivery__c', 'Shipper_Rate__c',
                'Equipment_Type__c', 'Weight__c', 'Commodity__c', 'Carrier__c', 'Load_Type__c'
            };
            SecurityUtil.enforceAccess(
                SecurityUtil.hasFieldLevelSecurityAccess(Load__c.SObjectType, requiredFields, 'READ'),
                'You do not have permission to access required load fields'
            );
            
            // Validate inputs
            if (pageNumber == null || pageNumber < 1) pageNumber = 1;
            if (pageSize == null || pageSize < 1 || pageSize > 100) pageSize = 25;

            // Get shipper account ID (enforces row-level security)
            String shipperAccountId = getShipperAccountId();
            if (String.isBlank(shipperAccountId)) {
                throw new AuraHandledException('No shipper account found for current user');
            }

            // Build filter WHERE clause (extracted to avoid duplication)
            String filterClause = buildFilterWhereClause(statusFilter, dateFrom, dateTo, loadType);

            // Build main query
            String query = 'SELECT Id, Name, Shipper_Account__c, Pickup_City__c, Delivery_City__c, ' +
                           'Status__c, Pickup_Date__c, Estimated_Delivery__c, Shipper_Rate__c, ' +
                           'Equipment_Type__c, Weight__c, Commodity__c, Carrier__c ' +
                           'FROM Load__c ' +
                           'WHERE Shipper_Account__c = :shipperAccountId ' + filterClause;

            // Add sorting and pagination
            query += ' ORDER BY Pickup_Date__c DESC, Name ASC ';
            query += ' LIMIT :pageSize OFFSET ' + ((pageNumber - 1) * pageSize);

            // Execute query
            List<Load__c> loads = Database.query(query);

            // Get total record count for pagination (use same filter clause)
            String countQuery = 'SELECT COUNT() FROM Load__c WHERE Shipper_Account__c = :shipperAccountId ' + filterClause;
            Integer totalRecords = Database.countQuery(countQuery);

            // Build response
            LoadListResponse response = new LoadListResponse();
            response.loads = loads;
            response.totalRecords = totalRecords;
            response.pageNumber = pageNumber;
            response.pageSize = pageSize;
            response.totalPages = (totalRecords + pageSize - 1) / pageSize;

            return response;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving loads: ' + e.getMessage());
        }
    }

    /**
     * Build filter WHERE clause to avoid duplication
     * Validates all filter values to prevent SQL injection
     * 
     * @param statusFilter - Comma-separated statuses
     * @param dateFrom - Start date
     * @param dateTo - End date
     * @param loadType - Load type
     * @return WHERE clause fragment (empty if no filters)
     */
    private static String buildFilterWhereClause(String statusFilter, String dateFrom, String dateTo, String loadType) {
        String whereClause = '';

        // SECURITY: Validate status filter values against picklist
        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            List<String> validStatuses = SecurityUtil.validateStatusFilter(statusFilter, Load__c.Status__c);
            if (!validStatuses.isEmpty()) {
                whereClause += ' AND Status__c IN (';
                List<String> quotedStatuses = new List<String>();
                for (String status : validStatuses) {
                    quotedStatuses.add('\'' + String.escapeSingleQuotes(status) + '\'');
                }
                whereClause += String.join(quotedStatuses, ',') + ') ';
            }
        }

        // SECURITY: Validate load type against picklist
        if (String.isNotBlank(loadType) && loadType != 'All') {
            if (SecurityUtil.isValidPicklistValue(Load__c.Load_Type__c, loadType)) {
                whereClause += ' AND Load_Type__c = :loadType ';
            }
        }

        // Date filters are safe (Date.valueOf() will throw if invalid)
        if (String.isNotBlank(dateFrom)) {
            Date startDate = Date.valueOf(dateFrom);
            whereClause += ' AND Pickup_Date__c >= :startDate ';
        }
        if (String.isNotBlank(dateTo)) {
            Date endDate = Date.valueOf(dateTo);
            whereClause += ' AND Pickup_Date__c <= :endDate ';
        }

        return whereClause;
    }

    /**
     * Get status options for filter dropdown
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getStatusOptions() {
        List<String> statuses = new List<String>();
        try {
            // Get picklist values from Load__c.Status__c field
            Schema.DescribeFieldResult fieldResult = Load__c.Status__c.getDescribe();
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
     * Get load type options for filter dropdown
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getLoadTypeOptions() {
        List<String> loadTypes = new List<String>();
        try {
            Schema.DescribeFieldResult fieldResult = Load__c.Load_Type__c.getDescribe();
            List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
            
            for (Schema.PicklistEntry entry : picklistEntries) {
                if (entry.isActive()) {
                    loadTypes.add(entry.getValue());
                }
            }
        } catch (Exception e) {
            System.debug('Error getting load type options: ' + e.getMessage());
        }
        return loadTypes;
    }

    /**
     * Response wrapper class for load list
     */
    public class LoadListResponse {
        @AuraEnabled
        public List<Load__c> loads;
        @AuraEnabled
        public Integer totalRecords;
        @AuraEnabled
        public Integer pageNumber;
        @AuraEnabled
        public Integer pageSize;
        @AuraEnabled
        public Integer totalPages;
    }
}
