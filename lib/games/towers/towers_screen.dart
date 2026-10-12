import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/progress.dart';
import '../../data/session.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/pill_button.dart';
import '../shared/session_game_views.dart';
import 'towers_logic.dart';

enum _Phase { ready, play, feedback, done }

/// Towers of Stockholm: rebuild the goal on three pegs in as few moves as
/// possible, while the frost keeps moving from colour to colour.
class TowersScreen extends StatefulWidget {
  const TowersScreen({super.key, this.random, this.api});

  /// For tests: fixes which puzzles come up.
  final Random? random;
  final ApiClient? api;

  static const feedbackFor = Duration(milliseconds: 1400);

  @override
  State<TowersScreen> createState() => _TowersScreenState();
}

class _TowersScreenState extends State<TowersScreen> {
  late final Random _random = widget.random ?? Random();
  late final ApiClient _api = widget.api ?? ApiClient();
  final _clock = Stopwatch();

  _Phase _phase = _Phase.ready;
  int _level = Towers.startLevel;
  late TowerPuzzle _puzzle;
  late TowerState _state;
  int _moves = 0;
  int? _lifted; // peg whose top ball is picked up
  String? _note; // why a tap did nothing
  final _trials = <TowerTrial>[];

  double? _score; // from the server, once saved
  String? _saveError;

  bool get _playedToday =>
      Progress.instance.plan?.lockedToday('towers-of-stockholm') ?? false;

  void _startPuzzle() {
    setState(() {
      _puzzle = Towers.generate(_random, _level);
      _state = _puzzle.start;
      _moves = 0;
      _lifted = null;
      _note = null;
      _phase = _Phase.play;
    });
    _clock
      ..reset()
      ..start();
  }

  void _onPegTap(int peg) {
    if (_phase != _Phase.play) return;
    final lifted = _lifted;
    final balls = _state.pegs[peg];

    if (lifted == null) {
      if (balls.isEmpty) return;
      setState(() {
        if (balls.last == _state.frozen) {
          _note = 'That ball is frozen. It thaws after your next move.';
        } else {
          _lifted = peg;
          _note = null;
        }
      });
    } else if (lifted == peg) {
      setState(() => _lifted = null);
    } else if (balls.length == Towers.capacities[peg]) {
      setState(() => _note = 'That peg is full.');
    } else {
      _move((from: lifted, to: peg));
    }
  }

  void _move(TowerMove move) {
    final before = _state;
    final after = Towers.apply(before, move);
    setState(() {
      _state = after;
      _moves++;
      _lifted = null;
      // Normally the frost moves one colour on. Two means it had to skip.
      final skipped = after.frozen != (before.frozen + 1) % Towers.colours;
      _note = skipped ? 'Nothing could move, so the frost passed on.' : null;
    });
    if (after.layout == Towers.layoutOf(_puzzle.goal)) {
      _endPuzzle(solved: true);
    } else if (_moves >= _puzzle.moveLimit) {
      _endPuzzle(solved: false);
    }
  }

  Future<void> _endPuzzle({required bool solved}) async {
    _clock.stop();
    final trial = TowerTrial(
      optimal: _puzzle.optimal,
      moves: _moves,
      solved: solved,
      duration: _clock.elapsed,
    );
    setState(() {
      _trials.add(trial);
      _note = null;
      _phase = _Phase.feedback;
    });
    await Future<void>.delayed(TowersScreen.feedbackFor);
    if (!mounted) return;
    _level = Towers.nextLevel(_level, perfect: trial.perfect);
    if (_trials.length < Towers.puzzles) {
      _startPuzzle();
    } else {
      setState(() => _phase = _Phase.done);
      _save();
    }
  }

  Future<void> _save() async {
    setState(() => _saveError = null);
    try {
      final r = await _api.post('/games/towers-of-stockholm/results', {
        'trials': [for (final t in _trials) t.toJson()],
      });
      if (!mounted) return;
      setState(() => _score = (r['score'] as num).toDouble());
      Session.instance.refreshActivity();
    } on ApiException catch (e) {
      if (mounted) setState(() => _saveError = e.message);
    }
  }

  List<Color> get _ballColors {
    final c = context.colors;
    return [c.flexibility, c.planning, c.attention];
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Towers of Stockholm',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: switch (_phase) {
          _Phase.ready when _playedToday => const [
            PlayedTodayNotice(gameName: 'Towers of Stockholm'),
          ],
          _Phase.ready => _intro(),
          _Phase.done => _summary(),
          _ => _play(),
        },
      ),
    );
  }

  List<Widget> _intro() {
    final c = context.colors;
    return [
      const SizedBox(height: 40),
      const Text(
        'Rebuild the towers',
        style: AppText.screenTitle,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        'Move one ball at a time until the pegs match the goal, in as few moves as you can. '
        'Tap a peg to lift its top ball, then tap the peg to drop it on.\n\n'
        'The twist is the frost: one colour is frozen and cannot move. After every move the '
        'frost passes to the next colour, always in the same order.\n\n'
        '${Towers.puzzles} puzzles. Solve one in the fewest moves and the next gets harder.',
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: 32),
      Center(
        child: PillButton(
          label: 'Start',
          width: 187,
          height: 42,
          onPressed: _startPuzzle,
        ),
      ),
    ];
  }

  List<Widget> _play() {
    final c = context.colors;
    final meta = AppText.mono12.copyWith(color: c.textSecondary);
    final puzzleNumber = _phase == _Phase.feedback
        ? _trials.length
        : _trials.length + 1;
    final (status, color) = switch (_phase) {
      _Phase.feedback when _trials.last.perfect => ('Perfect', c.improving),
      _Phase.feedback when _trials.last.solved => (
        'Solved in $_moves. The best was ${_puzzle.optimal}.',
        c.textPrimary,
      ),
      _Phase.feedback => ('Out of moves', c.declining),
      _ => ('Match the goal in ${_puzzle.optimal} moves', c.textPrimary),
    };

    return [
      Row(
        children: [
          Text('PUZZLE $puzzleNumber OF ${Towers.puzzles}', style: meta),
          const Spacer(),
          Text(
            'MOVES $_moves / ${_puzzle.moveLimit}',
            style: meta.copyWith(color: c.flexibility),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(status, style: AppText.sectionTitle.copyWith(color: color)),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _card(
              'GOAL',
              _Pegs(pegs: _puzzle.goal, colors: _ballColors, ball: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _card('FROST', _frostOrder())),
        ],
      ),
      const SizedBox(height: 28),
      _Pegs(
        pegs: _state.pegs,
        colors: _ballColors,
        ball: 68,
        frozen: _state.frozen,
        lifted: _lifted,
        onTap: _onPegTap,
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 40,
        child: Text(
          _note ?? '',
          textAlign: TextAlign.center,
          style: AppText.label.copyWith(color: c.textSecondary),
        ),
      ),
    ];
  }

  Widget _card(String label, Widget child) {
    final c = context.colors;
    return Container(
      height: 118,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.mono12.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(child: Center(child: child)),
        ],
      ),
    );
  }

  /// The three colours in the order the frost visits them, with the frozen
  /// one marked.
  Widget _frostOrder() {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var colour = 0; colour < Towers.colours; colour++) ...[
          if (colour > 0)
            Icon(Icons.chevron_right, size: 16, color: c.textMuted),
          _Ball(
            color: _ballColors[colour],
            size: 30,
            frozen: colour == _state.frozen,
          ),
        ],
      ],
    );
  }

  List<Widget> _summary() {
    final perfect = _trials.where((t) => t.perfect).length;
    final hardest = _trials
        .where((t) => t.solved)
        .fold(0, (best, t) => max(best, t.optimal));
    return [
      SessionScoreSummary(
        score: _score,
        color: context.colors.flexibility,
        stats: [
          ('Perfect puzzles', '$perfect of ${Towers.puzzles}'),
          ('Hardest solved', hardest == 0 ? '–' : '$hardest moves'),
        ],
        saveError: _saveError,
        onRetry: _save,
      ),
    ];
  }
}

/// Three pegs of heights 3, 2 and 1 with their balls.
class _Pegs extends StatelessWidget {
  const _Pegs({
    required this.pegs,
    required this.colors,
    required this.ball,
    this.frozen,
    this.lifted,
    this.onTap,
  });

  final List<List<int>> pegs;
  final List<Color> colors;
  final double ball; // diameter
  final int? frozen;
  final int? lifted;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tallest = Towers.capacities.reduce((a, b) => a > b ? a : b);
    final rod = ball * 0.16;
    // Room above the tallest peg for a lifted ball.
    final height = ball * (tallest + (onTap == null ? 0.3 : 1.3));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: Row(
            mainAxisSize: onTap == null ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var p = 0; p < pegs.length; p++)
                _slot(
                  child: GestureDetector(
                    key: onTap == null ? null : ValueKey('peg-$p'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap == null ? null : () => onTap!(p),
                    child: SizedBox(
                      width: ball * 1.35,
                      height: height,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            width: rod,
                            height: ball * (Towers.capacities[p] + 0.25),
                            decoration: BoxDecoration(
                              color: c.elevated,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(rod / 2),
                              ),
                            ),
                          ),
                          for (final (i, colour) in pegs[p].indexed)
                            AnimatedPositioned(
                              key: ValueKey('ball-$colour'),
                              duration: const Duration(milliseconds: 120),
                              // The top ball of a lifted peg floats above the rod.
                              bottom: lifted == p && i == pegs[p].length - 1
                                  ? ball * (Towers.capacities[p] + 0.3)
                                  : ball * i,
                              child: _Ball(
                                color: colors[colour],
                                size: ball,
                                frozen: colour == frozen,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          height: rod,
          width: onTap == null ? ball * 1.35 * pegs.length : double.infinity,
          decoration: BoxDecoration(
            color: c.elevated,
            borderRadius: BorderRadius.circular(rod / 2),
          ),
        ),
      ],
    );
  }

  Widget _slot({required Widget child}) =>
      onTap == null ? child : Expanded(child: Center(child: child));
}

/// A ball. Frozen ones are iced over and carry a snowflake, so the frost
/// doesn't depend on colour alone.
class _Ball extends StatelessWidget {
  const _Ball({required this.color, required this.size, this.frozen = false});

  final Color color;
  final double size;
  final bool frozen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: frozen ? Color.lerp(color, Colors.white, 0.6) : color,
        shape: BoxShape.circle,
        border: frozen
            ? Border.all(color: Colors.white, width: size * 0.06)
            : null,
      ),
      child: frozen
          ? Icon(Icons.ac_unit, size: size * 0.55, color: c.background)
          : null,
    );
  }
}
