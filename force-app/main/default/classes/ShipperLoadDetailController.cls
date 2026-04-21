/**
 * ShipperLoadDetailController
 * 
 * Apex controller for the Load Detail page in the Shipper Portal.
 * Provides full load information including related stops, tracking, and documents.
 * 
 * Features:
 * - Get single load by ID with row-level security verification
 * - Get related stop information (pickup, delivery)
 * - Get related documents (BOL, POD, invoices)
 * - Get tracking history via Platform Events (Phase 2)
 * 
 * Author: Agent 5 (Portal Development)
 * Created: April 2, 2026
 */

public with sharing class ShipperLoadDetailController {

    /**
     * Get full load details for a specific load
     * Enforces row-level security: shipper can only see own account's loads
     * 
     * @param loadId - The Load__c record ID
     * @return LoadDetailResponse with complete load information
     */
    @AuraEnabled
    public static LoadDetailResponse getLoadDetail(String loadId) {
        try {
            // SECURITY: Check CRUD access to Load__c
            SecurityUtil.enforceAccess(
                SecurityUtil.hasCRUDAccess(Load__c.SObjectType, 'READ'),
                'You do not have permission to access load details'
            );
            
            // SECURITY: Check FLS access to required fields
            List<String> requiredFields = new List<String>{
                'Id', 'Name', 'Shipper__c', 'Shipper_City__c', 'Receiver_City__c',
                'Status__c', 'Pickup_Date__c', 'Estimated_Delivery__c', 'Billing_Rate__c',
                'Equipment_Type__c', 'Equipment_Length__c', 'Weight_lbs__c', 'Commodity__c',
                'Carrier__c', 'IsDeleted', 'Pickup_Contact__c', 'Pickup_Company__c',
                'Pickup_Address__c', 'Pickup_Postal_Code__c', 'Pickup_State__c', 'Pickup_Country__c',
                'Delivery_Contact__c', 'Delivery_Company__c', 'Delivery_Address__c',
                'Delivery_Postal_Code__c', 'Delivery_State__c', 'Delivery_Country__c',
                'Pickup_Confirmation__c', 'Delivery_Confirmation__c',
                'Rate_Confirmation_PDF__c', 'Fuel_Surcharge__c', 'Notes__c'
            };
            SecurityUtil.enforceAccess(
                SecurityUtil.hasFieldLevelSecurityAccess(Load__c.SObjectType, requiredFields, 'READ'),
                'You do not have permission to access required load fields'
            );
            
            // Verify shipper account ID
            String shipperAccountId = ShipperLoadListController.getShipperAccountId();
            if (String.isBlank(shipperAccountId)) {
                throw new AuraHandledException('No shipper account found for current user');
            }

            // Query load with strict row-level security
            List<Load__c> loads = [
                SELECT Id, Name, Shipper__c, Shipper_City__c, Receiver_City__c,
                       Status__c, Pickup_Date__c, Estimated_Delivery__c, Billing_Rate__c,
                       Equipment_Type__c, Weight_lbs__c, Commodity__c,
                       Carrier__c, IsDeleted, Pickup_Contact__c, Pickup_Company__c,
                       Shipper_Address__c, Pickup_Country__c,
                       Delivery_Contact__c, Delivery_Company__c, Receiver_Address__c,
                       Delivery_Country__c,
                       Pickup_Confirmation__c, Delivery_Confirmation__c,
                       Fuel_Surcharge__c, Notes__c
                FROM Load__c
                WHERE Id = :loadId 
                  AND Shipper__c = :shipperAccountId
                  AND IsDeleted = false
                LIMIT 1
            ];

            if (loads.isEmpty()) {
                throw new AuraHandledException('Load not found or access denied');
            }

            Load__c load = loads[0];

            // Query related stops (if Stop__c exists) - graceful error handling
            List<Stop__c> stops = new List<Stop__c>();
            try {
                if (SecurityUtil.hasCRUDAccess(Stop__c.SObjectType, 'READ')) {
                    stops = [
                        SELECT Id, Sequence__c, Stop_Type__c,
                               Account__r.BillingCity, Account__r.BillingStreet, Account__r.BillingState,
                               Actual_Arrival__c, Actual_Departure__c, Appointment_Date__c
                        FROM Stop__c
                        WHERE Load__c = :loadId
                        ORDER BY Sequence__c ASC
                    ];
                }
            } catch (SObjectException e) {
                System.debug('Stop__c object not accessible: ' + e.getMessage());
            }

            // Query related invoices (if Invoice__c exists) - graceful error handling
            List<Invoice__c> invoices = new List<Invoice__c>();
            try {
                if (SecurityUtil.hasCRUDAccess(Invoice__c.SObjectType, 'READ')) {
                    invoices = [
                        SELECT Id, Name, Total_Amount__c, Status__c, Invoice_Date__c
                        FROM Invoice__c
                        WHERE Load__c = :loadId
                    ];
                }
            } catch (SObjectException e) {
                System.debug('Invoice__c object not accessible: ' + e.getMessage());
            }

            // Query related documents (ContentDocuments linked to Load via ContentDocumentLink)
            List<ContentDocumentLink> docLinks = new List<ContentDocumentLink>();
            try {
                if (SecurityUtil.hasCRUDAccess(ContentDocumentLink.SObjectType, 'READ')) {
                    docLinks = [
                        SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType,
                               ContentDocument.CreatedDate
                        FROM ContentDocumentLink
                        WHERE LinkedEntityId = :loadId
                    ];
                }
            } catch (SObjectException e) {
                System.debug('ContentDocumentLink object not accessible: ' + e.getMessage());
            }

            // Build response
            LoadDetailResponse response = new LoadDetailResponse();
            response.load = load;
            response.stops = stops;
            response.invoices = invoices;
            response.documents = docLinks;
            response.statusColor = getStatusColor(load.Status__c);
            response.etaCountdown = calculateETACountdown(load.Estimated_Delivery__c);

            return response;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving load details: ' + e.getMessage());
        }
    }

    /**
     * Get carrier information for a load
     * 
     * SECURITY: This method includes RLS check to prevent data leakage
     * (Fixed critical issue from peer review)
     * 
     * @param loadId - The Load__c record ID
     * @return CarrierInfo with carrier name and DOT number
     */
    @AuraEnabled
    public static CarrierInfo getCarrierInfo(String loadId) {
        try {
            // SECURITY: Get shipper account for RLS check (CRITICAL FIX)
            String shipperAccountId = ShipperLoadListController.getShipperAccountId();
            if (String.isBlank(shipperAccountId)) {
                throw new AuraHandledException('No shipper account found for current user');
            }

            // SECURITY: Check CRUD access to Load__c
            SecurityUtil.enforceAccess(
                SecurityUtil.hasCRUDAccess(Load__c.SObjectType, 'READ'),
                'You do not have permission to access load information'
            );

            // SECURITY: Check CRUD access to Carrier__c
            SecurityUtil.enforceAccess(
                SecurityUtil.hasCRUDAccess(Carrier__c.SObjectType, 'READ'),
                'You do not have permission to access carrier information'
            );

            // Query load with RLS check (CRITICAL FIX - was missing before)
            List<Load__c> loads = [
                SELECT Id, Carrier__c
                FROM Load__c
                WHERE Id = :loadId
                  AND Shipper__c = :shipperAccountId
                LIMIT 1
            ];

            if (loads.isEmpty()) {
                // Return null instead of throwing exception to avoid exposing whether load exists
                return null;
            }

            String carrierId = loads[0].Carrier__c;
            if (String.isBlank(carrierId)) {
                return null;
            }

            List<Carrier__c> carriers = [
                SELECT Id, Name, MC_Number__c, Phone__c, Email__c
                FROM Carrier__c
                WHERE Id = :carrierId
                LIMIT 1
            ];

            if (carriers.isEmpty()) {
                return null;
            }

            Carrier__c carrier = carriers[0];
            CarrierInfo info = new CarrierInfo();
            info.carrierName = carrier.Name;
            info.dotNumber = carrier.MC_Number__c;
            info.phone = carrier.Phone__c;
            info.email = carrier.Email__c;

            return info;

        } catch (Exception e) {
            System.debug('Error retrieving carrier info: ' + e.getMessage());
            return null;
        }
    }

    /**
     * Get status color for display (green = on-time, yellow = at-risk, red = late)
     */
    private static String getStatusColor(String status) {
        if (status == 'Delivered') {
            return 'green';
        } else if (status == 'In Transit') {
            return 'blue';
        } else if (status == 'At Risk') {
            return 'orange';
        } else if (status == 'Late') {
            return 'red';
        } else if (status == 'Posted' || status == 'Assigned') {
            return 'gray';
        }
        return 'gray';
    }

    /**
     * Calculate ETA countdown string (e.g., "2 days 3 hours")
     */
    private static String calculateETACountdown(DateTime eta) {
        if (eta == null) {
            return '';
        }
        
        Long millisDiff = eta.getTime() - System.now().getTime();
        if (millisDiff <= 0) {
            return 'Delivery window closed';
        }

        Long msPerDay = 24L * 60L * 60L * 1000L;
        Long msPerHour = 60L * 60L * 1000L;
        Long daysDiff = millisDiff / msPerDay;
        Long hoursDiff = (millisDiff - (daysDiff * msPerDay)) / msPerHour;

        String countdown = '';
        if (daysDiff > 0) {
            countdown += daysDiff + ' day' + (daysDiff > 1 ? 's' : '') + ' ';
        }
        if (hoursDiff > 0) {
            countdown += hoursDiff + ' hour' + (hoursDiff > 1 ? 's' : '');
        }

        return countdown.trim();
    }

    /**
     * Response wrapper for load detail
     */
    public class LoadDetailResponse {
        @AuraEnabled
        public Load__c load;
        @AuraEnabled
        public List<Stop__c> stops;
        @AuraEnabled
        public List<Invoice__c> invoices;
        @AuraEnabled
        public List<ContentDocumentLink> documents;
        @AuraEnabled
        public String statusColor;
        @AuraEnabled
        public String etaCountdown;
    }

    /**
     * Carrier information wrapper
     */
    public class CarrierInfo {
        @AuraEnabled
        public String carrierName;
        @AuraEnabled
        public String dotNumber;
        @AuraEnabled
        public String phone;
        @AuraEnabled
        public String email;
    }
}
