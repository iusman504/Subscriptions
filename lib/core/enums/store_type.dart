/// Purchase source/platform
enum StoreType { apple, google_play, internal }

extension StoreTypeX on StoreType {
  /// Converts backend string to enum
  static StoreType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'APPLE':
        return StoreType.apple;
      case 'GOOGLE_PLAY':
        return StoreType.google_play;
      case 'INTERNAL':
        return StoreType.internal;
      default:
        return StoreType.internal;
    }
  }

  /// Converts enum to backend-compatible string
  String get apiValue {
    switch (this) {
      case StoreType.apple:
        return 'APPLE';
      case StoreType.google_play:
        return 'GOOGLE_PLAY';
      case StoreType.internal:
        return 'INTERNAL';
    }
  }
}
