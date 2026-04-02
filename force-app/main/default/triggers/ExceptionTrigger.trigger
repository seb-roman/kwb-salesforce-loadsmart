/**
 * AGENT3_PHASE2: Exception Trigger
 * 
 * Fires on exception creation to send alerts.
 * Non-blocking: calls alert distribution asynchronously
 * 
 * @author Agent 3
 */
trigger ExceptionTrigger on Exception__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        // Send alerts asynchronously
        ExceptionAlertDistribution.processAlerts(Trigger.new);
    }
}
