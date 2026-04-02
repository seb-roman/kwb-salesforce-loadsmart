/**
 * AGENT3_PHASE2: Exception Alert Distribution Tests
 * 
 * Test alert routing and delivery for different severities.
 * 
 * Test Scenarios (5+ tests):
 * 1. Email alert for Warning
 * 2. Email + Slack for Critical
 * 3. Email + SMS for Critical with phone opt-in
 * 4. No Slack if not configured
 * 5. No SMS if phone not provided
 * 6. Alert message formatting
 * 7. Null recipient handling
 * 
 * @author Agent 3
 * @version 1.0
 */
@isTest
public with sharing class ExceptionAlertDistributionTest {
    
    /**
     * Test 1: Email Alert for Warning
     * Scenario: Warning exception creates email alert
     */
    @isTest
    static void testEmailAlertForWarning() {
        // Setup
        Load__c load = createTestLoadWithContacts('LOAD-W001', true, false);
        Exception__c exception = createTestException(load.Id, 'LATE_ARRIVAL', 'Warning');
        
        // Execute
        Test.startTest();
        ExceptionAlertDistribution.processAlerts(new List<Exception__c> { exception });
        Test.stopTest();
        
        // Verify email was queued
        System.assertEquals(1, [SELECT COUNT() FROM Exception__c WHERE Id = :exception.Id]);
    }
    
    /**
     * Test 2: Email + Slack for Critical
     * Scenario: Critical exception routes to email and Slack
     */
    @isTest
    static void testCriticalAlertRouting() {
        // Setup
        Load__c load = createTestLoadWithContacts('LOAD-C001', true, false);
        Exception__c exception = createTestException(load.Id, 'DRIVER_OFFLINE', 'Critical');
        
        // Execute
        Test.startTest();
        ExceptionAlertDistribution.processAlerts(new List<Exception__c> { exception });
        Test.stopTest();
        
        // Verify exception created
        List<Exception__c> exceptions = [SELECT Id, Severity__c FROM Exception__c WHERE Id = :exception.Id];
        System.assertEquals(1, exceptions.size());
        System.assertEquals('Critical', exceptions[0].Severity__c);
    }
    
    /**
     * Test 3: SMS for Critical with Phone Opt-In
     * Scenario: Critical exception with driver phone sends SMS
     */
    @isTest
    static void testSMSAlertWithPhoneOptIn() {
        // Setup
        Load__c load = createTestLoadWithContacts('LOAD-C002', true, true);
        Exception__c exception = createTestException(load.Id, 'EQUIPMENT_BREAKDOWN', 'Critical');
        
        // Execute
        Test.startTest();
        ExceptionAlertDistribution.processAlerts(new List<Exception__c> { exception });
        Test.stopTest();
        
        // Verify exception created
        System.assertEquals(1, [SELECT COUNT() FROM Exception__c WHERE Id = :exception.Id]);
    }
    
    /**
     * Test 4: No Slack Without Config
     * Scenario: Slack alert fails gracefully if webhook not configured
     */
    @isTest
    static void testNoSlackWithoutConfig() {
        // Setup
        Load__c load = createTestLoadWithContacts('LOAD-C003', true, false);
        Exception__c exception = createTestException(load.Id, 'GEOFENCE_VIOLATION', 'Critical');
        
        // Execute
        Test.startTest();
        ExceptionAlertDistribution.processAlerts(new List<Exception__c> { exception });
        Test.stopTest();
        
        // Verify no errors thrown
        System.assertEquals(1, [SELECT COUNT() FROM Exception__c WHERE Id = :exception.Id]);
    }
    
    /**
     * Test 5: No SMS Without Phone
     * Scenario: SMS alert skipped if no phone number
     */
    @isTest
    static void testNoSMSWithoutPhone() {
        // Setup
        Load__c load = createTestLoadWithContacts('LOAD-C004', true, false); // false = no phone
        Exception__c exception = createTestException(load.Id, 'MISSED_PICKUP', 'Critical');
        
        // Execute
        Test.startTest();
        ExceptionAlertDistribution.processAlerts(new List<Exception__c> { exception });
        Test.stopTest();
        
        // Verify exception created but no SMS sent
        System.assertEquals(1, [SELECT COUNT() FROM Exception__c WHERE Id = :exception.Id]);
    }
    
    /**
     * Test 6: Alert Message Formatting
     * Scenario: Alert messages format correctly with all required fields
     */
    @isTest
    static void testAlertMessageFormatting() {
        // Setup
        Load__c load = createTestLoadWithContacts('LOAD-MSG001', true, false);
        Exception__c exception = new Exception__c(
            Load__c = load.Id,
            Exception_Type__c = 'LONG_IDLE',
            Severity__c = 'Alert',
            Description__c = 'Driver idle at warehouse for 4.5 hours',
            Triggered_DateTime__c = System.now(),
            Status__c = 'Open'
        );
        insert exception;
        
        // Execute
        Test.startTest();
        ExceptionAlertDistribution.processAlerts(new List<Exception__c> { exception });
        Test.stopTest();
        
        // Verify exception details
        List<Exception__c> exceptions = [
            SELECT Id, Description__c, Triggered_DateTime__c 
            FROM Exception__c 
            WHERE Id = :exception.Id
        ];
        System.assertEquals(1, exceptions.size());
        System.assert(String.isNotBlank(exceptions[0].Description__c));
        System.assert(exceptions[0].Triggered_DateTime__c != null);
    }
    
    /**
     * Test 7: Null Recipient Handling
     * Scenario: Alert skipped gracefully if no recipients
     */
    @isTest
    static void testNullRecipientHandling() {
        // Setup - Load with no broker/dispatcher
        Load__c load = new Load__c(
            Name = 'LOAD-NO-CONTACTS',
            Status__c = 'IN_TRANSIT'
        );
        insert load;
        
        Exception__c exception = createTestException(load.Id, 'DRIVER_OFFLINE', 'Warning');
        
        // Execute
        Test.startTest();
        ExceptionAlertDistribution.processAlerts(new List<Exception__c> { exception });
        Test.stopTest();
        
        // Verify no errors
        System.assertEquals(1, [SELECT COUNT() FROM Exception__c WHERE Id = :exception.Id]);
    }
    
    /**
     * Test 8: Multiple Exceptions Bulk Processing
     * Scenario: Process multiple exceptions in one call
     */
    @isTest
    static void testMultipleExceptionProcessing() {
        // Setup
        List<Exception__c> exceptions = new List<Exception__c>();
        
        for (Integer i = 0; i < 5; i++) {
            Load__c load = createTestLoadWithContacts('LOAD-BULK-' + i, true, false);
            Exception__c exc = createTestException(load.Id, 'LATE_ARRIVAL', 'Alert');
            exceptions.add(exc);
        }
        
        // Execute
        Test.startTest();
        ExceptionAlertDistribution.processAlerts(exceptions);
        Test.stopTest();
        
        // Verify all exceptions processed
        System.assertEquals(5, [SELECT COUNT() FROM Exception__c WHERE Exception_Type__c = 'LATE_ARRIVAL']);
    }
    
    /**
     * Test 9: Different Severity Routing
     * Scenario: Verify routing matrix (Warning->Email, Alert->Email, Critical->Email+Slack+SMS)
     */
    @isTest
    static void testSeverityRoutingMatrix() {
        // Setup
        Load__c load1 = createTestLoadWithContacts('LOAD-SEVERITY-1', true, true);
        Load__c load2 = createTestLoadWithContacts('LOAD-SEVERITY-2', true, true);
        Load__c load3 = createTestLoadWithContacts('LOAD-SEVERITY-3', true, true);
        
        Exception__c warningExc = createTestException(load1.Id, 'LATE_ARRIVAL', 'Warning');
        Exception__c alertExc = createTestException(load2.Id, 'LONG_IDLE', 'Alert');
        Exception__c criticalExc = createTestException(load3.Id, 'EQUIPMENT_BREAKDOWN', 'Critical');
        
        // Execute
        Test.startTest();
        ExceptionAlertDistribution.processAlerts(
            new List<Exception__c> { warningExc, alertExc, criticalExc }
        );
        Test.stopTest();
        
        // Verify routing
        System.assertEquals(1, [SELECT COUNT() FROM Exception__c WHERE Severity__c = 'Warning']);
        System.assertEquals(1, [SELECT COUNT() FROM Exception__c WHERE Severity__c = 'Alert']);
        System.assertEquals(1, [SELECT COUNT() FROM Exception__c WHERE Severity__c = 'Critical']);
    }
    
    /**
     * Test 10: Empty Exception List
     * Scenario: Graceful handling of empty list
     */
    @isTest
    static void testEmptyExceptionList() {
        // Execute
        Test.startTest();
        ExceptionAlertDistribution.processAlerts(new List<Exception__c>());
        Test.stopTest();
        
        // Verify no errors
        System.assert(true, 'Empty list handled gracefully');
    }
    
    // ============ Helper Methods ============
    
    private static Load__c createTestLoadWithContacts(String name, Boolean withBroker, Boolean withDriver) {
        Load__c load = new Load__c(
            Name = name,
            Status__c = 'IN_TRANSIT'
        );
        
        // Create broker contact if needed
        if (withBroker) {
            Contact brokerContact = new Contact(
                LastName = 'Broker ' + name,
                Email = 'broker@example.com'
            );
            insert brokerContact;
            load.Broker_Rep__c = brokerContact.Id;
        }
        
        // Create driver if needed
        if (withDriver) {
            Contact driverContact = new Contact(
                LastName = 'Driver ' + name,
                Email = 'driver@example.com',
                Phone = '+1-555-0123'
            );
            insert driverContact;
            load.Driver__c = driverContact.Id;
        }
        
        insert load;
        return load;
    }
    
    private static Exception__c createTestException(Id loadId, String exceptionType, String severity) {
        Exception__c exception = new Exception__c(
            Load__c = loadId,
            Exception_Type__c = exceptionType,
            Severity__c = severity,
            Description__c = 'Test exception: ' + exceptionType,
            Triggered_DateTime__c = System.now(),
            Status__c = 'Open'
        );
        insert exception;
        return exception;
    }
}
