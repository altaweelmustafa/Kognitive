import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/pill_button.dart';
import 'quick_math_logic.dart';

enum _Phase { ready, running, done }

/// Quick Math: one sum at a time, 60 seconds on the clock. The answer is
/// checked as soon as enough digits are typed; right or wrong, the next sum
/// comes straight away.
class QuickMathScreen extends StatefulWidget {
  const QuickMathScreen({super.key, this.random, this.api});

  /// For tests: fixes the questions.
  final Random? random;
  final ApiClient? api;

  @override
  State<QuickMathScreen> createState() => _QuickMathScreenState();
}

class _QuickMathScreenState extends State<QuickMathScreen>
    with SingleTickerProviderStateMixin {
  late final Random _random = widget.random ?? Random();
  late final ApiClient _api = widget.api ?? ApiClient();
  late final Ticker _ticker = createTicker(_onTick);
  final _focus = FocusNode();

  _Phase _phase = _Phase.ready;
  Duration _elapsed = Duration.zero;
  late MathQuestion _question;
  String _typed = '';
  int _correct = 0;
  int _answered = 0;

  /// The last answer's outcome and when it was given, for the flash.
  bool? _lastRight;
  Duration _lastAt = Duration.zero;

  int? _best; // from the server, once saved
  bool _newBest = false;
  String? _saveError;

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _phase = _Phase.running;
      _elapsed = Duration.zero;
      _correct = 0;
      _answered = 0;
      _typed = '';
      _lastRight = null;
      _best = null;
      _saveError = null;
      _question = QuickMath.question(_random, 0);
    });
    _focus.requestFocus();
    _ticker
      ..stop()
      ..start();
  }

  void _onTick(Duration elapsed) {
    if (elapsed.inSeconds >= QuickMath.seconds) {
      _ticker.stop();
      setState(() {
        _elapsed = const Duration(seconds: QuickMath.seconds);
        _phase = _Phase.done;
      });
      _save();
    } else {
      setState(() => _elapsed = elapsed);
    }
  }

  void _press(String digit) {
    if (_phase != _Phase.running) return;
    final wanted = '${_question.answer}';
    final typed = _typed + digit;
    if (typed.length < wanted.length) {
      setState(() => _typed = typed);
      return;
    }
    // Enough digits: check it and move on, right or wrong.
    final right = typed == wanted;
    setState(() {
      _answered++;
      if (right) _correct++;
      _lastRight = right;
      _lastAt = _elapsed;
      _typed = '';
      _question = QuickMath.question(_random, _correct);
    });
  }

  void _erase() {
    if (_phase == _Phase.running && _typed.isNotEmpty) {
      setState(() => _typed = _typed.substring(0, _typed.length - 1));
    }
  }

  Future<void> _save() async {
    setState(() => _saveError = null);
    try {
      final r = await _api.post('/games/quick-math/results', {
        'correct': _correct,
        'answered': _answered,
      });
      if (!mounted) return;
      setState(() {
        _best = r['best'] as int;
        _newBest = r['new_best'] as bool;
      });
      Session.instance.refreshActivity();
    } on ApiException catch (e) {
      if (mounted) setState(() => _saveError = e.message);
    }
  }

  /// Keyboard play on desktop.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final digit = int.tryParse(event.character ?? '');
    if (digit != null) {
      _press('$digit');
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _erase();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Quick Math',
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: switch (_phase) {
            _Phase.ready => _intro(),
            _Phase.running => _play(),
            _Phase.done => _summary(),
          },
        ),
      ),
    );
  }

  List<Widget> _intro() {
    final c = context.colors;
    return [
      const SizedBox(height: 40),
      const Text(
        '60 seconds of sums',
        style: AppText.screenTitle,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        'Answer as many as you can before the clock runs out. Type the answer; it is checked '
        'the moment you have typed enough digits.\n\n'
        'A wrong answer just moves on to the next sum, so keep going. They get harder as you '
        'get more right.',
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(color: c.textSecondary),
      ),
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

  List<Widget> _play() {
    final c = context.colors;
    final left = QuickMath.seconds - _elapsed.inSeconds;
    final meta = AppText.mono12.copyWith(color: c.textSecondary);
    final flashing =
        _lastRight != null && _elapsed - _lastAt < QuickMath.flashFor;
    final flash = flashing
        ? (_lastRight! ? c.improving : c.declining)
        : c.surface;

    return [
      Row(
        children: [
          Text('CORRECT $_correct', style: meta.copyWith(color: c.reasoning)),
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
          value: 1 - _elapsed.inMilliseconds / (QuickMath.seconds * 1000),
          minHeight: 6,
          backgroundColor: c.elevated,
          color: left <= 10 ? c.declining : c.brandAccent,
        ),
      ),
      const SizedBox(height: 28),
      // The sum, with a border that flashes green or red for the last answer.
      Container(
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: flash, width: 3),
        ),
        child: Column(
          children: [
            Text(
              _question.text,
              key: const ValueKey('question'),
              style: AppText.mono16.copyWith(
                fontSize: 46,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _typed.isEmpty ? '?' : _typed,
              style: AppText.mono16.copyWith(
                fontSize: 34,
                color: _typed.isEmpty ? c.textMuted : c.brandAccent,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['', '0', '⌫'],
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              for (final (i, label) in row.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: label.isEmpty ? const SizedBox() : _key(label)),
              ],
            ],
          ),
        ),
    ];
  }

  Widget _key(String label) {
    final c = context.colors;
    final erase = label == '⌫';
    return GestureDetector(
      key: ValueKey(erase ? 'key-erase' : 'key-$label'),
      // On press, not release: every fraction of a second counts.
      onTapDown: (_) => erase ? _erase() : _press(label),
      child: Container(
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: erase
            ? Icon(Icons.backspace_outlined, color: c.textSecondary)
            : Text(
                label,
                style: AppText.mono16.copyWith(
                  fontSize: 28,
                  color: c.textPrimary,
                ),
              ),
      ),
    );
  }

  List<Widget> _summary() {
    final c = context.colors;
    final accuracy = _answered == 0
        ? null
        : (100 * _correct / _answered).round();
    Widget stat(String label, String value) => Column(
      children: [
        Text(
          value,
          style: AppText.mono16.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppText.caption.copyWith(color: c.textMuted)),
      ],
    );

    return [
      const SizedBox(height: 40),
      Text(
        _newBest ? 'NEW BEST' : 'CORRECT ANSWERS',
        textAlign: TextAlign.center,
        style: AppText.mono12.copyWith(
          color: _newBest ? c.improving : c.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '$_correct',
        textAlign: TextAlign.center,
        style: AppText.mono16.copyWith(
          fontSize: 56,
          fontWeight: FontWeight.w700,
          color: c.reasoning,
          letterSpacing: 0,
        ),
      ),
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          stat('Answered', '$_answered'),
          stat('Accuracy', accuracy == null ? '–' : '$accuracy%'),
          stat('Your best', _best?.toString() ?? '…'),
        ],
      ),
      const SizedBox(height: 32),
      if (_saveError case final error?) ...[
        Text(
          "$error Your result isn't saved yet.",
          textAlign: TextAlign.center,
          style: AppText.label.copyWith(color: c.declining),
        ),
        const SizedBox(height: 16),
        Center(
          child: PillButton(
            label: 'Try again',
            width: 187,
            height: 42,
            onPressed: _save,
          ),
        ),
      ] else ...[
        Center(
          child: PillButton(
            label: 'Play again',
            width: 187,
            height: 42,
            onPressed: _start,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: PillButton(
            label: 'Done',
            outlined: true,
            width: 187,
            height: 42,
            onPressed: () => context.pop(),
          ),
        ),
      ],
    ];
  }
}
