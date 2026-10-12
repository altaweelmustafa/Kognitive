import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/pill_button.dart';
import '../../data/api_client.dart';
import '../../data/progress.dart';
import '../../data/session.dart';
import 'chess_api.dart';
import 'chess_board.dart';
import 'chess_models.dart';

/// Chess Puzzles: the Lichess daily puzzle, then as many more as you like.
/// Moves are checked by the backend; the solution never reaches the app.
class ChessPuzzleScreen extends StatefulWidget {
  const ChessPuzzleScreen({super.key, this.api});

  final ChessApi? api;

  @override
  State<ChessPuzzleScreen> createState() => _ChessPuzzleScreenState();
}

class _ChessPuzzleScreenState extends State<ChessPuzzleScreen> {
  static const _replyDelay = Duration(milliseconds: 450);
  static const _wrongFlash = Duration(milliseconds: 700);

  late final ChessApi _api = widget.api ?? ChessApi();
  final _clock = Stopwatch();

  ChessPuzzle? _puzzle;
  ChessState? _state;
  bool _isDaily = true;
  bool _busy = false; // waiting on the server or the opponent's reply
  String? _error;

  String? _selected;

  /// The player's move, shown on the board while the server checks it.
  String? _pending;
  String? _wrong;
  Set<String> _hinted = {};
  bool _lastMoveWasWrong = false;
  int _mistakes = 0;
  int _hints = 0;

  @override
  void initState() {
    super.initState();
    // Today's daily first; once it is solved, a fresh puzzle every time.
    final dailySolved =
        Progress.instance.today?.dailySolved.contains('chess-puzzles') ?? false;
    _load(daily: !dailySolved);
  }

  Future<void> _load({required bool daily}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final puzzle = await (daily ? _api.daily() : _api.next());
      if (!mounted) return;
      setState(() {
        _puzzle = puzzle;
        _state = puzzle.state;
        _isDaily = daily;
        _selected = null;
        _pending = null;
        _wrong = null;
        _hinted = {};
        _lastMoveWasWrong = false;
        _mistakes = 0;
        _hints = 0;
        _busy = false;
      });
      _clock
        ..reset()
        ..start();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  List<String> _movesFrom(String square) =>
      _state!.legalMoves.where((m) => m.startsWith(square)).toList();

  bool get _canMove => _state != null && !_busy && !_state!.solved;

  void _onSquareTap(String square) {
    if (!_canMove) return;
    final selected = _selected;
    if (selected != null && selected != square && _attempt(selected, square)) {
      return;
    }
    setState(() {
      _selected = square != selected && _movesFrom(square).isNotEmpty
          ? square
          : null;
    });
  }

  void _onDrop(String from, String to) {
    if (_canMove && from != to) _attempt(from, to);
  }

  /// Plays from → to if that is a legal move. Returns whether it was.
  bool _attempt(String from, String to) {
    final state = _state!;
    final moves = state.legalMoves
        .where((m) => m.startsWith('$from$to'))
        .toList();
    if (moves.isEmpty) return false;
    if (moves.length == 1) {
      _play(moves.single);
    } else {
      // Same squares, several moves: a promotion.
      _pickPromotion(state.whiteToMove).then((piece) {
        if (piece != null && mounted) _play('$from$to$piece');
      });
    }
    return true;
  }

  Future<void> _play(String uci) async {
    final puzzle = _puzzle!;
    setState(() {
      _busy = true;
      _selected = null;
      _hinted = {};
      _error = null;
      _pending = uci;
    });
    try {
      final result = await _api.move(puzzle.id, _state!.step, uci);
      if (!mounted) return;

      if (!result.correct) {
        setState(() {
          _mistakes++;
          _lastMoveWasWrong = true;
          _wrong = uci.substring(2, 4);
          _busy = false;
        });
        await Future<void>.delayed(_wrongFlash);
        if (mounted) {
          // The piece slides back to where it came from.
          setState(() {
            _wrong = null;
            _pending = null;
          });
        }
        return;
      }

      setState(() {
        _lastMoveWasWrong = false;
        _state = result.afterMove;
        _pending = null;
      });
      if (!result.state.solved) await Future<void>.delayed(_replyDelay);
      if (!mounted) return;
      setState(() {
        _state = result.state;
        _busy = false;
      });
      if (result.state.solved) _finish();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _pending = null;
        _busy = false;
      });
    }
  }

  void _finish() {
    _clock.stop();
    // Best effort: a lost stat shouldn't interrupt the player.
    _api
        .recordAttempt(
          _puzzle!.id,
          solved: true,
          mistakes: _mistakes,
          hints: _hints,
          duration: _clock.elapsed,
        )
        .then((_) => Session.instance.refreshActivity())
        .catchError((_) {});
  }

  /// First tap shows which piece to move, second tap shows where.
  Future<void> _hint() async {
    final showTarget = _hinted.length == 1;
    setState(() => _busy = true);
    try {
      final (from, to) = await _api.hint(_puzzle!.id, _state!.step);
      if (!mounted) return;
      setState(() {
        if (_hinted.isEmpty) _hints++;
        _hinted = showTarget ? {from, to} : {from};
        _selected = null;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  Future<String?> _pickPromotion(bool white) {
    final c = context.colors;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.elevated,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Promote to', style: AppText.listTitle),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final piece in ['q', 'r', 'b', 'n'])
                    GestureDetector(
                      key: ValueKey('promote-$piece'),
                      onTap: () => Navigator.pop(context, piece),
                      child: Container(
                        width: 64,
                        height: 64,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: c.chessDark,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Image.asset(
                          'assets/chess/pieces/${white ? 'w' : 'b'}$piece.png',
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = _puzzle;
    final state = _state;

    return DetailScaffold(
      title: 'Chess Puzzles',
      child: puzzle == null || state == null
          ? _loadingOrError()
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
              children: [
                _header(puzzle, state),
                const SizedBox(height: 32),
                ChessBoard(
                  key: ValueKey(puzzle.id),
                  pieces: _shownPieces(state),
                  flipped: !puzzle.playsWhite,
                  draggable: {
                    if (_canMove)
                      for (final m in state.legalMoves) m.substring(0, 2),
                  },
                  selected: _selected,
                  targets: {
                    if (_selected case final from?)
                      for (final m in _movesFrom(from)) m.substring(2, 4),
                  },
                  highlighted: {
                    if (_pending ?? state.lastMove case final m?) ...{
                      m.substring(0, 2),
                      m.substring(2, 4),
                    },
                  },
                  hinted: _hinted,
                  wrong: _wrong,
                  checked: state.check && _pending == null
                      ? state.kingSquare
                      : null,
                  onTap: _onSquareTap,
                  onDragStart: (square) => setState(() => _selected = square),
                  onDrop: _onDrop,
                ),
                const SizedBox(height: 16),
                _footer(puzzle, state),
              ],
            ),
    );
  }

  /// The position, with the player's unconfirmed move already made.
  Map<String, String> _shownPieces(ChessState state) {
    final move = _pending;
    if (move == null) return state.pieces;
    final from = move.substring(0, 2);
    final piece = state.pieces[from];
    if (piece == null) return state.pieces;
    return {...state.pieces}
      ..remove(from)
      ..[move.substring(2, 4)] = move.length > 4
          ? '${piece[0]}${move[4]}'
          : piece;
  }

  Widget _loadingOrError() {
    final c = context.colors;
    final error = _error;
    if (error == null) {
      return Center(child: CircularProgressIndicator(color: c.brandAccent));
    }
    return Padding(
      padding: const EdgeInsets.all(27),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(error, textAlign: TextAlign.center, style: AppText.listTitle),
          const SizedBox(height: 8),
          Text(
            'Check that the backend is running, then try again.',
            textAlign: TextAlign.center,
            style: AppText.label.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 24),
          PillButton(
            label: 'Retry',
            width: 140,
            height: 42,
            onPressed: () => _load(daily: _isDaily),
          ),
        ],
      ),
    );
  }

  /// Speech bubble pointing at the board, with the rating beside it.
  Widget _header(ChessPuzzle puzzle, ChessState state) {
    final c = context.colors;
    final side = puzzle.playsWhite ? 'White' : 'Black';
    final (title, color) = switch (state) {
      _ when state.solved => ('Solved', c.improving),
      _ when _lastMoveWasWrong => (
        "That's not the move. Try again.",
        c.declining,
      ),
      _ when state.step == 0 => (
        '$side to move. Find the best move.',
        c.textPrimary,
      ),
      _ => ('Good. Keep going.', c.textPrimary),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isDaily ? 'DAILY PUZZLE' : 'PRACTICE PUZZLE',
            style: AppText.mono12.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The bubble's tail.
                    Positioned(
                      left: 22,
                      bottom: -6,
                      child: Transform.rotate(
                        angle: 0.785398, // 45°
                        child: Container(
                          width: 14,
                          height: 14,
                          color: c.elevated,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                      decoration: BoxDecoration(
                        color: c.elevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(color: color, width: 3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/chess/pieces/${puzzle.playsWhite ? 'w' : 'b'}k.png',
                            width: 26,
                            height: 26,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              title,
                              style: AppText.body.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (puzzle.rating case final rating?) ...[
                const SizedBox(width: 12),
                Text(
                  '$rating elo',
                  style: AppText.mono16.copyWith(
                    color: c.brandAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer(ChessPuzzle puzzle, ChessState state) {
    final c = context.colors;
    if (state.solved) {
      final t = _clock.elapsed;
      final time =
          '${t.inMinutes}:${(t.inSeconds % 60).toString().padLeft(2, '0')}';
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [_stat('Time', time), _stat('Hints', '$_hints')],
          ),
          const SizedBox(height: 20),
          PillButton(
            label: 'Next puzzle',
            width: 187,
            height: 42,
            onPressed: _busy ? null : () => _load(daily: false),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Text(error, style: AppText.label.copyWith(color: c.declining)),
          ],
        ],
      );
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        PillButton(
          label: _hinted.length == 1 ? 'Show move' : 'Hint',
          outlined: true,
          width: 187,
          height: 42,
          onPressed: _busy || _hinted.length == 2 ? null : _hint,
        ),
        if (_error case final error?) ...[
          const SizedBox(height: 12),
          Text(error, style: AppText.label.copyWith(color: c.declining)),
        ],
      ],
    );
  }

  Widget _stat(String label, String value) {
    final c = context.colors;
    return Column(
      children: [
        Text(
          value,
          style: AppText.mono16.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppText.caption.copyWith(color: c.textMuted)),
      ],
    );
  }
}
