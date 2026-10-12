import 'package:http/http.dart' as http;

import '../../data/api_client.dart';
import 'chess_models.dart';

/// Client for the backend's `/chess/puzzles` endpoints.
class ChessApi {
  ChessApi({http.Client? client, String? baseUrl})
    : _api = ApiClient(client: client, baseUrl: baseUrl);

  final ApiClient _api;
  static const _path = '/chess/puzzles';

  Future<ChessPuzzle> daily() async =>
      ChessPuzzle.fromJson(await _api.get('$_path/daily'));

  Future<ChessPuzzle> next() async =>
      ChessPuzzle.fromJson(await _api.get('$_path/next'));

  Future<ChessMoveResult> move(String puzzleId, int step, String uci) async =>
      ChessMoveResult.fromJson(
        await _api.post('$_path/$puzzleId/moves', {'step': step, 'move': uci}),
      );

  /// The (from, to) squares of the move to find.
  Future<(String, String)> hint(String puzzleId, int step) async {
    final j = await _api.get('$_path/$puzzleId/hint?step=$step');
    return (j['from'] as String, j['to'] as String);
  }

  Future<void> recordAttempt(
    String puzzleId, {
    required bool solved,
    required int mistakes,
    required int hints,
    required Duration duration,
  }) => _api.post('$_path/$puzzleId/attempts', {
    'solved': solved,
    'mistakes': mistakes,
    'hints': hints,
    'duration_ms': duration.inMilliseconds,
  });
}
