/// Matches backend + adds UNPAID for when user has no active purchase
enum PurchaseStatus {
  unpaid,
  active,
  inGrace,
  onHold,
  paused,
  expired,
  canceled,
  refunded,
  restored,
}
// PurchaseStatus.restored

extension PurchaseStatusX on PurchaseStatus {
  /// Converts backend string to enum (handles nulls too)
  static PurchaseStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'ACTIVE':
      case 'RESTORED':
        return PurchaseStatus.active;
      case 'IN_GRACE':
        return PurchaseStatus.inGrace;
      case 'ON_HOLD':
        return PurchaseStatus.onHold;
      case 'PAUSED':
        return PurchaseStatus.paused;
      case 'EXPIRED':
        return PurchaseStatus.expired;
      case 'CANCELED':
        return PurchaseStatus.canceled;
      case 'REFUNDED':
        return PurchaseStatus.refunded;
      default:
        return PurchaseStatus.unpaid;
    }
  }

  /// Converts enum to backend-compatible string
  String get apiValue {
    switch (this) {
      case PurchaseStatus.unpaid:
        return 'UNPAID';
      case PurchaseStatus.active:
      case PurchaseStatus.restored:
        return 'ACTIVE';
      case PurchaseStatus.inGrace:
        return 'IN_GRACE';
      case PurchaseStatus.onHold:
        return 'ON_HOLD';
      case PurchaseStatus.paused:
        return 'PAUSED';
      case PurchaseStatus.expired:
        return 'EXPIRED';
      case PurchaseStatus.canceled:
        return 'CANCELED';
      case PurchaseStatus.refunded:
        return 'REFUNDED';
    }
  }
}
