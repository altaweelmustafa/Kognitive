import 'package:flutter/foundation.dart';

/// Backend address.
///
/// - Phones and desktop default to the hosted server on the tailnet (the
///   device must be connected to Tailscale).
/// - The website defaults to the server it was loaded from, because the
///   backend serves the web build itself.
///
/// To point at another backend, e.g. one on your own machine:
/// `flutter run --dart-define=API_BASE_URL=http://localhost:8000`
/// (use `http://10.0.2.2:8000` from the Android emulator).
abstract final class ApiConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');
  static const _hosted = 'http://100.105.90.110:8000';

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    return kIsWeb ? Uri.base.origin : _hosted;
  }
}
