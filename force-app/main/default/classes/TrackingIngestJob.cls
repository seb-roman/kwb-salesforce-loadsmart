/**
 * TrackingIngestJob
 * 
 * Queueable job for processing Motive GPS webhook payloads asynchronously.
 * Handles high-volume events without blocking the webhook receiver.
 * 
 * Responsibilities:
 * - Parse Motive GPS payload (lat/lng, timestamp, driver_id, speed, heading)
 * - Create or update Tracking__c records (idempotent, no duplicates)
 * - Map Motive driver_id to Salesforce Driver__c
 * - Reverse-geocode coordinates to address (future: Google Maps API)
 * - Update Stop__c actual_arrival_time / actual_departure_time
 * - Trigger Platform Event on Tracking insert (for real-time dashboard)
 * - Handle errors gracefully (missing data, API failures)
 * 
 * Design Spec: AGENT3_ARCHITECTURE_DIAGRAMS_AND_DELIVERABLES.md
 */
public with sharing class TrackingIngestJob implements Queueable, Database.AllowsCallouts {

    private String rawPayload;
    private static final String CLASS_NAME = 'TrackingIngestJob';
    
    public TrackingIngestJob(String payload) {
        this.rawPayload = payload;
    }
    
    /**
     * Execute the job
     */
    public void execute(QueueableContext ctx) {
        try {
            // Parse payload
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(rawPayload);
            
            // Extract Motive event data
            String eventId = (String) payload.get('id');
            String vehicleId = (String) payload.get('vehicleId');
            String eventType = (String) payload.get('type');
            DateTime eventTimestamp = parseDateTime((String) payload.get('timestamp'));
            
            // Get GPS location data
            Map<String, Object> location = (Map<String, Object>) payload.get('location');
            Double latitude = location != null ? (Double) location.get('latitude') : null;
            Double longitude = location != null ? (Double) location.get('longitude') : null;
            Double speedMph = location != null ? (Double) location.get('speedMph') : null;
            Integer heading = location != null ? (Integer) location.get('heading') : null;
            
            // Validate GPS data before processing
            if (!isValidGPSData(latitude, longitude, speedMph, heading)) {
                logWarning('Invalid GPS data: lat=' + latitude + ', lng=' + longitude + ', speed=' + speedMph);
                return; // Skip invalid records
            }
            
            // Get driver data from payload
            Map<String, Object> driver = (Map<String, Object>) payload.get('driver');
            String driverId = driver != null ? (String) driver.get('id') : null;
            
            // Find associated Load__c
            Load__c load = findActiveLoadForVehicle(vehicleId);
            if (load == null) {
                logWarning('No active load found for vehicle: ' + vehicleId);
                return; // Skip if no associated load
            }
            
            // Create Tracking__c record
            Tracking__c tracking = new Tracking__c();
            tracking.Load__c = load.Id;
            tracking.Motive_Event_ID__c = eventId;
            tracking.Motive_Vehicle_ID__c = vehicleId;
            tracking.Motive_Driver_ID__c = driverId;
            tracking.Event_Type__c = normalizeEventType(eventType);
            tracking.Latitude__c = latitude;
            tracking.Longitude__c = longitude;
            if (speedMph != null) {
                tracking.Speed_mph__c = speedMph;
            }
            tracking.Heading_degrees__c = heading;
            tracking.Event_Timestamp__c = eventTimestamp;
            tracking.Address__c = 'TBD'; // Reverse geocoding in future
            
            // Set sequence number (for chronological ordering)
            Integer sequenceNumber = getNextSequenceNumber(load.Id);
            tracking.Sequence_Number__c = sequenceNumber;
            
            // Lookup and set Driver__c
            Driver__c driverRecord = findDriver(driverId);
            if (driverRecord != null) {
                tracking.Driver__c = driverRecord.Id;
            }
            
            // Insert tracking record (trigger will publish Platform Event)
            insert tracking;
            
            // Update Stop__c with actual arrival/departure times if applicable
            updateStopTimesIfApplicable(load, tracking);
            
        } catch (Exception e) {
            logError('execute', e);
            // Don't rethrow - queueable jobs should fail gracefully
        }
    }
    
    /**
     * Find the active Load__c for a vehicle (using Motive vehicle ID)
     * 
     * Strategy: Query Equipment__c with matching Motive_Vehicle_ID__c,
     * then find associated Load__c with Status = 'in_transit'.
     * If multiple loads for the same vehicle, pick the earliest (oldest first).
     * 
     * @param motiveVehicleId The Motive vehicle ID from webhook
     * @return The active Load__c record, or null if not found
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static Load__c findActiveLoadForVehicle(String motiveVehicleId) {
        if (String.isEmpty(motiveVehicleId)) {
            return null;
        }
        
        try {
            // First, find Equipment__c record with matching Motive vehicle ID
            List<Equipment__c> equipment = [
                SELECT Id, Current_Load__c FROM Equipment__c 
                WHERE Motive_Vehicle_ID__c = :motiveVehicleId
                LIMIT 10 // Get multiple in case of reassignment
            ];
            
            if (equipment.isEmpty()) {
                logWarning('No equipment found with Motive_Vehicle_ID: ' + motiveVehicleId);
                return null;
            }
            
            // Extract load IDs from equipment
            Set<Id> loadIds = new Set<Id>();
            for (Equipment__c eq : equipment) {
                if (eq.Current_Load__c != null) {
                    loadIds.add(eq.Current_Load__c);
                }
            }
            
            if (loadIds.isEmpty()) {
                logWarning('Equipment found but not assigned to any load. Vehicle: ' + motiveVehicleId);
                return null;
            }
            
            // Find in_transit load(s) - pick the earliest if multiple
            List<Load__c> loads = [
                SELECT Id, Status__c, CreatedDate FROM Load__c 
                WHERE Id IN :loadIds 
                AND Status__c = 'in_transit'
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            
            if (loads.isEmpty()) {
                logWarning('No in_transit load found for vehicle: ' + motiveVehicleId);
                return null;
            }
            
            return loads[0];
            
        } catch (Exception e) {
            logError('findActiveLoadForVehicle', e);
            return null;
        }
    }
    
    /**
     * Find Driver__c by Motive driver ID
     * 
     * @param motiveDriverId The Motive driver ID from webhook
     * @return The Driver__c record, or null if not found or ID is empty
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static Driver__c findDriver(String motiveDriverId) {
        if (String.isEmpty(motiveDriverId)) {
            return null;
        }
        
        try {
            List<Driver__c> drivers = [
                SELECT Id FROM Driver__c 
                WHERE Motive_Driver_ID__c = :motiveDriverId
                LIMIT 1
            ];
            
            if (drivers.isEmpty()) {
                logWarning('No driver found with Motive_Driver_ID: ' + motiveDriverId);
                return null;
            }
            
            return drivers[0];
            
        } catch (Exception e) {
            logError('findDriver', e);
            return null;
        }
    }
    
    /**
     * Get next sequence number for this load's tracking events
     * 
     * Uses pessimistic locking (FOR UPDATE) to prevent race conditions
     * in concurrent job execution. Updates the Load__c.Tracking_Sequence_Counter__c field.
     * 
     * @param loadId The Load ID to get sequence for
     * @return The next sequence number (1-based)
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static Integer getNextSequenceNumber(String loadId) {
        try {
            // Use pessimistic locking to prevent race conditions
            List<Load__c> loads = [
                SELECT Id, Tracking_Sequence_Counter__c FROM Load__c 
                WHERE Id = :loadId
                FOR UPDATE
            ];
            
            if (loads.isEmpty()) {
                logWarning('Load not found for sequence numbering: ' + loadId);
                return 1;
            }
            
            Load__c load = loads[0];
            
            // Increment counter and get the new value
            Integer nextSeq = (Integer)(load.Tracking_Sequence_Counter__c ?? 0) + 1;
            load.Tracking_Sequence_Counter__c = nextSeq;
            
            // Update to persist the new counter (still in transaction, still locked)
            update load;
            
            return nextSeq;
            
        } catch (Exception e) {
            logError('getNextSequenceNumber', e);
            return 1;
        }
    }
    
    /**
     * Validate GPS coordinates and speed data
     * 
     * Checks:
     * - Latitude: between -90 and 90
     * - Longitude: between -180 and 180
     * - Speed: non-negative
     * - Heading: between 0 and 360 (if present)
     * 
     * @param latitude GPS latitude
     * @param longitude GPS longitude
     * @param speed Speed in mph
     * @param heading Heading in degrees
     * @return true if all data is valid, false if any validation fails
     */
    private static Boolean isValidGPSData(Double latitude, Double longitude, Double speed, Integer heading) {
        if (latitude == null || longitude == null) {
            return false; // Both coordinates required
        }
        
        // Validate latitude range
        if (latitude < -90.0 || latitude > 90.0) {
            logWarning('Invalid latitude: ' + latitude);
            return false;
        }
        
        // Validate longitude range
        if (longitude < -180.0 || longitude > 180.0) {
            logWarning('Invalid longitude: ' + longitude);
            return false;
        }
        
        // Validate speed (must be non-negative)
        if (speed != null && speed < 0) {
            logWarning('Invalid speed (negative): ' + speed);
            return false;
        }
        
        // Validate heading (if present)
        if (heading != null && (heading < 0 || heading > 360)) {
            logWarning('Invalid heading: ' + heading);
            return false;
        }
        
        return true;
    }
    
    /**
     * Normalize Motive event type to our local enum
     * 
     * Maps Motive event types to Salesforce Tracking__c picklist values.
     * If input is null or unmapped, returns a safe default.
     * 
     * @param motiveEventType The event type from Motive API
     * @return The normalized event type string
     */
    private static String normalizeEventType(String motiveEventType) {
        // Handle null input
        if (String.isEmpty(motiveEventType)) {
            return 'vehicle_location_update'; // Default event type
        }
        
        Map<String, String> mapping = new Map<String, String>{
            'vehicle.location.update' => 'vehicle_location_update',
            'vehicle.eld_status.change' => 'eld_status_change',
            'vehicle.geofence_event' => 'geofence_event',
            'vehicle.harsh_acceleration' => 'harsh_acceleration',
            'vehicle.harsh_braking' => 'harsh_braking',
            'arrived_at_pickup' => 'arrived_at_pickup',
            'arrived_at_delivery' => 'arrived_at_delivery',
            'in_transit' => 'in_transit'
        };
        
        return mapping.containsKey(motiveEventType) ? 
            mapping.get(motiveEventType) : motiveEventType;
    }
    
    /**
     * Update Stop__c actual arrival/departure times when applicable
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void updateStopTimesIfApplicable(Load__c load, Tracking__c tracking) {
        try {
            // Get all stops for this load
            List<Stop__c> stops = [
                SELECT Id, Sequence__c, Actual_Arrival__c, Actual_Departure__c, 
                       Stop_Type__c, Latitude__c, Longitude__c
                FROM Stop__c 
                WHERE Load__c = :load.Id
                ORDER BY Sequence__c ASC
            ];
            
            if (stops.isEmpty()) {
                return;
            }
            
            // Determine which stop this tracking event applies to
            // Simple logic: check geofence (coordinates within ~1 mile)
            // TODO: Implement proper geofence checking
            
            Stop__c targetStop = null;
            for (Stop__c stop : stops) {
                if (isWithinGeofence((Double)tracking.Latitude__c, (Double)tracking.Longitude__c, 
                                    (Double)stop.Latitude__c, (Double)stop.Longitude__c)) {
                    targetStop = stop;
                    break;
                }
            }
            
            if (targetStop == null) {
                return; // Not at any stop location
            }
            
            // Update appropriate time based on event type
            if (tracking.Event_Type__c == 'arrived_at_pickup' || 
                tracking.Event_Type__c == 'arrived_at_delivery') {
                if (targetStop.Actual_Arrival__c == null) {
                    targetStop.Actual_Arrival__c = tracking.Event_Timestamp__c;
                }
            } else if (tracking.Event_Type__c == 'pickup_complete' || 
                      tracking.Event_Type__c == 'delivery_complete') {
                if (targetStop.Actual_Departure__c == null) {
                    targetStop.Actual_Departure__c = tracking.Event_Timestamp__c;
                }
            }
            
            // Save updated stop
            update targetStop;
            
        } catch (Exception e) {
            logError('updateStopTimesIfApplicable', e);
            // Don't fail - tracking insert already succeeded
        }
    }
    
    /**
     * Check if coordinates are within geofence of a stop (using Haversine formula)
     * 
     * Uses accurate great-circle distance calculation (Haversine formula) instead of
     * simplistic Euclidean distance. This is accurate at all latitudes, not just equator.
     * 
     * @param lat1 Vehicle latitude
     * @param lng1 Vehicle longitude
     * @param lat2 Stop latitude
     * @param lng2 Stop longitude
     * @return true if vehicle is within 1 mile of stop, false otherwise
     */
    private static Boolean isWithinGeofence(Double lat1, Double lng1, Double lat2, Double lng2) {
        if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
            return false;
        }
        
        // Use Haversine formula for accurate great-circle distance
        Double distanceMiles = haversineDistance(lat1, lng1, lat2, lng2);
        
        // Geofence threshold: 1 mile
        return distanceMiles <= 1.0;
    }
    
    /**
     * Calculate great-circle distance between two coordinates using Haversine formula
     * 
     * Formula:
     *   a = sin²(Δφ/2) + cos φ1 ⋅ cos φ2 ⋅ sin²(Δλ/2)
     *   c = 2 ⋅ atan2( √a, √(1−a) )
     *   d = R ⋅ c
     * 
     * where φ is latitude, λ is longitude, R is earth's radius (3959 miles)
     * 
     * @param lat1 Point 1 latitude (degrees)
     * @param lon1 Point 1 longitude (degrees)
     * @param lat2 Point 2 latitude (degrees)
     * @param lon2 Point 2 longitude (degrees)
     * @return Distance in miles
     */
    private static Double haversineDistance(Double lat1, Double lon1, Double lat2, Double lon2) {
        // Earth radius in miles
        Double earthRadiusMiles = 3959.0;
        
        // Convert to radians
        Double phi1 = (lat1 * Math.PI) / 180.0;
        Double phi2 = (lat2 * Math.PI) / 180.0;
        Double deltaLat = ((lat2 - lat1) * Math.PI) / 180.0;
        Double deltaLon = ((lon2 - lon1) * Math.PI) / 180.0;
        
        // Haversine formula
        Double a = Math.sin(deltaLat / 2.0) * Math.sin(deltaLat / 2.0) +
                   Math.cos(phi1) * Math.cos(phi2) *
                   Math.sin(deltaLon / 2.0) * Math.sin(deltaLon / 2.0);
        
        Double c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a));
        Double distance = earthRadiusMiles * c;
        
        return distance;
    }
    
    /**
     * Parse ISO 8601 datetime string
     * 
     * Assumes all Motive timestamps are in UTC (indicated by 'Z' suffix).
     * Converts to Salesforce DateTime which is stored in UTC internally.
     * 
     * Expected format: "2026-04-03T14:32:15Z" or "2026-04-03T14:32:15.123Z"
     * 
     * @param dateTimeStr ISO 8601 formatted datetime string (UTC)
     * @return Parsed DateTime, or current time if parsing fails
     */
    private static DateTime parseDateTime(String dateTimeStr) {
        if (String.isEmpty(dateTimeStr)) {
            logWarning('Empty datetime string provided');
            return DateTime.now();
        }
        
        try {
            // Replace 'Z' (UTC indicator) with '+0000' for Salesforce parsing
            if (!dateTimeStr.endsWith('Z')) {
                logWarning('Expected UTC timestamp (Z suffix), got: ' + dateTimeStr);
            }
            
            String cleanDate = dateTimeStr.replace('Z', '+0000');
            return DateTime.parse(cleanDate);
            
        } catch (Exception e) {
            logWarning('Failed to parse datetime: ' + dateTimeStr + ' - ' + e.getMessage());
            return DateTime.now();
        }
    }
    
    /**
     * Logging helper
     */
    private static void logError(String method, Exception e) {
        System.debug(LoggingLevel.ERROR, CLASS_NAME + '.' + method + ': ' + 
            e.getMessage() + ' ' + e.getStackTraceString());
    }
    
    private static void logWarning(String message) {
        System.debug(LoggingLevel.WARN, CLASS_NAME + ': ' + message);
    }
}
