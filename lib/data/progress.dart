import 'package:flutter/foundation.dart';

import '../models/progress_models.dart';
import 'api_client.dart';

/// Today's session, the player's performance, and the state of the games
/// outside the session, from the backend.
/// Listen to it to rebuild when they change.
class Progress extends ChangeNotifier {
  Progress._();
  static final instance = Progress._();

  SessionPlan? plan;
  Performance? performance;
  TodayStatus? today;

  /// The last refresh couldn't reach the server.
  bool failed = false;

  /// Call at login, after every finished game, and after a Sudoku is saved.
  Future<void> refresh() async {
    final api = ApiClient();
    try {
      final results = await Future.wait([
        api.get('/session/today'),
        api.get('/me/performance'),
        api.get('/me/today'),
      ]);
      today = TodayStatus.fromJson(results[2]);
      plan = SessionPlan.fromJson(results[0]);
      performance = Performance.fromJson(results[1]);
      failed = false;
    } on ApiException {
      failed = true;
    }
    notifyListeners();
  }

  void clear() {
    plan = null;
    performance = null;
    today = null;
    failed = false;
    notifyListeners();
  }
}
