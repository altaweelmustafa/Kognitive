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
import 'quiver_board.dart';
import 'quiver_logic.dart';
import 'quiver_tutorial.dart';
import 'quiver_widgets.dart';

enum _Phase { ready, running, done }

/// Quiver: a field of drifting arrows, 45 seconds on the clock. Green arrows
/// are swiped the way they point, red ones the way they move. Right answers
/// in a row build a multiplier; a wrong one resets it.
class QuiverScreen extends StatefulWidget {
  const QuiverScreen({super.key, this.random, this.api});

  /// For tests: fixes the trials.
  final Random? random;
  final ApiClient? api;

  @override
  State<QuiverScreen> createState() => _QuiverScreenState();
}

class _QuiverScreenState extends State<QuiverScreen>
    with SingleTickerProviderStateMixin, TutorialGate {
  @override
  String get tutorialId => 'quiver';

  late final Random _random = widget.random ?? Random();
  late final ApiClient _api = widget.api ?? ApiClient();
  late final Ticker _ticker = createTicker(_onTick);

  _Phase _phase = _Phase.ready;
  Duration _elapsed = Duration.zero;
  late QuiverTrial _trial;
  int _score = 0;
  int _streak = 0;
  int _correct = 0;
  int _answered = 0;
  Duration _lockedUntil = Duration.zero;

  /// The last answer: right or wrong, what it earned, and when.
  bool? _lastRight;
  int _lastPoints = 0;
  Duration _lastAt = Duration.zero;

  double? _sessionScore; // from the server, once saved
  String? _saveError;

  bool get _playedToday =>
      Progress.instance.plan?.lockedToday('quiver') ?? false;

  @override
  void initState() {
    super.initState();
    QuiverBoard.preload();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _phase = _Phase.running;
      _elapsed = Duration.zero;
      _score = 0;
      _streak = 0;
      _correct = 0;
      _answered = 0;
      _lockedUntil = Duration.zero;
      _lastRight = null;
      _sessionScore = null;
      _saveError = null;
      _trial = Quiver.trial(_random, 0);
    });
    _ticker
      ..stop()
      ..start();
  }

  void _onTick(Duration elapsed) {
    if (elapsed.inSeconds >= Quiver.seconds) {
      _ticker.stop();
      setState(() {
        _elapsed = const Duration(seconds: Quiver.seconds);
        _phase = _Phase.done;
      });
      _save();
    } else {
      setState(() => _elapsed = elapsed);
    }
  }

  void _swipe(Dir dir) {
    if (_phase != _Phase.running || _elapsed < _lockedUntil) return;
    final right = dir == _trial.answer;
    setState(() {
      _answered++;
      if (right) {
        _lastPoints = Quiver.points(_streak);
        _score += _lastPoints;
        _streak++;
        _correct++;
      } else {
        _lastPoints = 0;
        _streak = 0;
        _lockedUntil = _elapsed + Quiver.wrongLock;
      }
      _lastRight = right;
      _lastAt = _elapsed;
      _trial = Quiver.trial(_random, _correct, _trial);
    });
  }

  Future<void> _save() async {
    setState(() => _saveError = null);
    try {
      final r = await _api.post('/games/quiver/results', {
        'score': _score,
        'correct': _correct,
        'answered': _answered,
      });
      if (!mounted) return;
      setState(() {
        _sessionScore = (r['score'] as num).toDouble();
      });
      Session.instance.refreshActivity();
    } on ApiException catch (e) {
      if (mounted) setState(() => _saveError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Quiver',
      child: switch (_phase) {
        _Phase.running => _play(),
        _ => ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: switch (_phase) {
            _Phase.ready when _playedToday => const [
              PlayedTodayNotice(gameName: 'Quiver'),
            ],
            _Phase.ready when showTutorial == null => const [],
            _Phase.ready when showTutorial! => [
              QuiverTutorial(onDone: () => finishTutorial(_start)),
            ],
            _Phase.ready => _intro(),
            _ => _summary(),
          },
        ),
      },
    );
  }

  List<Widget> _intro() {
    final c = context.colors;
    return [
      const SizedBox(height: 40),
      const Text(
        'Point or path?',
        style: AppText.screenTitle,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        'Green arrows: swipe the way they point.\n'
        'Red arrows: swipe the way they move.\n\n'
        '${Quiver.seconds} seconds. Right answers in a row raise your '
        'multiplier, up to ×${Quiver.maxMultiplier}; a wrong one resets it.',
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: 24),
      const QuiverLegend(),
      const SizedBox(height: 32),
      Center(
        child: PillButton(
          label: 'Start',
          width: 187,
          height: 42,
          onPressed: _start,
        ),
      ),
    ];
  }

  Widget _play() {
    final c = context.colors;
    final left = Quiver.seconds - _elapsed.inSeconds;
    final meta = AppText.mono12.copyWith(color: c.textSecondary);
    final flashing = _lastRight != null && _elapsed - _lastAt < Quiver.flashFor;
    final multiplier = Quiver.multiplier(_streak);
    final maxed = multiplier == Quiver.maxMultiplier;
    final toNext = maxed ? Quiver.streakStep : _streak % Quiver.streakStep;

    return QuiverSwipeArea(
      onSwipe: _swipe,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          children: [
            Row(
              children: [
                Text('SCORE ', style: meta),
                Text(
                  '$_score',
                  key: const ValueKey('score'),
                  style: AppText.mono16.copyWith(
                    color: c.flexibility,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                // The last answer's points, fading out.
                AnimatedOpacity(
                  opacity: flashing && _lastPoints > 0 ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '+$_lastPoints',
                    style: meta.copyWith(color: c.improving),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: left <= 10 ? c.declining : c.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$left',
                  key: const ValueKey('seconds-left'),
                  style: AppText.mono16.copyWith(
                    color: left <= 10 ? c.declining : c.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: 1 - _elapsed.inMilliseconds / (Quiver.seconds * 1000),
                minHeight: 6,
                backgroundColor: c.elevated,
                color: left <= 10 ? c.declining : c.brandAccent,
              ),
            ),
            const SizedBox(height: 14),
            // The multiplier, and how close the next one is.
            Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, a) =>
                      ScaleTransition(scale: a, child: child),
                  child: Text(
                    '×$multiplier',
                    key: ValueKey(multiplier),
                    style: AppText.mono16.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: multiplier > 1 ? c.flexibility : c.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                for (var i = 0; i < Quiver.streakStep; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 5),
                    width: 14,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < toNext ? c.flexibility : c.elevated,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // The board as big as fits (it is square), the rules under it.
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: QuiverBoard(
                        trial: _trial,
                        speed: Quiver.speed(_correct),
                        background: c.surface,
                        border: flashing
                            ? (_lastRight! ? c.improving : c.declining)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const QuiverLegend(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Swipe anywhere',
              style: AppText.caption.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _summary() {
    final accuracy = _answered == 0
        ? '–'
        : '${(100 * _correct / _answered).round()}%';
    return [
      SessionScoreSummary(
        score: _sessionScore,
        color: context.colors.flexibility,
        stats: [
          ('Points', '$_score'),
          ('Correct', '$_correct'),
          ('Accuracy', accuracy),
        ],
        saveError: _saveError,
        onRetry: _save,
      ),
    ];
  }
}
