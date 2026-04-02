/**
 * FuelSurchargeCalculationTest.cls
 * 
 * Test class for FuelSurchargeCalculation functionality
 * Covers: Surcharge calculation, DAI price locking, and precision
 * 
 * @author Agent 4
 * @version 1.0
 */
@IsTest
private class FuelSurchargeCalculationTest {
    
    @IsTest
    static void testNormalSurchargeCalculation() {
        // Arrange
        Load__c load = new Load__c();
        load.Distance_Miles__c = 500;
        load.DAI_Price_At_Booking__c = 3.15; // Fixed DAI price
        
        // Act
        Decimal surcharge = FuelSurchargeCalculation.calculateFuelSurcharge(load);
        
        // Assert
        System.assertNotEquals(null, surcharge, 'Should calculate surcharge');
        System.assert(surcharge > 0, 'Surcharge should be positive');
    }
    
    @IsTest
    static void testZeroSurchargeWhenBelowBaseline() {
        // Arrange
        Load__c load = new Load__c();
        load.Distance_Miles__c = 500;
        load.DAI_Price_At_Booking__c = 2.00; // Below baseline of 2.50
        
        // Act
        Decimal surcharge = FuelSurchargeCalculation.calculateFuelSurcharge(load);
        
        // Assert
        System.assertEquals(0, surcharge, 'Should return 0 surcharge when DAI below baseline');
    }
    
    @IsTest
    static void testZeroSurchargeWhenNullDistance() {
        // Arrange
        Load__c load = new Load__c();
        load.Distance_Miles__c = null;
        load.DAI_Price_At_Booking__c = 3.15;
        
        // Act
        Decimal surcharge = FuelSurchargeCalculation.calculateFuelSurcharge(load);
        
        // Assert
        System.assertEquals(0, surcharge, 'Should return 0 when distance is null');
    }
    
    @IsTest
    static void testZeroSurchargeWhenZeroDistance() {
        // Arrange
        Load__c load = new Load__c();
        load.Distance_Miles__c = 0;
        load.DAI_Price_At_Booking__c = 3.15;
        
        // Act
        Decimal surcharge = FuelSurchargeCalculation.calculateFuelSurcharge(load);
        
        // Assert
        System.assertEquals(0, surcharge, 'Should return 0 when distance is 0');
    }
    
    @IsTest
    static void testSurchargeDetail() {
        // Arrange
        Load__c load = new Load__c();
        load.Distance_Miles__c = 500;
        load.DAI_Price_At_Booking__c = 3.15;
        
        // Act
        Map<String, Decimal> detail = FuelSurchargeCalculation.getSurchargeDetail(load);
        
        // Assert
        System.assertEquals(3.15, detail.get('daiPrice'));
        System.assertEquals(2.50, detail.get('baselinePrice'));
        System.assertEquals(0.65, detail.get('priceDifference'));
        System.assertEquals(500, detail.get('distance'));
    }
    
    @IsTest
    static void testLargeSurcharge() {
        // Arrange
        Load__c load = new Load__c();
        load.Distance_Miles__c = 1000; // Long distance
        load.DAI_Price_At_Booking__c = 5.00; // High DAI price
        
        // Act
        Decimal surcharge = FuelSurchargeCalculation.calculateFuelSurcharge(load);
        
        // Assert
        System.assert(surcharge > 300, 'Should calculate high surcharge for long distance + high DAI');
    }
    
    @IsTest
    static void testPrecisionAndRounding() {
        // Arrange
        Load__c load = new Load__c();
        load.Distance_Miles__c = 123.45;
        load.DAI_Price_At_Booking__c = 3.14159; // Lots of decimal places
        
        // Act
        Decimal surcharge = FuelSurchargeCalculation.calculateFuelSurcharge(load);
        
        // Assert
        // Should be rounded to 2 decimals
        System.assertEquals(2, surcharge.scale(), 'Should have exactly 2 decimal places');
    }
    
    @IsTest
    static void testValidateFuelSurcharge_Success() {
        // Arrange
        Load__c load = new Load__c();
        load.Fuel_Surcharge__c = 100.50;
        
        // Act & Assert (no exception)
        try {
            FuelSurchargeCalculation.validateFuelSurcharge(load);
        } catch (Exception e) {
            System.fail('Validation should pass for positive surcharge: ' + e.getMessage());
        }
    }
    
    @IsTest
    static void testValidateFuelSurcharge_NegativeValue() {
        // Arrange
        Load__c load = new Load__c();
        load.Fuel_Surcharge__c = -50;
        
        // Act & Assert
        try {
            FuelSurchargeCalculation.validateFuelSurcharge(load);
            System.fail('Should throw exception for negative surcharge');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('negative'));
        }
    }
    
    @IsTest
    static void testLockDAIPriceAtBooking() {
        // Arrange
        Load__c load = new Load__c();
        load.Distance_Miles__c = 500;
        // DAI_Price_At_Booking__c is null
        
        // Act
        FuelSurchargeCalculation.lockDAIPriceAtBooking(load);
        
        // Assert
        System.assertNotEquals(null, load.DAI_Price_At_Booking__c, 'Should lock DAI price at booking');
        System.assertEquals(3.15, load.DAI_Price_At_Booking__c, 'Should use Phase 1 DAI price');
    }
    
    @IsTest
    static void testLockDAIPriceAtBooking_AlreadyLocked() {
        // Arrange
        Load__c load = new Load__c();
        load.Distance_Miles__c = 500;
        load.DAI_Price_At_Booking__c = 2.99; // Already locked at different price
        
        // Act
        FuelSurchargeCalculation.lockDAIPriceAtBooking(load);
        
        // Assert
        System.assertEquals(2.99, load.DAI_Price_At_Booking__c, 'Should not overwrite existing price');
    }
}
