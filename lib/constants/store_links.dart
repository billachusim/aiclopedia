import 'dart:io';

/// Public store links used in share text.
class StoreLinks {
  StoreLinks._();

  static const String playUrl =
      'https://play.google.com/store/apps/details?id=com.socialfaculty.AiClopedia';

  /// Apple ID of the App Store record (numbers only).
  static const String appStoreId = '';

  static String get appStoreUrl => appStoreId.isEmpty
      ? playUrl
      : 'https://apps.apple.com/app/id$appStoreId';

  static String get forThisPlatform =>
      Platform.isIOS ? appStoreUrl : playUrl;
}
