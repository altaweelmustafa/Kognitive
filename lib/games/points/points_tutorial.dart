import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';
import '../shared/tutorial_frame.dart';
import 'points_board.dart';
import 'points_logic.dart';

enum _Step { watch, flip, practice, ready }

/// Interactive first-play tutorial on the smallest board: watch a point roll
/// home, steer one with the toggles, then deliver three in a row.
class PointsTutorial extends StatefulWidget {
  const PointsTutorial({super.key, this.random, required this.onDone});

  /// For tests: fixes the practice dots.
  final Random? random;

  /// Called by Start at the end, or by Skip.
  final VoidCallback onDone;

  @override
  State<PointsTutorial> createState() => _PointsTutorialState();
}

class _PointsTutorialState extends State<PointsTutorial>
    with SingleTickerProviderStateMixin, TutorialTimers {
  // Level one: the first switch sends left to target 1, or right to a
  // second switch that splits between targets 2 and 3.
  static const _root = 0;
  static const _second = 2;
  static const _practiceDots = 3;

  late final Random _random = widget.random ?? Random();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;

  _Step _step = _Step.watch;
  late PointsRound _round;
  int _arrived = 0;
  bool? _lastCorrect; // the last arrival, while its caption shows
  bool _tried = false; // a steered point went astray and is being retried

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// A round that sends only [dots] more points.
  PointsRound _newRound(int dots) =>
      PointsRound(level: 1, random: _random)
        ..sent = PointsOfThought.dotsPerRound - dots;

  void _run(PointsRound round) {
    _ticker.stop();
    setState(() {
      _round = round;
      _arrived = 0;
      _lastCorrect = null;
    });
    _lastTick = Duration.zero;
    _ticker.start();
  }

  /// A 3 rolls home with the toggles already set for it.
  void _watch() {
    _step = _Step.watch;
    _run(
      _newRound(1)
        ..nextColour = 2
        ..sendsRight[_root] = true
        ..sendsRight[_second] = true,
    );
  }

  /// A 2, with both toggles set the wrong way.
  void _flip() {
    _step = _Step.flip;
    _run(
      _newRound(1)
        ..nextColour = 1
        ..sendsRight[_root] = false
        ..sendsRight[_second] = true,
    );
  }

  void _practice() {
    _step = _Step.practice;
    _run(_newRound(_practiceDots));
  }

  void _onTick(Duration elapsed) {
    final round = _round;
    final dt = min((elapsed - _lastTick).inMicroseconds / 1e6, 0.1);
    _lastTick = elapsed;
    final before = round.delivered + round.lost;
    setState(() => round.update(dt));
    if (round.delivered + round.lost > before) _onArrival();
    if (round.finished) _ticker.stop();
  }

  void _onArrival() {
    final latest = _round.lastArrival.values.reduce(
      (a, b) => a.at >= b.at ? a : b,
    );
    setState(() {
      _arrived++;
      _lastCorrect = latest.correct;
    });
    switch (_step) {
      case _Step.watch:
        after(const Duration(milliseconds: 1200), _flip);
      case _Step.flip:
        if (_lastCorrect!) {
          _tried = false;
          after(const Duration(milliseconds: 1200), _practice);
        } else {
          _tried = true;
          after(const Duration(milliseconds: 1600), _flip);
        }
      case _Step.practice || _Step.ready:
        break;
    }
  }

  /// The first switch on the waiting point's way that points wrong.
  int? get _wrongSwitch {
    if (_step != _Step.flip || _arrived > 0) return null;
    if (_round.sendsRight[_root]!) {
      return _round.sendsRight[_second]! ? _second : null;
    }
    return _root;
  }

  (String, String) get _text => switch (_step) {
    _Step.watch when _arrived > 0 => (
      'Delivered',
      'It reached the target with its own colour and number.',
    ),
    _Step.watch => (
      'Follow the lines',
      'Points drop in from the top and roll down the lines. The next one waits at the top.',
    ),
    _Step.flip when _arrived > 0 && _lastCorrect! => (
      'Delivered',
      'A point goes the way each toggle is set when it gets there.',
    ),
    _Step.flip when _arrived > 0 => (
      'Wrong target',
      'Set every toggle on its way before it arrives. Let’s try again.',
    ),
    _Step.flip when _wrongSwitch == null => ('All set', 'Now watch it roll.'),
    _Step.flip => (
      _tried ? 'Try again' : 'Flip the toggles',
      'This point is a 2. Tap the toggles so it rolls to target 2.',
    ),
    _Step.practice when _round.finished => (
      '${_round.delivered} of $_practiceDots delivered',
      'In the game they keep coming, so plan for the one waiting at the top.',
    ),
    _Step.practice => (
      'Your turn',
      'Here come $_practiceDots points. Get each one to its own target.',
    ),
    _Step.ready => (
      'Ready?',
      'One round of ${PointsOfThought.dotsPerRound} points. Deliver nearly '
          'all of them and your next session gets busier.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (title, body) = _text;
    final meta = AppText.mono12.copyWith(color: c.textSecondary);
    final round = _round;
    final interactive = _step == _Step.flip || _step == _Step.practice;

    return TutorialFrame(
      step: _step.index,
      steps: _Step.values.length,
      color: c.attention,
      title: title,
      body: body,
      titleColor: switch (_lastCorrect) {
        true when _step != _Step.practice => c.improving,
        false when _step == _Step.flip => c.declining,
        _ => null,
      },
      onSkip: widget.onDone,
      footerHeight: 50,
      footer: switch (_step) {
        _Step.practice when round.finished => TutorialButton(
          label: 'Next',
          onPressed: () => setState(() => _step = _Step.ready),
        ),
        _Step.ready => TutorialButton(label: 'Start', onPressed: widget.onDone),
        _ => null,
      },
      child: Column(
        children: [
          Row(
            children: [
              Text('TUTORIAL', style: meta),
              const Spacer(),
              if (_step == _Step.practice)
                Text(
                  'DELIVERED ${round.delivered} / $_practiceDots',
                  style: meta.copyWith(color: c.attention),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Shorter than in the game, so the caption and button fit around it.
          FractionallySizedBox(
            widthFactor: 0.82,
            child: PointsBoard(
              round: round,
              colours: pointsColours(c),
              highlight: _wrongSwitch,
              onToggle: interactive && !round.finished
                  ? (node) => setState(() => round.toggle(node))
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
