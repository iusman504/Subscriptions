# **Complete Subscription & Purchase System Documentation (Full Stack)**

This documentation covers **Flutter app**, **backend sync**, **subscription lifecycle**, **history tracking**, and **platform differences (iOS & Android)**.

---

## **1. Overview**

Your subscription system consists of:

1. **SubscriptionService (Flutter)** – Handles IAP interactions and purchase updates.
2. **Models** – `Subscription`, `Purchase`, `Plan`, `PurchaseStatus`, `StoreType`.
3. **Backend Sync** – Tracks purchases, cancellations, and refunds in your server.
4. **History** – Saves all transactions to maintain a log of user subscription activity.

**Key Features:**

* Supports Android & iOS
* Handles active, canceled, refunded, and restored purchases
* Auto-restores subscriptions on app launch
* Syncs with backend for accurate user subscription status
* Maintains full subscription history
* Handles edge cases like unpaid, in-grace period, and paused subscriptions
* Provides status mapping to backend-compatible strings

---

## **2. Initialization**

### 2.1 Setup SubscriptionService

```dart
final subscriptionService = SubscriptionService();
await subscriptionService.init();
```

* Initializes streams for purchase updates
* Loads products from app stores
* Restores active purchases
* Initializes backend sync (if enabled)
* Handles platform-specific initialization:

  * **iOS**: `buyNonConsumable` for subscriptions
  * **Android**: `purchaseStream` + restore purchases

---

## **3. Fetch Products & Plans**

```dart
await subscriptionService.getAllSubscriptions();
```

### Steps:

1. Fetch product IDs from backend (your server contains all valid subscription product IDs).
2. Call **in-app purchase APIs**:

   * **iOS**: `_getAllSubscriptionsIOS()`
   * **Android**: `_getAllSubscriptionsAndroid()`
3. Match `ProductDetails` with your backend `Subscription` plans.
4. Update `subscriptionPlans` list in your app.
5. Restore any existing active purchases.

**Backend Sync:**
After fetching products, send device info to backend:

```json
{
  "userId": 123,
  "platform": "ios",
  "deviceId": "ABC-123",
  "availableProducts": ["monthly_premium", "yearly_premium"]
}
```

* Backend validates product IDs.
* Returns any previously purchased active subscriptions for this user.

---

## **4. Purchase Flow**

### 4.1 Initiate Purchase

```dart
await subscriptionService.buyProduct(productDetails);
```

Steps:

1. Create a `PurchaseParam` with user info.
2. Call `buyNonConsumable` (iOS) or `buyNonConsumable` (Android).
3. Wait for `_purchaseCompleter` to complete.
4. Listen to `purchaseStream` for updates.

### 4.2 Handle Purchase Updates

**iOS & Android** share same pattern:

1. Listen to `purchaseStream`.
2. Map purchase status to `PurchaseStatus` enum.
3. Handle each case:

| Status    | Action                                                       |
| --------- | ------------------------------------------------------------ |
| purchased | Add to `activePurchases`, complete purchase, send to backend |
| restored  | Add to `activePurchases`, complete purchase, send to backend |
| canceled  | Complete purchase, update backend                            |
| refunded  | Complete purchase, update backend                            |
| error     | Log error, notify user                                       |

**Example backend sync payload:**

```json
{
  "userId": 123,
  "productId": "monthly_premium",
  "purchaseToken": "abc123",
  "transactionId": "tx123",
  "platform": "ios",
  "status": "ACTIVE",
  "priceAmount": 9.99,
  "currency": "USD",
  "periodStartAt": "2026-02-04T10:00:00Z",
  "periodEndAt": "2026-03-04T10:00:00Z"
}
```

* Backend saves this in **purchase history table**
* Backend updates **user subscription status** (`isPremium: true`)

---

## **5. Restore Purchases**

```dart
await subscriptionService.restorePurchases();
```

* **iOS**: `inAppPurchase.restorePurchases()`
* **Android**: same method
* Updates `activePurchases` list
* For each restored purchase, sync with backend
* Completes `_restoreCompleter` for UI feedback

**History Tracking:**

* Each restored purchase is **added to backend history**
* If the purchase already exists, backend can **update the status**.

---

## **6. Backend Synchronization**

Backend API endpoints to implement:

1. **Add Purchase**

   * `POST /api/purchases`
   * Payload: purchase details + user info
   * Backend saves in `purchase_history` and updates `user_subscription_status`
2. **Update Purchase**

   * `PUT /api/purchases/{transactionId}`
   * Used for refunds, cancellations, or status changes
3. **Fetch Active Subscriptions**

   * `GET /api/users/{userId}/subscriptions`
   * Returns all active subscriptions and history
4. **Cancel Subscription**

   * `POST /api/subscriptions/cancel`
   * Update backend to mark subscription as canceled

---

## **7. Subscription Status & History Tracking**

### 7.1 PurchaseStatus Enum

```dart
PurchaseStatus {
  unpaid,
  active,
  inGrace,
  onHold,
  paused,
  expired,
  canceled,
  refunded,
  restored
}
```

* All statuses map to backend strings via `apiValue`.
* `RESTORED` → `ACTIVE`
* `UNPAID` → No active purchase

### 7.2 Backend History Schema

| Field          | Type     | Notes                           |
| -------------- | -------- | ------------------------------- |
| id             | int      | auto-increment                  |
| userId         | int      | FK to users                     |
| subscriptionId | int      | FK to subscription plan         |
| productId      | string   | Product ID                      |
| platform       | string   | iOS / Android                   |
| purchaseToken  | string   | App store token                 |
| transactionId  | string   | App store transaction ID        |
| status         | string   | ACTIVE, CANCELED, REFUNDED, etc |
| priceAmount    | float    | Price paid                      |
| priceCurrency  | string   | Currency code                   |
| periodStartAt  | datetime | Subscription start              |
| periodEndAt    | datetime | Subscription end                |
| verifiedAt     | datetime | Verification timestamp          |
| createdAt      | datetime | Created timestamp               |
| updatedAt      | datetime | Last updated                    |

---

## **8. Cancellation & Refund Flow**

### 8.1 Cancel Subscription

* **Frontend**: calls `cancelSubscription(productId)`
* **Backend**: marks subscription as canceled
* **iOS**: opens Apple subscription page
* **Android**: opens Play Store subscription page
* Status updated in `PurchaseStatus.canceled`

### 8.2 Refund

* Refund requests are **platform-specific**:

  * **iOS**: redirect to Apple Report a Problem
  * **Android**: redirect to Play Store refund
* Once processed:

  * Backend updates `PurchaseStatus.refunded`
  * Frontend refreshes `activePurchases` list

---

## **9. Periodic Sync / Background Checks**

* On app launch:

  * Restore purchases
  * Fetch backend active subscriptions
  * Resolve discrepancies:

    * Purchase exists in backend but not in app → restore locally
    * Purchase exists in app but not in backend → push to backend
* On subscription expiration:

  * App receives updated status
  * Backend marks subscription as expired

---

## **10. Edge Cases & Error Handling**

| Case                                |             Solution                           |
| ----------------------------------- | ---------------------------------------------- |
| Network error during purchase       | Complete purchase locally, retry backend sync  |
| Duplicate purchase                  | Backend ignores duplicate `transactionId`      |
| Subscription restored on another device | Restore purchase, update backend           |
| Subscription expired                | Set status `EXPIRED`, update backend           |
| Grace period                        | Keep `IN_GRACE` status until end, notify user  |
| Paused subscription                 | Keep `PAUSED` status, disable premium features |
| Refund / chargeback                 | Update backend, remove premium access          |

---

## **11. UI Considerations**

* Show active subscription status to users
* Disable purchase button if already subscribed
* Handle multiple subscription plans:

  * Monthly / Yearly / Custom
* Show grace period info, renewal info, and cancellation notice

---

## **12.Store Behaviours**

## **1. Playstore Behaviour**

* Device (new vs old)
* User account (new vs existing)
* Free trials, introductory pricing
* Cancellation, renewal, refund flows

### **Test Setup**

1. Create **multiple test accounts** (Gmail) in Play Console:

   * New user (never bought your app)
   * Existing user (already purchased a subscription)
2. Add test license accounts in **Play Console → Setup → License Testing**.
3. Upload your app to **Internal Test Track** or **Internal App Sharing**.

### **Notes**

* Free trials are **per account**, not per device.
* Existing users may **not see free trial** if they already subscribed before.
* Use **short test subscription periods** (e.g., 5 mins for trial) in Play Console for testing.

---

## **2. Apple App Store (iOS)**

### **Test Setup**

1. Create **Sandbox tester accounts** in App Store Connect.
2. Use a **real device signed in with sandbox account**.
3. Install your app via **Xcode / TestFlight**.

### **Notes**

* Free trials and intro offers are **per Apple ID**, not device.
* Trial periods are **shortened in sandbox** (e.g., 3 days trial = 5 minutes in sandbox).
* Restores must be tested **on device**, not simulator.

---

## **3. Key Differences Between Platforms**

| Feature        | Google Play                          | Apple App Store              |
| -------------- | ------------------------------------ | ---------------------------- |
| Free Trial     | Per account                          | Per Apple ID                 |
| Intro Pricing  | Per account                          | Per Apple ID                 |
| Device Changes | Use `queryPastPurchases()`           | Use `restorePurchases()`     |
| Cancellations  | Play Store → app receives canceled   | Settings → app canceled      |
| Refunds        | Manual via Play Store                | Manual via Apple support     |

---

### **4. How to Log and Observe Behavior in Flutter**

1. Listen to `purchaseStream`:

```dart
InAppPurchase.instance.purchaseStream.listen((purchases) {
  for (var purchase in purchases) {
    print('Purchase: ${purchase.productID}, status: ${purchase.status}');
  }
});
```

2. Track **start & end dates** (`transactionDate`) to see trial/intro periods.
3. Sync with backend to verify status changes.
4. Test **multiple devices** with same account to observe restoration behavior.

---

✅ **Tip:** Both stores are **account-based**, not device-based. The only difference is sandbox vs production:

* Sandbox periods are short → easy to test.
* Real accounts take real-time periods (month/year) for renewals.

---

## **14. Full Lifecycle Diagram**

```
            +--------------------+
            | App Launch         |
            +--------------------+
                     |
                     v
          +----------------------+
          | Restore Purchases     |
          +----------------------+
                     |
                     v
          +----------------------+
          | Check Backend Status |
          +----------------------+
                     |
                     v
       +-------------+---------------+
       |                             |
       v                             v
  Active Purchase                 No Active Purchase
       |                             |
       v                             v
  User has access             Show purchase options
       |
       v
   User Buys / Restores
       |
       v
   Update activePurchases
       |
       v
   Sync with Backend
       |
       v
   Save in purchase_history
       |
       v
   Monitor expiration / refund / cancel
```
