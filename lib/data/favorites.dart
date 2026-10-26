import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Library articles the player has saved, kept on the server so they follow
/// the account to every device. Listen to it to rebuild when it changes.
class Favorites extends ChangeNotifier {
  Favorites._();
  static final instance = Favorites._();

  /// Saved article ids, most recently saved first. Empty until [load].
  List<String> ids = const [];
  bool loaded = false;

  ApiClient get _api => ApiClient();

  bool contains(String id) => ids.contains(id);

  Future<void> load() async {
    try {
      final r = await _api.get('/library/favorites');
      ids = (r['ids'] as List).cast<String>();
      loaded = true;
      notifyListeners();
    } on ApiException {
      // Keep what we had; the library still works without favourites.
    }
  }

  /// Saves or unsaves [id]. The change shows at once and is undone if the
  /// server refuses it. Throws [ApiException] in that case.
  Future<void> toggle(String id) async {
    final saving = !contains(id);
    final before = ids;
    ids = saving ? [id, ...ids] : ids.where((i) => i != id).toList();
    notifyListeners();
    try {
      if (saving) {
        await _api.put('/library/favorites/$id', const {});
      } else {
        await _api.delete('/library/favorites/$id');
      }
    } on ApiException {
      ids = before;
      notifyListeners();
      rethrow;
    }
  }

  /// On logout.
  void clear() {
    ids = const [];
    loaded = false;
    notifyListeners();
  }
}
