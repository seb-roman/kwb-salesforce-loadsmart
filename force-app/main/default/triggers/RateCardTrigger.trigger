/**
 * RateCardTrigger.trigger
 * 
 * Validates rate cards before insert/update
 * Ensures:
 * - Rate > 0
 * - Priority 1-3
 * - Equipment type required
 * 
 * @author Agent 4
 * @version 1.0
 */
trigger RateCardTrigger on RateCard__c (before insert, before update) {
    
    for (RateCard__c rateCard : Trigger.new) {
        try {
            RateCardLookup.validateRateCard(rateCard);
        } catch (IllegalArgumentException e) {
            rateCard.addError(e.getMessage());
        }
    }
}
