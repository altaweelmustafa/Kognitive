import 'package:http/http.dart' as http;

import '../../data/api_client.dart';
import 'sudoku_models.dart';

/// Client for the backend's `/sudoku/puzzles` endpoints.
class SudokuApi {
  SudokuApi({http.Client? client, String? baseUrl})
    : _api = ApiClient(client: client, baseUrl: baseUrl);

  final ApiClient _api;
  static const _path = '/sudoku/puzzles';

  Future<SudokuPuzzle> daily() async =>
      SudokuPuzzle.fromJson(await _api.get('$_path/daily'));

  Future<SudokuPuzzle> next(SudokuDifficulty difficulty) async =>
      SudokuPuzzle.fromJson(
        await _api.get('$_path/next?difficulty=${difficulty.name}'),
      );

  /// A specific puzzle, with the player's saved game on it.
  Future<SudokuPuzzle> puzzle(String id) async =>
      SudokuPuzzle.fromJson(await _api.get('$_path/$id'));

  /// Unfinished games, most recent first.
  Future<List<SudokuSaveSummary>> saves() async {
    final r = await _api.get('$_path/saves');
    return [
      for (final s in r['saves'] as List)
        SudokuSaveSummary.fromJson(s as Map<String, dynamic>),
    ];
  }

  Future<void> save(String puzzleId, SudokuSave save) =>
      _api.put('$_path/$puzzleId/save', save.toJson());

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
