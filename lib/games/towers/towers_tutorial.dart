import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';
import '../shared/tutorial_frame.dart';
import 'towers_logic.dart';
import 'towers_pegs.dart';

enum _Step { lift, frost, perfect, ready }

/// Interactive first-play tutorial: one plain move, then a puzzle where the
/// ball you want is frozen and you have to move another one first.
class TowersTutorial extends StatefulWidget {
  const TowersTutorial({super.key, required this.onDone});

  /// Called by Start at the end, or by Skip.
  final VoidCallback onDone;

  @override
  State<TowersTutorial> createState() => _TowersTutorialState();
}

class _TowersTutorialState extends State<TowersTutorial> with TutorialTimers {
  // Step one: no frost yet, one move to the goal.
  static const _liftStart = [
    [0, 1],
    [2],
    <int>[],
  ];
  static const _liftGoal = [
    [0],
    [2],
    [1],
  ];
  static const _liftSolution = [(from: 0, to: 2)];

  // Step two: the green ball is frozen, so the orange one goes first.
  static const _frostStart = TowerState([
    [0],
    [1],
    [2],
  ], 2);
  static const _frostGoal = [
    [0, 1],
    [2],
    <int>[],
  ];
  static const _frostSolution = [(from: 1, to: 0), (from: 2, to: 1)];

  static const _hintAfter = Duration(seconds: 4);

  _Step _step = _Step.lift;
  late TowerState _state;
  int _moves = 0;
  int? _lifted;
  String? _note;
  bool _solved = false;
  bool _tried = false; // a try went wrong and the puzzle was set back
  int _shakes = 0;
  bool _hint = false;
  Timer? _hintTimer;
  int _count = 2; // the puzzle length counter on the perfect step

  @override
  void initState() {
    super.initState();
    _setUp(_Step.lift);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  List<List<int>> get _goal => _step == _Step.lift ? _liftGoal : _frostGoal;
  List<TowerMove> get _solution =>
      _step == _Step.lift ? _liftSolution : _frostSolution;
  bool get _frostOn => _step != _Step.lift;

  void _setUp(_Step step) {
    cancelTimers();
    setState(() {
      _step = step;
      _state = step == _Step.lift
          ? TowerState([
              for (final p in _liftStart) [...p],
            ], -1)
          : _frostStart;
      _moves = 0;
      _lifted = null;
      _note = null;
      _solved = false;
    });
    _armHint();
  }

  void _armHint() {
    _hintTimer?.cancel();
    if (_hint) setState(() => _hint = false);
    _hintTimer = Timer(_hintAfter, () {
      if (mounted && !_solved) setState(() => _hint = true);
    });
  }

  /// The peg to point at: where the next move of the solution starts, or
  /// ends once its ball is lifted.
  int? get _hintPeg {
    if (!_hint || _solved || _moves >= _solution.length) return null;
    final move = _solution[_moves];
    return _lifted == move.from ? move.to : move.from;
  }

  void _onPegTap(int peg) {
    if (_solved || _step == _Step.perfect || _step == _Step.ready) return;
    _armHint();
    final lifted = _lifted;
    final balls = _state.pegs[peg];

    if (lifted == null) {
      if (balls.isEmpty) return;
      setState(() {
        if (_frostOn && balls.last == _state.frozen) {
          _note = 'That ball is frozen. It thaws after your next move.';
          _shakes++;
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
    final TowerState next;
    if (_frostOn) {
      next = Towers.apply(before, move);
    } else {
      final pegs = [
        for (final p in before.pegs) [...p],
      ];
      pegs[move.to].add(pegs[move.from].removeLast());
      next = TowerState(pegs, -1);
    }
    final solved = next.layout == Towers.layoutOf(_goal);
    setState(() {
      _state = next;
      _moves++;
      _lifted = null;
      _note = _frostOn && !solved
          ? 'The frost moved on to the next colour.'
          : null;
      _solved = solved;
    });
    if (solved) {
      _hintTimer?.cancel();
      _advance(_step == _Step.lift ? _Step.frost : _Step.perfect);
    } else if (_moves >= _solution.length) {
      // Off the shortest path: set it back and let them try again.
      setState(() {
        _note = 'Not quite. Let’s set it back and try again.';
        _shakes++;
      });
      after(const Duration(milliseconds: 1400), () {
        _tried = true;
        _setUp(_step);
      });
    }
  }

  /// After a moment to see the solved pegs, on to [next].
  void _advance(_Step next) {
    after(const Duration(milliseconds: 1100), () {
      if (next == _Step.perfect) {
        setState(() {
          _step = _Step.perfect;
          _count = _frostSolution.length;
        });
        after(
          const Duration(milliseconds: 700),
          () => setState(() => _count = _frostSolution.length + 1),
        );
      } else {
        _tried = false;
        _setUp(next);
      }
    });
  }

  (String, String) get _text => switch (_step) {
    _Step.lift when _solved => ('That’s it', 'The pegs match the goal.'),
    _Step.lift when _tried => (
      'Try again',
      'Make your pegs look like the goal. Tap a peg to lift its top ball, then tap where it goes.',
    ),
    _Step.lift => (
      'Move a ball',
      'Make your pegs look like the goal. Tap a peg to lift its top ball, then tap where it goes.',
    ),
    _Step.frost when _solved => ('Solved', 'Two moves, the fewest possible.'),
    _Step.frost when _tried => (
      'Try again',
      'Move a ball that isn’t frozen first. Then the frost passes on and the snowflake ball thaws.',
    ),
    _Step.frost => (
      'Mind the frost',
      'The snowflake ball is frozen and can’t move. After every move the frost passes to the next colour.',
    ),
    _Step.perfect => (
      'Perfect',
      'Solve a puzzle in the fewest moves and the next one is a move longer. '
          'Anything else, and it’s a move shorter.',
    ),
    _Step.ready => (
      'Ready?',
      '${Towers.puzzles} puzzles. Each says how few moves it takes, and you '
          'have ${Towers.spareMoves} to spare before it ends.',
    ),
  };

  List<Color> get _ballColors {
    final c = context.colors;
    return [c.flexibility, c.planning, c.attention];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (title, body) = _text;
    final showFrost = _frostOn;
    return TutorialFrame(
      step: _step.index,
      steps: _Step.values.length,
      color: c.flexibility,
      title: title,
      body: body,
      titleColor: _solved || _step == _Step.perfect ? c.improving : null,
      onSkip: widget.onDone,
      footer: _footer(),
      footerHeight: 72,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _card(
                  'GOAL',
                  TowerPegs(pegs: _goal, colors: _ballColors, ball: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedOpacity(
                  opacity: showFrost ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: _card('FROST', _frostOrder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TutorialShake(
            trigger: _shakes,
            child: TowerPegs(
              pegs: _state.pegs,
              colors: _ballColors,
              ball: 60,
              frozen: showFrost ? _state.frozen : null,
              lifted: _lifted,
              onTap: _onPegTap,
              highlight: _hintPeg,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: Text(
              _note ?? '',
              textAlign: TextAlign.center,
              style: AppText.label.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _footer() {
    final c = context.colors;
    return switch (_step) {
      _Step.lift || _Step.frost => Align(
        alignment: Alignment.topCenter,
        child: Text(
          'MOVES $_moves / ${_solution.length}',
          style: AppText.mono12.copyWith(color: c.flexibility),
        ),
      ),
      _Step.perfect => TutorialButton(
        label: 'Next',
        onPressed: () => setState(() => _step = _Step.ready),
        above: TutorialCount(
          before: 'NEXT PUZZLE · ',
          count: _count,
          after: ' MOVES',
          color: c.improving,
        ),
      ),
      _Step.ready => TutorialButton(label: 'Start', onPressed: widget.onDone),
    };
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

  Widget _frostOrder() {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var colour = 0; colour < Towers.colours; colour++) ...[
          if (colour > 0)
            Icon(Icons.chevron_right, size: 16, color: c.textMuted),
          TowerBall(
            color: _ballColors[colour],
            size: 26,
            frozen: colour == _state.frozen,
          ),
        ],
      ],
    );
  }
}
