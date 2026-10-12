/// Backend address. Defaults to the hosted server on the tailnet (the device
/// must be connected to Tailscale).
///
/// For a backend on your own machine:
/// `flutter run --dart-define=API_BASE_URL=http://localhost:8000`
/// (use `http://10.0.2.2:8000` from the Android emulator).
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://100.105.90.110:8000',
  );
}
