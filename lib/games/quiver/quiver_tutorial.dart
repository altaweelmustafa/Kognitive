import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../shared/tutorial_frame.dart';
import 'quiver_board.dart';
import 'quiver_logic.dart';
import 'quiver_widgets.dart';

enum _Step { green, red, mixed, ready }

/// Interactive first-play tutorial: swipe a green arrow the way it points,
/// a red one the way it moves, then a short mixed run.
class QuiverTutorial extends StatefulWidget {
  const QuiverTutorial({super.key, required this.onDone});

  /// Called by Start at the end, or by Skip.
  final VoidCallback onDone;

  @override
  State<QuiverTutorial> createState() => _QuiverTutorialState();
}

class _QuiverTutorialState extends State<QuiverTutorial> with TutorialTimers {
  static const _green = QuiverTrial(
    red: false,
    points: Dir.up,
    moves: Dir.right,
    count: 1,
  );
  static const _red = QuiverTrial(
    red: true,
    points: Dir.up,
    moves: Dir.left,
    count: 1,
  );
  static const _mixed = [
    QuiverTrial(red: false, points: Dir.left, moves: Dir.down, count: 2),
    QuiverTrial(red: true, points: Dir.right, moves: Dir.up, count: 2),
    QuiverTrial(red: true, points: Dir.down, moves: Dir.left, count: 3),
    QuiverTrial(red: false, points: Dir.right, moves: Dir.left, count: 3),
  ];

  _Step _step = _Step.green;
  QuiverTrial _trial = _green;
  int _mixedDone = 0;

  /// The last swipe, while it is judged.
  bool? _right;
  int _misses = 0;

  void _swipe(Dir dir) {
    if (_right != null || _step == _Step.ready) return;
    final right = dir == _trial.answer;
    setState(() {
      _right = right;
      if (!right) _misses++;
    });
    if (!right) {
      // Let them try the same screen again.
      after(
        const Duration(milliseconds: 900),
        () => setState(() => _right = null),
      );
      return;
    }
    after(const Duration(milliseconds: 900), () {
      setState(() {
        _right = null;
        switch (_step) {
          case _Step.green:
            _step = _Step.red;
            _trial = _red;
          case _Step.red:
            _step = _Step.mixed;
            _trial = _mixed.first;
          case _Step.mixed:
            _mixedDone++;
            if (_mixedDone < _mixed.length) {
              _trial = _mixed[_mixedDone];
            } else {
              _step = _Step.ready;
            }
          case _Step.ready:
        }
      });
    });
  }

  (String, String) get _text {
    final rule = _trial.red
        ? 'Red: swipe the way it moves, not the way it points.'
        : 'Green: swipe the way it points, not the way it moves.';
    return switch (_step) {
      _ when _right == true => ('Right', 'Nicely done.'),
      _ when _right == false => ('Not quite', rule),
      _Step.green => (
        'Green: follow the point',
        'This arrow drifts sideways, but it points up. Swipe up.',
      ),
      _Step.red => (
        'Red: follow the path',
        'This one points up, but it drifts left. Swipe left.',
      ),
      _Step.mixed => (
        'Check the colour first',
        'Green, where they point. Red, where they move. '
            '${_mixed.length - _mixedDone} to go.',
      ),
      _Step.ready => (
        'Ready?',
        '${Quiver.seconds} seconds. Right answers in a row raise your '
            'multiplier; a wrong one resets it.',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (title, body) = _text;
    return TutorialFrame(
      step: _step.index,
      steps: _Step.values.length,
      color: c.flexibility,
      title: title,
      body: body,
      titleColor: switch (_right) {
        true => c.improving,
        false => c.declining,
        null => null,
      },
      onSkip: widget.onDone,
      footerHeight: _step == _Step.ready ? 60 : 0,
      footer: _step == _Step.ready
          ? TutorialButton(label: 'Start', onPressed: widget.onDone)
          : null,
      child: Column(
        children: [
          QuiverSwipeArea(
            onSwipe: _swipe,
            child: TutorialShake(
              trigger: _misses,
              child: QuiverBoard(
                trial: _trial,
                speed: 0.08,
                background: c.surface,
                border: switch (_right) {
                  true => c.improving,
                  false => c.declining,
                  null => null,
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          QuiverLegend(
            highlight: switch (_step) {
              _Step.green => false,
              _Step.red => true,
              _Step.mixed => _trial.red,
              _Step.ready => null,
            },
          ),
        ],
      ),
    );
  }
}
