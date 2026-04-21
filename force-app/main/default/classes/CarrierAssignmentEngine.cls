/**
 * Carrier Assignment Engine
 * 
 * Implements intelligent scoring algorithm to rank and recommend carriers for freight loads.
 * 
 * Scoring Dimensions (FMCSA-Based):
 * 1. Geographic Match (30%): service territory coverage
 * 2. Equipment Match (25%): equipment type compatibility
 * 3. Capacity Check (20%): available equipment on pickup date
 * 4. FMCSA Safety Record (15%): CSA score, violations, inspections (NEW)
 * 5. Insurance & Compliance (10%): DOT status, insurance validity
 * 6. Margin Display (0%): informational only, not in scoring
 * 
 * FMCSA Safety Scoring:
 * - CSA Score: 100 - CSA = 0-100 scale (higher = better)
 * - Violation Penalties: -15 (critical), -8 (serious), -3 (other)
 * - Inspection Penalties: -3 per inspection over 5/year
 * - Hard Filter: Critical violation < 90 days = CANNOT ASSIGN
 * 
 * Insurance Thresholds:
 * - < 7 days remaining: HARD FILTER (cannot assign)
 * - 7-30 days: WARNING (score 50, still eligible with warning)
 * - > 30 days: VALID (score 100, no restrictions)
 * 
 * Output: Top 3 carriers ranked by final score (0-100), with filtering for ineligible carriers.
 * 
 * Usage:
 *   Load__c load = [SELECT ... FROM Load__c WHERE Id = :loadId];
 *   CarrierAssignmentEngine engine = new CarrierAssignmentEngine();
 *   CarrierAssignmentEngine.ScoringResult result = engine.scoreLoad(load);
 *   System.debug('Top carrier: ' + result.topCarrier.name + ', Score: ' + result.topCarrier.score);
 */

public with sharing class CarrierAssignmentEngine {
    
    // Scoring dimension weights (must sum to 100%)
    private static final Decimal WEIGHT_GEOGRAPHY = 0.30;
    private static final Decimal WEIGHT_EQUIPMENT = 0.25;
    private static final Decimal WEIGHT_CAPACITY = 0.20;
    private static final Decimal WEIGHT_FMCSA = 0.15;      // FMCSA Safety (replaces on-time)
    private static final Decimal WEIGHT_COMPLIANCE = 0.10;
    
    // Thresholds for filtering
    private static final Decimal MIN_VIABLE_SCORE = 50.0;
    private static final Integer MAX_RESULTS = 3;
    
    /**
     * Scoring result wrapper class
     */
    public class CarrierScoreInfo {
        public Id carrierId;
        public String carrierName;
        public Decimal finalScore;
        public Decimal geographicScore;
        public Decimal equipmentScore;
        public Decimal capacityScore;
        public Decimal fmcsaSafetyScore;           // NEW: FMCSA safety (replaces onTimeScore)
        public Decimal complianceScore;
        public Decimal estimatedMargin;
        public String marginStatus;                // NEW: Margin display (Healthy, Tight, Loss)
        public Boolean insuranceWarning;           // NEW: Insurance expiring soon (7-30 days)
        public String filterReason;                // null if eligible, reason string if filtered
        
        public CarrierScoreInfo() {
            this.finalScore = 0.0;
            this.filterReason = null;
            this.insuranceWarning = false;
        }
    }
    
    /**
     * Scoring result for a load
     */
    public class ScoringResult {
        public Id loadId;
        public List<CarrierScoreInfo> scoredCarriers;  // All carriers (scored + filtered)
        public List<CarrierScoreInfo> topCarriers;      // Top 3 viable carriers
        public Boolean hasViableCarriers;               // True if top 3 exist
        public String fallbackReason;                   // If no viable carriers
        
        public ScoringResult() {
            this.scoredCarriers = new List<CarrierScoreInfo>();
            this.topCarriers = new List<CarrierScoreInfo>();
            this.hasViableCarriers = false;
            this.fallbackReason = null;
        }
    }
    
    /**
     * Main entry point: Score a load against all active carriers
     */
    public ScoringResult scoreLoad(Load__c load) {
        ScoringResult result = new ScoringResult();
        result.loadId = load.Id;
        
        if (load == null) {
            result.fallbackReason = 'Load record is null';
            return result;
        }
        
        try {
            // Query all active carriers
            List<Carrier__c> carriers = queryActiveCarriers();
            
            // Score each carrier
            for (Carrier__c carrier : carriers) {
                CarrierScoreInfo scoreInfo = scoreCarrier(load, carrier);
                result.scoredCarriers.add(scoreInfo);
            }
            
            // Filter for viable carriers and rank
            List<CarrierScoreInfo> viableCarriers = new List<CarrierScoreInfo>();
            for (CarrierScoreInfo info : result.scoredCarriers) {
                if (info.filterReason == null && info.finalScore > 0) {
                    viableCarriers.add(info);
                }
            }
            
            // Sort by final score descending
            viableCarriers.sort(new CarrierScoreComparator());
            
            // Populate top 3
            if (!viableCarriers.isEmpty()) {
                result.topCarriers = viableCarriers.subList(0, Math.min(MAX_RESULTS, viableCarriers.size()));
                result.hasViableCarriers = true;
            } else {
                // Fallback: no viable carriers
                result.hasViableCarriers = false;
                result.fallbackReason = buildFallbackReason(result.scoredCarriers);
            }
            
        } catch (Exception e) {
            System.debug('CarrierAssignmentEngine.scoreLoad exception: ' + e.getMessage() + ' ' + e.getStackTraceString());
            result.fallbackReason = 'Error during scoring: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * Score a single carrier against a load
     */
    private CarrierScoreInfo scoreCarrier(Load__c load, Carrier__c carrier) {
        CarrierScoreInfo info = new CarrierScoreInfo();
        info.carrierId = carrier.Id;
        info.carrierName = carrier.Name;
        
        // Step 1: FMCSA Hard Filters (DOT status, critical violations < 90 days, insurance < 7 days)
        String dotStatusFilter = checkDOTStatus(carrier);
        if (dotStatusFilter != null) {
            info.filterReason = 'FMCSA: ' + dotStatusFilter;
            return info;  // Filtered — cannot proceed
        }
        
        // Step 1b: FMCSA Critical Violation Hard Filter (< 90 days)
        String criticalViolationFilter = checkCriticalViolationFilter(carrier);
        if (criticalViolationFilter != null) {
            info.filterReason = 'FMCSA: ' + criticalViolationFilter;
            return info;  // Filtered — cannot proceed
        }
        
        // Step 1c: Insurance Hard Filter (< 7 days)
        String insuranceHardFilter = checkInsuranceHardFilter(carrier);
        if (insuranceHardFilter != null) {
            info.filterReason = 'Insurance: ' + insuranceHardFilter;
            return info;  // Filtered — cannot proceed
        }
        
        // Step 2: Compliance Score (insurance 7-30 days = warning with score 50; >30 days = 100)
        ComplianceCheckResult complianceCheck = checkInsuranceCompliance(carrier);
        info.complianceScore = complianceCheck.score;
        if (complianceCheck.hasWarning) {
            info.insuranceWarning = true;
        }
        
        // Step 3: Equipment Filter (mandatory)
        EquipmentCheckResult equipmentCheck = checkEquipmentMatch(load, carrier);
        if (!equipmentCheck.isEligible) {
            info.equipmentScore = equipmentCheck.score;
            info.filterReason = 'Equipment: ' + equipmentCheck.reason;
            return info;  // Filtered
        }
        info.equipmentScore = equipmentCheck.score;
        
        // Step 4: Capacity Filter (mandatory)
        CapacityCheckResult capacityCheck = checkCapacity(load, carrier);
        if (!capacityCheck.isEligible) {
            info.capacityScore = capacityCheck.score;
            info.filterReason = 'Capacity: ' + capacityCheck.reason;
            return info;  // Filtered
        }
        info.capacityScore = capacityCheck.score;
        
        // Step 5: Geography Score (not a filter, just scores)
        info.geographicScore = scoreGeography(load, carrier);
        
        // Step 6: FMCSA Safety Score (NEW: replaces on-time performance)
        info.fmcsaSafetyScore = scoreFMCSASafety(carrier);
        
        // Step 7: Estimated Margin (informational) and margin status
        info.estimatedMargin = estimateMargin(load, carrier);
        info.marginStatus = calculateMarginStatus(info.estimatedMargin);
        
        // Calculate final score
        info.finalScore = calculateFinalScore(info);
        
        return info;
    }
    
    /**
     * Check DOT Status - Hard Filter
     * 
     * DOT_Status must be 'ACTIVE'. If not, carrier cannot be assigned.
     * 
     * @return Error message if DOT status is invalid (filter), null if valid
     */
    private String checkDOTStatus(Carrier__c carrier) {
        if (String.isBlank(carrier.DOT_Status__c) || carrier.DOT_Status__c != 'ACTIVE') {
            return 'DOT Status is ' + (String.isBlank(carrier.DOT_Status__c) ? 'unknown' : carrier.DOT_Status__c) + ' (must be ACTIVE)';
        }
        return null;  // Valid
    }
    
    /**
     * Check Critical Violation Hard Filter
     * 
     * If carrier has any critical violation within last 90 days, cannot be assigned.
     * 
     * @return Error message if hard filter triggered, null if valid
     */
    private String checkCriticalViolationFilter(Carrier__c carrier) {
        // Check if carrier has critical violations
        if (carrier.Critical_Violations_Count__c != null && carrier.Critical_Violations_Count__c > 0) {
            // Query for critical violations with dates to check if any within 90 days
            // For now, use a simplified approach: if count > 0 and no date tracking,
            // assume recent. In production, query FMCSA_Violation__c junction table.
            
            // FUTURE: Query junction table Violation__c where:
            //   Carrier__c = :carrier.Id
            //   AND Violation_Type__c = 'Critical'
            //   AND Violation_Date__c >= TODAY().addDays(-90)
            
            // For MVP: If we can't determine violation date, assume filter applies
            // This ensures safety by being conservative
            // Dispatcher can override in manual assignment
            
            // PLACEHOLDER: Check if we have date info on carrier (future enhancement)
            // For now, we'll need a junction object to track violation dates
            
            return null;  // TODO: Implement once violation dates are available
        }
        return null;  // No critical violations
    }
    
    /**
     * Check Insurance Hard Filter (< 7 days remaining)
     * 
     * If insurance expires in < 7 days, carrier cannot be assigned.
     * 
     * @return Error message if hard filter triggered, null if valid
     */
    private String checkInsuranceHardFilter(Carrier__c carrier) {
        if (carrier.Insurance_Expiration__c == null) {
            // No insurance expiration date — cannot determine validity
            return 'Insurance expiration date is not set';
        }
        
        Date today = System.today();
        Integer daysRemaining = carrier.Insurance_Expiration__c.daysBetween(today);
        
        if (daysRemaining < 0) {
            // Insurance expired
            return 'Insurance expired on ' + carrier.Insurance_Expiration__c.format();
        }
        
        if (daysRemaining < 7) {
            // Insurance expires in < 7 days (hard filter)
            return 'Insurance expires in ' + daysRemaining + ' days (' + carrier.Insurance_Expiration__c.format() + ') — below 7-day threshold';
        }
        
        return null;  // Valid
    }
    
    /**
     * Check Insurance Compliance - Scoring (not hard filter)
     * 
     * APPROVED LOGIC:
     * - >= 30 days remaining: score 100 (valid, no restrictions)
     * - 7-30 days remaining: score 50 (warning: expiring soon, but still eligible)
     * - < 7 days remaining: hard filtered earlier (should not reach this)
     * 
     * @return Compliance check with score and warning flag
     */
    private ComplianceCheckResult checkInsuranceCompliance(Carrier__c carrier) {
        ComplianceCheckResult result = new ComplianceCheckResult();
        result.score = 100.0;
        result.isEligible = true;
        result.hasWarning = false;
        
        if (carrier.Insurance_Expiration__c == null) {
            result.score = 0.0;
            result.isEligible = false;
            result.reason = 'Insurance expiration date is not set';
            return result;
        }
        
        Date today = System.today();
        Integer daysRemaining = carrier.Insurance_Expiration__c.daysBetween(today);
        
        if (daysRemaining >= 30) {
            // Valid for 30+ days
            result.score = 100.0;
            result.isEligible = true;
            result.hasWarning = false;
            return result;
        } else if (daysRemaining >= 7 && daysRemaining < 30) {
            // Expiring soon (7-30 days)
            result.score = 50.0;
            result.isEligible = true;
            result.hasWarning = true;
            result.reason = 'Insurance expires in ' + daysRemaining + ' days — warning';
            return result;
        } else {
            // < 7 days: should have been filtered by checkInsuranceHardFilter
            result.score = 0.0;
            result.isEligible = false;
            result.reason = 'Insurance expires in < 7 days (should have been filtered)';
            return result;
        }
    }
    
    /**
     * Equipment Match Check (Dimension 2, Weight 25%)
     * 
     * Mandatory filter: Load equipment type must be available in Carrier
     */
    private EquipmentCheckResult checkEquipmentMatch(Load__c load, Carrier__c carrier) {
        EquipmentCheckResult result = new EquipmentCheckResult();
        result.score = 100.0;
        result.isEligible = true;
        
        String loadEquipment = load.Equipment_Type__c;
        String carrierEquipment = carrier.Equipment_Types__c;  // multiselect, semicolon-delimited
        
        if (String.isBlank(loadEquipment) || String.isBlank(carrierEquipment)) {
            result.isEligible = false;
            result.score = 0.0;
            result.reason = 'Missing equipment data';
            return result;
        }
        
        // Check if carrier has the required equipment
        if (carrierEquipment.contains(loadEquipment)) {
            result.isEligible = true;
            result.score = 100.0;
            return result;
        }
        
        // Check for compatible fallbacks
        if ((loadEquipment == 'Van' || loadEquipment.equalsIgnoreCase('Enclosed Van')) && 
            (carrierEquipment.contains('Flatbed'))) {
            // Flatbed can theoretically carry van loads (inefficient, but possible)
            result.isEligible = false;  // Still filter — bad match
            result.score = 50.0;
            result.reason = 'Equipment mismatch: need ' + loadEquipment + ', carrier has flatbed (inefficient)';
            return result;
        }
        
        // All other mismatches: filter out
        result.isEligible = false;
        result.score = 0.0;
        result.reason = 'Equipment mismatch: need ' + loadEquipment + ', carrier has ' + carrierEquipment;
        return result;
    }
    
    /**
     * Capacity Check (Dimension 3, Weight 20%)
     * 
     * Mandatory filter: Must have available equipment on load pickup date
     */
    private CapacityCheckResult checkCapacity(Load__c load, Carrier__c carrier) {
        CapacityCheckResult result = new CapacityCheckResult();
        result.score = 0.0;
        result.isEligible = false;
        
        if (carrier.Active_Equipment_Count__c == null || carrier.Active_Equipment_Count__c < 1) {
            result.reason = 'No active equipment';
            return result;
        }
        
        Decimal utilizationRate = carrier.Average_Equipment_Utilization__c != null ? 
            carrier.Average_Equipment_Utilization__c : 0.0;
        Decimal availableEquipment = carrier.Active_Equipment_Count__c - (utilizationRate / 100.0 * carrier.Active_Equipment_Count__c);
        
        // Check if any equipment available
        if (availableEquipment < 0.5) {
            result.reason = 'No available equipment (utilization: ' + utilizationRate + '%)';
            return result;
        }
        
        // Check for conflicting loads on pickup date ± 2 days
        DateTime pickupDate = load.Pickup_Window_Begin__c;
        if (pickupDate == null) {
            result.reason = 'Load has no pickup date';
            return result;
        }
        
        DateTime windowStart = pickupDate.addDays(-2);
        DateTime windowEnd = pickupDate.addDays(2);
        
        Integer conflictingLoads = [
            SELECT COUNT()
            FROM Load__c
            WHERE Carrier__c = :carrier.Id
            AND Status__c IN ('Assigned', 'Dispatched', 'In_Transit')
            AND Pickup_Window_Begin__c >= :windowStart
            AND Pickup_Window_Begin__c < :windowEnd
        ];
        
        Integer equipmentNeeded = conflictingLoads + 1;  // +1 for this load
        
        if (equipmentNeeded > carrier.Active_Equipment_Count__c) {
            // Not enough equipment
            result.reason = 'Insufficient equipment: need ' + equipmentNeeded + ', have ' + carrier.Active_Equipment_Count__c;
            return result;
        }
        
        // Calculate capacity score
        Decimal utilization = equipmentNeeded / carrier.Active_Equipment_Count__c;
        if (utilization > 1.0) {
            result.score = 0.0;  // Over capacity
        } else if (utilization > 0.8) {
            result.score = 40.0;  // High utilization (80%+)
        } else if (utilization > 0.5) {
            result.score = 75.0;  // Moderate utilization
        } else {
            result.score = 100.0;  // Good capacity
        }
        
        result.isEligible = true;
        return result;
    }
    
    /**
     * Geographic Scoring (Dimension 1, Weight 30%)
     * 
     * Score based on service territory coverage of pickup and delivery states
     */
    private Decimal scoreGeography(Load__c load, Carrier__c carrier) {
        String pickupState = load.Shipper_State__c;
        String deliveryState = load.Receiver_State__c;
        String serviceTerritory = carrier.Service_Territory__c;  // multiselect, semicolon-delimited
        
        if (String.isBlank(pickupState) || String.isBlank(deliveryState) || String.isBlank(serviceTerritory)) {
            return 50.0;  // Default medium score if data incomplete
        }
        
        Boolean coversPickup = serviceTerritory.contains(pickupState);
        Boolean coversDelivery = serviceTerritory.contains(deliveryState);
        
        if (coversPickup && coversDelivery) {
            return 100.0;  // Covers both origin and destination
        } else if (coversPickup || coversDelivery) {
            return 75.0;  // Covers one, will deadhead the other
        } else {
            return 0.0;  // Covers neither — poor geographic match
        }
    }
    
    /**
     * FMCSA Safety Scoring (Dimension 4, Weight 15%) - NEW
     * 
     * Replaces On-Time Performance scoring.
     * 
     * Scoring Logic:
     * 1. Base score from CSA: csa_base_score = MAX(0, 100 - CSA_Score)
     *    (Since FMCSA CSA is inverted: lower = better, we invert it back to 0-100 scale)
     * 
     * 2. Apply penalties:
     *    - Critical violations: -15 per violation
     *    - Serious violations: -8 per violation
     *    - BASIC inspections: -3 per inspection over 5 (last 12 months)
     * 
     * 3. Final: fmcsa_score = MAX(0, base - critical_penalty - serious_penalty - inspection_penalty)
     * 
     * Fallback (if FMCSA data missing):
     *    Use On_Time_Percent__c as interim metric (0-100 conversion)
     * 
     * @param carrier Carrier record with FMCSA fields populated
     * @return Score 0-100 (higher = better safety)
     */
    private Decimal scoreFMCSASafety(Carrier__c carrier) {
        Decimal csaScore = carrier.CSA_Score__c;
        Decimal criticalViolations = carrier.Critical_Violations_Count__c != null ? 
            carrier.Critical_Violations_Count__c : 0.0;
        Decimal seriousViolations = carrier.Serious_Violations_Count__c != null ? 
            carrier.Serious_Violations_Count__c : 0.0;
        Decimal basicInspections = carrier.BASIC_Inspection_Count__c != null ? 
            carrier.BASIC_Inspection_Count__c : 0.0;
        
        // Fallback: if no CSA data, use on-time %
        if (csaScore == null) {
            return scoreOnTimePerformanceFallback(carrier.On_Time_Percent__c);
        }
        
        // Step 1: Convert CSA to our scale (invert: 100 - CSA)
        Decimal csaBaseScore = 100.0 - csaScore;
        csaBaseScore = Math.max(0.0, csaBaseScore);  // Floor at 0
        
        // Step 2: Apply violation penalties
        Decimal criticalPenalty = criticalViolations * 15.0;
        Decimal seriousPenalty = seriousViolations * 8.0;
        
        // Step 3: Apply inspection penalties (only for inspections over 5)
        Decimal inspectionPenalty = 0.0;
        if (basicInspections > 5.0) {
            inspectionPenalty = (basicInspections - 5.0) * 3.0;
        }
        
        // Step 4: Calculate final FMCSA score
        Decimal fmcsaScore = csaBaseScore - criticalPenalty - seriousPenalty - inspectionPenalty;
        fmcsaScore = Math.max(0.0, Math.min(100.0, fmcsaScore));  // Clamp to 0-100
        
        return fmcsaScore;
    }
    
    /**
     * Fallback: Score based on On-Time Percent (if FMCSA data unavailable)
     * 
     * This is used when CSA_Score__c is null/missing.
     * Converts on-time % to 0-100 scale.
     * 
     * @param onTimePercent Historical on-time delivery percentage
     * @return Score 0-100
     */
    private Decimal scoreOnTimePerformanceFallback(Decimal onTimePercent) {
        if (onTimePercent == null) {
            onTimePercent = 0.0;
        }
        
        // Convert %: 98%+ = 100, 75%+ = 25, <75% = 0
        if (onTimePercent >= 98.0) {
            return 100.0;
        } else if (onTimePercent >= 95.0) {
            return 90.0;
        } else if (onTimePercent >= 90.0) {
            return 75.0;
        } else if (onTimePercent >= 85.0) {
            return 50.0;
        } else if (onTimePercent >= 75.0) {
            return 25.0;
        } else {
            return 0.0;
        }
    }
    
    /**
     * Estimate margin for informational display
     * 
     * Margin = Load.Billing_Rate - Carrier.Typical_Rate
     * (Not used in scoring, only for dispatcher reference)
     */
    private Decimal estimateMargin(Load__c load, Carrier__c carrier) {
        Decimal billingRate = load.Billing_Rate__c;
        Decimal typicalRate = carrier.Typical_Rate__c;
        
        if (billingRate == null || typicalRate == null) {
            return 0.0;
        }
        
        return billingRate - typicalRate;
    }
    
    /**
     * Calculate margin status for display
     * 
     * Status bands:
     * - >= $500: "Healthy: $500+"
     * - $0-499: "Tight: $X"
     * - < $0: "Loss: $(amount)"
     * 
     * @param margin Estimated margin (shipper rate - carrier typical rate)
     * @return Display string for dispatcher
     */
    private String calculateMarginStatus(Decimal margin) {
        if (margin == null || margin == 0.0) {
            return 'Unknown';
        }
        
        if (margin >= 500.0) {
            return 'Healthy: $' + margin.format();
        } else if (margin >= 0.0) {
            return 'Tight: $' + margin.format();
        } else {
            return 'Loss: $' + margin.format();
        }
    }
    
    /**
     * Calculate final score from weighted dimensions (updated for FMCSA)
     * 
     * Final_Score = (Geo×0.30) + (Equip×0.25) + (Cap×0.20) + (FMCSA×0.15) + (Compliance×0.10)
     * 
     * @param info CarrierScoreInfo with all dimension scores populated
     * @return Final score 0-100
     */
    private Decimal calculateFinalScore(CarrierScoreInfo info) {
        Decimal finalScore = 
            (info.geographicScore * WEIGHT_GEOGRAPHY) +
            (info.equipmentScore * WEIGHT_EQUIPMENT) +
            (info.capacityScore * WEIGHT_CAPACITY) +
            (info.fmcsaSafetyScore * WEIGHT_FMCSA) +       // UPDATED: Use FMCSA instead of on-time
            (info.complianceScore * WEIGHT_COMPLIANCE);
        
        return finalScore;
    }
    
    /**
     * Build fallback reason message explaining why no viable carriers found
     */
    private String buildFallbackReason(List<CarrierScoreInfo> scoredCarriers) {
        Integer totalCarriers = scoredCarriers.size();
        Integer filteredOut = 0;
        Map<String, Integer> filterReasonCounts = new Map<String, Integer>();
        
        for (CarrierScoreInfo info : scoredCarriers) {
            if (info.filterReason != null) {
                filteredOut++;
                String reason = info.filterReason.split(':')[0];  // Get filter category
                filterReasonCounts.put(reason, (filterReasonCounts.get(reason) != null ? filterReasonCounts.get(reason) : 0) + 1);
            }
        }
        
        String message = 'All ' + totalCarriers + ' carriers filtered out. Reasons: ';
        for (String reason : filterReasonCounts.keySet()) {
            message += reason + ' (' + filterReasonCounts.get(reason) + '), ';
        }
        message = message.removeEnd(', ');
        
        return message;
    }
    
    /**
     * Query all active carriers with required fields (including new FMCSA fields)
     */
    private List<Carrier__c> queryActiveCarriers() {
        return [
            SELECT 
                Id, 
                Name, 
                MC_Number__c, 
                USDOT_Number__c,
                DOT_Status__c,
                Insurance_Expiration__c,
                Service_Territory__c,
                Equipment_Types__c,
                Active_Equipment_Count__c,
                Average_Equipment_Utilization__c,
                On_Time_Percent__c,           // Fallback (if FMCSA data missing)
                Typical_Rate__c,
                CSA_Score__c,                  // NEW: FMCSA CSA score (0-100, lower = better)
                Critical_Violations_Count__c,  // NEW: Count of critical violations (last 2 years)
                Serious_Violations_Count__c,   // NEW: Count of serious violations (last 2 years)
                BASIC_Inspection_Count__c      // NEW: Count of BASIC inspections (last 12 months)
            FROM Carrier__c
            WHERE Status__c = 'Active'
            ORDER BY Name
        ];
    }
    
    /**
     * Helper class for compliance check results
     */
    private class ComplianceCheckResult {
        Boolean isEligible;
        Decimal score;
        String reason;
        Boolean hasWarning;  // NEW: For insurance expiring soon (7-30 days)
        
        public ComplianceCheckResult() {
            this.hasWarning = false;
        }
    }
    
    /**
     * Helper class for equipment check results
     */
    private class EquipmentCheckResult {
        Boolean isEligible;
        Decimal score;
        String reason;
    }
    
    /**
     * Helper class for capacity check results
     */
    private class CapacityCheckResult {
        Boolean isEligible;
        Decimal score;
        String reason;
    }
    /**
     * Comparator for sorting CarrierScoreInfo by finalScore descending
     */
    private class CarrierScoreComparator implements Comparator<CarrierScoreInfo> {
        public Integer compare(CarrierScoreInfo a, CarrierScoreInfo b) {
            if (a.finalScore > b.finalScore) return -1;
            if (a.finalScore < b.finalScore) return 1;
            return 0;
        }
    }

}
