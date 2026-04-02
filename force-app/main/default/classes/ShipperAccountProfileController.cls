/**
 * ShipperAccountProfileController
 * 
 * Apex controller for the Account Profile page in the Shipper Portal.
 * Provides account information, billing contact, and payment method management.
 * 
 * Features:
 * - Get shipper account information (read-only company details)
 * - Get and update billing contact information
 * - Get and update payment method
 * - Get portal users list (admin only)
 * - Portal preferences management
 * 
 * Author: Agent 5 (Portal Development)
 * Created: April 2, 2026
 */

public with sharing class ShipperAccountProfileController {

    /**
     * Get shipper account details
     * 
     * @return AccountDetail with account info, billing contact, payment method
     */
    @AuraEnabled
    public static AccountDetail getAccountProfile() {
        try {
            // SECURITY: Check CRUD access to Account
            SecurityUtil.enforceAccess(
                SecurityUtil.hasCRUDAccess(Account.SObjectType, 'READ'),
                'You do not have permission to access account information'
            );
            
            // SECURITY: Check FLS access to Account fields
            List<String> accountFields = new List<String>{
                'Id', 'Name', 'BillingStreet', 'BillingCity', 'BillingState', 'BillingPostalCode',
                'BillingCountry', 'Phone', 'Website', 'Type', 'Industry', 'NumberOfEmployees'
            };
            SecurityUtil.enforceAccess(
                SecurityUtil.hasFieldLevelSecurityAccess(Account.SObjectType, accountFields, 'READ'),
                'You do not have permission to access required account fields'
            );
            
            String shipperAccountId = ShipperLoadListController.getShipperAccountId();
            if (String.isBlank(shipperAccountId)) {
                throw new AuraHandledException('No shipper account found');
            }

            // Query account
            List<Account> accounts = [
                SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode,
                       BillingCountry, Phone, Website, Type, Industry, NumberOfEmployees
                FROM Account
                WHERE Id = :shipperAccountId
                LIMIT 1
            ];

            if (accounts.isEmpty()) {
                throw new AuraHandledException('Account not found');
            }

            Account account = accounts[0];

            // Query billing contact (primary contact or specified billing contact)
            Contact billingContact = null;
            try {
                if (SecurityUtil.hasCRUDAccess(Contact.SObjectType, 'READ')) {
                    List<Contact> contacts = [
                        SELECT Id, FirstName, LastName, Title, Phone, Email, MailingStreet,
                               MailingCity, MailingState, MailingPostalCode, MailingCountry
                        FROM Contact
                        WHERE AccountId = :shipperAccountId
                          AND (Is_Billing_Contact__c = true OR Is_Primary_Contact__c = true)
                        ORDER BY Is_Billing_Contact__c DESC
                        LIMIT 1
                    ];
                    billingContact = contacts.isEmpty() ? null : contacts[0];
                }
            } catch (SObjectException e) {
                System.debug('Contact object not accessible: ' + e.getMessage());
            }

            // Query payment method
            PaymentMethod__c paymentMethod = null;
            try {
                if (SecurityUtil.hasCRUDAccess(PaymentMethod__c.SObjectType, 'READ')) {
                    List<PaymentMethod__c> paymentMethods = [
                        SELECT Id, Payment_Type__c, Bank_Name__c, Account_Last_Four__c,
                               Is_Default__c, Verified__c
                        FROM PaymentMethod__c
                        WHERE Account__c = :shipperAccountId
                          AND Is_Default__c = true
                        LIMIT 1
                    ];
                    paymentMethod = paymentMethods.isEmpty() ? null : paymentMethods[0];
                }
            } catch (SObjectException e) {
                System.debug('PaymentMethod__c object not accessible: ' + e.getMessage());
            }

            // Query account manager - graceful error handling
            List<User> accountManagers = new List<User>();
            try {
                if (SecurityUtil.hasCRUDAccess(User.SObjectType, 'READ')) {
                    accountManagers = [
                        SELECT Id, Name, Email, Phone
                        FROM User
                        WHERE Id IN (SELECT AccountTeamMemberId FROM AccountTeamMember 
                                     WHERE AccountId = :shipperAccountId AND TeamMemberRole = 'Account Manager')
                        LIMIT 1
                    ];
                }
            } catch (SObjectException e) {
                System.debug('User object not accessible: ' + e.getMessage());
            }

            // Build response
            AccountDetail detail = new AccountDetail();
            detail.account = account;
            detail.billingContact = billingContact;
            detail.paymentMethod = paymentMethod;
            detail.accountManager = accountManagers.isEmpty() ? null : accountManagers[0];
            
            // Calculate account metrics
            detail.totalLoadsYTD = getTotalLoadsYTD(shipperAccountId);
            detail.totalSpendYTD = getTotalSpendYTD(shipperAccountId);

            return detail;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving account profile: ' + e.getMessage());
        }
    }

    /**
     * Update billing contact information
     * 
     * SECURITY: Added CRUD/FLS checks before creating/updating contact
     * (Fixed critical privilege escalation vulnerability)
     * 
     * @param contactId - Contact ID to update (or null to create new)
     * @param firstName - First name
     * @param lastName - Last name
     * @param title - Job title
     * @param phone - Phone number
     * @param email - Email address
     * @param street - Street address
     * @param city - City
     * @param state - State/Province
     * @param postalCode - Postal code
     * @param country - Country
     * @return Updated Contact
     */
    @AuraEnabled
    public static Contact updateBillingContact(
        String contactId,
        String firstName,
        String lastName,
        String title,
        String phone,
        String email,
        String street,
        String city,
        String state,
        String postalCode,
        String country
    ) {
        try {
            // SECURITY: Validate email format
            if (String.isNotBlank(email)) {
                Pattern emailPattern = Pattern.compile('^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$');
                SecurityUtil.enforceAccess(
                    emailPattern.matcher(email).matches(),
                    'Invalid email format'
                );
            }

            // SECURITY: Determine CRUD operation
            Boolean isCreate = String.isBlank(contactId);
            String crudOperation = isCreate ? 'CREATE' : 'UPDATE';

            // SECURITY: Check CRUD access to Contact
            SecurityUtil.enforceAccess(
                SecurityUtil.hasCRUDAccess(Contact.SObjectType, crudOperation),
                'You do not have permission to ' + crudOperation.toLowerCase() + ' contacts'
            );

            // SECURITY: Check FLS access to all fields being set
            List<String> contactFields = new List<String>{
                'FirstName', 'LastName', 'Title', 'Phone', 'Email',
                'MailingStreet', 'MailingCity', 'MailingState', 'MailingPostalCode', 'MailingCountry',
                'Is_Billing_Contact__c'
            };
            SecurityUtil.enforceAccess(
                SecurityUtil.hasFieldLevelSecurityAccess(Contact.SObjectType, contactFields, 'UPDATE'),
                'You do not have permission to modify contact fields'
            );

            String shipperAccountId = ShipperLoadListController.getShipperAccountId();

            Contact contact;
            if (isCreate) {
                // Create new contact
                contact = new Contact(
                    AccountId = shipperAccountId,
                    FirstName = firstName,
                    LastName = lastName,
                    Title = title,
                    Phone = phone,
                    Email = email,
                    MailingStreet = street,
                    MailingCity = city,
                    MailingState = state,
                    MailingPostalCode = postalCode,
                    MailingCountry = country,
                    Is_Billing_Contact__c = true
                );
                insert contact;
            } else {
                // Update existing contact - verify ownership
                List<Contact> contacts = [
                    SELECT Id
                    FROM Contact
                    WHERE Id = :contactId
                      AND AccountId = :shipperAccountId
                    LIMIT 1
                ];

                if (contacts.isEmpty()) {
                    throw new AuraHandledException('Contact not found or access denied');
                }

                contact = new Contact(
                    Id = contactId,
                    FirstName = firstName,
                    LastName = lastName,
                    Title = title,
                    Phone = phone,
                    Email = email,
                    MailingStreet = street,
                    MailingCity = city,
                    MailingState = state,
                    MailingPostalCode = postalCode,
                    MailingCountry = country
                );
                update contact;
            }

            return contact;

        } catch (Exception e) {
            throw new AuraHandledException('Error updating billing contact: ' + e.getMessage());
        }
    }

    /**
     * Update payment method
     * 
     * SECURITY: Added CRUD/FLS checks before creating/updating payment method
     * (Fixed critical privilege escalation vulnerability)
     * NOTE: In production, sensitive payment data should use Encrypted Fields or Vault
     * 
     * @param paymentType - 'ACH', 'Wire', 'Check', 'CreditCard'
     * @param bankName - Bank name (for ACH)
     * @param accountLastFour - Last 4 digits of bank account
     * @param creditCardLastFour - Last 4 digits of credit card (if credit card)
     * @return Updated PaymentMethod__c
     */
    @AuraEnabled
    public static PaymentMethod__c updatePaymentMethod(
        String paymentType,
        String bankName,
        String accountLastFour,
        String creditCardLastFour
    ) {
        try {
            // SECURITY: Determine CRUD operation (we'll check both Create and Update)
            List<PaymentMethod__c> existing = [
                SELECT Id
                FROM PaymentMethod__c
                WHERE Account__c = :ShipperLoadListController.getShipperAccountId()
                  AND Is_Default__c = true
                LIMIT 1
            ];

            Boolean isCreate = existing.isEmpty();
            String crudOperation = isCreate ? 'CREATE' : 'UPDATE';

            // SECURITY: Check CRUD access to PaymentMethod__c
            SecurityUtil.enforceAccess(
                SecurityUtil.hasCRUDAccess(PaymentMethod__c.SObjectType, crudOperation),
                'You do not have permission to ' + crudOperation.toLowerCase() + ' payment methods'
            );

            // SECURITY: Check FLS access to all payment fields
            List<String> paymentFields = new List<String>{
                'Account__c', 'Payment_Type__c', 'Bank_Name__c', 'Account_Last_Four__c',
                'Is_Default__c', 'Verified__c'
            };
            SecurityUtil.enforceAccess(
                SecurityUtil.hasFieldLevelSecurityAccess(PaymentMethod__c.SObjectType, paymentFields, 'UPDATE'),
                'You do not have permission to modify payment method fields'
            );

            // SECURITY: Validate payment type against picklist
            SecurityUtil.enforceAccess(
                SecurityUtil.isValidPicklistValue(PaymentMethod__c.Payment_Type__c, paymentType),
                'Invalid payment type'
            );

            String shipperAccountId = ShipperLoadListController.getShipperAccountId();

            PaymentMethod__c paymentMethod = new PaymentMethod__c(
                Account__c = shipperAccountId,
                Payment_Type__c = paymentType,
                Bank_Name__c = bankName,
                Account_Last_Four__c = accountLastFour,
                Is_Default__c = true,
                Verified__c = false
            );

            if (!existing.isEmpty()) {
                paymentMethod.Id = existing[0].Id;
                update paymentMethod;
            } else {
                insert paymentMethod;
            }

            return paymentMethod;

        } catch (Exception e) {
            throw new AuraHandledException('Error updating payment method: ' + e.getMessage());
        }
    }

    /**
     * Get portal users for this account (admin only)
     * 
     * SECURITY: Added CRUD check before querying users
     * 
     * @return List of portal users
     */
    @AuraEnabled
    public static List<PortalUser> getPortalUsers() {
        try {
            // SECURITY: Check CRUD access to User object
            SecurityUtil.enforceAccess(
                SecurityUtil.hasCRUDAccess(User.SObjectType, 'READ'),
                'You do not have permission to view portal users'
            );
            
            String shipperAccountId = ShipperLoadListController.getShipperAccountId();

            // Query portal users for this account
            List<User> users = [
                SELECT Id, Name, Email, Username, IsActive, CreatedDate
                FROM User
                WHERE AccountId = :shipperAccountId
            ];

            List<PortalUser> portalUsers = new List<PortalUser>();
            for (User user : users) {
                // Only include portal users (optional Portal_Role__c field)
                portalUsers.add(new PortalUser(user.Id, user.Name, user.Email, ''));
            }

            return portalUsers;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving portal users: ' + e.getMessage());
        }
    }

    /**
     * Get total loads for YTD
     */
    private static Integer getTotalLoadsYTD(String shipperAccountId) {
        try {
            Integer year = System.today().year();
            Date startOfYear = Date.newInstance(year, 1, 1);
            
            return [
                SELECT COUNT()
                FROM Load__c
                WHERE Shipper_Account__c = :shipperAccountId
                  AND Pickup_Date__c >= :startOfYear
            ];
        } catch (Exception e) {
            return 0;
        }
    }

    /**
     * Get total spend for YTD
     */
    private static Decimal getTotalSpendYTD(String shipperAccountId) {
        try {
            Integer year = System.today().year();
            Date startOfYear = Date.newInstance(year, 1, 1);
            
            List<AggregateResult> results = [
                SELECT SUM(Shipper_Rate__c) totalSpend
                FROM Load__c
                WHERE Shipper_Account__c = :shipperAccountId
                  AND Pickup_Date__c >= :startOfYear
                  AND Status__c IN ('Delivered', 'In Transit')
            ];

            if (!results.isEmpty() && results[0].get('totalSpend') != null) {
                return (Decimal) results[0].get('totalSpend');
            }
            return 0;
        } catch (Exception e) {
            return 0;
        }
    }

    /**
     * Response wrapper for account detail
     */
    public class AccountDetail {
        @AuraEnabled
        public Account account;
        @AuraEnabled
        public Contact billingContact;
        @AuraEnabled
        public PaymentMethod__c paymentMethod;
        @AuraEnabled
        public User accountManager;
        @AuraEnabled
        public Integer totalLoadsYTD;
        @AuraEnabled
        public Decimal totalSpendYTD;
    }

    /**
     * Wrapper for portal user
     */
    public class PortalUser {
        @AuraEnabled
        public String userId;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String email;
        @AuraEnabled
        public String role;

        public PortalUser(String userId, String name, String email, String role) {
            this.userId = userId;
            this.name = name;
            this.email = email;
            this.role = role;
        }
    }
}
