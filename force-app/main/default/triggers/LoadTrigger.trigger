/**
 * LoadTrigger.trigger
 * 
 * Orchestrates key Load operations:
 * 1. Locks DAI price at booking (before insert)
 * 2. Invokes invoice generation (after update when POD + BOL complete)
 * 3. Applies rate lookups (before insert/update)
 * 
 * @author Agent 4
 * @version 1.0
 */
trigger LoadTrigger on Load__c (before insert, before update, after insert, after update) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
        // Lock DAI price at booking
        for (Load__c load : Trigger.new) {
            FuelSurchargeCalculation.lockDAIPriceAtBooking(load);
        }
    }
    
    if (Trigger.isBefore && Trigger.isInsert) {
        // Apply rate lookups
        for (Load__c load : Trigger.new) {
            RateCardLookup.lookupAndApplyRates(load);
            
            // Calculate fuel surcharge if we have distance
            if (load.Distance_Miles__c != null && load.Distance_Miles__c > 0) {
                load.Fuel_Surcharge__c = FuelSurchargeCalculation.calculateFuelSurcharge(load);
                FuelSurchargeCalculation.validateFuelSurcharge(load);
            }
        }
    }
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        // Check if invoice generation should be triggered
        List<Load__c> eligibleLoads = new List<Load__c>();
        for (Load__c load : Trigger.new) {
            Load__c oldLoad = Trigger.oldMap.get(load.Id);
            
            // Trigger invoice generation if POD was captured or BOL was entered
            if ((load.POD_Captured__c != oldLoad.POD_Captured__c || 
                 load.BOL_Number__c != oldLoad.BOL_Number__c) &&
                load.POD_Captured__c == true &&
                String.isNotBlank(load.BOL_Number__c)) {
                eligibleLoads.add(load);
            }
        }
        
        if (!eligibleLoads.isEmpty()) {
            InvoiceGenerator.generateInvoices(eligibleLoads);
        }
    }
}
