import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Turns any photo into the profile picture the server keeps: the largest
/// centred square, shrunk to [size] pixels, as PNG. Done on the device, so
/// a 10 MB camera photo becomes a small upload.
Future<Uint8List> squareAvatar(Uint8List photo, {int size = 256}) async {
  final codec = await ui.instantiateImageCodec(photo);
  final image = (await codec.getNextFrame()).image;
  final side = min(image.width, image.height).toDouble();
  final source = ui.Rect.fromLTWH(
    (image.width - side) / 2,
    (image.height - side) / 2,
    side,
    side,
  );

  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    image,
    source,
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final square = await recorder.endRecording().toImage(size, size);
  final png = await square.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  square.dispose();
  return png!.buffer.asUint8List();
}
