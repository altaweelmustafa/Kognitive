import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/progress.dart';
import '../../data/session.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/pill_button.dart';
import '../shared/session_game_views.dart';
import '../shared/tutorial_frame.dart';
import 'points_tutorial.dart';
import 'points_board.dart';
import 'points_logic.dart';

enum _Phase { ready, running, between, done }

/// Points of Thought: dots leave the origin and follow the switches. Tap a
/// switch to flip it, and get every dot to the target of its own colour.
class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key, this.random, this.api});

  /// For tests: fixes the dot colours and the starting switches.
  final Random? random;
  final ApiClient? api;

  static const betweenRoundsFor = Duration(milliseconds: 1600);

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen>
    with SingleTickerProviderStateMixin, TutorialGate {
  @override
  String get tutorialId => 'points-of-thought';

  late final Random _random = widget.random ?? Random();
  late final ApiClient _api = widget.api ?? ApiClient();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;

  _Phase _phase = _Phase.ready;
  int _level = PointsOfThought.startLevel;
  PointsRound? _round;
  final _results = <PointsRoundResult>[];

  double? _score; // from the server, once saved
  String? _saveError;

  bool get _playedToday =>
      Progress.instance.plan?.lockedToday('points-of-thought') ?? false;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Asks the server which level to play, then starts. If it can't be
  /// reached, plays the starting level.
  Future<void> _begin() async {
    try {
      final r = await _api.get('/games/points-of-thought/level');
      _level = (r['level'] as int).clamp(1, PointsOfThought.maxLevel);
    } on ApiException {
      // Keep the default.
    }
    if (mounted) _startRound();
  }

  void _startRound() {
    setState(() {
      _round = PointsRound(level: _level, random: _random);
      _phase = _Phase.running;
    });
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final round = _round!;
    // A long gap (the app was in the background) shouldn't teleport dots.
    final dt = min((elapsed - _lastTick).inMicroseconds / 1e6, 0.1);
    _lastTick = elapsed;
    setState(() => round.update(dt));
    if (round.finished) _endRound();
  }

  Future<void> _endRound() async {
    _ticker.stop();
    final round = _round!;
    _results.add(
      PointsRoundResult(
        level: round.level,
        delivered: round.delivered,
        duration: Duration(milliseconds: (round.clock * 1000).round()),
      ),
    );
    setState(() => _phase = _Phase.between);
    await Future<void>.delayed(PointsScreen.betweenRoundsFor);
    if (!mounted) return;
    _level = PointsOfThought.nextLevel(_level, delivered: round.delivered);
    if (_results.length < PointsOfThought.rounds) {
      _startRound();
    } else {
      setState(() => _phase = _Phase.done);
      _save();
    }
  }

  Future<void> _save() async {
    setState(() => _saveError = null);
    try {
      final r = await _api.post('/games/points-of-thought/results', {
        'rounds': [for (final result in _results) result.toJson()],
      });
      if (!mounted) return;
      setState(() => _score = (r['score'] as num).toDouble());
      Session.instance.refreshActivity();
    } on ApiException catch (e) {
      if (mounted) setState(() => _saveError = e.message);
    }
  }

  List<Color> get _colours => pointsColours(context.colors);

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Points of Thought',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        physics: _phase == _Phase.running
            ? const NeverScrollableScrollPhysics()
            : null,
        children: switch (_phase) {
          _Phase.ready when _playedToday => const [
            PlayedTodayNotice(gameName: 'Points of Thought'),
          ],
          _Phase.ready when showTutorial == null => const [],
          _Phase.ready when showTutorial! => [
            PointsTutorial(onDone: () => finishTutorial(_begin)),
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
        'Every point to its target',
        style: AppText.screenTitle,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        'Points drop in from the top, one after another, and roll down the lines. Each belongs '
        'at the target with its own colour and number.\n\n'
        'Each junction has a toggle. Tap it to send points left or right. A point goes the way '
        'the toggle is set at the moment it gets there. The next point waits at the top, so '
        'you can plan ahead.\n\n'
        'One round of ${PointsOfThought.dotsPerRound} points. '
        'Deliver nearly all of them and your next session gets busier.',
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
    final round = _round!;
    final meta = AppText.mono12.copyWith(color: c.textSecondary);
    final between = _phase == _Phase.between;

    return [
      Row(
        children: [
          Text('LEVEL ${round.level}', style: meta),
          const Spacer(),
          Text(
            'DELIVERED ${round.delivered} / ${PointsOfThought.dotsPerRound}',
            style: meta.copyWith(color: c.attention),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        between
            ? '${round.delivered} of ${PointsOfThought.dotsPerRound} delivered'
            : 'Set the toggles',
        style: AppText.sectionTitle.copyWith(
          color: between
              ? (round.delivered >=
                        PointsOfThought.dotsPerRound * PointsOfThought.levelUpAt
                    ? c.improving
                    : c.textPrimary)
              : c.textPrimary,
        ),
      ),
      const SizedBox(height: 16),
      PointsBoard(
        round: round,
        colours: _colours,
        onToggle: between ? null : (node) => setState(() => round.toggle(node)),
      ),
    ];
  }

  List<Widget> _summary() {
    final delivered = _results.fold(0, (sum, r) => sum + r.delivered);
    final topLevel = _results.fold(0, (best, r) => max(best, r.level));
    return [
      SessionScoreSummary(
        score: _score,
        color: context.colors.attention,
        stats: [
          (
            'Points delivered',
            '$delivered of ${PointsOfThought.rounds * PointsOfThought.dotsPerRound}',
          ),
          ('Level', '$topLevel'),
        ],
        saveError: _saveError,
        onRetry: _save,
      ),
    ];
  }
}
