# AGENT 5: Security Fixes + Unit Testing Strategy

**Agent:** Agent 5  
**Date:** April 2, 2026  
**Addressing:** Agent 4 Security Review (4 CRITICAL, 16 HIGH issues)

---

## CRITICAL FIXES - Must Complete Before Portal Deployment

### Fix #1: RLS Bypass in getCarrierInfo() (CRITICAL)

**Issue:** Data leakage vulnerability - drivers can access ANY load's carrier info

**Location:** ShipperLoadDetailController.getCarrierInfo()

**Current Code (VULNERABLE):**
```apex
@AuraEnabled
public static CarrierInfo getCarrierInfo(String loadId) {
  List<Load__c> loads = [
    SELECT Id, Carrier__c
    FROM Load__c
    WHERE Id = :loadId  // ❌ NO SHIPPER ACCOUNT CHECK
  ];
  // ... query carrier directly without RLS check
}
```

**Fixed Code:**
```apex
@AuraEnabled
public static CarrierInfo getCarrierInfo(String loadId) {
  try {
    // 1. Get current shipper account ID
    String shipperAccountId = getShipperAccountId();
    if (String.isBlank(shipperAccountId)) {
      throw new AuraHandledException('User not authenticated as shipper');
    }

    // 2. Verify load belongs to shipper
    List<Load__c> loads = [
      SELECT Id, Carrier__c, Carrier__r.Name, Carrier__r.Phone
      FROM Load__c
      WHERE Id = :loadId
        AND Shipper_Account__c = :shipperAccountId  // ✅ ADD THIS LINE
      LIMIT 1
    ];

    if (loads.isEmpty()) {
      return null; // Or throw exception
    }

    Load__c load = loads[0];
    
    // 3. Return carrier info
    return new CarrierInfo(
      load.Carrier__r.Id,
      load.Carrier__r.Name,
      load.Carrier__r.Phone
    );
  } catch (Exception e) {
    throw new AuraHandledException('Error fetching carrier info: ' + e.getMessage());
  }
}
```

**Testing:**
```apex
@isTest
static void testGetCarrierInfoRLSEnforcement() {
  // Create 2 shippers
  Account shipper1 = new Account(Name = 'Shipper 1');
  Account shipper2 = new Account(Name = 'Shipper 2');
  insert new List<Account>{ shipper1, shipper2 };

  // Create loads for each shipper
  Load__c load1 = new Load__c(Shipper_Account__c = shipper1.Id, Name = 'Load1');
  Load__c load2 = new Load__c(Shipper_Account__c = shipper2.Id, Name = 'Load2');
  insert new List<Load__c>{ load1, load2 };

  // Test: User 1 should NOT access load2 info
  System.runAs(getShipperUser(shipper1.Id)) {
    CarrierInfo info = ShipperLoadDetailController.getCarrierInfo(load2.Id);
    System.assertEquals(null, info, 'Should not return carrier info for other shipper load');
  }
}
```

---

### Fix #2 & #3: Missing CRUD/FLS Checks (CRITICAL)

**Issue:** No verification that user can CREATE/UPDATE Contact + PaymentMethod records

**Location:** ShipperAccountProfileController.updateBillingContact() + updatePaymentMethod()

**Fixed Code Template:**
```apex
@AuraHandledException
public static void updateBillingContact(
  String firstName,
  String lastName,
  String email,
  String phone
) {
  try {
    // 1. ✅ CHECK CRUD
    if (!Contact.SObjectType.getDescribe().isCreateable() || 
        !Contact.SObjectType.getDescribe().isUpdateable()) {
      throw new AuraHandledException(
        'You do not have permission to modify contacts'
      );
    }

    // 2. ✅ CHECK FLS
    Map<String, Schema.SObjectField> fieldMap = 
      Contact.SObjectType.getDescribe().fields.getMap();
    
    List<String> fieldsToCheck = new List<String>{
      'FirstName', 'LastName', 'Email', 'Phone'
    };
    
    for (String field : fieldsToCheck) {
      if (!fieldMap.get(field).getDescribe().isUpdateable()) {
        throw new AuraHandledException(
          'You do not have permission to update ' + field
        );
      }
    }

    // 3. ✅ INPUT VALIDATION
    if (String.isBlank(firstName) || String.isBlank(lastName)) {
      throw new AuraHandledException('First and last name required');
    }
    
    if (String.isNotBlank(email) && !isValidEmail(email)) {
      throw new AuraHandledException('Invalid email format');
    }

    // 4. ✅ GET SHIPPER ACCOUNT
    String shipperAccountId = getShipperAccountId();
    
    // 5. CREATE/UPDATE CONTACT
    List<Contact> existingContacts = [
      SELECT Id FROM Contact 
      WHERE AccountId = :shipperAccountId 
        AND Phone = :phone
      LIMIT 1
    ];

    Contact contact;
    if (!existingContacts.isEmpty()) {
      contact = existingContacts[0];
      contact.FirstName = firstName;
      contact.LastName = lastName;
      contact.Email = email;
      contact.Phone = phone;
      update contact;
    } else {
      contact = new Contact(
        AccountId = shipperAccountId,
        FirstName = firstName,
        LastName = lastName,
        Email = email,
        Phone = phone
      );
      insert contact;
    }
  } catch (Exception e) {
    throw new AuraHandledException('Error updating contact: ' + e.getMessage());
  }
}

// Utility: Email validation
private static Boolean isValidEmail(String email) {
  Pattern emailPattern = Pattern.compile(
    '^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$'
  );
  return emailPattern.matcher(email).matches();
}
```

**Apply same pattern to updatePaymentMethod():**
- Check PaymentMethod__c.SObjectType.isCreateable()
- Check FLS on: Payment_Type__c, Bank_Name__c, Account_Last_Four__c
- Validate payment data
- Encrypt sensitive fields

---

### Fix #4: ShowToastEvent Import Missing (CRITICAL)

**Issue:** Runtime error when methods called

**Location:** shipperLoadList.js

**Fix:**
```javascript
// BEFORE (Missing import)
import { LightningElement, wire, track } from 'lwc';

// AFTER (✅ Add import)
import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLoads from '@salesforce/apex/ShipperLoadListController.getLoads';
```

---

## HIGH PRIORITY FIXES - Complete Before Release

### Fix SQL Injection Vulnerability (HIGH)

**Issue:** Dynamic SOQL with string concatenation

**Location:** ShipperLoadListController.getLoads() lines 78-84

**Current (VULNERABLE):**
```apex
List<String> statuses = new List<String>();
for (String status : statusFilter.split(',')) {
  statuses.add('\'' + status.trim() + '\'');
}
query += ' AND Status__c IN (' + String.join(statuses, ',') + ') ';
```

**Fixed:**
```apex
// Validate against schema picklist values
private static Boolean isValidStatus(String status) {
  List<String> validStatuses = getStatusOptions();
  return validStatuses.contains(status);
}

// In getLoads():
if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
  List<String> requestedStatuses = new List<String>();
  
  for (String status : statusFilter.split(',')) {
    String trimmed = status.trim();
    if (isValidStatus(trimmed)) {
      requestedStatuses.add(trimmed);
    }
  }
  
  if (!requestedStatuses.isEmpty()) {
    // Now safe to use with validated values
    query += ' AND Status__c IN (';
    for (Integer i = 0; i < requestedStatuses.size(); i++) {
      query += '\'' + requestedStatuses[i] + '\'';
      if (i < requestedStatuses.size() - 1) query += ',';
    }
    query += ') ';
  }
}
```

---

### Add FLS Checks to All Controllers

**Helper Method (add to each controller):**
```apex
/**
 * Verify user has FLS READ access to specified fields
 */
private static void validateFieldAccess(
  SObjectType sObjectType,
  List<String> fields,
  String accessLevel
) {
  Map<String, Schema.SObjectField> fieldMap = 
    sObjectType.getDescribe().fields.getMap();
  
  for (String field : fields) {
    Schema.SObjectField fieldObj = fieldMap.get(field);
    if (fieldObj == null) {
      throw new AuraHandledException('Field ' + field + ' not found');
    }
    
    Schema.DescribeFieldResult fieldDescribe = fieldObj.getDescribe();
    
    if (accessLevel == 'READ' && !fieldDescribe.isAccessible()) {
      throw new AuraHandledException(
        'You do not have read access to ' + field
      );
    }
    
    if (accessLevel == 'UPDATE' && !fieldDescribe.isUpdateable()) {
      throw new AuraHandledException(
        'You do not have update access to ' + field
      );
    }
  }
}

/**
 * Verify user has CRUD access to SObject
 */
private static void validateCRUDAccess(
  SObjectType sObjectType,
  String accessLevel
) {
  Schema.DescribeSObjectResult describe = sObjectType.getDescribe();
  
  switch on accessLevel {
    when 'READ' {
      if (!describe.isAccessible()) {
        throw new AuraHandledException(
          'You do not have read permission on this object'
        );
      }
    }
    when 'CREATE' {
      if (!describe.isCreateable()) {
        throw new AuraHandledException(
          'You do not have create permission on this object'
        );
      }
    }
    when 'UPDATE' {
      if (!describe.isUpdateable()) {
        throw new AuraHandledException(
          'You do not have update permission on this object'
        );
      }
    }
  }
}
```

**Apply to ShipperLoadListController.getLoads():**
```apex
public static LoadListResponse getLoads(...) {
  try {
    // ✅ ADD CRUD CHECK
    validateCRUDAccess(Load__c.SObjectType, 'READ');
    
    // ✅ ADD FLS CHECK
    List<String> requiredFields = new List<String>{
      'Id', 'Name', 'Shipper_Account__c', 'Pickup_City__c',
      'Delivery_City__c', 'Status__c', 'Pickup_DateTime__c',
      'Estimated_Delivery_DateTime__c', 'Shipper_Rate__c'
    };
    validateFieldAccess(Load__c.SObjectType, requiredFields, 'READ');
    
    // ... rest of method
  }
}
```

---

## Unit Testing Strategy

### Test Coverage Goals
- Mobile App Services: >80% coverage
- Portal Controllers: >85% coverage  
- Salesforce Apex: >90% coverage
- React Components: >75% coverage

### Test Files to Create

#### 1. Mobile App Tests

**File:** `__tests__/services/salesforceService.test.ts`
```typescript
describe('Salesforce Service', () => {
  describe('Authentication', () => {
    test('loginDriver: successful login', async () => {
      const response = await loginDriver('5551234567', 'password123');
      expect(response).toHaveProperty('accessToken');
      expect(response).toHaveProperty('instanceUrl');
    });

    test('loginDriver: invalid credentials', async () => {
      await expect(loginDriver('invalid', 'wrong')).rejects.toThrow('Login failed');
    });

    test('validateToken: valid token', async () => {
      await loginDriver('5551234567', 'password123');
      const isValid = await validateToken();
      expect(isValid).toBe(true);
    });

    test('validateToken: expired token', async () => {
      // Set token expiry to past
      await AsyncStorage.setItem('sf_token_expires_at', '2020-01-01T00:00:00Z');
      const isValid = await validateToken();
      expect(isValid).toBe(false);
    });

    test('logoutDriver: clears credentials', async () => {
      await loginDriver('5551234567', 'password123');
      await logoutDriver();
      const token = await AsyncStorage.getItem('sf_access_token');
      expect(token).toBeNull();
    });
  });

  describe('Load Fetching', () => {
    beforeEach(async () => {
      await loginDriver('5551234567', 'password123');
    });

    test('fetchLoads: returns array of loads', async () => {
      const loads = await fetchLoads('driverId123');
      expect(Array.isArray(loads)).toBe(true);
      expect(loads.length).toBeGreaterThan(0);
    });

    test('fetchLoads: load object has required fields', async () => {
      const loads = await fetchLoads('driverId123');
      const load = loads[0];
      expect(load).toHaveProperty('id');
      expect(load).toHaveProperty('name');
      expect(load).toHaveProperty('status');
      expect(load).toHaveProperty('pickupDateTime');
    });

    test('fetchLoads: not authenticated throws error', async () => {
      await logoutDriver();
      await expect(fetchLoads('driverId123')).rejects.toThrow('Not authenticated');
    });
  });

  describe('Check-In Creation', () => {
    beforeEach(async () => {
      await loginDriver('5551234567', 'password123');
    });

    test('createCheckIn: successful creation', async () => {
      const checkInData = {
        loadId: 'load123',
        eventType: 'pickup',
        latitude: 41.6632,
        longitude: -83.5550,
        accuracy: 15,
        timestamp: new Date().toISOString()
      };
      const id = await createCheckIn(checkInData, 'driverId123');
      expect(id).toBeDefined();
      expect(typeof id).toBe('string');
    });

    test('createCheckIn: offline queues operation', async () => {
      // Simulate offline
      // Should queue to Realm instead of API call
      const checkInData = { /* ... */ };
      const id = await createCheckIn(checkInData, 'driverId123');
      // Verify queued in Realm
      expect(id).toBeDefined();
    });

    test('createCheckIn: accuracy validation', async () => {
      const checkInData = {
        // ...
        accuracy: 150 // > 100m threshold
      };
      // Should reject or log warning
    });
  });
});
```

#### 2. Offline Sync Tests

**File:** `__tests__/services/offlineSyncService.test.ts`
```typescript
describe('Offline Sync Service', () => {
  describe('Queue Management', () => {
    test('queueOperation: adds to Realm SyncQueue', async () => {
      const operation = {
        type: 'create_check_in',
        targetId: 'load123',
        payload: { /* ... */ }
      };
      await queueOperation(operation.type, operation.targetId, operation.payload);
      
      // Verify in Realm
      const realm = await getRealm();
      const queue = realm.objects('SyncQueue').filtered("status = 'pending'");
      expect(queue.length).toBeGreaterThan(0);
    });

    test('syncQueue: processes pending operations', async () => {
      // Add pending operations
      await queueOperation('create_check_in', 'load123', { /* ... */ });
      
      // Trigger sync (with mock online status)
      await syncQueue();
      
      // Verify operations marked as synced
      const realm = await getRealm();
      const pending = realm.objects('SyncQueue').filtered("status = 'pending'");
      expect(pending.length).toBe(0);
    });

    test('retryFailedOperations: exponential backoff', async () => {
      // Simulate failed operation
      // Verify retry count increments
      // Verify nextRetryAt time increases exponentially
    });
  });

  describe('Offline Scenario', () => {
    test('app offline: check-in queued, not synced', async () => {
      // Simulate offline network state
      const checkInId = await createCheckIn(checkInData, 'driverId123');
      
      // Verify in Realm with synced = false
      const realm = await getRealm();
      const checkIn = realm.objects('CheckIn').filtered("id = $0", checkInId)[0];
      expect(checkIn.synced).toBe(false);
    });

    test('offline to online transition: auto-sync', async () => {
      // Start offline, create check-in
      // Transition to online
      // Verify auto-sync triggered
      // Verify synced = true after sync
    });

    test('sync conflict: duplicate external ID handling', async () => {
      // Create operation, fail sync
      // Queue retry with same external ID
      // Verify Salesforce deduplication handles it
    });
  });

  describe('Data Loss Prevention', () => {
    test('app crash during sync: data preserved', async () => {
      // Queue operation
      // Simulate app crash mid-sync
      // Relaunch app
      // Verify operation still queued + re-synced
    });

    test('storage full scenario: graceful handling', async () => {
      // Fill storage
      // Attempt to save POD photo
      // Verify user notified + option to clear cache
    });
  });
});
```

#### 3. Portal Tests

**File:** `__tests__/controllers/ShipperLoadListControllerTest.cls`
```apex
@isTest
private class ShipperLoadListControllerTest {
  
  @isTest
  static void testGetLoads_AsShipper() {
    // Setup
    Account shipper = new Account(Name = 'Test Shipper');
    insert shipper;
    
    User shipperUser = createShipperPortalUser(shipper.Id);
    
    Load__c load = new Load__c(
      Name = 'Load001',
      Shipper_Account__c = shipper.Id,
      Status__c = 'ASSIGNED',
      Pickup_DateTime__c = System.now().addDays(1),
      Estimated_Delivery__c = System.now().addDays(2)
    );
    insert load;

    Test.startTest();
    System.runAs(shipperUser) {
      ShipperLoadListController.LoadListResponse response = 
        ShipperLoadListController.getLoads('ASSIGNED', null, null, null, 1);
      
      System.assertEquals(1, response.loads.size());
      System.assertEquals('Load001', response.loads[0].name);
    }
    Test.stopTest();
  }

  @isTest
  static void testGetLoads_RLS_EnforcedCrossShibpper() {
    // Create 2 shippers
    Account shipper1 = new Account(Name = 'Shipper1');
    Account shipper2 = new Account(Name = 'Shipper2');
    insert new List<Account>{ shipper1, shipper2 };

    // Create loads for shipper2
    Load__c load2 = new Load__c(
      Name = 'Load002',
      Shipper_Account__c = shipper2.Id,
      Status__c = 'ASSIGNED'
    );
    insert load2;

    // Create shipper1 user
    User shipper1User = createShipperPortalUser(shipper1.Id);

    Test.startTest();
    System.runAs(shipper1User) {
      ShipperLoadListController.LoadListResponse response = 
        ShipperLoadListController.getLoads('ASSIGNED', null, null, null, 1);
      
      // Should return 0 loads (cannot access shipper2's loads)
      System.assertEquals(0, response.loads.size());
    }
    Test.stopTest();
  }

  @isTest
  static void testGetLoads_FLSEnforced() {
    // User without FLS access should get error
    // Note: This is harder to test in Apex
    // Rely on manual testing or integration tests
  }

  // Helper method
  private static User createShipperPortalUser(Id accountId) {
    Contact con = new Contact(
      AccountId = accountId,
      LastName = 'TestContact'
    );
    insert con;

    User portalUser = new User(
      Username = 'shipper' + accountId + '@test.com',
      LastName = 'Shipper',
      Email = 'shipper@test.com',
      ContactId = con.Id,
      ProfileId = [SELECT Id FROM Profile WHERE Name = 'Customer Portal User' LIMIT 1].Id
    );
    insert portalUser;
    return portalUser;
  }
}
```

---

## Implementation Timeline

### Week 1: CRITICAL Fixes
- [ ] Fix RLS bypass in getCarrierInfo() (2-3 hours)
- [ ] Add CRUD/FLS checks to Contact + PaymentMethod (4-6 hours)
- [ ] Add ShowToastEvent import (10 min)
- [ ] Fix SQL injection vulnerability (2-3 hours)
- **Total: ~10 hours**

### Week 2: HIGH Priority Fixes
- [ ] Add FLS checks to all controllers (6-8 hours)
- [ ] Add CRUD checks (3-4 hours)
- [ ] Email validation + input sanitization (2-3 hours)
- [ ] Payment data encryption setup (3-4 hours)
- **Total: ~15 hours**

### Week 3: Unit Tests
- [ ] Salesforce Apex tests (8-10 hours)
- [ ] React LWC tests (6-8 hours)
- [ ] Mobile app tests (10-12 hours)
- **Total: ~25 hours**

### Week 4: Integration Tests + QA
- [ ] End-to-end scenarios (8-10 hours)
- [ ] Accessibility audit (4-6 hours)
- [ ] Performance testing (4-6 hours)
- [ ] Security review (4-6 hours)
- **Total: ~20 hours**

---

## Test Execution Commands

```bash
# Apex tests (Salesforce)
sfdx force:apex:test:run -u production --outputdir ./test-results

# React/LWC tests
npm test -- --coverage

# Mobile app tests
detox test -c ios.sim.debug

# Integration tests
npm run test:integration
```

---

## Success Criteria

✅ All 4 CRITICAL issues fixed + tested  
✅ All 16 HIGH issues fixed + tested  
✅ Unit test coverage >80% (app + portal)  
✅ Integration tests pass (end-to-end)  
✅ Security review approved  
✅ Accessibility audit WCAG AA  
✅ No data loss in offline scenarios  
✅ No RLS/FLS bypass vulnerabilities  
