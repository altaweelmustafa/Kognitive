/// Picks a profile photo and returns it ready to upload: a small square
/// image, or null if the player didn't choose one.
///
/// The web app uses `web/photo.js` (the browser decodes and shrinks the
/// photo, which avoids Safari's trouble with the image_picker plugin on the
/// web); the phone and desktop apps use image_picker.
library;

export 'photo_picker_native.dart'
    if (dart.library.js_interop) 'photo_picker_web.dart';
