import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_subscriptions/locator.dart';
import 'package:flutter_subscriptions/core/models/custom_logger.dart';
import 'package:flutter_subscriptions/core/services/subscription_service.dart';

/// ------------------------------------------------------------
/// SubscriptionProvider
/// ------------------------------------------------------------
///
/// Handles:
/// - Fetching subscription products
/// - Managing selected plans
/// - Listening to purchase updates
/// - Activating / refreshing subscriptions
/// - Handling free trials
///
/// This provider is safe against widget disposal
/// and avoids duplicate purchase handling.
///
class SubscriptionProvider with ChangeNotifier {
  /// Logger instance
  final log = CustomLogger(className: '@SubscriptionProvider');

  /// Subscription service abstraction
  final SubscriptionService subscription = locator<SubscriptionService>();

  /// In-app purchase instance
  final InAppPurchase inAppPurchase = InAppPurchase.instance;

  /// Purchase stream subscription
  StreamSubscription<List<PurchaseDetails>>? _purchaseStream;

  /// UI / State flags
  bool isPurchaseInProgress = false;
  bool _isDisposed = false;

  /// Selected plan index
  int selectedPlanIndex = 0;

  /// Subscription products
  List<SubsPlan> products = [];

  /// Prevent duplicate success callbacks
  String? _lastSuccessPurchaseId;

  /// Latest subscription snapshot (Firestore)
  Map<String, dynamic>? latestSubscription;

  /// Optional callback after successful purchase
  VoidCallback? onPurchaseCompleted;

  /// Testimonials UI state
  int currentTestimonialIndex = 0;
  final PageController testimonialController = PageController();

  /// ------------------------------------------------------------
  /// Constructor
  /// ------------------------------------------------------------
  SubscriptionProvider() {
    initializeInAppPurchase();
    fetchLatestSubscription();
  }

  /// ------------------------------------------------------------
  /// Testimonials
  /// ------------------------------------------------------------
final List<Testimonial> testimonials = [
    Testimonial(
      name: "User 1",
      location: "City, Country",
      rating: 5,
      review: "This app made understanding food for my child so easy!",
    ),
    Testimonial(
      name: "User 2",
      location: "City, Country",
      rating: 4,
      review: "Very helpful and fast barcode scanning.",
    ),
    Testimonial(
      name: "User 3",
      location: "City, Country",
      rating: 5,
      review: "I love getting instant, age-specific ratings for products.",
    ),
  ];
  
  /// Update testimonial page index
  void updateCurrentTestimonialIndex(int index) {
    currentTestimonialIndex = index;
    _safeNotify();
  }

  /// ------------------------------------------------------------
  /// Plan Selection
  /// ------------------------------------------------------------
  void selectPlan(int index) {
    for (int i = 0; i < products.length; i++) {
      products[i].isSelected = i == index;
    }
    selectedPlanIndex = index;
    _safeNotify();
  }

  /// ------------------------------------------------------------
  /// Initialize In-App Purchase
  /// ------------------------------------------------------------
  Future<void> initializeInAppPurchase() async {
    final isAvailable = await inAppPurchase.isAvailable();
    if (!isAvailable) {
      log.w("In-App Purchases not available");
      return;
    }

    /// Listen to purchase updates only once
    _purchaseStream ??= inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (e) {
        log.e("Purchase stream error: $e");
        isPurchaseInProgress = false;
        _safeNotify();
      },
    );

    /// Fetch products from store
    final response = await inAppPurchase.queryProductDetails(
      subscription.productIds.toSet(),
    );

    if (response.notFoundIDs.isNotEmpty) {
      log.w("Missing product IDs: ${response.notFoundIDs}");
    }

    _prepareProducts(response.productDetails);
  }

  /// Sort & map products into local model
  void _prepareProducts(List<ProductDetails> details) {
    final sorted = List<ProductDetails>.from(details)
      ..sort((a, b) => a.title.compareTo(b.title));

    products.clear();

    for (int i = 0; i < sorted.length; i++) {
      products.add(
        SubsPlan(
          product: sorted[i],
          isSelected: i == 0,
          isVisiblePlan: i != 0,
          displayPrice: sorted[i].price,
        ),
      );
    }

    _safeNotify();
  }

  /// ------------------------------------------------------------
  /// Start Purchase Flow
  /// ------------------------------------------------------------
  Future<void> startPurchase(ProductDetails product) async {
    if (isPurchaseInProgress) return;

    isPurchaseInProgress = true;
    _safeNotify();

    try {
      final started = await subscription.buyProduct(product);
      if (!started) {
        isPurchaseInProgress = false;
        _safeNotify();
      }
    } catch (e, s) {
      log.e("Failed to start purchase: $e $s");
      isPurchaseInProgress = false;
      _safeNotify();
    }
  }

  /// ------------------------------------------------------------
  /// Handle Purchase Updates
  /// ------------------------------------------------------------
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    if (_isDisposed) return;

    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _processSuccessfulPurchase(purchase);
      }

      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        isPurchaseInProgress = false;
        _safeNotify();
      }

      if (purchase.pendingCompletePurchase) {
        await inAppPurchase.completePurchase(purchase);
      }
    }
  }

  /// Handle successful purchase logic
  Future<void> _processSuccessfulPurchase(PurchaseDetails purchase) async {
    final purchaseId = purchase.purchaseID;
    if (purchaseId == null || purchaseId.isEmpty) return;

    _notifyPurchaseSuccess(purchaseId);
    isPurchaseInProgress = false;
    _safeNotify();
  }

  /// ------------------------------------------------------------
  /// Free Trial Handling
  /// ------------------------------------------------------------
  // bool isEligibleForFreeTrial() => auth.appUser.hasUsedFreeTrial != true;

  /// ------------------------------------------------------------
  /// Helpers
  /// ------------------------------------------------------------
  double getPriceForProduct(String productId) {
    try {
      final plan = products.firstWhere((p) => p.product?.id == productId);
      return plan.product?.rawPrice ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  void _notifyPurchaseSuccess(String purchaseId) {
    if (_lastSuccessPurchaseId == purchaseId) return;
    _lastSuccessPurchaseId = purchaseId;
    onPurchaseCompleted?.call();
  }

/// Returns a user-friendly title for a product
  String getDisplayTitle(ProductDetails product) {
    if (product.id.contains('weekly')) return 'Weekly';
    if (product.id.contains('monthly')) return 'Monthly';
    if (product.id.contains('yearly')) return 'Yearly';
    return product.title;
  }

/// Whether user currently has an active subscription
  bool get isPremium => latestSubscription != null;

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  /// ------------------------------------------------------------
  /// Firestore Fetch (stub)
  /// ------------------------------------------------------------
  Future<void> fetchLatestSubscription() async {
    // Implement Firestore logic if needed
  }

  /// ------------------------------------------------------------
  /// Dispose
  /// ------------------------------------------------------------
  @override
  void dispose() {
    _isDisposed = true;
    _purchaseStream?.cancel();
    testimonialController.dispose();
    super.dispose();
  }
}

class SubsPlan {
  final ProductDetails? product;
  bool isSelected;
  final bool isVisiblePlan;
  final String displayPrice;

  SubsPlan({
    this.product,
    this.isSelected = false,
    required this.isVisiblePlan,
    required this.displayPrice,
  });
}

class Testimonial {
  final String name;
  final String location;
  final int rating;
  final String review;

  Testimonial({
    required this.name,
    required this.location,
    required this.rating,
    required this.review,
  });
}
