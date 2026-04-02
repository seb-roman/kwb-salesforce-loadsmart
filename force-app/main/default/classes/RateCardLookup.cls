/**
 * RateCardLookup.cls
 * 
 * Provides rate card lookup functionality with priority-based matching
 * Priority 1: Shipper-specific rates (origin + destination + equipment)
 * Priority 2: Default rates (equipment only)
 * Priority 3: Manual override
 * 
 * @author Agent 4
 * @version 1.0
 */
public class RateCardLookup {
    
    /**
     * Query rate card based on load origin, destination, and equipment
     * Returns the highest priority matching rate
     */
    public static Decimal queryRateCard(String origin, String destination, String equipment, String accountId) {
        try {
            // Priority 1: Check shipper-specific rate (origin + destination + equipment)
            List<RateCard__c> shipper_specific = [
                SELECT Amount__c, Priority__c
                FROM RateCard__c
                WHERE Account__c = :accountId
                    AND Origin__c = :origin
                    AND Destination__c = :destination
                    AND Equipment_Type__c = :equipment
                    AND Is_Active__c = true
                ORDER BY Priority__c ASC, CreatedDate DESC
                LIMIT 1
            ];
            
            if (!shipper_specific.isEmpty()) {
                return shipper_specific[0].Amount__c;
            }
            
            // Priority 2: Check default rate (equipment only)
            List<RateCard__c> default_rate = [
                SELECT Amount__c, Priority__c
                FROM RateCard__c
                WHERE Account__c = :accountId
                    AND Origin__c = null
                    AND Destination__c = null
                    AND Equipment_Type__c = :equipment
                    AND Is_Active__c = true
                ORDER BY Priority__c ASC, CreatedDate DESC
                LIMIT 1
            ];
            
            if (!default_rate.isEmpty()) {
                return default_rate[0].Amount__c;
            }
            
            // No rate found
            return null;
            
        } catch (Exception e) {
            System.debug('Error querying rate card: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Validate rate card before insert/update
     * - Rate must be > 0
     * - Priority must be 1-3
     * - Equipment type required
     */
    public static void validateRateCard(RateCard__c rateCard) {
        List<String> errors = new List<String>();
        
        // Validate amount
        if (rateCard.Amount__c == null || rateCard.Amount__c <= 0) {
            errors.add('Rate must be greater than 0');
        }
        
        // Validate priority
        if (rateCard.Priority__c == null || rateCard.Priority__c < 1 || rateCard.Priority__c > 3) {
            errors.add('Priority must be between 1 and 3');
        }
        
        // Validate equipment type
        if (String.isBlank(rateCard.Equipment_Type__c)) {
            errors.add('Equipment type is required');
        }
        
        // Throw exception if validation errors
        if (!errors.isEmpty()) {
            throw new IllegalArgumentException(String.join(errors, '; '));
        }
    }
    
    /**
     * Get all rate cards for a given account
     */
    public static List<RateCard__c> getRateCardsForAccount(String accountId) {
        try {
            return [
                SELECT Id, Name, Amount__c, Priority__c, Equipment_Type__c, 
                       Origin__c, Destination__c, Is_Active__c
                FROM RateCard__c
                WHERE Account__c = :accountId
                ORDER BY Priority__c ASC, Equipment_Type__c ASC
            ];
        } catch (Exception e) {
            System.debug('Error fetching rate cards: ' + e.getMessage());
            return new List<RateCard__c>();
        }
    }
    
    /**
     * Look up and apply rates to a load
     */
    public static void lookupAndApplyRates(Load__c load) {
        if (load.Shipper_Account__c == null || load.Equipment_Type__c == null) {
            return;
        }
        
        // Query rate based on origin, destination, equipment
        Decimal rate = queryRateCard(
            load.Origin_State__c,
            load.Destination_State__c,
            load.Equipment_Type__c,
            String.valueOf(load.Shipper_Account__c)
        );
        
        if (rate != null) {
            load.Shipper_Rate__c = rate;
        }
    }
}
