import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which game tutorials the player has finished or skipped,
/// so each one only shows the first time.
abstract final class Tutorials {
  /// While testing, every game shows its tutorial every time.
  /// Set to false to show each one only once.
  static const alwaysShow = true;

  static String _key(String gameId) => 'tutorial_seen_$gameId';

  static Future<bool> shouldShow(String gameId) async {
    if (alwaysShow) return true;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_key(gameId)) ?? false);
  }

  static Future<void> markSeen(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(gameId), true);
  }
}
