import 'dart:convert';
import 'dart:js_interop';

@JS('kognitivPush')
external _Push? get _push;

extension type _Push(JSObject _) implements JSObject {
  external bool secure();
  external bool supported();
  external bool ios();
  external bool standalone();
  external String permission();
  external String timeZone();
  external JSPromise<JSString> subscribe(String serverKey);
  external JSPromise<JSString> current();
  external JSPromise<JSString> unsubscribe();
}

/// The web app: talks to `web/push.js`.
abstract final class WebPush {
  /// The browser can do Web Push here: a secure page with the APIs present.
  /// On iPhone that means the app opened from the Home Screen.
  static bool get available =>
      (_push?.secure() ?? false) && (_push?.supported() ?? false);
  static bool get secure => _push?.secure() ?? false;
  static bool get ios => _push?.ios() ?? false;
  static bool get standalone => _push?.standalone() ?? false;

  /// 'default', 'granted', 'denied' or 'unsupported'.
  static String get permission => _push?.permission() ?? 'unsupported';

  /// The device's IANA time zone, e.g. 'Europe/Berlin'.
  static String? get timeZone => _push?.timeZone();

  /// Asks permission and subscribes. Call it straight from a tap, before any
  /// await: iPhones only allow the permission prompt from a tap.
  /// Throws a [StateError] with 'denied' or 'default' if permission wasn't
  /// given, or with the browser's own message if subscribing failed.
  static Future<Map<String, dynamic>> subscribe(String serverKey) async {
    try {
      final json = (await _push!.subscribe(serverKey).toDart).toDart;
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      // A JS Error: "Error: permission:denied" from push.js, or the
      // browser's own reason the subscription failed.
      final message = e.toString();
      throw StateError(switch (message) {
        _ when message.contains('permission:denied') => 'denied',
        _ when message.contains('permission:default') => 'default',
        _ => message,
      });
    }
  }

  /// This device's subscription, or null.
  static Future<Map<String, dynamic>?> current() async {
    final json = (await _push!.current().toDart).toDart;
    return json.isEmpty ? null : jsonDecode(json) as Map<String, dynamic>;
  }

  /// Unsubscribes this device. Returns the endpoint it had, or null.
  static Future<String?> unsubscribe() async {
    final endpoint = (await _push!.unsubscribe().toDart).toDart;
    return endpoint.isEmpty ? null : endpoint;
  }
}
