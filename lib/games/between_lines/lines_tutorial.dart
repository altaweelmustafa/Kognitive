import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../shared/tutorial_frame.dart';
import 'lines_logic.dart';
import 'lines_widgets.dart';

enum _Step { answer, sources, ready }

/// Interactive first-play tutorial: fill one gap, then learn where the
/// passages come from and how the speed bonus works.
class LinesTutorial extends StatefulWidget {
  const LinesTutorial({super.key, required this.onDone});

  /// Called by Start at the end, or by Skip.
  final VoidCallback onDone;

  @override
  State<LinesTutorial> createState() => _LinesTutorialState();
}

class _LinesTutorialState extends State<LinesTutorial> with TutorialTimers {
  static const _question = LinesQuestion(
    passage: Passage(title: 'TCP', source: 'Kognitiv', text: ''),
    before:
        'The Transmission Control Protocol provides reliable delivery on top '
        'of an unreliable network. Every segment is numbered, and the '
        'receiver sends ',
    after:
        ' for the data it has received. Anything that is not acknowledged in '
        'time is sent again.',
    answer: 'acknowledgements',
    choices: ['compliments', 'acknowledgements', 'ingredients', 'apologies'],
  );

  static const _hintAfter = Duration(seconds: 8);

  _Step _step = _Step.answer;
  String? _chosen;
  int _misses = 0;
  bool _hint = false;

  @override
  void initState() {
    super.initState();
    after(_hintAfter, () {
      if (_chosen == null) setState(() => _hint = true);
    });
  }

  void _pick(String word) {
    if (word == _question.answer) {
      setState(() => _chosen = word);
      after(const Duration(milliseconds: 1400), () {
        setState(() => _step = _Step.sources);
      });
    } else {
      // Wrong: shake, and let them try again.
      setState(() {
        _misses++;
        _hint = true;
      });
    }
  }

  (String, String) get _text => switch (_step) {
    _Step.answer when _chosen != null => (
      'Right',
      'The words around the gap told you: the next sentence talks about '
          'things being acknowledged.',
    ),
    _Step.answer when _misses > 0 => (
      'Not that one',
      'Read the sentence after the gap too. It points to the answer.',
    ),
    _Step.answer => (
      'Find the missing word',
      'One word has been taken out of the passage. Tap the one that belongs.',
    ),
    _Step.sources => (
      'Real reading',
      'Pick a subject and the passages come live from Wikipedia, or from '
          'classic novels on Project Gutenberg. Every round is new.',
    ),
    _Step.ready => (
      'Be quick, be right',
      '${Lines.base} points a word, plus up to ${Lines.bonus} more for '
          'answering within ${Lines.bonusFrom.inSeconds} seconds.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (title, body) = _text;
    return TutorialFrame(
      step: _step.index,
      steps: _Step.values.length,
      color: c.reasoning,
      title: title,
      body: body,
      titleColor: switch (_step) {
        _Step.answer when _chosen != null => c.improving,
        _Step.answer when _misses > 0 => c.declining,
        _ => null,
      },
      onSkip: widget.onDone,
      footerHeight: _step == _Step.answer ? 0 : 60,
      footer: switch (_step) {
        _Step.answer => null,
        _Step.sources => TutorialButton(
          label: 'Next',
          onPressed: () => setState(() => _step = _Step.ready),
        ),
        _Step.ready => TutorialButton(label: 'Start', onPressed: widget.onDone),
      },
      child: TutorialShake(
        trigger: _misses,
        child: Column(
          children: [
            LinesPassageCard(question: _question, chosen: _chosen),
            const SizedBox(height: 18),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _step == _Step.answer ? 1 : 0.35,
              child: LinesChoices(
                question: _question,
                chosen: _chosen,
                onPick: _pick,
                hint: _hint && _chosen == null ? _question.answer : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
