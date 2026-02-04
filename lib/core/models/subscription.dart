import 'package:in_app_purchase/in_app_purchase.dart';

class Subscription {
  int? id;
  String? key;
  String? title;
  String? description;
  String? tag;
  String? source;
  String? durationUnit;
  int? durationCount;
  String? currency;
  double? priceAmount;
  int? savePercent;
  String? status;
  int? order;
  String? productId;
  String? bundleId;
  int? defaultReportQuota;
  ProductDetails? product;
  bool? isSelected;
  String? createdAt;
  String? updatedAt;

  Subscription({
    this.id,
    this.key,
    this.title,
    this.description,
    this.tag,
    this.source,
    this.durationUnit,
    this.durationCount,
    this.currency,
    this.priceAmount,
    this.savePercent,
    this.status,
    this.order,
    this.productId,
    this.bundleId,
    this.product,
    this.isSelected = false,
    this.defaultReportQuota,
    this.createdAt,
    this.updatedAt,
  });

  Subscription.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    key = json['key'];
    title = json['title'];
    description = json['description'];
    tag = json['tag'];
    source = json['source'];
    durationUnit = json['duration_unit'];
    durationCount = json['duration_count'];
    currency = json['currency'];
    priceAmount = json['price_amount'] is int
        ? (json['price_amount'] as int).toDouble()
        : json['price_amount'] is double
        ? json['price_amount']
        : null;
    savePercent = json['save_percent'];
    status = json['status'];
    order = json['order'];
    productId = json['product_id'];
    bundleId = json['bundle_id'];
    defaultReportQuota = json['default_report_quota'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['key'] = key;
    data['title'] = title;
    data['description'] = description;
    data['tag'] = tag;
    data['source'] = source;
    data['duration_unit'] = durationUnit;
    data['duration_count'] = durationCount;
    data['currency'] = currency;
    data['price_amount'] = priceAmount;
    data['save_percent'] = savePercent;
    data['status'] = status;
    data['order'] = order;
    data['product_id'] = productId;
    data['bundle_id'] = bundleId;
    data['default_report_quota'] = defaultReportQuota;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    return data;
  }
}
