import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';
import '../shared/tutorial_frame.dart';
import 'apothecary_game.dart';
import 'apothecary_logic.dart';

enum _Step { pour, rules, par, ready }

/// Interactive first-play tutorial on the real bottles: one pour, then a
/// small puzzle that needs the empty bottle, then what par means.
class ApothecaryTutorial extends StatefulWidget {
  const ApothecaryTutorial({super.key, required this.onDone});

  /// Called by Start at the end, or by Skip.
  final VoidCallback onDone;

  @override
  State<ApothecaryTutorial> createState() => _ApothecaryTutorialState();
}

class _ApothecaryTutorialState extends State<ApothecaryTutorial>
    with TutorialTimers {
  /// One pour: two half-full bottles of the same colour make a full one.
  static const _first = ApothecaryPuzzle(
    bottles: [
      [0, 0],
      [1, 1, 1, 1],
      [0, 0],
    ],
    colours: 2,
    par: 1,
  );

  /// Two colours swapped: the empty bottle has to hold one while the other
  /// goes home.
  static const _second = ApothecaryPuzzle(
    bottles: [
      [0, 0, 1, 1],
      [1, 1, 0, 0],
      <int>[],
    ],
    colours: 2,
    par: 3,
  );

  _Step _step = _Step.pour;
  ApothecaryGame? _current;
  bool _solved = false;
  int _count = 2; // the colour counter on the par step

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs the theme's colours, so not in initState.
    if (_current == null) _setUp(_first);
  }

  void _setUp(ApothecaryPuzzle puzzle) {
    final c = context.colors;
    _solved = false;
    _current = ApothecaryGame(
      puzzle: puzzle,
      colours: ApothecaryColours(
        liquids: c.liquids,
        glass: c.textPrimary,
        stopper: c.textSecondary,
        background: c.background,
      ),
      onPoured: () => setState(() {}),
      onSelect: () => setState(() {}),
      onSolved: _onSolved,
    );
  }

  ApothecaryGame get _game => _current!;

  void _onSolved() {
    setState(() => _solved = true);
    after(const Duration(milliseconds: 1300), () {
      if (_step == _Step.pour) {
        setState(() {
          _step = _Step.rules;
          _setUp(_second);
        });
      } else {
        setState(() {
          _step = _Step.par;
          _count = _second.colours;
        });
        after(
          const Duration(milliseconds: 700),
          () => setState(() => _count = _second.colours + 1),
        );
      }
    });
  }

  (String, String) get _text {
    final picked = _game.selected != null;
    return switch (_step) {
      _Step.pour when _solved => (
        'Sorted',
        'Every bottle holds a single colour.',
      ),
      _Step.pour when picked => (
        'Now pour',
        'Tap the bottle to pour into. Tap the same one again to put it down.',
      ),
      _Step.pour => (
        'Pick up a bottle',
        'Bottles count once they’re full of one colour. Tap a half-full one to pick it up.',
      ),
      _Step.rules when _solved => (
        'Sorted',
        '${_game.pours} pours. The par was ${_second.par}.',
      ),
      _Step.rules => (
        'Same colour or empty',
        'Liquid only pours onto its own colour or into an empty bottle, and only as much as fits.',
      ),
      _Step.par => (
        'Aim for par',
        'Each puzzle shows a par to aim for. Sort it close to par and the '
            'next puzzle has another colour.',
      ),
      _Step.ready => (
        'Ready?',
        '${Apothecary.puzzles} puzzles. Undo and Restart are there if you '
            'get stuck, and Skip moves on.',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (title, body) = _text;
    final meta = AppText.mono12.copyWith(color: c.textSecondary);
    final puzzle = _step == _Step.pour ? _first : _second;

    return TutorialFrame(
      step: _step.index,
      steps: _Step.values.length,
      color: c.planning,
      title: title,
      body: body,
      titleColor: _solved || _step == _Step.par ? c.improving : null,
      onSkip: widget.onDone,
      footerHeight: 72,
      footer: switch (_step) {
        _Step.rules when !_solved => Align(
          alignment: Alignment.topCenter,
          child: TextButton(
            onPressed: () => setState(_game.restart),
            child: Text(
              'Restart',
              style: AppText.label.copyWith(color: c.textSecondary),
            ),
          ),
        ),
        _Step.par => TutorialButton(
          label: 'Next',
          onPressed: () => setState(() => _step = _Step.ready),
          above: TutorialCount(
            before: 'NEXT PUZZLE · ',
            count: _count,
            after: ' COLOURS',
            color: c.improving,
          ),
        ),
        _Step.ready => TutorialButton(label: 'Start', onPressed: widget.onDone),
        _ => null,
      },
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'POURS ${_game.pours} · PAR ${puzzle.par}',
              style: meta.copyWith(color: c.planning),
            ),
          ),
          SizedBox(
            height: 300,
            // A fresh game for every puzzle.
            child: GameWidget(key: ObjectKey(_game), game: _game),
          ),
        ],
      ),
    );
  }
}
