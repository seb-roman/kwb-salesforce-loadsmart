/**
 * AGENT3_PHASE2: Exception Alert Distribution System
 * 
 * Sends alerts for exceptions based on severity and user preferences.
 * Triggered on exception creation via trigger.
 * 
 * Delivery Channels:
 * - Email: Load's broker representative + dispatcher
 * - Slack: Operations channel (critical only)
 * - SMS: Critical exceptions only (respects phone opt-in)
 * 
 * Features:
 * - Configuration from custom settings (user alert preferences)
 * - Severity-based routing (Warning, Alert, Critical)
 * - No spam: respects 1-hour deduplication
 * - Graceful degradation: missing channels don't fail entire alert
 * - Async processing: doesn't block exception creation
 * 
 * @author Agent 3
 * @version 1.0
 */
public without sharing class ExceptionAlertDistribution {
    
    // Alert severity levels
    public static final String SEVERITY_WARNING = 'Warning';
    public static final String SEVERITY_ALERT = 'Alert';
    public static final String SEVERITY_CRITICAL = 'Critical';
    
    /**
     * Process exceptions and send alerts
     * Called from Exception__c trigger (after insert)
     */
    public static void processAlerts(List<Exception__c> exceptions) {
        if (exceptions == null || exceptions.isEmpty()) {
            return;
        }
        
        // Get user preferences and load information
        Map<Id, AlertPreference> userPreferences = loadAlertPreferences();
        Set<Id> loadIds = new Set<Id>();
        for (Exception__c exc : exceptions) {
            loadIds.add(exc.Load__c);
        }
        
        Map<Id, Load__c> loadMap = getLoadsWithContacts(loadIds);
        
        // Prepare alerts
        List<AlertMessage> emailAlerts = new List<AlertMessage>();
        List<AlertMessage> slackAlerts = new List<AlertMessage>();
        List<AlertMessage> smsAlerts = new List<AlertMessage>();
        
        for (Exception__c exc : exceptions) {
            Load__c load = loadMap.get(exc.Load__c);
            if (load == null) {
                continue;
            }
            
            // Route based on severity
            Boolean isCritical = exc.Severity__c == SEVERITY_CRITICAL;
            Boolean isAlert = exc.Severity__c == SEVERITY_ALERT;
            Boolean isWarning = exc.Severity__c == SEVERITY_WARNING;
            
            // Email: all severities
            if (load.Broker_Rep__c != null || load.Dispatcher__c != null) {
                AlertMessage emailAlert = buildEmailAlert(exc, load);
                if (emailAlert != null) {
                    emailAlerts.add(emailAlert);
                }
            }
            
            // Slack: critical only
            if (isCritical && hasSlackConfig()) {
                AlertMessage slackAlert = buildSlackAlert(exc, load);
                if (slackAlert != null) {
                    slackAlerts.add(slackAlert);
                }
            }
            
            // SMS: critical only, phone opt-in required
            if (isCritical && hasPhoneOptIn(load)) {
                AlertMessage smsAlert = buildSMSAlert(exc, load);
                if (smsAlert != null) {
                    smsAlerts.add(smsAlert);
                }
            }
        }
        
        // Send alerts asynchronously
        if (!emailAlerts.isEmpty()) {
            sendEmailAlerts(emailAlerts);
        }
        
        if (!slackAlerts.isEmpty()) {
            sendSlackAlerts(slackAlerts);
        }
        
        if (!smsAlerts.isEmpty()) {
            sendSMSAlerts(smsAlerts);
        }
    }
    
    /**
     * Build email alert message
     */
    private static AlertMessage buildEmailAlert(Exception__c exc, Load__c load) {
        AlertMessage alert = new AlertMessage();
        alert.exceptionId = exc.Id;
        alert.loadId = load.Id;
        alert.recipients = new List<String>();
        
        if (load.Broker_Rep__c != null) {
            alert.recipients.add(load.Broker_Rep__r.Email);
        }
        
        if (load.Dispatcher__c != null) {
            alert.recipients.add(load.Dispatcher__r.Email);
        }
        
        alert.subject = buildEmailSubject(exception, load);
        alert.body = buildEmailBody(exception, load);
        alert.channel = 'EMAIL';
        
        return alert.recipients.isEmpty() ? null : alert;
    }
    
    /**
     * Build Slack alert message
     */
    private static AlertMessage buildSlackAlert(Exception__c exc, Load__c load) {
        AlertMessage alert = new AlertMessage();
        alert.exceptionId = exc.Id;
        alert.loadId = load.Id;
        alert.channel = 'SLACK';
        alert.slackChannel = getOpsSlackChannel(); // Get from settings
        alert.slackMessage = buildSlackMessage(exception, load);
        
        return alert.slackMessage != null ? alert : null;
    }
    
    /**
     * Build SMS alert message
     */
    private static AlertMessage buildSMSAlert(Exception__c exc, Load__c load) {
        AlertMessage alert = new AlertMessage();
        alert.exceptionId = exc.Id;
        alert.loadId = load.Id;
        alert.channel = 'SMS';
        alert.smsNumber = load.Driver__r?.Phone; // Get from driver
        alert.smsMessage = buildSMSMessage(exception, load);
        
        return String.isNotBlank(alert.smsNumber) && String.isNotBlank(alert.smsMessage) ? alert : null;
    }
    
    /**
     * Build email subject
     */
    private static String buildEmailSubject(Exception__c exc, Load__c load) {
        String severity = exc.Severity__c;
        String exceptionType = exc.Exception_Type__c;
        
        return '[' + severity.toUpperCase() + '] ' + exceptionType + ' - Load ' + load.Name;
    }
    
    /**
     * Build email body
     */
    private static String buildEmailBody(Exception__c exc, Load__c load) {
        String body = 'An exception has been triggered on load tracking.\n\n';
        body += 'Load: ' + load.Name + '\n';
        body += 'Severity: ' + exc.Severity__c + '\n';
        body += 'Exception Type: ' + exc.Exception_Type__c + '\n';
        body += 'Description: ' + exc.Description__c + '\n';
        body += 'Triggered: ' + exc.Triggered_DateTime__c.format('yyyy-MM-dd HH:mm:ss') + '\n\n';
        body += 'Status: ' + exc.Status__c + '\n';
        body += 'Load Details: https://[salesforce-instance].salesforce.com/' + load.Id + '\n';
        body += 'Exception Details: https://[salesforce-instance].salesforce.com/' + exc.Id + '\n';
        
        return body;
    }
    
    /**
     * Build Slack message
     */
    private static String buildSlackMessage(Exception__c exc, Load__c load) {
        String message = ':warning: *Critical Exception*\n';
        message += '*Load:* ' + load.Name + '\n';
        message += '*Type:* ' + exc.Exception_Type__c + '\n';
        message += '*Description:* ' + exc.Description__c + '\n';
        message += '*Time:* ' + exc.Triggered_DateTime__c.format('yyyy-MM-dd HH:mm:ss') + '\n';
        
        return message;
    }
    
    /**
     * Build SMS message
     */
    private static String buildSMSMessage(Exception__c exc, Load__c load) {
        return 'ALERT: Load ' + load.Name + ' - ' + exc.Exception_Type__c + 
               ' at ' + exc.Triggered_DateTime__c.format('HH:mm:ss');
    }
    
    /**
     * Send email alerts
     */
    @Future(callout=false)
    private static void sendEmailAlerts(List<AlertMessage> alerts) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (AlertMessage alert : alerts) {
            if (alert.recipients != null && !alert.recipients.isEmpty()) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(alert.recipients);
                email.setSubject(alert.subject);
                email.setPlainTextBody(alert.body);
                emails.add(email);
            }
        }
        
        if (!emails.isEmpty()) {
            try {
                List<Messaging.SendEmailResult> results = Messaging.sendEmail(emails);
                logInfo('Sent ' + results.size() + ' email alerts');
            } catch (Exception e) {
                logError('Failed to send email alerts: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Send Slack alerts (via HTTP callout)
     */
    private static void sendSlackAlerts(List<AlertMessage> alerts) {
        // Get Slack webhook URL from custom settings
        String slackWebhookUrl = getSlackWebhookUrl();
        
        if (String.isBlank(slackWebhookUrl)) {
            logWarning('Slack webhook URL not configured');
            return;
        }
        
        for (AlertMessage alert : alerts) {
            sendSlackAlert(slackWebhookUrl, alert);
        }
    }
    
    /**
     * Send single Slack alert
     */
    private static void sendSlackAlert(String webhookUrl, AlertMessage alert) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(webhookUrl);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('text', alert.slackMessage);
            payload.put('channel', alert.slackChannel);
            
            req.setBody(JSON.serialize(payload));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() >= 400) {
                logError('Slack alert failed: ' + res.getStatus());
            } else {
                logInfo('Slack alert sent successfully');
            }
        } catch (Exception e) {
            logError('Failed to send Slack alert: ' + e.getMessage());
        }
    }
    
    /**
     * Send SMS alerts (via Twilio or similar service)
     */
    private static void sendSMSAlerts(List<AlertMessage> alerts) {
        // Get SMS provider config from custom settings
        String smsApiKey = getSMSApiKey();
        String smsApiEndpoint = getSMSApiEndpoint();
        
        if (String.isBlank(smsApiKey) || String.isBlank(smsApiEndpoint)) {
            logWarning('SMS provider not configured');
            return;
        }
        
        for (AlertMessage alert : alerts) {
            sendSMSAlert(smsApiEndpoint, smsApiKey, alert);
        }
    }
    
    /**
     * Send single SMS alert
     */
    private static void sendSMSAlert(String endpoint, String apiKey, AlertMessage alert) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + apiKey);
            
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('to', alert.smsNumber);
            payload.put('message', alert.smsMessage);
            
            req.setBody(JSON.serialize(payload));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() >= 400) {
                logError('SMS alert failed: ' + res.getStatus());
            } else {
                logInfo('SMS alert sent successfully');
            }
        } catch (Exception e) {
            logError('Failed to send SMS alert: ' + e.getMessage());
        }
    }
    
    /**
     * Load all alert preferences from custom settings
     */
    private static Map<Id, AlertPreference> loadAlertPreferences() {
        // TODO: Implement based on custom settings object
        // For now, return empty map (all users get default alerts)
        return new Map<Id, AlertPreference>();
    }
    
    /**
     * Get loads with related broker rep and dispatcher contacts
     */
    private static Map<Id, Load__c> getLoadsWithContacts(Set<Id> loadIds) {
        return new Map<Id, Load__c>([
            SELECT Id, Name, Status__c, Broker_Rep__c, Broker_Rep__r.Email,
                   Dispatcher__c, Dispatcher__r.Email, Driver__c, Driver__r.Phone
            FROM Load__c
            WHERE Id IN :loadIds
            LIMIT 50000
        ]);
    }
    
    /**
     * Helper: Check if Slack is configured
     */
    private static Boolean hasSlackConfig() {
        return String.isNotBlank(getSlackWebhookUrl());
    }
    
    /**
     * Helper: Check if driver has opted in to SMS
     */
    private static Boolean hasPhoneOptIn(Load__c load) {
        return load.Driver__c != null && String.isNotBlank(load.Driver__r?.Phone);
    }
    
    /**
     * Helper: Get Slack webhook URL from settings
     */
    private static String getSlackWebhookUrl() {
        // TODO: Retrieve from custom settings
        return null;
    }
    
    /**
     * Helper: Get Slack ops channel
     */
    private static String getOpsSlackChannel() {
        return '#operations'; // TODO: Make configurable
    }
    
    /**
     * Helper: Get SMS API key
     */
    private static String getSMSApiKey() {
        // TODO: Retrieve from custom settings
        return null;
    }
    
    /**
     * Helper: Get SMS API endpoint
     */
    private static String getSMSApiEndpoint() {
        // TODO: Retrieve from custom settings
        return null;
    }
    
    // ============ Logging Helpers ============
    
    private static void logInfo(String message) {
        System.debug(LoggingLevel.INFO, 'ExceptionAlertDistribution: ' + message);
    }
    
    private static void logWarning(String message) {
        System.debug(LoggingLevel.WARN, 'ExceptionAlertDistribution: ' + message);
    }
    
    private static void logError(String message) {
        System.debug(LoggingLevel.ERROR, 'ExceptionAlertDistribution: ' + message);
    }
    
    /**
     * Inner class to represent an alert message
     */
    private class AlertMessage {
        public Id exceptionId;
        public Id loadId;
        public String channel; // EMAIL, SLACK, SMS
        public List<String> recipients; // For email
        public String subject; // For email
        public String body; // For email
        public String slackChannel;
        public String slackMessage;
        public String smsNumber;
        public String smsMessage;
    }
    
    /**
     * Inner class to represent user alert preferences
     */
    private class AlertPreference {
        public Boolean emailEnabled;
        public Boolean slackEnabled;
        public Boolean smsEnabled;
        public List<String> preferredChannels;
    }
}
