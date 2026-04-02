/**
 * FuelSurchargeCalculation.cls
 * 
 * Calculates fuel surcharge based on DAI (Diesel Average Index) price
 * Formula: (DAI_Price - Baseline) × (Distance / MPG) × Factor
 * 
 * Key Feature: DAI price is LOCKED at booking to prevent disputes
 * 
 * @author Agent 4
 * @version 1.0
 */
public class FuelSurchargeCalculation {
    
    // Phase 1: Fixed DAI price (will be replaced with real-time API in Phase 2)
    private static final Decimal PHASE1_DAI_PRICE = 3.15;
    
    // Baseline diesel price (below this, surcharge is zero)
    private static final Decimal BASELINE_COST = 2.50;
    
    // Miles per gallon (average truck)
    private static final Decimal MPG = 6.5;
    
    // Surcharge factor (multiplier)
    private static final Decimal SURCHARGE_FACTOR = 1.0;
    
    /**
     * Calculate fuel surcharge for a load
     * Uses locked DAI price (from Load__c.DAI_Price_At_Booking__c)
     * Falls back to current price if locked price not set
     */
    public static Decimal calculateFuelSurcharge(Load__c load) {
        // Validate prerequisites
        if (load.Distance_Miles__c == null || load.Distance_Miles__c == 0) {
            return 0;
        }
        
        // Get DAI price (locked at booking)
        Decimal daiPrice = load.DAI_Price_At_Booking__c != null 
            ? load.DAI_Price_At_Booking__c
            : getCurrentDAIPrice();
        
        // Calculate surcharge
        Decimal priceDifference = daiPrice - BASELINE_COST;
        if (priceDifference <= 0) {
            return 0;
        }
        
        // Formula: (DAI - Baseline) × (Distance / MPG) × Factor
        Decimal surcharge = priceDifference * (load.Distance_Miles__c / MPG) * SURCHARGE_FACTOR;
        
        // Round to 2 decimals
        return surcharge.setScale(2, RoundingMode.HALF_UP);
    }
    
    /**
     * Get current DAI price
     * Phase 1: Returns fixed PHASE1_DAI_PRICE
     * Phase 2: Will integrate with EIA API for real-time pricing
     */
    public static Decimal getCurrentDAIPrice() {
        try {
            // TODO: Phase 2 - Integrate with custom setting
            // Fuel_Surcharge_Settings__c setting = Fuel_Surcharge_Settings__c.getInstance();
            // if (setting != null && setting.DAI_Price__c != null) {
            //     return setting.DAI_Price__c;
            // }
            
            // Phase 1: Return fixed price
            return PHASE1_DAI_PRICE;
            
        } catch (Exception e) {
            System.debug('Error getting DAI price: ' + e.getMessage());
            return PHASE1_DAI_PRICE;
        }
    }
    
    /**
     * Lock DAI price at booking
     * Called from LoadTrigger before insert
     */
    public static void lockDAIPriceAtBooking(Load__c load) {
        // Only set if not already set
        if (load.DAI_Price_At_Booking__c == null) {
            load.DAI_Price_At_Booking__c = getCurrentDAIPrice();
        }
    }
    
    /**
     * Validate fuel surcharge calculation
     * Ensures precision and no negative values
     */
    public static void validateFuelSurcharge(Load__c load) {
        if (load.Fuel_Surcharge__c != null && load.Fuel_Surcharge__c < 0) {
            throw new IllegalArgumentException('Fuel surcharge cannot be negative');
        }
    }
    
    /**
     * Get surcharge detail breakdown for a load
     * Returns map with component values
     */
    public static Map<String, Decimal> getSurchargeDetail(Load__c load) {
        Map<String, Decimal> detail = new Map<String, Decimal>();
        
        Decimal daiPrice = load.DAI_Price_At_Booking__c != null 
            ? load.DAI_Price_At_Booking__c
            : getCurrentDAIPrice();
        
        detail.put('daiPrice', daiPrice);
        detail.put('baselinePrice', BASELINE_COST);
        detail.put('priceDifference', daiPrice - BASELINE_COST);
        detail.put('distance', load.Distance_Miles__c != null ? load.Distance_Miles__c : 0);
        detail.put('mpg', MPG);
        detail.put('surcharge', calculateFuelSurcharge(load));
        
        return detail;
    }
}
