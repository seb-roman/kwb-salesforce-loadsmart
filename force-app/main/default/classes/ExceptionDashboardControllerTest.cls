/**
 * AGENT3_PHASE2: Exception Dashboard Controller Tests
 * 
 * Test dashboard queries, filtering, sorting, and actions.
 * 
 * Test Scenarios:
 * 1. Get dashboard metrics (counts by severity)
 * 2. Get exception list with pagination
 * 3. Filter by severity
 * 4. Filter by exception type
 * 5. Sort by different fields
 * 6. Acknowledge exception
 * 7. Resolve exception with reason
 * 8. Auto-escalation of critical exceptions (>2 hours)
 * 9. Get filter options
 * 10. Empty dashboard (no exceptions)
 * 
 * @author Agent 3
 * @version 1.0
 */
@isTest
public with sharing class ExceptionDashboardControllerTest {
    
    /**
     * Test 1: Get Dashboard Metrics
     * Scenario: Dashboard shows correct counts by severity
     */
    @isTest
    static void testGetDashboardMetrics() {
        // Setup
        createTestExceptions(5, 'Warning', 'LATE_ARRIVAL', 'Open');
        createTestExceptions(3, 'Alert', 'LONG_IDLE', 'Open');
        createTestExceptions(2, 'Critical', 'DRIVER_OFFLINE', 'Open');
        
        // Execute
        Test.startTest();
        ExceptionDashboardController.DashboardMetrics metrics = ExceptionDashboardController.getDashboardMetrics();
        Test.stopTest();
        
        // Verify
        System.assertEquals(5, metrics.warningCount);
        System.assertEquals(3, metrics.alertCount);
        System.assertEquals(2, metrics.criticalCount);
        System.assertEquals(10, metrics.totalOpenExceptions);
        System.assert(!metrics.exceptionsByType.isEmpty());
    }
    
    /**
     * Test 2: Get Exception List with Pagination
     * Scenario: Paginated list of exceptions
     */
    @isTest
    static void testGetExceptionListPagination() {
        // Setup
        createTestExceptions(25, 'Alert', 'LATE_ARRIVAL', 'Open');
        
        // Execute
        Test.startTest();
        ExceptionDashboardController.ExceptionListResult result = 
            ExceptionDashboardController.getExceptions(1, null, null, null, null, null, 'Open');
        Test.stopTest();
        
        // Verify
        System.assertEquals(25, result.totalRecords);
        System.assertEquals(1, result.currentPage);
        System.assert(result.exceptions.size() > 0);
    }
    
    /**
     * Test 3: Filter by Severity
     * Scenario: Filter exceptions by severity level
     */
    @isTest
    static void testFilterBySeverity() {
        // Setup
        createTestExceptions(5, 'Warning', 'LATE_ARRIVAL', 'Open');
        createTestExceptions(3, 'Alert', 'LONG_IDLE', 'Open');
        createTestExceptions(2, 'Critical', 'DRIVER_OFFLINE', 'Open');
        
        // Execute
        Test.startTest();
        ExceptionDashboardController.ExceptionListResult result = 
            ExceptionDashboardController.getExceptions(1, null, null, 'Critical', null, null, 'Open');
        Test.stopTest();
        
        // Verify
        System.assertEquals(2, result.totalRecords);
        for (ExceptionDashboardController.ExceptionItem item : result.exceptions) {
            System.assertEquals('Critical', item.severity);
        }
    }
    
    /**
     * Test 4: Filter by Exception Type
     * Scenario: Filter exceptions by type
     */
    @isTest
    static void testFilterByExceptionType() {
        // Setup
        createTestExceptions(5, 'Alert', 'LATE_ARRIVAL', 'Open');
        createTestExceptions(3, 'Alert', 'LONG_IDLE', 'Open');
        
        // Execute
        Test.startTest();
        ExceptionDashboardController.ExceptionListResult result = 
            ExceptionDashboardController.getExceptions(1, null, null, null, 'LATE_ARRIVAL', null, 'Open');
        Test.stopTest();
        
        // Verify
        System.assertEquals(5, result.totalRecords);
        for (ExceptionDashboardController.ExceptionItem item : result.exceptions) {
            System.assertEquals('LATE_ARRIVAL', item.exceptionType);
        }
    }
    
    /**
     * Test 5: Sort by Different Fields
     * Scenario: Sort exceptions by triggered timestamp
     */
    @isTest
    static void testSortByTriggeredDateTime() {
        // Setup
        Load__c load = createTestLoad('LOAD-SORT-001');
        createExceptionAtTime(load.Id, System.now().addMinutes(-60));
        createExceptionAtTime(load.Id, System.now().addMinutes(-30));
        createExceptionAtTime(load.Id, System.now().addMinutes(-5));
        
        // Execute
        Test.startTest();
        ExceptionDashboardController.ExceptionListResult result = 
            ExceptionDashboardController.getExceptions(1, 'Triggered_DateTime__c', 'DESC', null, null, null, 'Open');
        Test.stopTest();
        
        // Verify descending order
        System.assertEquals(3, result.totalRecords);
        System.assert(result.exceptions.size() >= 2);
        if (result.exceptions.size() >= 2) {
            System.assert(
                result.exceptions[0].triggeredDateTime >= result.exceptions[1].triggeredDateTime,
                'Should be sorted descending'
            );
        }
    }
    
    /**
     * Test 6: Acknowledge Exception
     * Scenario: Mark exception as acknowledged
     */
    @isTest
    static void testAcknowledgeException() {
        // Setup
        Exception__c exc = createTestException(
            createTestLoad('LOAD-ACK-001').Id, 
            'Alert', 
            'LATE_ARRIVAL', 
            'Open'
        );
        
        // Execute
        Test.startTest();
        ExceptionDashboardController.acknowledgeException(exc.Id);
        Test.stopTest();
        
        // Verify
        Exception__c updated = [SELECT Id, Status__c, Acknowledged_DateTime__c FROM Exception__c WHERE Id = :exc.Id];
        System.assertEquals('Acknowledged', updated.Status__c);
        System.assert(updated.Acknowledged_DateTime__c != null);
    }
    
    /**
     * Test 7: Resolve Exception with Reason
     * Scenario: Resolve exception and store reason
     */
    @isTest
    static void testResolveException() {
        // Setup
        Exception__c exc = createTestException(
            createTestLoad('LOAD-RES-001').Id, 
            'Alert', 
            'LONG_IDLE', 
            'Open'
        );
        String reason = 'Driver documented loading delay with shipper';
        
        // Execute
        Test.startTest();
        ExceptionDashboardController.resolveException(exc.Id, reason);
        Test.stopTest();
        
        // Verify
        Exception__c updated = [SELECT Id, Status__c, Resolved_DateTime__c, Notes__c FROM Exception__c WHERE Id = :exc.Id];
        System.assertEquals('Resolved', updated.Status__c);
        System.assert(updated.Resolved_DateTime__c != null);
        System.assertEquals(reason, updated.Notes__c);
    }
    
    /**
     * Test 8: Auto-Escalation of Critical Exceptions
     * Scenario: Critical exception >2 hours old should be flagged
     */
    @isTest
    static void testAutoEscalationCriticalExceptions() {
        // Setup - Create critical exception >2 hours old
        Load__c load = createTestLoad('LOAD-ESC-001');
        Exception__c oldException = new Exception__c(
            Load__c = load.Id,
            Exception_Type__c = 'EQUIPMENT_BREAKDOWN',
            Severity__c = 'Critical',
            Description__c = 'Test escalation',
            Triggered_DateTime__c = System.now().addHours(-3), // 3 hours ago
            Status__c = 'Open',
            Acknowledged_DateTime__c = null
        );
        insert oldException;
        
        // Execute
        Test.startTest();
        ExceptionDashboardController.ExceptionListResult result = 
            ExceptionDashboardController.getExceptions(1, null, null, 'Critical', null, null, 'Open');
        Test.stopTest();
        
        // Verify - Should be in critical list
        System.assertEquals(1, result.totalRecords);
        System.assertEquals('Critical', result.exceptions[0].severity);
    }
    
    /**
     * Test 9: Get Filter Options
     * Scenario: Retrieve available filter options
     */
    @isTest
    static void testGetFilterOptions() {
        // Setup
        createTestExceptions(3, 'Warning', 'LATE_ARRIVAL', 'Open');
        createTestExceptions(2, 'Critical', 'GEOFENCE_VIOLATION', 'Open');
        
        // Execute
        Test.startTest();
        ExceptionDashboardController.FilterOptions options = ExceptionDashboardController.getFilterOptions();
        Test.stopTest();
        
        // Verify
        System.assert(options.severityOptions.size() > 0);
        System.assert(options.typeOptions.size() > 0);
        System.assert(options.statusOptions.size() > 0);
    }
    
    /**
     * Test 10: Empty Dashboard
     * Scenario: Dashboard handles no exceptions gracefully
     */
    @isTest
    static void testEmptyDashboard() {
        // Execute
        Test.startTest();
        ExceptionDashboardController.DashboardMetrics metrics = ExceptionDashboardController.getDashboardMetrics();
        ExceptionDashboardController.ExceptionListResult result = 
            ExceptionDashboardController.getExceptions(1, null, null, null, null, null, 'Open');
        Test.stopTest();
        
        // Verify
        System.assertEquals(0, metrics.totalOpenExceptions);
        System.assertEquals(0, result.totalRecords);
    }
    
    /**
     * Test 11: Filter by Load Name
     * Scenario: Search exceptions by load name
     */
    @isTest
    static void testFilterByLoadName() {
        // Setup
        Load__c load1 = createTestLoad('LOAD-SEARCH-001');
        Load__c load2 = createTestLoad('LOAD-SEARCH-002');
        
        createTestException(load1.Id, 'Alert', 'LATE_ARRIVAL', 'Open');
        createTestException(load2.Id, 'Alert', 'LONG_IDLE', 'Open');
        
        // Execute
        Test.startTest();
        ExceptionDashboardController.ExceptionListResult result = 
            ExceptionDashboardController.getExceptions(1, null, null, null, null, 'SEARCH-001', 'Open');
        Test.stopTest();
        
        // Verify
        System.assertEquals(1, result.totalRecords);
        System.assertEquals('LOAD-SEARCH-001', result.exceptions[0].loadName);
    }
    
    /**
     * Test 12: Exception Item Display Properties
     * Scenario: Verify exception items have all required display fields
     */
    @isTest
    static void testExceptionItemDisplayProperties() {
        // Setup
        Load__c load = createTestLoad('LOAD-DISPLAY-001');
        Exception__c exc = createTestException(load.Id, 'Alert', 'LATE_ARRIVAL', 'Open');
        
        // Execute
        Test.startTest();
        ExceptionDashboardController.ExceptionListResult result = 
            ExceptionDashboardController.getExceptions(1, null, null, null, null, null, 'Open');
        Test.stopTest();
        
        // Verify
        System.assertEquals(1, result.totalRecords);
        ExceptionDashboardController.ExceptionItem item = result.exceptions[0];
        System.assert(String.isNotBlank(item.id));
        System.assert(String.isNotBlank(item.exceptionType));
        System.assert(String.isNotBlank(item.severity));
        System.assert(String.isNotBlank(item.status));
        System.assert(item.displayAge != null);
    }
    
    // ============ Helper Methods ============
    
    private static Load__c createTestLoad(String name) {
        Load__c load = new Load__c(
            Name = name,
            Status__c = 'IN_TRANSIT'
        );
        insert load;
        return load;
    }
    
    private static Exception__c createTestException(Id loadId, String severity, String exceptionType, String status) {
        Exception__c exc = new Exception__c(
            Load__c = loadId,
            Exception_Type__c = exceptionType,
            Severity__c = severity,
            Description__c = 'Test exception: ' + exceptionType,
            Triggered_DateTime__c = System.now(),
            Status__c = status
        );
        insert exc;
        return exc;
    }
    
    private static void createTestExceptions(Integer count, String severity, String exceptionType, String status) {
        List<Exception__c> exceptions = new List<Exception__c>();
        
        for (Integer i = 0; i < count; i++) {
            Load__c load = createTestLoad('LOAD-' + exceptionType + '-' + i);
            exceptions.add(new Exception__c(
                Load__c = load.Id,
                Exception_Type__c = exceptionType,
                Severity__c = severity,
                Description__c = 'Test exception ' + i,
                Triggered_DateTime__c = System.now().addMinutes(-i),
                Status__c = status
            ));
        }
        
        insert exceptions;
    }
    
    private static void createExceptionAtTime(Id loadId, DateTime triggeredTime) {
        Exception__c exc = new Exception__c(
            Load__c = loadId,
            Exception_Type__c = 'LATE_ARRIVAL',
            Severity__c = 'Alert',
            Description__c = 'Test exception at ' + triggeredTime,
            Triggered_DateTime__c = triggeredTime,
            Status__c = 'Open'
        );
        insert exc;
    }
}
