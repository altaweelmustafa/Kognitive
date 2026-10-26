{{flutter_js}}
{{flutter_build_config}}

// Flutter's own service worker is left out: sw.js handles notifications,
// and a page can only have one service worker.
_flutter.loader.load();
