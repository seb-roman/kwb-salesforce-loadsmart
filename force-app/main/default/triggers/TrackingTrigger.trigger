/**
 * TrackingTrigger
 * 
 * Trigger on Tracking__c object
 * 
 * On INSERT:
 *  - Publish TrackingUpdate__e Platform Event (for real-time dashboard refresh, <5 sec latency)
 * 
 * On UPDATE:
 *  - Publish Platform Event if critical fields changed (lat/lng, speed, event_type)
 * 
 * Design Spec: AGENT3_ARCHITECTURE_DIAGRAMS_AND_DELIVERABLES.md
 */
trigger TrackingTrigger on Tracking__c (after insert, after update) {
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            TrackingTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            TrackingTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
