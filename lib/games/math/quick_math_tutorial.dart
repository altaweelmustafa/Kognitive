import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';
import '../shared/tutorial_frame.dart';
import 'quick_math_keypad.dart';
import 'quick_math_logic.dart';

enum _Step { single, double, clock, ready }

/// Interactive first-play tutorial: answer a one-digit sum, then a two-digit
/// one (checked without pressing Enter), then watch the clock run.
class QuickMathTutorial extends StatefulWidget {
  const QuickMathTutorial({super.key, required this.onDone});

  /// Called by Start at the end, or by Skip.
  final VoidCallback onDone;

  @override
  State<QuickMathTutorial> createState() => _QuickMathTutorialState();
}

class _QuickMathTutorialState extends State<QuickMathTutorial>
    with TutorialTimers {
  static const _single = (text: '3 + 4', answer: 7);
  static const _double = (text: '12 + 9', answer: 21);

  /// Answered by themselves on the clock step.
  static const _demo = [
    (text: '6 + 5', answer: 11),
    (text: '14 − 6', answer: 8),
    (text: '7 × 3', answer: 21),
    (text: '9 + 8', answer: 17),
  ];

  static const _hintAfter = Duration(seconds: 4);

  final _focus = FocusNode();
  Timer? _hintTimer;

  _Step _step = _Step.single;
  MathQuestion _question = _single;
  String _typed = '';
  bool? _right; // the last answer, while it is judged
  bool _hint = false;
  int _correct = 0; // the counter on the clock step
  double _clock = 1; // share of the minute left on the clock step

  @override
  void initState() {
    super.initState();
    _armHint();
    // Take the keyboard from the screen around us.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  bool get _answering =>
      (_step == _Step.single || _step == _Step.double) && _right == null;

  void _armHint() {
    _hintTimer?.cancel();
    if (_hint) setState(() => _hint = false);
    _hintTimer = Timer(_hintAfter, () {
      if (mounted && _answering) setState(() => _hint = true);
    });
  }

  /// The next digit of the answer, for the hint.
  String? get _hintKey {
    if (!_hint || !_answering) return null;
    final wanted = '${_question.answer}';
    return _typed.length < wanted.length ? wanted[_typed.length] : null;
  }

  void _press(String digit) {
    if (!_answering) return;
    _armHint();
    final wanted = '${_question.answer}';
    final typed = _typed + digit;
    if (typed.length < wanted.length) {
      setState(() => _typed = typed);
      return;
    }
    _hintTimer?.cancel();
    setState(() {
      _typed = typed;
      _right = typed == wanted;
      _hint = false;
    });
    after(const Duration(milliseconds: 1600), () {
      if (_step == _Step.single) {
        setState(() {
          _step = _Step.double;
          _question = _double;
          _typed = '';
          _right = null;
        });
        _armHint();
      } else {
        _startClock();
      }
    });
  }

  void _erase() {
    if (_answering && _typed.isNotEmpty) {
      _armHint();
      setState(() => _typed = _typed.substring(0, _typed.length - 1));
    }
  }

  /// Plays a few quick answers with the clock running down.
  void _startClock() {
    setState(() {
      _step = _Step.clock;
      _correct = 0;
      _clock = 1;
      _question = _demo.first;
      _typed = '';
      _right = null;
    });
    const each = Duration(milliseconds: 900);
    for (final (i, q) in _demo.indexed) {
      final t = each * i + const Duration(milliseconds: 400);
      after(t, () => setState(() => _typed = '${q.answer}'));
      after(t + const Duration(milliseconds: 250), () {
        setState(() {
          _right = true;
          _correct++;
          _clock = 1 - (i + 1) / _demo.length;
        });
      });
      after(t + const Duration(milliseconds: 550), () {
        setState(() {
          _right = null;
          _typed = '';
          if (i + 1 < _demo.length) _question = _demo[i + 1];
        });
      });
    }
  }

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

  (String, String) get _text => switch (_step) {
    _Step.single when _right == true => ('Right', 'On to the next one.'),
    _Step.single when _right == false => (
      'It was ${_single.answer}',
      'A wrong answer just moves on to the next sum. No need to stop.',
    ),
    _Step.single => ('Type the answer', 'Tap the keys to answer the sum.'),
    _Step.double when _right == true => (
      'Right',
      'No Enter key needed: it was checked as soon as both digits were in.',
    ),
    _Step.double when _right == false => (
      'It was ${_double.answer}',
      'It was checked as soon as both digits were in. On you go.',
    ),
    _Step.double => (
      'Two digits',
      'The answer is checked the moment you’ve typed enough digits.',
    ),
    _Step.clock => (
      'Beat the clock',
      '${QuickMath.seconds} seconds. Answer as many as you can; they get '
          'harder as you get more right.',
    ),
    _Step.ready => ('Ready?', 'The clock starts as soon as you tap Start.'),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (title, body) = _text;
    final flash = switch (_right) {
      true => c.improving,
      false => c.declining,
      null => c.surface,
    };
    final meta = AppText.mono12.copyWith(color: c.textSecondary);
    final onClock = _step == _Step.clock || _step == _Step.ready;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: TutorialFrame(
        step: _step.index,
        steps: _Step.values.length,
        color: c.reasoning,
        title: title,
        body: body,
        titleColor: switch (_right) {
          true => c.improving,
          false => c.declining,
          null => null,
        },
        onSkip: widget.onDone,
        footerHeight: onClock ? 60 : 0,
        footer: switch (_step) {
          _Step.clock => TutorialButton(
            label: 'Next',
            onPressed: () {
              cancelTimers();
              setState(() {
                _step = _Step.ready;
                _right = null;
                _typed = '';
              });
            },
          ),
          _Step.ready => TutorialButton(
            label: 'Start',
            onPressed: widget.onDone,
          ),
          _ => null,
        },
        child: Column(
          children: [
            AnimatedOpacity(
              opacity: onClock ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'CORRECT $_correct',
                        style: meta.copyWith(color: c.reasoning),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: c.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: _clock),
                      duration: const Duration(milliseconds: 600),
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: c.elevated,
                        color: c.brandAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: flash, width: 3),
              ),
              child: Column(
                children: [
                  Text(
                    _question.text,
                    style: AppText.mono16.copyWith(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _typed.isEmpty ? '?' : _typed,
                    key: const ValueKey('tutorial-typed'),
                    style: AppText.mono16.copyWith(
                      fontSize: 32,
                      color: _typed.isEmpty ? c.textMuted : c.brandAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AnimatedOpacity(
              // The pad is for the player only while they answer.
              opacity: onClock ? 0.35 : 1,
              duration: const Duration(milliseconds: 300),
              child: MathKeypad(
                onDigit: _press,
                onErase: _erase,
                highlight: _hintKey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
