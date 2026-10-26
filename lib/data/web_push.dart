/// Notifications in the web app (Web Push), via `web/push.js`. Elsewhere
/// (phone and desktop apps) every call says "not available".
library;

export 'web_push_stub.dart' if (dart.library.js_interop) 'web_push_web.dart';
