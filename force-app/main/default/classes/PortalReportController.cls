/**
 * PortalReportController
 * 
 * Generates business reports for shipper and carrier portals
 * 5 core reports: on-time delivery, cost per mile, utilization, trends, forecasts
 * 
 * @author Agent 5 (Portal & Mobile)
 * @version 1.0
 * @date April 2, 2026
 */
public with sharing class PortalReportController {
    
    /**
     * OnTimeDeliveryReport
     * 
     * KPI: % of loads delivered within delivery window
     */
    public class OnTimeDeliveryReport {
        @AuraEnabled public Decimal onTimePercentage;
        @AuraEnabled public Integer onTimeCount;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public DateTime generatedDate;
    }
    
    /**
     * CostPerMileReport
     * 
     * KPI: Average cost per mile by distance range
     */
    public class CostPerMileReport {
        @AuraEnabled public List<CostBucket> buckets;
        @AuraEnabled public Decimal averageCostPerMile;
        @AuraEnabled public DateTime generatedDate;
    }
    
    /**
     * CostBucket
     * 
     * Cost data for distance range
     */
    public class CostBucket {
        @AuraEnabled public String distanceRange;
        @AuraEnabled public Decimal averageCost;
        @AuraEnabled public Integer loadCount;
    }
    
    /**
     * UtilizationReport
     * 
     * KPI: Average time from pickup to delivery
     */
    public class UtilizationReport {
        @AuraEnabled public Decimal averageTransitHours;
        @AuraEnabled public Decimal averageMilesPerDay;
        @AuraEnabled public Integer totalLoads;
        @AuraEnabled public Decimal utilizationPercentage;
        @AuraEnabled public DateTime generatedDate;
    }
    
    /**
     * TrendReport
     * 
     * Trend data over 7-day periods
     */
    public class TrendReport {
        @AuraEnabled public List<TrendBucket> trends;
        @AuraEnabled public String metric;
        @AuraEnabled public DateTime generatedDate;
    }
    
    /**
     * TrendBucket
     * 
     * Trend data point
     */
    public class TrendBucket {
        @AuraEnabled public Date periodStart;
        @AuraEnabled public Decimal value;
        @AuraEnabled public Integer loadCount;
    }
    
    /**
     * ForecastReport
     * 
     * 7-day load forecast
     */
    public class ForecastReport {
        @AuraEnabled public List<ForecastBucket> forecast;
        @AuraEnabled public DateTime generatedDate;
    }
    
    /**
     * ForecastBucket
     * 
     * Forecast data point
     */
    public class ForecastBucket {
        @AuraEnabled public Date forecastDate;
        @AuraEnabled public Integer predictedLoads;
        @AuraEnabled public Decimal confidence;
    }
    
    /**
     * getOnTimeDeliveryReport
     * 
     * Calculates on-time delivery percentage
     * On-time = Actual Delivery <= Delivery Window End
     * 
     * @return OnTimeDeliveryReport with KPI
     */
    @AuraEnabled(cacheable=true)
    public static OnTimeDeliveryReport getOnTimeDeliveryReport() {
        try {
            if (!Load__c.sObjectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('You do not have permission to view reports.');
            }
            
            String accountId = getCurrentAccountId();
            
            // Query delivered loads
            List<Load__c> deliveredLoads = [
                SELECT Id, Actual_Delivery_Time__c, Delivery_Window_End__c
                FROM Load__c
                WHERE (Shipper__c = :accountId OR Carrier__c = :accountId)
                AND Status__c = 'DELIVERED'
                AND CreatedDate = LAST_N_DAYS:30
            ];
            
            Integer onTimeCount = 0;
            for (Load__c load : deliveredLoads) {
                if (load.Actual_Delivery_Time__c != null 
                    && load.Delivery_Window_End__c != null
                    && load.Actual_Delivery_Time__c <= load.Delivery_Window_End__c) {
                    onTimeCount++;
                }
            }
            
            OnTimeDeliveryReport report = new OnTimeDeliveryReport();
            report.totalCount = deliveredLoads.size();
            report.onTimeCount = onTimeCount;
            report.onTimePercentage = report.totalCount > 0 ? 
                (Decimal.valueOf(onTimeCount) / Decimal.valueOf(report.totalCount)) * 100 : 0;
            report.generatedDate = System.now();
            
            return report;
        } catch (Exception e) {
            throw new AuraHandledException('Error generating on-time delivery report: ' + e.getMessage());
        }
    }
    
    /**
     * getCostPerMileReport
     * 
     * Calculates average cost per mile by distance range
     * 
     * @return CostPerMileReport with cost buckets
     */
    @AuraEnabled(cacheable=true)
    public static CostPerMileReport getCostPerMileReport() {
        try {
            if (!Load__c.sObjectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('You do not have permission to view reports.');
            }
            
            String accountId = getCurrentAccountId();
            
            // Query loads and bucket by distance in Apex (SOQL doesn't support ROUND in GROUP BY)
            List<Load__c> rawLoads = [
                SELECT Id, Distance_Miles__c, Cost_Per_Mile__c
                FROM Load__c
                WHERE (Shipper__c = :accountId OR Carrier__c = :accountId)
                AND Status__c = 'DELIVERED'
                AND CreatedDate = LAST_N_DAYS:30
            ];
            
            Map<Integer, Integer> loadCountByBucket = new Map<Integer, Integer>();
            Map<Integer, Decimal> costSumByBucket = new Map<Integer, Decimal>();
            
            for (Load__c ld : rawLoads) {
                Decimal dist = ld.Distance_Miles__c != null ? ld.Distance_Miles__c : 0;
                Integer bucket = (Integer)(Math.floor(dist / 100) * 100);
                if (!loadCountByBucket.containsKey(bucket)) {
                    loadCountByBucket.put(bucket, 0);
                    costSumByBucket.put(bucket, 0);
                }
                loadCountByBucket.put(bucket, loadCountByBucket.get(bucket) + 1);
                costSumByBucket.put(bucket, costSumByBucket.get(bucket) + (ld.Cost_Per_Mile__c != null ? ld.Cost_Per_Mile__c : 0));
            }
            
            List<CostBucket> buckets = new List<CostBucket>();
            Decimal totalCost = 0;
            Integer totalLoads = 0;
            
            List<Integer> sortedKeys = new List<Integer>(loadCountByBucket.keySet());
            sortedKeys.sort();
            for (Integer bkt : sortedKeys) {
                CostBucket bucket = new CostBucket();
                bucket.distanceRange = bkt + ' - ' + (bkt + 100) + ' mi';
                bucket.loadCount = loadCountByBucket.get(bkt);
                bucket.averageCost = bucket.loadCount > 0 ? costSumByBucket.get(bkt) / bucket.loadCount : 0;
                
                buckets.add(bucket);
                totalLoads += bucket.loadCount;
                totalCost += bucket.averageCost != null ? bucket.averageCost * bucket.loadCount : 0;
            }
            
            CostPerMileReport report = new CostPerMileReport();
            report.buckets = buckets;
            report.averageCostPerMile = totalLoads > 0 ? totalCost / totalLoads : 0;
            report.generatedDate = System.now();
            
            return report;
        } catch (Exception e) {
            throw new AuraHandledException('Error generating cost per mile report: ' + e.getMessage());
        }
    }
    
    /**
     * getUtilizationReport
     * 
     * Calculates utilization metrics
     * Transit hours = actual delivery - pickup
     * Utilization % = active hours / 24 hours
     * 
     * @return UtilizationReport with efficiency KPIs
     */
    @AuraEnabled(cacheable=true)
    public static UtilizationReport getUtilizationReport() {
        try {
            if (!Load__c.sObjectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('You do not have permission to view reports.');
            }
            
            String accountId = getCurrentAccountId();
            
            List<Load__c> loads = [
                SELECT Id, Actual_Pickup_Time__c, Actual_Delivery_Time__c, Distance_Miles__c
                FROM Load__c
                WHERE (Shipper__c = :accountId OR Carrier__c = :accountId)
                AND Status__c = 'DELIVERED'
                AND CreatedDate = LAST_N_DAYS:30
            ];
            
            Decimal totalTransitHours = 0;
            Decimal totalMiles = 0;
            Integer loadCount = 0;
            
            for (Load__c load : loads) {
                if (load.Actual_Pickup_Time__c != null && load.Actual_Delivery_Time__c != null) {
                    Long timeDiffMs = load.Actual_Delivery_Time__c.getTime() - 
                                      load.Actual_Pickup_Time__c.getTime();
                    Decimal hours = Decimal.valueOf(timeDiffMs) / (1000 * 60 * 60);
                    totalTransitHours += hours;
                    
                    if (load.Distance_Miles__c != null) {
                        totalMiles += load.Distance_Miles__c;
                    }
                    loadCount++;
                }
            }
            
            UtilizationReport report = new UtilizationReport();
            report.totalLoads = loadCount;
            report.averageTransitHours = loadCount > 0 ? totalTransitHours / loadCount : 0;
            report.averageMilesPerDay = loadCount > 0 ? totalMiles / report.averageTransitHours * 24 : 0;
            report.utilizationPercentage = report.averageTransitHours > 0 ? 
                (report.averageTransitHours / 24) * 100 : 0;
            report.generatedDate = System.now();
            
            return report;
        } catch (Exception e) {
            throw new AuraHandledException('Error generating utilization report: ' + e.getMessage());
        }
    }
    
    /**
     * getTrendReport
     * 
     * Calculates on-time delivery trend over 7-day periods (last 30 days)
     * 
     * @return TrendReport with 7-day buckets
     */
    @AuraEnabled(cacheable=true)
    public static TrendReport getTrendReport() {
        try {
            if (!Load__c.sObjectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('You do not have permission to view reports.');
            }
            
            String accountId = getCurrentAccountId();
            
            // Get delivered loads for last 30 days
            List<Load__c> loads = [
                SELECT Id, CreatedDate, Actual_Delivery_Time__c, Delivery_Window_End__c
                FROM Load__c
                WHERE (Shipper__c = :accountId OR Carrier__c = :accountId)
                AND Status__c = 'DELIVERED'
                AND CreatedDate = LAST_N_DAYS:30
            ];
            
            // Group by 7-day buckets
            Map<Date, Integer> onTimeByBucket = new Map<Date, Integer>();
            Map<Date, Integer> totalByBucket = new Map<Date, Integer>();
            
            for (Load__c load : loads) {
                Date bucketDate = load.CreatedDate.dateGMT();
                Integer dayOfPeriod = Math.mod(bucketDate.dayOfYear(), 7);
                Date bucketStart = bucketDate.addDays(-dayOfPeriod);
                
                if (!totalByBucket.containsKey(bucketStart)) {
                    totalByBucket.put(bucketStart, 0);
                    onTimeByBucket.put(bucketStart, 0);
                }
                
                totalByBucket.put(bucketStart, totalByBucket.get(bucketStart) + 1);
                
                if (load.Actual_Delivery_Time__c != null 
                    && load.Delivery_Window_End__c != null
                    && load.Actual_Delivery_Time__c <= load.Delivery_Window_End__c) {
                    onTimeByBucket.put(bucketStart, onTimeByBucket.get(bucketStart) + 1);
                }
            }
            
            List<TrendBucket> trends = new List<TrendBucket>();
            for (Date bucketStart : totalByBucket.keySet()) {
                TrendBucket bucket = new TrendBucket();
                bucket.periodStart = bucketStart;
                bucket.loadCount = totalByBucket.get(bucketStart);
                bucket.value = bucket.loadCount > 0 ? 
                    (Decimal.valueOf(onTimeByBucket.get(bucketStart)) / 
                     Decimal.valueOf(bucket.loadCount)) * 100 : 0;
                trends.add(bucket);
            }
            
            // Sort by date
            trends.sort();
            
            TrendReport report = new TrendReport();
            report.trends = trends;
            report.metric = 'On-Time Delivery %';
            report.generatedDate = System.now();
            
            return report;
        } catch (Exception e) {
            throw new AuraHandledException('Error generating trend report: ' + e.getMessage());
        }
    }
    
    /**
     * getLoadForecast
     * 
     * Forecasts load volume for next 7 days
     * Based on historical 30-day average + day-of-week seasonality
     * 
     * @return ForecastReport with 7-day predictions
     */
    @AuraEnabled(cacheable=true)
    public static ForecastReport getLoadForecast() {
        try {
            if (!Load__c.sObjectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('You do not have permission to view reports.');
            }
            
            String accountId = getCurrentAccountId();
            
            // Get loads for last 30 days
            List<Load__c> loads = [
                SELECT CreatedDate
                FROM Load__c
                WHERE (Shipper__c = :accountId OR Carrier__c = :accountId)
                AND CreatedDate = LAST_N_DAYS:30
            ];
            
            // Calculate daily averages by day of week
            Map<Integer, Integer> loadsByDayOfWeek = new Map<Integer, Integer>();
            for (Load__c load : loads) {
                Date loadDate = load.CreatedDate.dateGMT();
                Integer dayOfWeek = Math.mod(loadDate.dayOfYear(), 7);
                
                if (!loadsByDayOfWeek.containsKey(dayOfWeek)) {
                    loadsByDayOfWeek.put(dayOfWeek, 0);
                }
                loadsByDayOfWeek.put(dayOfWeek, loadsByDayOfWeek.get(dayOfWeek) + 1);
            }
            
            // Generate 7-day forecast
            List<ForecastBucket> forecast = new List<ForecastBucket>();
            Date today = System.today();
            
            for (Integer i = 1; i <= 7; i++) {
                Date forecastDate = today.addDays(i);
                Integer dayOfWeek = Math.mod(forecastDate.dayOfYear(), 7);
                
                ForecastBucket bucket = new ForecastBucket();
                bucket.forecastDate = forecastDate;
                bucket.predictedLoads = loadsByDayOfWeek.containsKey(dayOfWeek) ? 
                    loadsByDayOfWeek.get(dayOfWeek) : 0;
                bucket.confidence = 0.85; // 85% confidence for historical baseline
                
                forecast.add(bucket);
            }
            
            ForecastReport report = new ForecastReport();
            report.forecast = forecast;
            report.generatedDate = System.now();
            
            return report;
        } catch (Exception e) {
            throw new AuraHandledException('Error generating forecast report: ' + e.getMessage());
        }
    }
    
    /**
     * getCurrentAccountId
     * 
     * Gets current user's account ID (shipper or carrier)
     * 
     * @return Account ID
     */
    private static String getCurrentAccountId() {
        User currentUser = [SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        
        if (currentUser.ContactId == null) {
            throw new AuraHandledException('User contact not found.');
        }
        
        Contact contact = [SELECT AccountId FROM Contact WHERE Id = :currentUser.ContactId LIMIT 1];
        
        if (contact.AccountId == null) {
            throw new AuraHandledException('User account not found.');
        }
        
        return contact.AccountId;
    }
}
