/**
 * TrackingTriggerHandler
 * 
 * Handles trigger logic for Tracking__c object.
 * 
 * Responsibilities:
 * - Publish TrackingUpdate__e Platform Event on insert (for real-time dashboard)
 * - Publish Platform Event on update if critical fields changed
 * - Prevent trigger recursion via static guard
 * - Validation of tracking events
 * 
 * Design Spec: AGENT3_ARCHITECTURE_DIAGRAMS_AND_DELIVERABLES.md
 */
public with sharing class TrackingTriggerHandler {
    
    private static final String CLASS_NAME = 'TrackingTriggerHandler';
    
    // Recursion prevention guard - prevents infinite loops if trigger causes updates
    private static Boolean isExecuting = false;
    
    /**
     * Handle after insert - publish Platform Event for real-time updates
     * 
     * Publishes one TrackingUpdate__e Platform Event per inserted Tracking__c record
     * for consumption by the real-time dashboard and other event subscribers.
     * 
     * @param newRecords List of newly inserted Tracking__c records
     */
    public static void handleAfterInsert(List<Tracking__c> newRecords) {
        // Prevent recursion if trigger fires again due to event processing
        if (isExecuting) {
            return;
        }
        isExecuting = true;
        
        try {
            List<TrackingUpdate__e> events = new List<TrackingUpdate__e>();
            
            for (Tracking__c tracking : newRecords) {
                TrackingUpdate__e evt = new TrackingUpdate__e();
                evt.Load_Id__c = tracking.Load__c;
                evt.Tracking_Id__c = tracking.Id;
                
                // Handle null Event_Type__c safely
                if (tracking.Event_Type__c != null) {
                    evt.Event_Type__c = tracking.Event_Type__c;
                } else {
                    logWarning('Null Event_Type for tracking: ' + tracking.Id);
                    evt.Event_Type__c = 'vehicle_location_update'; // Default
                }
                
                evt.Latitude__c = tracking.Latitude__c;
                evt.Longitude__c = tracking.Longitude__c;
                evt.Speed_mph__c = tracking.Speed_mph__c;
                evt.Driver_Id__c = tracking.Driver__c;
                
                // Format timestamp as ISO 8601 UTC string
                if (tracking.Event_Timestamp__c != null) {
                    evt.Event_Timestamp__c = tracking.Event_Timestamp__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
                }
                
                evt.Sequence_Number__c = tracking.Sequence_Number__c;
                
                events.add(evt);
            }
            
            // Publish events immediately (SLA: < 5 sec delivery)
            if (!events.isEmpty()) {
                List<Database.SaveResult> results = EventBus.publish(events);
                
                // Log any publish failures
                for (Database.SaveResult result : results) {
                    if (!result.isSuccess()) {
                        for (Database.Error error : result.getErrors()) {
                            logError('handleAfterInsert', 'Failed to publish Platform Event: ' + error.getMessage());
                        }
                    }
                }
            }
            
        } catch (Exception e) {
            logError('handleAfterInsert', e.getMessage());
            // Don't throw - trigger should succeed even if event publish fails
        } finally {
            // Always reset recursion guard
            isExecuting = false;
        }
    }
    
    /**
     * Handle after update - publish event if critical fields changed
     * 
     * @param newRecords List of updated Tracking__c records
     * @param oldMap Map of old Tracking__c values before update
     */
    public static void handleAfterUpdate(List<Tracking__c> newRecords, Map<Id, Tracking__c> oldMap) {
        // Prevent recursion
        if (isExecuting) {
            return;
        }
        isExecuting = true;
        
        try {
            List<TrackingUpdate__e> events = new List<TrackingUpdate__e>();
            
            for (Tracking__c tracking : newRecords) {
                Tracking__c oldTracking = oldMap.get(tracking.Id);
                
                // Check if critical fields changed
                if (hasSignificantChange(tracking, oldTracking)) {
                    TrackingUpdate__e evt = new TrackingUpdate__e();
                    evt.Load_Id__c = tracking.Load__c;
                    evt.Tracking_Id__c = tracking.Id;
                    
                    // Handle null Event_Type__c safely
                    if (tracking.Event_Type__c != null) {
                        evt.Event_Type__c = tracking.Event_Type__c;
                    } else {
                        evt.Event_Type__c = 'vehicle_location_update'; // Default
                    }
                    
                    evt.Latitude__c = tracking.Latitude__c;
                    evt.Longitude__c = tracking.Longitude__c;
                    evt.Speed_mph__c = tracking.Speed_mph__c;
                    evt.Driver_Id__c = tracking.Driver__c;
                    
                    // Format timestamp as ISO 8601 UTC string
                    if (tracking.Event_Timestamp__c != null) {
                        evt.Event_Timestamp__c = tracking.Event_Timestamp__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
                    }
                    
                    evt.Sequence_Number__c = tracking.Sequence_Number__c;
                    
                    events.add(evt);
                }
            }
            
            // Publish events
            if (!events.isEmpty()) {
                List<Database.SaveResult> results = EventBus.publish(events);
                
                for (Database.SaveResult result : results) {
                    if (!result.isSuccess()) {
                        for (Database.Error error : result.getErrors()) {
                            logError('handleAfterUpdate', 'Failed to publish Platform Event: ' + error.getMessage());
                        }
                    }
                }
            }
            
        } catch (Exception e) {
            logError('handleAfterUpdate', e.getMessage());
        } finally {
            // Always reset recursion guard
            isExecuting = false;
        }
    }
    
    /**
     * Check if a tracking update has significant changes
     */
    private static Boolean hasSignificantChange(Tracking__c newTracking, Tracking__c oldTracking) {
        // Consider changes in location, speed, or event type as significant
        if (newTracking.Latitude__c != oldTracking.Latitude__c) return true;
        if (newTracking.Longitude__c != oldTracking.Longitude__c) return true;
        if (newTracking.Speed_mph__c != oldTracking.Speed_mph__c) return true;
        if (newTracking.Event_Type__c != oldTracking.Event_Type__c) return true;
        
        return false;
    }
    
    /**
     * Error logging
     */
    private static void logError(String method, String message) {
        System.debug(LoggingLevel.ERROR, CLASS_NAME + '.' + method + ': ' + message);
    }
    
    /**
     * Warning logging
     */
    private static void logWarning(String message) {
        System.debug(LoggingLevel.WARN, CLASS_NAME + ': ' + message);
    }
}
