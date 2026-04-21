/**
 * RateCardLookupTest.cls
 * 
 * Test class for RateCardLookup functionality
 * Covers: Rate matching, validation, and priority logic
 * 
 * @author Agent 4
 * @version 1.0
 */
@IsTest
private class RateCardLookupTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test account (shipper)
        Account shipper = new Account();
        shipper.Name = 'Test Shipper';
        shipper.Type = 'Shipper';
        insert shipper;
        
        // Create rate cards
        List<RateCard__c> rateCards = new List<RateCard__c>();
        
        // Priority 1: Shipper-specific rate (origin + destination + equipment)
        RateCard__c card1 = new RateCard__c();
        card1.Account__c = shipper.Id;
        card1.Base_Rate__c = 1500; // $1500/load
        card1.Priority__c = 1;
        card1.Equipment_Type__c = 'Dry Van';
        card1.Origin__c = 'OH';
        card1.Destination__c = 'PA';
        card1.Active__c = true;
        rateCards.add(card1);
        
        // Priority 2: Default rate (equipment only)
        RateCard__c card2 = new RateCard__c();
        card2.Account__c = shipper.Id;
        card2.Base_Rate__c = 1200; // $1200/load
        card2.Priority__c = 2;
        card2.Equipment_Type__c = 'Dry Van';
        card2.Active__c = true;
        rateCards.add(card2);
        
        // Inactive rate (should be ignored)
        RateCard__c card3 = new RateCard__c();
        card3.Account__c = shipper.Id;
        card3.Base_Rate__c = 2000;
        card3.Priority__c = 1;
        card3.Equipment_Type__c = 'Reefer';
        card3.Active__c = false;
        rateCards.add(card3);
        
        insert rateCards;
    }
    
    @IsTest
    static void testShipperSpecificRateMatch() {
        // Arrange
        Account shipper = [SELECT Id FROM Account LIMIT 1];
        
        // Act
        Decimal rate = RateCardLookup.queryRateCard('OH', 'PA', 'Dry Van', shipper.Id);
        
        // Assert
        System.assertEquals(1500, rate, 'Should match shipper-specific rate');
    }
    
    @IsTest
    static void testDefaultRateFallback() {
        // Arrange
        Account shipper = [SELECT Id FROM Account LIMIT 1];
        
        // Act
        Decimal rate = RateCardLookup.queryRateCard('TX', 'CA', 'Dry Van', shipper.Id);
        
        // Assert
        System.assertEquals(1200, rate, 'Should fall back to default rate');
    }
    
    @IsTest
    static void testNoRateFound() {
        // Arrange
        Account shipper = [SELECT Id FROM Account LIMIT 1];
        
        // Act
        Decimal rate = RateCardLookup.queryRateCard('TX', 'CA', 'Flatbed', shipper.Id);
        
        // Assert
        System.assertEquals(null, rate, 'Should return null if no rate found');
    }
    
    @IsTest
    static void testInactiveRateIgnored() {
        // Arrange
        Account shipper = [SELECT Id FROM Account LIMIT 1];
        
        // Act
        Decimal rate = RateCardLookup.queryRateCard('OH', 'PA', 'Reefer', shipper.Id);
        
        // Assert
        System.assertEquals(null, rate, 'Should ignore inactive rates');
    }
    
    @IsTest
    static void testValidateRateCard_Success() {
        // Arrange
        RateCard__c card = new RateCard__c();
        card.Base_Rate__c = 1500;
        card.Priority__c = 1;
        card.Equipment_Type__c = 'Dry Van';
        
        // Act & Assert (no exception thrown)
        try {
            RateCardLookup.validateRateCard(card);
        } catch (Exception e) {
            System.assert(false, 'Validation should pass for valid rate card: ' + e.getMessage());
        }
    }
    
    @IsTest
    static void testValidateRateCard_InvalidAmount() {
        // Arrange
        RateCard__c card = new RateCard__c();
        card.Base_Rate__c = -100; // Negative amount
        card.Priority__c = 1;
        card.Equipment_Type__c = 'Dry Van';
        
        // Act & Assert
        try {
            RateCardLookup.validateRateCard(card);
            System.assert(false, 'Should throw exception for invalid amount');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('greater than 0'));
        }
    }
    
    @IsTest
    static void testValidateRateCard_InvalidPriority() {
        // Arrange
        RateCard__c card = new RateCard__c();
        card.Base_Rate__c = 1500;
        card.Priority__c = 5; // Invalid priority
        card.Equipment_Type__c = 'Dry Van';
        
        // Act & Assert
        try {
            RateCardLookup.validateRateCard(card);
            System.assert(false, 'Should throw exception for invalid priority');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Priority'));
        }
    }
    
    @IsTest
    static void testValidateRateCard_MissingEquipment() {
        // Arrange
        RateCard__c card = new RateCard__c();
        card.Base_Rate__c = 1500;
        card.Priority__c = 1;
        // Equipment_Type__c is blank
        
        // Act & Assert
        try {
            RateCardLookup.validateRateCard(card);
            System.assert(false, 'Should throw exception for missing equipment');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Equipment type is required'));
        }
    }
    
    @IsTest
    static void testGetRateCardsForAccount() {
        // Arrange
        Account shipper = [SELECT Id FROM Account LIMIT 1];
        
        // Act
        List<RateCard__c> cards = RateCardLookup.getRateCardsForAccount(shipper.Id);
        
        // Assert
        System.assertEquals(3, cards.size(), 'Should return all 3 rate cards (including inactive)');
        System.assertEquals('Dry Van', cards[0].Equipment_Type__c);
    }
    
    @IsTest
    static void testLookupAndApplyRates() {
        // Arrange
        Account shipper = [SELECT Id FROM Account LIMIT 1];
        Load__c load = new Load__c();
        load.Shipper__c = shipper.Id;
        load.Equipment_Type__c = 'Dry Van';
        load.Shipper_State__c = 'OH';
        load.Receiver_State__c = 'PA';
        
        // Act
        RateCardLookup.lookupAndApplyRates(load);
        
        // Assert
        System.assertEquals(1500, load.Billing_Rate__c, 'Should apply shipper-specific rate');
    }
}
