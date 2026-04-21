/**
 * LoadsmartPostbackBatch
 * 
 * Scheduled Batch: Sync all "Assigned" loads to Loadsmart nightly
 * Extracted from LoadsmartPostback as top-level class (inner classes can't implement Database.Batchable)
 */
public with sharing class LoadsmartPostbackBatch implements Database.Batchable<SObject>, Schedulable {
    
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new LoadsmartPostbackBatch(), 10);
    }
    
    public Database.QueryLocator start(Database.BatchableContext ctx) {
        return Database.getQueryLocator([
            SELECT Id 
            FROM Load__c 
            WHERE Status__c IN ('Assigned', 'Confirmed') 
            AND Loadsmart_Synced__c = false
            ORDER BY CreatedDate DESC
        ]);
    }
    
    public void execute(Database.BatchableContext ctx, List<Load__c> loads) {
        LoadsmartPostback postback = new LoadsmartPostback();
        for (Load__c load : loads) {
            postback.syncLoadToLoadsmart(load.Id);
        }
    }
    
    public void finish(Database.BatchableContext ctx) {
        System.debug('LoadsmartPostbackBatch completed');
    }
}
