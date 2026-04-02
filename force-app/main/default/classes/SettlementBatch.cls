/**
 * SettlementBatch.cls
 * 
 * Scheduled batch job that consolidates loads into weekly carrier settlements
 * Runs: Monday 1 AM ET
 * Process: Groups paid loads by carrier, calculates deductions, creates Settlement__c
 * 
 * @author Agent 4
 * @version 1.0
 */
public class SettlementBatch implements Database.Batchable<SObject>, Schedulable {
    
    private DateTime weekStart;
    private DateTime weekEnd;
    
    /**
     * Constructor - sets settlement week boundaries
     */
    public SettlementBatch() {
        // Calculate last Monday (start of settlement week)
        Date today = Date.today();
        Integer dayOfWeek = today.daysBetween(today.toStartOfWeek());
        // dayOfWeek: 0=Sunday, 1=Monday, ... 6=Saturday
        Integer daysBack = dayOfWeek == 0 ? 6 : dayOfWeek - 1;
        Date lastMonday = today.addDays(-daysBack);
        
        this.weekStart = DateTime.newInstance(lastMonday.year(), lastMonday.month(), lastMonday.day(), 0, 0, 0);
        this.weekEnd = weekStart.addDays(7);
    }
    
    /**
     * Schedulable context - execute the batch
     */
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(this, 100);
    }
    
    /**
     * Batch start - query loads for settlement
     */
    public Database.QueryLocator start(Database.BatchableContext ctx) {
        String query = 'SELECT Id, Name, Assigned_Carrier__c, Carrier_Rate__c, ' +
                       'Invoice_Status__c, Settlement_Status__c, CreatedDate ' +
                       'FROM Load__c ' +
                       'WHERE Invoice_Status__c = \'Invoiced\' ' +
                       'AND Settlement_Status__c = \'Not_Settled\' ' +
                       'AND CreatedDate >= ' + formatDateTimeForSOQL(weekStart) + ' ' +
                       'AND CreatedDate < ' + formatDateTimeForSOQL(weekEnd) + ' ' +
                       'ORDER BY Assigned_Carrier__c ASC';
        return Database.getQueryLocator(query);
    }
    
    /**
     * Batch execute - process loads in batches
     */
    public void execute(Database.BatchableContext ctx, List<Load__c> loads) {
        if (loads.isEmpty()) {
            return;
        }
        
        // Group loads by carrier
        Map<Id, List<Load__c>> loadsByCarrier = new Map<Id, List<Load__c>>();
        Set<Id> carrierIds = new Set<Id>();
        
        for (Load__c load : loads) {
            if (load.Assigned_Carrier__c != null) {
                if (!loadsByCarrier.containsKey(load.Assigned_Carrier__c)) {
                    loadsByCarrier.put(load.Assigned_Carrier__c, new List<Load__c>());
                }
                loadsByCarrier.get(load.Assigned_Carrier__c).add(load);
                carrierIds.add(load.Assigned_Carrier__c);
            }
        }
        
        // Check for existing settlements (prevent duplicates)
        Set<Id> carriersWithSettlements = new Set<Id>();
        List<Settlement__c> existingSettlements = [
            SELECT Carrier__c FROM Settlement__c
            WHERE Carrier__c IN :carrierIds
            AND Settlement_Period_Start__c = :weekStart.date()
            AND Settlement_Status__c IN ('Pending', 'Approved', 'Paid')
        ];
        
        for (Settlement__c settlement : existingSettlements) {
            carriersWithSettlements.add(settlement.Carrier__c);
        }
        
        // Create settlements for each carrier
        List<Settlement__c> settlementsToCreate = new List<Settlement__c>();
        List<Load__c> loadsToUpdate = new List<Load__c>();
        
        for (Id carrierId : loadsByCarrier.keySet()) {
            // Skip if settlement already exists for this period
            if (carriersWithSettlements.contains(carrierId)) {
                continue;
            }
            
            List<Load__c> carrierLoads = loadsByCarrier.get(carrierId);
            
            Settlement__c settlement = createCarrierSettlement(carrierId, carrierLoads);
            if (settlement != null) {
                settlementsToCreate.add(settlement);
                
                // Mark loads as pending settlement
                for (Load__c load : carrierLoads) {
                    load.Settlement_Status__c = 'Pending';
                    loadsToUpdate.add(load);
                }
            }
        }
        
        // Insert settlements and update loads
        try {
            if (!settlementsToCreate.isEmpty()) {
                insert settlementsToCreate;
            }
            if (!loadsToUpdate.isEmpty()) {
                update loadsToUpdate;
            }
        } catch (Exception e) {
            System.debug('Error creating settlements: ' + e.getMessage());
        }
    }
    
    /**
     * Batch finish - generate report and CSV export
     */
    public void finish(Database.BatchableContext ctx) {
        try {
            // Query all settlements created in this batch
            List<Settlement__c> settlements = [
                SELECT Id, Name, Carrier__c, Carrier__r.Name, Gross_Amount__c, 
                       Deductions__c, Net_Payment__c, Settlement_Status__c
                FROM Settlement__c
                WHERE Settlement_Period_Start__c = :weekStart.date()
                ORDER BY Carrier__r.Name ASC
            ];
            
            if (!settlements.isEmpty()) {
                // Generate CSV export
                String csvContent = generateSettlementCSV(settlements);
                
                // TODO: Send email to AP team with CSV attachment
                sendSettlementReport(settlements, csvContent);
            }
            
        } catch (Exception e) {
            System.debug('Error in batch finish: ' + e.getMessage());
        }
    }
    
    /**
     * Create settlement record for a carrier
     */
    private Settlement__c createCarrierSettlement(Id carrierId, List<Load__c> loads) {
        try {
            Settlement__c settlement = new Settlement__c();
            settlement.Carrier__c = carrierId;
            settlement.Settlement_Period_Start__c = weekStart.date();
            settlement.Settlement_Period_End__c = weekStart.date().addDays(6);
            
            // Calculate gross amount (sum of carrier rates)
            Decimal grossAmount = 0;
            for (Load__c load : loads) {
                if (load.Carrier_Rate__c != null) {
                    grossAmount += load.Carrier_Rate__c;
                }
            }
            settlement.Gross_Amount__c = grossAmount;
            
            // Calculate deductions
            Decimal deductions = calculateDeductions(carrierId);
            settlement.Deductions__c = deductions;
            
            // Calculate net payment
            settlement.Net_Payment__c = (grossAmount - deductions).setScale(2, RoundingMode.HALF_UP);
            
            // Set status
            settlement.Settlement_Status__c = 'Pending';
            
            return settlement;
            
        } catch (Exception e) {
            System.debug('Error creating settlement: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Calculate deductions (claims, advances, etc.)
     * Phase 1: Returns 0 (placeholder)
     * Phase 2: Will integrate with Claim__c and CarrierAdvance__c objects
     */
    private Decimal calculateDeductions(Id carrierId) {
        try {
            Decimal deductions = 0;
            
            // TODO: Phase 2 - Query claims
            // try {
            //     List<Claim__c> claims = [
            //         SELECT Amount__c FROM Claim__c
            //         WHERE Carrier__c = :carrierId
            //         AND Status__c = 'Open'
            //     ];
            //     for (Claim__c claim : claims) {
            //         deductions += claim.Amount__c;
            //     }
            // } catch (Exception e) {
            //     System.debug('Claims object not available yet');
            // }
            
            // TODO: Phase 2 - Query advances
            // try {
            //     List<CarrierAdvance__c> advances = [
            //         SELECT Outstanding_Balance__c FROM CarrierAdvance__c
            //         WHERE Carrier__c = :carrierId
            //         AND Outstanding_Balance__c > 0
            //     ];
            //     for (CarrierAdvance__c adv : advances) {
            //         deductions += adv.Outstanding_Balance__c;
            //     }
            // } catch (Exception e) {
            //     System.debug('CarrierAdvance object not available yet');
            // }
            
            return deductions.setScale(2, RoundingMode.HALF_UP);
            
        } catch (Exception e) {
            System.debug('Error calculating deductions: ' + e.getMessage());
            return 0;
        }
    }
    
    /**
     * Generate CSV export for settlement
     */
    private String generateSettlementCSV(List<Settlement__c> settlements) {
        StringBuilder csv = new StringBuilder();
        csv.append('Carrier,Settlement Period,Gross Amount,Deductions,Net Payment\n');
        
        for (Settlement__c settlement : settlements) {
            csv.append(settlement.Carrier__r.Name).append(',');
            csv.append(settlement.Settlement_Period_Start__c).append(',');
            csv.append(settlement.Gross_Amount__c).append(',');
            csv.append(settlement.Deductions__c).append(',');
            csv.append(settlement.Net_Payment__c).append('\n');
        }
        
        return csv.toString();
    }
    
    /**
     * Send settlement report to AP team
     */
    private void sendSettlementReport(List<Settlement__c> settlements, String csvContent) {
        try {
            // TODO: Get email from custom setting
            String apEmail = 'ap@kwblogistics.com';
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { apEmail });
            email.setSubject('Weekly Settlement Report - ' + Date.today());
            email.setPlainTextBody('Weekly settlement batch complete. ' + settlements.size() + ' carriers processed.');
            
            // TODO: Attach CSV file
            
            // Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            
        } catch (Exception e) {
            System.debug('Error sending settlement report: ' + e.getMessage());
        }
    }
    
    /**
     * Format DateTime for SOQL query
     */
    private String formatDateTimeForSOQL(DateTime dt) {
        return dt.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
}
