import 'package:flutter_subscriptions/core/enums/purchase_status.dart';
import 'package:flutter_subscriptions/core/enums/store_type.dart';

class Purchase {
  int? id;
  int? userId;
  int? subscriptionId;

  // String? type; // PURCHASED, RENEWED, CANCELED, EXPIRED, REFUNDED
  StoreType? store; // APPLE, GOOGLE, INTERNAL

  String? transactionId;
  String? originalTransactionId;
  String? purchaseToken;
  String? orderId;
  Plan? plan;
  String? renewalStatus; // SCHEDULED, CANCELED, UNKNOWN, NOT_APPLICABLE
  PurchaseStatus?
  status; // ACTIVE, IN_GRACE, ON_HOLD, PAUSED, EXPIRED, CANCELED, REFUNDED

  String? periodStartAt;
  String? periodEndAt;
  DateTime? graceEndsAt;

  int? reportQuota;
  int? reportUsed;

  double? priceAmount;
  String? priceCurrency;

  String? verificationSource; // APPLE_SERVER, GOOGLE_SERVER, INTERNAL, UNKNOWN
  DateTime? verifiedAt;

  String? rawReceipt;
  String? signaturePayload;

  DateTime? createdAt;
  DateTime? updatedAt;

  Purchase({
    this.id,
    this.userId,
    this.subscriptionId,

    this.store,
    this.plan,
    this.transactionId,
    this.originalTransactionId,
    this.purchaseToken,
    this.orderId,
    this.renewalStatus,
    this.status,
    this.periodStartAt,
    this.periodEndAt,
    this.graceEndsAt,
    this.reportQuota,
    this.reportUsed = 0,
    this.priceAmount,
    this.priceCurrency,
    this.verificationSource,
    this.verifiedAt,
    this.rawReceipt,
    this.signaturePayload,
    this.createdAt,
    this.updatedAt,
  });

  /// Create a Purchase instance from JSON
  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'],
      userId: json['user_id'],
      subscriptionId: json['subscription_id'],
      store: StoreTypeX.fromString(json['store']),
      transactionId: json['transaction_id'],
      originalTransactionId: json['original_transaction_id'],
      purchaseToken: json['purchase_token'],
      orderId: json['order_id'],
      renewalStatus: json['renewal_status'],
      status: PurchaseStatusX.fromString(json['status']),
      plan: json['plan'] != null ? Plan.fromJson(json['plan']) : null,
      periodStartAt: json['period_start_at'],
      periodEndAt: json['period_end_at'],
      graceEndsAt: json['grace_ends_at'] != null
          ? DateTime.parse(json['grace_ends_at'])
          : null,
      reportQuota: json['report_quota'],
      reportUsed: json['report_used'] ?? 0,
      priceAmount: json['price_amount'] != null
          ? double.tryParse(json['price_amount'].toString())
          : null,
      priceCurrency: json['price_currency'],
      verificationSource: json['verification_source'],
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'])
          : null,
      rawReceipt: json['raw_receipt'],
      signaturePayload: json['signature_payload'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  factory Purchase.fromPurchaseDetails(Map<String, dynamic> json) {
    return Purchase(
      subscriptionId: json['id'],
      status: PurchaseStatusX.fromString(json['status'].toString()),
      store: StoreTypeX.fromString(json['verificationSource'].toString()),
      orderId: json['purchaseID'],
      periodStartAt: DateTime.fromMillisecondsSinceEpoch(
        int.parse(json['transactionDate'].toString()),
        isUtc: true,
      ).toIso8601String().toString(),
    );
  }

  /// Convert Purchase instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'subscription_id': subscriptionId,

      'store': store,
      'transaction_id': transactionId,
      'original_transaction_id': originalTransactionId,
      'purchase_token': purchaseToken,
      'order_id': orderId,
      'renewal_status': renewalStatus,
      'status': status,
      'plan': plan?.toJson(),
      'period_start_at': periodStartAt,
      'period_end_at': periodEndAt,
      'grace_ends_at': graceEndsAt?.toIso8601String(),
      'report_quota': reportQuota,
      'report_used': reportUsed,
      'price_amount': priceAmount,
      'price_currency': priceCurrency,
      'verification_source': verificationSource,
      'verified_at': verifiedAt?.toIso8601String(),
      'raw_receipt': rawReceipt,
      'signature_payload': signaturePayload,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class Plan {
  int? id;
  String? key;
  String? title;
  String? durationUnit;
  int? durationCount;
  String? priceAmount;
  String? priceCurrency;
  String? tag;

  Plan({
    this.id,
    this.key,
    this.title,
    this.durationUnit,
    this.durationCount,
    this.priceAmount,
    this.priceCurrency,
    this.tag,
  });

  Plan.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    key = json['key'];
    title = json['title'];
    durationUnit = json['duration_unit'];
    durationCount = json['duration_count'];
    priceAmount = json['price_amount'];
    priceCurrency = json['price_currency'];
    tag = json['tag'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['key'] = key;
    data['title'] = title;
    data['duration_unit'] = durationUnit;
    data['duration_count'] = durationCount;
    data['price_amount'] = priceAmount;
    data['price_currency'] = priceCurrency;
    data['tag'] = tag;
    return data;
  }
}
