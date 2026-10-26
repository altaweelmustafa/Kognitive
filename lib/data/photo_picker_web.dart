import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('kognitivPhoto.pick')
external JSPromise<JSString> _pick(int size);

/// The web app: `web/photo.js` opens the picker and hands back a square
/// JPEG. Call straight from a tap, before any await: Safari only opens the
/// picker from a tap.
Future<Uint8List?> pickAvatarPhoto({int size = 256}) async {
  final String data;
  try {
    data = (await _pick(size).toDart).toDart;
  } catch (e) {
    // A JS Error: say what the browser said.
    throw StateError(e.toString().replaceFirst('Error: ', ''));
  }
  return data.isEmpty ? null : base64Decode(data);
}
