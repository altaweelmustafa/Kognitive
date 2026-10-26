import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'avatar_image.dart';

/// Phone and desktop apps: the system photo picker, then a square PNG.
Future<Uint8List?> pickAvatarPhoto({int size = 256}) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    // Plenty for the avatar, and much quicker to read.
    maxWidth: 1024,
    maxHeight: 1024,
  );
  if (file == null) return null;
  return squareAvatar(await file.readAsBytes(), size: size);
}
