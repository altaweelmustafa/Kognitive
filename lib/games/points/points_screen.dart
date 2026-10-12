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
    with SingleTickerProviderStateMixin {
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

  /// One colour per target, at most six.
  List<Color> get _colours {
    final c = context.colors;
    return [
      c.memory,
      c.attention,
      c.reasoning,
      c.planning,
      c.flexibility,
      c.brandAccent,
    ];
  }

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
      AspectRatio(
        aspectRatio: PointsOfThought.boardWidth / PointsOfThought.boardHeight,
        child: LayoutBuilder(
          builder: (context, box) {
            final scale = box.maxWidth / PointsOfThought.boardWidth;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TrackPainter(
                      round: round,
                      colours: _colours,
                      palette: c,
                    ),
                  ),
                ),
                // A generous tap area over each switch.
                for (final node in round.layout.switches)
                  Positioned(
                    left: round.layout.nodes[node].position.dx * scale - 34,
                    top: round.layout.nodes[node].position.dy * scale - 28,
                    width: 68,
                    height: 56,
                    child: GestureDetector(
                      key: ValueKey('switch-$node'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: between
                          ? null
                          : (_) => setState(() => round.toggle(node)),
                    ),
                  ),
              ],
            );
          },
        ),
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

/// Draws the tracks, switches, targets and dots. Repainted every frame.
class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.round,
    required this.colours,
    required this.palette,
  });

  final PointsRound round;
  final List<Color> colours;
  final AppColors palette;

  static const _flashFor = 0.6; // seconds a target shows right / wrong
  static const _toggleWidth = 46.0;
  static const _toggleHeight = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / PointsOfThought.boardWidth;
    Offset at(Offset p) => p * scale;
    final layout = round.layout;

    final idle = Paint()
      ..color = palette.elevated
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final open = Paint()
      ..color = palette.textMuted
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    // Tracks: the way each switch points is drawn brighter, on top.
    canvas.drawLine(
      at(TrackLayout.origin),
      at(layout.nodes[layout.root].position),
      open,
    );
    for (final pass in [false, true]) {
      for (final i in layout.switches) {
        final node = layout.nodes[i];
        final right = round.sendsRight[i]!;
        for (final (child, taken) in [
          (node.left!, !right),
          (node.right!, right),
        ]) {
          if (taken == pass) {
            canvas.drawLine(
              at(node.position),
              at(layout.nodes[child].position),
              taken ? open : idle,
            );
          }
        }
      }
    }

    // Origin mouth, with the next dot waiting inside.
    final origin = at(TrackLayout.origin);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(center: origin, width: 58, height: 40),
        topLeft: const Radius.circular(29),
        topRight: const Radius.circular(29),
      ),
      Paint()..color = palette.surface,
    );
    if (round.nextColour case final next?) {
      canvas.drawCircle(origin, 12.5, Paint()..color = colours[next]);
      _label(canvas, origin, '${next + 1}', 15);
    }

    // Switches: a toggle, with its knob on the side dots are sent to.
    for (final i in layout.switches) {
      final centre = at(layout.nodes[i].position);
      final right = round.sendsRight[i]!;
      final pill = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: centre,
          width: _toggleWidth,
          height: _toggleHeight,
        ),
        const Radius.circular(_toggleHeight / 2),
      );
      canvas.drawRRect(pill.inflate(3), Paint()..color = palette.background);
      canvas.drawRRect(pill, Paint()..color = palette.brandFill);
      final travel = (_toggleWidth - _toggleHeight) / 2;
      canvas.drawCircle(
        centre + Offset(right ? travel : -travel, 0),
        _toggleHeight / 2 - 3,
        Paint()..color = palette.onBrand,
      );
    }

    // Targets, flashing green or red when a dot has just arrived.
    for (final node in layout.nodes) {
      if (node.isSwitch) continue;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: at(node.position), width: 40, height: 40),
        const Radius.circular(8),
      );
      final arrival = round.lastArrival[node.target];
      if (arrival != null && round.clock - arrival.at < _flashFor) {
        canvas.drawRRect(
          rect.inflate(5),
          Paint()
            ..color = arrival.correct ? palette.improving : palette.declining,
        );
      }
      canvas.drawRRect(rect, Paint()..color = colours[node.target!]);
      _label(canvas, at(node.position), '${node.target! + 1}', 20);
    }

    // Points.
    for (final dot in round.dots) {
      final centre = at(dot.position);
      canvas.drawCircle(centre, 15, Paint()..color = palette.background);
      canvas.drawCircle(centre, 12.5, Paint()..color = colours[dot.colour]);
      _label(canvas, centre, '${dot.colour + 1}', 15);
    }
  }

  /// The target number, so matching never depends on colour alone.
  void _label(Canvas canvas, Offset centre, String text, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppText.mono,
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: palette.background,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) => true;
}
