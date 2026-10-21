import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/progress.dart';
import '../../data/session.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/pill_button.dart';
import '../shared/session_game_views.dart';
import '../shared/tutorial_frame.dart';
import 'apothecary_tutorial.dart';
import 'apothecary_game.dart';
import 'apothecary_logic.dart';

enum _Phase { ready, play, feedback, done }

/// Apothecary: pour liquid between bottles until each holds one colour.
/// The bottles themselves are a Flame game; this screen is everything around
/// them.
class ApothecaryScreen extends StatefulWidget {
  const ApothecaryScreen({super.key, this.random, this.api});

  /// For tests: fixes which puzzles come up.
  final Random? random;
  final ApiClient? api;

  static const feedbackFor = Duration(milliseconds: 1500);

  @override
  State<ApothecaryScreen> createState() => _ApothecaryScreenState();
}

class _ApothecaryScreenState extends State<ApothecaryScreen> with TutorialGate {
  @override
  String get tutorialId => 'apothecary';

  late final Random _random = widget.random ?? Random();
  late final ApiClient _api = widget.api ?? ApiClient();
  final _clock = Stopwatch();

  _Phase _phase = _Phase.ready;
  int _colours = Apothecary.startColours;
  late ApothecaryPuzzle _puzzle;
  ApothecaryGame? _game;
  final _trials = <ApothecaryTrial>[];

  double? _score; // from the server, once saved
  String? _saveError;

  bool get _playedToday =>
      Progress.instance.plan?.lockedToday('apothecary') ?? false;

  /// Asks the server how many colours to start with, then begins. If it
  /// can't be reached, starts at the default.
  Future<void> _begin() async {
    try {
      final r = await _api.get('/games/apothecary/level');
      _colours = (r['colours'] as int).clamp(
        Apothecary.minColours,
        Apothecary.maxColours,
      );
    } on ApiException {
      // Keep the default.
    }
    if (mounted) _startPuzzle();
  }

  void _startPuzzle() {
    final c = context.colors;
    final puzzle = Apothecary.generate(_random, _colours);
    setState(() {
      _puzzle = puzzle;
      _game = ApothecaryGame(
        puzzle: puzzle,
        colours: ApothecaryColours(
          liquids: c.liquids,
          glass: c.textPrimary,
          stopper: c.textSecondary,
          background: c.background,
        ),
        onPoured: () => setState(() {}),
        onSolved: () => _endPuzzle(solved: true),
      );
      _phase = _Phase.play;
    });
    _clock
      ..reset()
      ..start();
  }

  Future<void> _endPuzzle({required bool solved}) async {
    if (_phase != _Phase.play) return;
    _clock.stop();
    final trial = ApothecaryTrial(
      colours: _puzzle.colours,
      par: _puzzle.par,
      moves: _game!.pours,
      solved: solved,
      duration: _clock.elapsed,
    );
    setState(() {
      _trials.add(trial);
      _phase = _Phase.feedback;
    });
    await Future<void>.delayed(ApothecaryScreen.feedbackFor);
    if (!mounted) return;
    _colours = Apothecary.nextColours(trial);
    if (_trials.length < Apothecary.puzzles) {
      _startPuzzle();
    } else {
      setState(() {
        _phase = _Phase.done;
        _game = null;
      });
      _save();
    }
  }

  Future<void> _save() async {
    setState(() => _saveError = null);
    try {
      final r = await _api.post('/games/apothecary/results', {
        'trials': [for (final t in _trials) t.toJson()],
      });
      if (!mounted) return;
      setState(() => _score = (r['score'] as num).toDouble());
      Session.instance.refreshActivity();
    } on ApiException catch (e) {
      if (mounted) setState(() => _saveError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Apothecary',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        // The bottles own every touch while a puzzle is on.
        physics: _phase == _Phase.play
            ? const NeverScrollableScrollPhysics()
            : null,
        children: switch (_phase) {
          _Phase.ready when _playedToday => const [
            PlayedTodayNotice(gameName: 'Apothecary'),
          ],
          _Phase.ready when showTutorial == null => const [],
          _Phase.ready when showTutorial! => [
            ApothecaryTutorial(onDone: () => finishTutorial(_begin)),
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
        'One colour to a bottle',
        style: AppText.screenTitle,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        'Tap a bottle to pick it up, then tap another to pour. Liquid only pours onto the same '
        'colour or into an empty bottle, and only as much as fits.\n\n'
        'Sort them until every bottle holds a single colour, in as few pours as you can. '
        'Each puzzle shows a par to aim for.\n\n'
        '${Apothecary.puzzles} puzzles. Solve one cleanly and the next has another colour.',
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: 32),
      Center(
        child: PillButton(
          label: 'Start',
          width: 187,
          height: 42,
          onPressed: _begin,
        ),
      ),
    ];
  }

  List<Widget> _play() {
    final c = context.colors;
    final game = _game!;
    final meta = AppText.mono12.copyWith(color: c.textSecondary);
    final feedback = _phase == _Phase.feedback;
    final number = feedback ? _trials.length : _trials.length + 1;
    final (status, color) = switch (_phase) {
      _Phase.feedback when !_trials.last.solved => ('Skipped', c.declining),
      _Phase.feedback when _trials.last.moves <= _puzzle.par => (
        'Sorted, at par',
        c.improving,
      ),
      _Phase.feedback => (
        'Sorted in ${_trials.last.moves} pours',
        c.textPrimary,
      ),
      _ => ('Sort every colour into its own bottle', c.textPrimary),
    };

    return [
      Row(
        children: [
          Text('PUZZLE $number OF ${Apothecary.puzzles}', style: meta),
          const SizedBox(width: 12),
          // Shrinks rather than overflowing with large system text.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                'POURS ${game.pours} · PAR ${_puzzle.par}',
                style: meta.copyWith(color: c.planning),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(status, style: AppText.sectionTitle.copyWith(color: color)),
      const SizedBox(height: 8),
      SizedBox(
        height: 470,
        // A fresh game for every puzzle.
        child: GameWidget(key: ObjectKey(game), game: game),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          _action(
            Icons.undo_rounded,
            'Undo',
            feedback || !game.canUndo ? null : () => setState(game.undo),
          ),
          _action(
            Icons.restart_alt_rounded,
            'Restart',
            feedback ? null : () => setState(game.restart),
          ),
          _action(
            Icons.skip_next_rounded,
            'Skip',
            feedback ? null : () => _endPuzzle(solved: false),
          ),
        ],
      ),
    ];
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap) {
    final c = context.colors;
    final color = onTap == null ? c.textMuted : c.textPrimary;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppText.caption.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  List<Widget> _summary() {
    final solved = _trials.where((t) => t.solved).length;
    final most = _trials
        .where((t) => t.solved)
        .fold(0, (best, t) => max(best, t.colours));
    return [
      SessionScoreSummary(
        score: _score,
        color: context.colors.planning,
        stats: [
          ('Puzzles sorted', '$solved of ${Apothecary.puzzles}'),
          ('Most colours', most == 0 ? '–' : '$most'),
        ],
        saveError: _saveError,
        onRetry: _save,
      ),
    ];
  }
}
