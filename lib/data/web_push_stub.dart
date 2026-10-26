/// Phone and desktop apps: Web Push isn't available.
abstract final class WebPush {
  static bool get available => false;
  static bool get secure => false;
  static bool get ios => false;
  static bool get standalone => false;

  /// 'default', 'granted', 'denied' or 'unsupported'.
  static String get permission => 'unsupported';
  static String? get timeZone => null;

  static Future<Map<String, dynamic>> subscribe(String serverKey) =>
      throw UnsupportedError('Web Push is only in the web app.');
  static Future<Map<String, dynamic>?> current() async => null;
  static Future<String?> unsubscribe() async => null;
}
