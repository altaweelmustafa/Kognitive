/// Board position and what the player may do in it. Mirrors the backend's
/// puzzle state.
class ChessState {
  ChessState({
    required this.fen,
    required this.lastMove,
    required this.legalMoves,
    required this.check,
    required this.step,
    required this.totalSteps,
    required this.solved,
  }) : pieces = _parsePlacement(fen),
       whiteToMove = fen.split(' ')[1] == 'w';

  factory ChessState.fromJson(Map<String, dynamic> j) => ChessState(
    fen: j['fen'] as String,
    lastMove: j['last_move'] as String?,
    legalMoves: (j['legal_moves'] as List).cast<String>(),
    check: j['check'] as bool,
    step: j['step'] as int,
    totalSteps: j['total_steps'] as int,
    solved: j['solved'] as bool,
  );

  final String fen;
  final String? lastMove; // UCI
  final List<String> legalMoves; // UCI
  final bool check;
  final int step; // player moves made so far
  final int totalSteps;
  final bool solved;

  /// Square name → piece code: color + type, e.g. `wk`, `bp`.
  final Map<String, String> pieces;
  final bool whiteToMove;

  /// Square of the king that is to move.
  String? get kingSquare {
    final king = whiteToMove ? 'wk' : 'bk';
    for (final e in pieces.entries) {
      if (e.value == king) return e.key;
    }
    return null;
  }

  static Map<String, String> _parsePlacement(String fen) {
    final pieces = <String, String>{};
    final ranks = fen.split(' ').first.split('/');
    for (var r = 0; r < 8; r++) {
      var file = 0;
      for (final ch in ranks[r].split('')) {
        final skip = int.tryParse(ch);
        if (skip != null) {
          file += skip;
          continue;
        }
        final lower = ch.toLowerCase();
        pieces['${'abcdefgh'[file]}${8 - r}'] =
            '${ch == lower ? 'b' : 'w'}$lower';
        file++;
      }
    }
    return pieces;
  }
}

class ChessPuzzle {
  ChessPuzzle({
    required this.id,
    required this.rating,
    required this.themes,
    required this.playsWhite,
    required this.state,
  });

  factory ChessPuzzle.fromJson(Map<String, dynamic> j) => ChessPuzzle(
    id: j['id'] as String,
    rating: j['rating'] as int?,
    themes: (j['themes'] as List).cast<String>(),
    playsWhite: j['player_color'] == 'white',
    state: ChessState.fromJson(j['state'] as Map<String, dynamic>),
  );

  final String id;
  final int? rating;
  final List<String> themes;
  final bool playsWhite;
  final ChessState state;
}

class ChessMoveResult {
  ChessMoveResult({
    required this.correct,
    required this.afterMove,
    required this.state,
  });

  factory ChessMoveResult.fromJson(Map<String, dynamic> j) => ChessMoveResult(
    correct: j['correct'] as bool,
    afterMove: j['after_move'] == null
        ? null
        : ChessState.fromJson(j['after_move'] as Map<String, dynamic>),
    state: ChessState.fromJson(j['state'] as Map<String, dynamic>),
  );

  final bool correct;

  /// Position right after the player's move, before the opponent replies.
  final ChessState? afterMove;
  final ChessState state;
}
