import 'dart:async';
import 'dart:io';
import 'package:flutter_subscriptions/core/models/custom_logger.dart';
import 'package:flutter_subscriptions/core/models/purchase.dart';
import 'package:flutter_subscriptions/core/models/subscription.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionService {
  final log = CustomLogger(className: '@subscriptionService');
  final InAppPurchase inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> subscription;
  List<ProductDetails> products = [];
  List<Subscription> subscriptionPlans = [];
  List<PurchaseDetails> activePurchases = [];
  Completer<bool>? _purchaseCompleter;
  Completer<void>? _restoreCompleter;
  List<String> productIds = ['monthly_subscription', 'yearly_subscription'];

  ///
  /// Get all Available Subscriptions - Platform Specific
  ///
  Future<void> getAllSubscriptions() async {
    try {
      log.d(
        "🔍 Getting available subscriptions for platform: ${Platform.operatingSystem}",
      );

      final isAvailable = await inAppPurchase.isAvailable();
      if (!isAvailable) {
        log.d("IAP not available on ${Platform.operatingSystem}");
        return;
      } else {
        log.d("IAP is available on ${Platform.operatingSystem}");
      }

      // Platform-specific subscription retrieval
      if (Platform.isIOS) {
        await _getAllSubscriptionsIOS();
      } else if (Platform.isAndroid) {
        await _getAllSubscriptionsAndroid();
      } else {
        log.e(
          "Unsupported platform for subscriptions: ${Platform.operatingSystem}",
        );
        return;
      }

      log.d("Available subscription plans: ${subscriptionPlans.length}");
    } catch (e) {
      log.e("❌ Error getting subscriptions: $e");
    }
  }

  /// ============================================================= ///
  /// =================== iOS Subscriptions ======================= ///
  /// ============================================================= ///
  Future<void> _getAllSubscriptionsIOS() async {
    try {
      log.d("🍎 Fetching iOS subscriptions");

      // Subscribe to purchase updates
      subscription = inAppPurchase.purchaseStream.listen(
        (purchaseDetailsList) => _handlePurchaseUpdatesIOS(purchaseDetailsList),
        onDone: () => subscription.cancel(),
        onError: (error) => log.d("iOS purchase stream error: $error"),
      );

      // Query subscriptions with iOS-specific handling
      final response = await inAppPurchase.queryProductDetails(
        productIds.toSet(),
      );

      if (response.notFoundIDs.isNotEmpty) {
        log.d("🍎 iOS Missing product IDs: ${response.notFoundIDs}");
      }

      // Clear existing plans and add new ones
      // subscriptionPlans.clear();
      products = response.productDetails;
      // await getSubscriptionsFromDb();
      // subscriptionPlans.addAll(
      //   response.productDetails.asMap().entries.map(
      //     (entry) => SubsPlan(
      //       product: entry.value,
      //       isSelected: entry.key == 1, // Default select middle option
      //     ),
      //   ),
      // );

      // IMPORTANT: Check for existing purchases after loading subscriptions
      log.d("🍎 Checking for existing iOS purchases...");
      await _checkExistingIOSPurchases();

      log.d("🍎 iOS subscriptions loaded: ${subscriptionPlans.length}");
    } catch (e) {
      log.e("❌ Error getting iOS subscriptions: $e");
    }
  }

  ///
  /// Check for existing iOS purchases
  ///
  Future<void> _checkExistingIOSPurchases() async {
    try {
      log.d("🍎 Restoring existing iOS purchases...");

      _restoreCompleter = Completer<void>();

      // Restore purchases to trigger the purchase stream with existing purchases
      await inAppPurchase.restorePurchases();

      // Wait for the purchase stream to emit restored items (or timeout)
      await _restoreCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          log.w("⏰ iOS restore timeout waiting for purchase stream");
        },
      );
      _restoreCompleter = null;

      log.d("🍎 Existing purchases check completed");
      log.d(
        "🍎 Total active purchases after restore: ${activePurchases.length}",
      );
      // _syncSubscriptionWithBackend(); // Sync with backend
      Purchase activePurchase = Purchase();

      for (int i = 0; i < subscriptionPlans.length; i++) {
        for (var p in activePurchases) {
          if (subscriptionPlans[i].product!.id == p.productID) {
            activePurchase = Purchase.fromPurchaseDetails({
              'id': subscriptionPlans[i].id,
              'status': p.status.toString(),
              'purchaseID': p.purchaseID,
              'transactionDate': p.transactionDate,
              'verificationSource': p.verificationData.source,
              'purchaseToken': p.verificationData.serverVerificationData,
            });
            log.i(
              "Matched active purchase for product ${p.productID}: ${activePurchase.toJson()}",
            );
            // auth.user.purchaseStatus = "ACTIVE";
            // auth.user.lastPurchase = activePurchase;
          }
        }
      }
    } catch (e) {
      log.e("❌ Error checking existing iOS purchases: $e");
    }
  }

  /// ============================================================= ///
  /// =================== Android Subscriptions ==================== ///
  /// ============================================================= ///

  Future<void> _getAllSubscriptionsAndroid() async {
    try {
      log.d("🤖 Fetching Android subscriptions");

      // Subscribe to purchase updates
      subscription = inAppPurchase.purchaseStream.listen(
        (purchaseDetailsList) =>
            _handlePurchaseUpdatesAndroid(purchaseDetailsList),
        onDone: () => subscription.cancel(),
        onError: (error) => log.d("Android purchase stream error: $error"),
      );

      // Query subscriptions with Android-specific handling
      final response = await inAppPurchase.queryProductDetails(
        productIds.toSet(),
      );

      if (response.notFoundIDs.isNotEmpty) {
        log.d("🤖 Android Missing product IDs: ${response.notFoundIDs}");
      }

      // Clear existing plans and add new ones
      products = response.productDetails;
      // await getSubscriptionsFromDb();
      // subscriptionPlans.clear();
      // subscriptionPlans.addAll(
      //   response.productDetails.asMap().entries.map(
      //     (entry) => SubsPlan(
      //       product: entry.value,
      //       isSelected: entry.key == 1, // Default select middle option
      //     ),
      //   ),
      // );

      // IMPORTANT: Check for existing purchases after loading subscriptions
      log.d("🤖 Checking for existing Android purchases...");
      await _checkExistingAndroidPurchases();

      log.d("🤖 Android subscriptions loaded: ${subscriptionPlans.length}");
    } catch (e) {
      log.e("❌ Error getting Android subscriptions: $e");
    }
  }

  ///
  /// Check for existing Android purchases
  ///
  Future<void> _checkExistingAndroidPurchases() async {
    try {
      log.d("🤖 Restoring existing Android purchases...");

      // Restore purchases to trigger the purchase stream with existing purchases
      await inAppPurchase.restorePurchases();

      // Give it a moment to process
      await Future.delayed(Duration(seconds: 2));
     // _syncSubscriptionWithBackend(); // Sync with backend
      log.d("🤖 Existing purchases check completed");
      log.d(
        "🤖 Total active purchases after restore: ${activePurchases.length}",
      );

      Purchase? activePurchase;

      for (int i = 0; i < subscriptionPlans.length; i++) {
        for (var p in activePurchases) {
          if (subscriptionPlans[i].product!.id == p.productID) {
            activePurchase = Purchase.fromPurchaseDetails({
              'id': subscriptionPlans[i].id,
              'status': p.status.toString(),
              'purchaseID': p.purchaseID,
              'purchase_token': p.verificationData.serverVerificationData,
              'transactionDate': p.transactionDate,
              'verificationSource': p.verificationData.source,
            });
            log.i(
              "Matched active purchase for product ${p.productID}: ${activePurchase.toJson()}",
            );
            // auth.user.purchaseStatus = "ACTIVE";
            // auth.user.lastPurchase = activePurchase;
          }
        }
      }
      // if (activePurchase != null) {
      //   PurchaseResponse response = await _db.createPurchase();
      //   if (response.success) {
      //     auth.getUserProfile();
      //   }
      // }
    } catch (e, s) {
      log.e("❌ Error checking existing Android purchases: $e $s");
    }
  }

  ///
  /// Handle Purchase Updates for iOS
  ///
  void _handlePurchaseUpdatesIOS(List<PurchaseDetails> purchaseDetailsList) {
    log.d("🍎 Processing iOS purchase updates: ${purchaseDetailsList.length}");

    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        log.d("✅ iOS Purchase Successful: ${purchaseDetails.productID}");
        _addToActivePurchases(purchaseDetails, "iOS");
        _completePurchase(true);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        log.e("❌ iOS Purchase Failed: ${purchaseDetails.error}");
        _handleIOSPurchaseError(purchaseDetails);
        _completePurchase(false);
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        log.d("🚫 iOS Purchase Canceled: ${purchaseDetails.productID}");
        _completePurchase(false);
      } else if (purchaseDetails.status == PurchaseStatus.restored) {
        log.d("🔄 iOS Purchase Restored: ${purchaseDetails.productID}");
        _addToActivePurchases(purchaseDetails, "iOS");
      }

      if (purchaseDetails.pendingCompletePurchase) {
        inAppPurchase.completePurchase(purchaseDetails);
        log.d("🍎 iOS purchase completed: ${purchaseDetails.productID}");
      }
    }

    if (_restoreCompleter != null && !_restoreCompleter!.isCompleted) {
      _restoreCompleter!.complete();
    }
  }

  ///
  /// Handle Purchase Updates for Android
  ///
  void _handlePurchaseUpdatesAndroid(
    List<PurchaseDetails> purchaseDetailsList,
  ) {
    log.d(
      "🤖 Processing Android purchase updates: ${purchaseDetailsList.length}",
    );

    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        log.d("✅ Android Purchase Successful: ${purchaseDetails.productID}");
        _addToActivePurchases(purchaseDetails, "Android");
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        log.e("❌ Android Purchase Failed: ${purchaseDetails.error}");
        _handleAndroidPurchaseError(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        log.d("🚫 Android Purchase Canceled: ${purchaseDetails.productID}");
      } else if (purchaseDetails.status == PurchaseStatus.restored) {
        log.d("🔄 Android Purchase Restored: ${purchaseDetails.productID}");
        _addToActivePurchases(purchaseDetails, "Android");
      }

      if (purchaseDetails.pendingCompletePurchase) {
        inAppPurchase.completePurchase(purchaseDetails);
        log.d("🤖 Android purchase completed: ${purchaseDetails.productID}");
      }
    }
  }

  ///
  /// Add purchase to active purchases list
  ///
  void _addToActivePurchases(PurchaseDetails purchaseDetails, String platform) {
    if (productIds.contains(purchaseDetails.productID)) {
      activePurchases.removeWhere(
        (p) => p.productID == purchaseDetails.productID,
      );
      activePurchases.add(purchaseDetails);
      log.d(
        "$platform: Added to active purchases: ${purchaseDetails.productID}",
      );
      log.d("$platform: Total active purchases: ${activePurchases.length}");
      log.d("$platform: Purchase status: ${purchaseDetails.status}");
      log.d("$platform: Purchase date: ${purchaseDetails.transactionDate}");
      // _syncSubscriptionWithBackend(); // Sync with backend
    } else {
      log.d(
        "$platform: Product ${purchaseDetails.productID} not in our product list",
      );
      log.d("$platform: Our products: $productIds");
    }
  }

  ///
  /// Handle iOS-specific purchase errors
  ///
  void _handleIOSPurchaseError(PurchaseDetails purchaseDetails) {
    log.e("🍎 iOS Purchase Error Details:");
    log.e("   Product: ${purchaseDetails.productID}");
    log.e("   Error: ${purchaseDetails.error}");

    // iOS-specific error handling
    if (purchaseDetails.error?.code == 'storekit_duplicate_product_object') {
      log.e("   Fix: Check for duplicate product IDs in iOS");
    } else if (purchaseDetails.error?.code == 'storekit_invalid_payment') {
      log.e("   Fix: Verify payment information and App Store account");
    }
  }

  ///
  /// Handle Android-specific purchase errors
  ///
  void _handleAndroidPurchaseError(PurchaseDetails purchaseDetails) {
    log.e("🤖 Android Purchase Error Details:");
    log.e("   Product: ${purchaseDetails.productID}");
    log.e("   Error: ${purchaseDetails.error}");

    // Android-specific error handling
    if (purchaseDetails.error?.code == 'billing_unavailable') {
      log.e(
        "   Fix: Google Play Billing not available - check device settings",
      );
    } else if (purchaseDetails.error?.code == 'developer_error') {
      log.e("   Fix: Check app signing and Google Play Console setup");
    }
  }

  ///
  /// Buy Product/Subscription - Platform Specific
  ///
  Future<bool> buyProduct(ProductDetails productDetails) async {
    try {
      log.d("🛒 Initiating purchase for: ${productDetails.id}");
      log.d("Platform: ${Platform.operatingSystem}");

      // Platform-specific purchase logic
      if (Platform.isIOS) {
        return await _buyProductIOS(productDetails);
      } else if (Platform.isAndroid) {
        return await _buyProductAndroid(productDetails);
      } else {
        log.e(
          "Unsupported platform for purchases: ${Platform.operatingSystem}",
        );
        return false;
      }
    } catch (e) {
      log.e("❌ Error buying product: $e");
      return false;
    }
  }

  ///
  /// Buy Product for iOS
  ///
  Future<bool> _buyProductIOS(ProductDetails productDetails) async {
    try {
      log.d("🍎 Processing iOS purchase for: ${productDetails.id}");
      log.d("🍎 Price: ${productDetails.price}");
      log.d("🍎 Currency: ${productDetails.currencyCode}");

      // Create a new completer for this purchase
      _purchaseCompleter = Completer<bool>();

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: 'userId', //Replace with user ID
      );

      // For subscriptions, use buyNonConsumable on iOS
      final initiated = await inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!initiated) {
        log.e("🍎 Failed to initiate iOS purchase");
        _completePurchase(false);
        return false;
      }

      log.d("🍎 iOS purchase initiated, waiting for completion...");

      // Wait for purchase to complete with 2 minute timeout
      final result = await _purchaseCompleter!.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          log.e("⏰ iOS purchase timeout");
          return false;
        },
      );

      log.d("🍎 iOS purchase result: $result");
      return result;
    } catch (e) {
      log.e("❌ Error buying iOS product: $e");
      _completePurchase(false);
      return false;
    }
  }

  ///
  /// Buy Product for Android
  ///
  Future<bool> _buyProductAndroid(ProductDetails productDetails) async {
    try {
      log.d("🤖 Processing Android purchase for: ${productDetails.id}");
      log.d("🤖 Price: ${productDetails.price}");
      log.d("🤖 Currency: ${productDetails.currencyCode}");

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: 'userId', //Replace with user ID
      );

      // For subscriptions, use buyNonConsumable on Android
      final result = await inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      // if (result) {
      //   await _db.createPurchase();
      // }
      log.d("🤖 Android purchase initiated: $result");
      return result;
    } catch (e) {
      log.e("❌ Error buying Android product: $e");
      return false;
    }
  }

  ///
  /// Cancel Subscription - Platform Specific
  /// Handles cancellation differently for iOS and Android
  ///
  Future<bool> cancelSubscription(String productId) async {
    try {
      log.d("Initiating subscription cancellation for: $productId");

      // Check if we have an active purchase for this product
      final hasActivePurchase = activePurchases.any(
        (purchase) => purchase.productID == productId,
      );

      if (!hasActivePurchase) {
        log.e("No active subscription found for $productId");
        return false;
      }

      // Platform-specific cancellation logic
      if (Platform.isIOS) {
        return await _cancelSubscriptionIOS(productId);
      } else if (Platform.isAndroid) {
        return await _cancelSubscriptionAndroid(productId);
      } else {
        log.e("Unsupported platform for subscription cancellation");
        return false;
      }
    } catch (e) {
      log.e("❌ Error cancelling subscription: $e");
      return false;
    }
  }

  Future<bool> openSubscriptionManagement() async {
    final url = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse('https://play.google.com/store/account/subscriptions');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      log.e("❌ Could not open subscription management page");
      return false;
    }
    return true;
  }

  Future<bool> cancelSubscriptionAndSync({
    required String productId,
    String? purchaseId,
  }) async {
    try {
      final canceled = await cancelSubscription(productId);
      if (!canceled) {
        return false;
      }

      // if (purchaseId != null && purchaseId.isNotEmpty) {
      //   await _dbService.collection('Subscriptions').doc(purchaseId).update({
      //     'subscription_status': 'canceled',
      //     'updated_at': FieldValue.serverTimestamp(),
      //   });
      // }

      // auth.appUser.isPremium = false;
      return true;
    } catch (e) {
      log.e("❌ Error syncing cancellation: $e");
      return false;
    }
  }

  ///
  /// Cancel Subscription for iOS
  ///
  Future<bool> _cancelSubscriptionIOS(String productId) async {
    try {
      log.d("🍎 Redirecting iOS user to Apple Subscriptions");

      const url = "https://apps.apple.com/account/subscriptions";

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return true;
      } else {
        throw "Could not open Apple subscriptions";
      }
    } catch (e) {
      log.e("❌ Error cancelling iOS subscription: $e");
      return false;
    }
  }

  ///
  /// Cancel Subscription for Android
  ///
  Future<bool> _cancelSubscriptionAndroid(String productId) async {
    try {
      log.d("🤖 Processing Android subscription cancellation for: $productId");

      // Remove from active purchases locally
      activePurchases.removeWhere((p) => p.productID == productId);

      log.d("✅ Android Subscription cancelled locally: $productId");
      log.d("📱 Android Users must cancel through:");
      log.d("   Google Play Store → Menu → Subscriptions → LAAK → Cancel");
      log.d("   Or visit: https://play.google.com/store/account/subscriptions");

      // In production, you might want to:
      // 1. Direct users to Google Play Subscriptions
      // 2. Use Intent to open Google Play Store
      // 3. Provide deeplink to subscription management

      return true;
    } catch (e) {
      log.e("❌ Error cancelling Android subscription: $e");
      return false;
    }
  }

  ///
  /// Request Refund for Subscription - Platform Specific
  /// Handles refund requests differently for iOS and Android
  ///
  Future<bool> requestRefund(String productId, String reason) async {
    try {
      log.d("Requesting refund for: $productId");
      log.d("Refund reason: $reason");

      // Find the purchase details for this product
      final purchaseToRefund = activePurchases.firstWhere(
        (purchase) => purchase.productID == productId,
        orElse: () => throw Exception("No purchase found for $productId"),
      );

      // Log refund request details
      log.d("Purchase ID: ${purchaseToRefund.purchaseID}");
      log.d("Transaction date: ${purchaseToRefund.transactionDate}");

      // Platform-specific refund logic
      if (Platform.isIOS) {
        return await _requestRefundIOS(productId, reason, purchaseToRefund);
      } else if (Platform.isAndroid) {
        return await _requestRefundAndroid(productId, reason, purchaseToRefund);
      } else {
        log.e("Unsupported platform for refund requests");
        return false;
      }
    } catch (e) {
      log.e("❌ Error requesting refund: $e");
      return false;
    }
  }

  ///
  /// Request Refund for iOS
  ///
  Future<bool> _requestRefundIOS(
    String productId,
    String reason,
    PurchaseDetails purchase,
  ) async {
    try {
      log.d("🍎 Processing iOS refund request for: $productId");

      // Log iOS-specific refund details
      log.d("📋 iOS Refund Process:");
      log.d("   Transaction ID: ${purchase.purchaseID}");
      log.d("   Reason: $reason");

      // iOS refund process information
      log.d("🔄 iOS Users can request refunds through:");
      log.d("   1. Visit: https://reportaproblem.apple.com/");
      log.d("   2. Sign in with Apple ID");
      log.d("   3. Find ThinkLawn subscription");
      log.d("   4. Select 'Request a refund'");
      log.d("   5. Choose reason and submit");

      // In production, you might want to:
      // 1. Generate a refund request ID
      // 2. Send refund details to your backend
      // 3. Track refund status with App Store Server API
      // 4. Send confirmation email to user

      log.d("✅ iOS refund request initiated for: $productId");

      // Don't remove from active purchases until Apple confirms refund
      log.d("⏳ Keeping subscription active until Apple processes refund");

      return true;
    } catch (e) {
      log.e("❌ Error processing iOS refund: $e");
      return false;
    }
  }

  ///
  /// Request Refund for Android
  ///
  Future<bool> _requestRefundAndroid(
    String productId,
    String reason,
    PurchaseDetails purchase,
  ) async {
    try {
      log.d("🤖 Processing Android refund request for: $productId");

      // Log Android-specific refund details
      log.d("📋 Android Refund Process:");
      log.d("   Purchase Token: ${purchase.purchaseID}");
      log.d("   Reason: $reason");

      // Android refund process information
      log.d("🔄 Android Users can request refunds through:");
      log.d(
        "   1. Visit: https://support.google.com/googleplay/contact/play_request_refund_apps",
      );
      log.d("   2. Or Google Play Store → Account → Order history");
      log.d("   3. Find ThinkLawn subscription");
      log.d("   4. Select 'Request a refund'");
      log.d("   5. Follow Google's refund process");

      // Android refund timeline
      log.d("⏰ Google Play refund timeline:");
      log.d("   - Apps/Games: 2 hours for automatic refund");
      log.d("   - Subscriptions: Case-by-case review");
      log.d("   - In-app purchases: 48 hours for review");

      // In production, you might want to:
      // 1. Use Google Play Developer API to initiate refund
      // 2. Send refund request to your backend
      // 3. Track refund status with Google Play Console
      // 4. Handle refund webhooks from Google

      log.d("✅ Android refund request initiated for: $productId");

      // Don't remove from active purchases until Google confirms refund
      log.d("⏳ Keeping subscription active until Google processes refund");

      return true;
    } catch (e) {
      log.e("❌ Error processing Android refund: $e");
      return false;
    }
  }

  ///
  /// Check if User is Subscribed - Platform Specific
  ///
  Future<bool> isUserSubscribed() async {
    try {
      log.d("🔍 Checking subscription status for: ${Platform.operatingSystem}");

      // Debug current state before checking
      debugSubscriptionState();

      // Check if IAP is available
      final isAvailable = await inAppPurchase.isAvailable();
      if (!isAvailable) {
        log.d(
          "IAP not available for subscription check on ${Platform.operatingSystem}",
        );
        return false;
      }

      bool result = false;

      // Platform-specific subscription checking
      if (Platform.isIOS) {
        result = await _isUserSubscribedIOS();
      } else if (Platform.isAndroid) {
        result = await _isUserSubscribedAndroid();
      } else {
        log.e(
          "Unsupported platform for subscription check: ${Platform.operatingSystem}",
        );
        return false;
      }

      log.d("🎯 Final subscription result: $result");
      return result;
    } catch (e) {
      log.e("❌ Error checking subscription status: $e");
      return false;
    }
  }

  ///
  /// Check iOS Subscription Status
  ///
  Future<bool> _isUserSubscribedIOS() async {
    try {
      log.d("🍎 Checking iOS subscription status");
      log.d("🍎 Current active purchases count: ${activePurchases.length}");

      // Log current active purchases
      for (var purchase in activePurchases) {
        log.d(
          "🍎 Active purchase: ${purchase.productID} - Status: ${purchase.status}",
        );
      }

      // Restore purchases to get existing purchases
      log.d("🍎 Restoring purchases...");
      await inAppPurchase.restorePurchases();

      // Give the purchase stream time to emit restored items
      await Future.delayed(const Duration(milliseconds: 500));

      log.d(
        "🍎 After restore - Active purchases count: ${activePurchases.length}",
      );

      // Check if we have any active purchases for our subscription products
      final hasActivePurchase = activePurchases.any(
        (purchase) =>
            productIds.contains(purchase.productID) &&
            (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored),
      );

      log.d("🍎 Product IDs to check: $productIds");
      log.d("🍎 Has active purchase: $hasActivePurchase");

      if (hasActivePurchase) {
        log.d("🍎 iOS user has active subscription");
        // Log which specific subscription is active
        final activeSubscriptions = activePurchases.where(
          (purchase) =>
              productIds.contains(purchase.productID) &&
              (purchase.status == PurchaseStatus.purchased ||
                  purchase.status == PurchaseStatus.restored),
        );
        for (var sub in activeSubscriptions) {
          log.d("🍎 Active subscription: ${sub.productID}");
        }
        return true;
      }

      log.d("🍎 No active iOS subscription found");
      return false;
    } catch (e) {
      log.e("❌ Error checking iOS subscription: $e");
      return false;
    }
  }

  ///
  /// Check Android Subscription Status
  ///
  Future<bool> _isUserSubscribedAndroid() async {
    try {
      log.d("🤖 Checking Android subscription status");
      log.d("🤖 Current active purchases count: ${activePurchases.length}");

      // Log current active purchases
      for (var purchase in activePurchases) {
        log.d(
          "🤖 Active purchase: ${purchase.productID} - Status: ${purchase.status}",
        );
      }

      // Restore purchases to get existing purchases
      log.d("🤖 Restoring purchases...");
      await inAppPurchase.restorePurchases();

      log.d(
        "🤖 After restore - Active purchases count: ${activePurchases.length}",
      );

      // Check if we have any active purchases for our subscription products
      final hasActivePurchase = activePurchases.any(
        (purchase) =>
            productIds.contains(purchase.productID) &&
            (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored),
      );

      log.d("🤖 Product IDs to check: $productIds");
      log.d("🤖 Has active purchase: $hasActivePurchase");

      if (hasActivePurchase) {
        log.d("🤖 Android user has active subscription");
        // Log which specific subscription is active
        final activeSubscriptions = activePurchases.where(
          (purchase) =>
              productIds.contains(purchase.productID) &&
              (purchase.status == PurchaseStatus.purchased ||
                  purchase.status == PurchaseStatus.restored),
        );
        for (var sub in activeSubscriptions) {
          log.d("🤖 Active subscription: ${sub.productID}");
        }
        return true;
      }

      log.d("🤖 No active Android subscription found");
      return false;
    } catch (e) {
      log.e("❌ Error checking Android subscription: $e");
      return false;
    }
  }

  ///
  /// Dispose service and cancel subscriptions
  ///
  void dispose() {
    try {
      subscription.cancel();
      _purchaseCompleter?.complete(false);
      log.d("🧹 Subscription service disposed");
    } catch (e) {
      log.e("❌ Error disposing subscription service: $e");
    }
  }

  ///
  /// Complete purchase process (iOS)
  ///
  void _completePurchase(bool success) {
    if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
      _purchaseCompleter!.complete(success);
      log.d("✅ Purchase completer completed with: $success");
    }
  }

  ///
  /// Debug method to print current subscription state
  ///
  void debugSubscriptionState() {
    log.d("🔍 === SUBSCRIPTION DEBUG INFO ===");
    log.d("Platform: ${Platform.operatingSystem}");
    log.d("Product IDs: $productIds");
    log.d("Active purchases count: ${activePurchases.length}");
    log.d("Subscription plans count: ${subscriptionPlans.length}");

    if (activePurchases.isEmpty) {
      log.d("❌ No active purchases found");
    } else {
      log.d("✅ Active purchases:");
      for (int i = 0; i < activePurchases.length; i++) {
        final purchase = activePurchases[i];
        log.d("  ${i + 1}. Product: ${purchase.productID}");
        log.d("     Status: ${purchase.status}");
        log.d("     Purchase ID: ${purchase.purchaseID}");
        log.d("     Transaction Date: ${purchase.transactionDate}");
        log.d("     Verified Receipt: ${purchase.verificationData.source}");
      }
    }

    if (subscriptionPlans.isEmpty) {
      log.d("❌ No subscription plans loaded");
    } else {
      log.d("✅ Available subscription plans:");
      for (int i = 0; i < subscriptionPlans.length; i++) {
        final plan = subscriptionPlans[i];
        log.d(
          "  ${i + 1}. ${plan.product?.id ?? 'Unknown ID'} - ${plan.product?.price ?? 'Unknown Price'}",
        );
        log.d("     Selected: ${plan.isSelected}");
      }
    }
    log.d("🔍 === END DEBUG INFO ===");
  }

  }

 