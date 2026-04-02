/**
 * SecurityUtil
 * 
 * Utility class for Field-Level Security (FLS) and CRUD permission checks
 * Provides reusable methods to validate user access before DML/query operations
 * 
 * Author: Agent 5 (Portal Development - Security Refactor)
 * Created: April 2, 2026
 */

public with sharing class SecurityUtil {

    /**
     * Checks if user has CRUD access to an object
     * @param sObjectType - The SObjectType to check
     * @param accessType - 'CREATE', 'READ', 'UPDATE', 'DELETE'
     * @return true if user has access, false otherwise
     */
    public static Boolean hasCRUDAccess(SObjectType sObjectType, String accessType) {
        try {
            DescribeSObjectResult sObjectDescribe = sObjectType.getDescribe();
            
            switch on accessType.toUpperCase() {
                when 'CREATE' {
                    return sObjectDescribe.isCreateable();
                }
                when 'READ' {
                    return sObjectDescribe.isAccessible();
                }
                when 'UPDATE' {
                    return sObjectDescribe.isUpdateable();
                }
                when 'DELETE' {
                    return sObjectDescribe.isDeletable();
                }
                when else {
                    return false;
                }
            }
        } catch (Exception e) {
            System.debug('Error checking CRUD access: ' + e.getMessage());
            return false;
        }
    }

    /**
     * Checks if user has FLS access to specific fields
     * @param sObjectType - The SObjectType to check
     * @param fieldNames - List of field API names
     * @param accessType - 'READ', 'UPDATE'
     * @return true if user has access to ALL fields, false otherwise
     */
    public static Boolean hasFieldLevelSecurityAccess(SObjectType sObjectType, List<String> fieldNames, String accessType) {
        try {
            Map<String, SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
            
            for (String fieldName : fieldNames) {
                if (!fieldMap.containsKey(fieldName)) {
                    System.debug('Field not found: ' + fieldName);
                    return false;
                }
                
                DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                
                if (accessType.toUpperCase() == 'READ' && !fieldDescribe.isAccessible()) {
                    System.debug('No READ access to field: ' + fieldName);
                    return false;
                }
                
                if (accessType.toUpperCase() == 'UPDATE' && !fieldDescribe.isUpdateable()) {
                    System.debug('No UPDATE access to field: ' + fieldName);
                    return false;
                }
            }
            
            return true;
        } catch (Exception e) {
            System.debug('Error checking FLS access: ' + e.getMessage());
            return false;
        }
    }

    /**
     * Checks if user has FLS access to at least one field in a list
     * Useful for optional fields
     * @param sObjectType - The SObjectType to check
     * @param fieldNames - List of field API names
     * @param accessType - 'READ', 'UPDATE'
     * @return true if user has access to at least one field, false otherwise
     */
    public static Boolean hasAnyFieldLevelSecurityAccess(SObjectType sObjectType, List<String> fieldNames, String accessType) {
        try {
            Map<String, SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
            
            for (String fieldName : fieldNames) {
                if (!fieldMap.containsKey(fieldName)) {
                    continue;
                }
                
                DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                
                if (accessType.toUpperCase() == 'READ' && fieldDescribe.isAccessible()) {
                    return true;
                }
                
                if (accessType.toUpperCase() == 'UPDATE' && fieldDescribe.isUpdateable()) {
                    return true;
                }
            }
            
            return false;
        } catch (Exception e) {
            System.debug('Error checking FLS access: ' + e.getMessage());
            return false;
        }
    }

    /**
     * Validates status value against picklist values
     * Used to prevent SQL injection in dynamic queries
     * @param fieldToken - Schema.SObjectField reference
     * @param statusValue - Value to validate
     * @return true if value exists in picklist, false otherwise
     */
    public static Boolean isValidPicklistValue(SObjectField fieldToken, String statusValue) {
        try {
            DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            List<PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
            
            for (PicklistEntry entry : picklistEntries) {
                if (entry.getValue().equals(statusValue)) {
                    return true;
                }
            }
            
            return false;
        } catch (Exception e) {
            System.debug('Error validating picklist value: ' + e.getMessage());
            return false;
        }
    }

    /**
     * Gets all valid picklist values for a field
     * @param fieldToken - Schema.SObjectField reference
     * @return List of valid picklist values
     */
    public static List<String> getPicklistValues(SObjectField fieldToken) {
        List<String> values = new List<String>();
        try {
            DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            List<PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
            
            for (PicklistEntry entry : picklistEntries) {
                if (entry.isActive()) {
                    values.add(entry.getValue());
                }
            }
        } catch (Exception e) {
            System.debug('Error getting picklist values: ' + e.getMessage());
        }
        return values;
    }

    /**
     * Validates and filters a comma-separated list of status values
     * Prevents SQL injection while allowing multiple statuses
     * @param statusFilterString - Comma-separated statuses
     * @param fieldToken - Schema.SObjectField reference
     * @return List of validated status values
     */
    public static List<String> validateStatusFilter(String statusFilterString, SObjectField fieldToken) {
        List<String> validStatuses = new List<String>();
        
        if (String.isBlank(statusFilterString) || statusFilterString == 'All') {
            return validStatuses; // Return empty list for 'All'
        }
        
        List<String> validPicklistValues = getPicklistValues(fieldToken);
        
        for (String status : statusFilterString.split(',')) {
            String trimmedStatus = status.trim();
            if (validPicklistValues.contains(trimmedStatus)) {
                validStatuses.add(trimmedStatus);
            }
        }
        
        return validStatuses;
    }

    /**
     * Throws an AuraHandledException if condition is false
     * @param condition - Condition to check
     * @param message - Error message
     */
    public static void enforceAccess(Boolean condition, String message) {
        if (!condition) {
            throw new AuraHandledException(message);
        }
    }
}
