import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';
import '../../widgets/pill_button.dart';
import '../shared/tutorial_frame.dart';
import 'names_logic.dart';

enum _Step { meet, ask, review, ready }

/// What came of a practice answer.
enum _Verdict { right, close, wrong }

/// Interactive first-play tutorial, at the player's own pace: meet Tyrell,
/// answer the three kinds of question about him, then see how reviews
/// space out.
///
/// Tyrell is the game's logo, not one of the bundled portraits, so a
/// made-up name never gets attached to a face the game uses.
class NamesTutorial extends StatefulWidget {
  const NamesTutorial({super.key, required this.onDone});

  /// Called by Got it at the end, or by Skip.
  final VoidCallback onDone;

  @override
  State<NamesTutorial> createState() => _NamesTutorialState();
}

class _NamesTutorialState extends State<NamesTutorial> {
  static const _logo = 'assets/game_icons/Whats_My_Name.png';
  static const _name = 'Tyrell';
  static const _profession = 'CTO of E Corp';
  static const _detail = 'Likes hacking';

  /// Gaps between reviews, each one longer after a face is remembered.
  static const _gaps = ['Tomorrow', '3 days', '1 week', '3 weeks'];

  final _input = TextEditingController();
  final _inputFocus = FocusNode();

  _Step _step = _Step.meet;
  int _question = 0; // index into NamesQuestion.values
  _Verdict? _verdict;

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  NamesQuestion get _asking => NamesQuestion.values[_question];

  String get _expected => switch (_asking) {
    NamesQuestion.name => _name,
    NamesQuestion.profession => _profession,
    NamesQuestion.detail => _detail,
  };

  void _ask(int question) {
    _input.clear();
    setState(() {
      _step = _Step.ask;
      _question = question;
      _verdict = null;
    });
    _inputFocus.requestFocus();
  }

  void _next() {
    if (_question + 1 < NamesQuestion.values.length) {
      _ask(_question + 1);
    } else {
      setState(() => _step = _Step.review);
    }
  }

  void _submit(String text) {
    if (_verdict != null) return;
    _inputFocus.unfocus();
    setState(() => _verdict = _judge(_asking, text));
  }

  /// Forgiving like the game: a typo in the name is close, and for the
  /// other questions the key words are enough.
  static _Verdict _judge(NamesQuestion question, String answer) {
    final a = _simple(answer);
    if (a.isEmpty) return _Verdict.wrong;
    switch (question) {
      case NamesQuestion.name:
        final b = _simple(_name);
        if (a == b) return _Verdict.right;
        return _distance(a, b) <= 1 ? _Verdict.close : _Verdict.wrong;
      case NamesQuestion.profession:
        return ['cto', 'ecorp', 'chieftechnology'].any(a.contains)
            ? _Verdict.right
            : _Verdict.wrong;
      case NamesQuestion.detail:
        return a.contains('hack') ? _Verdict.right : _Verdict.wrong;
    }
  }

  /// Lower case, letters and digits only.
  static String _simple(String s) =>
      s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  static int _distance(String a, String b) {
    var row = List.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final next = [i];
      for (var j = 1; j <= b.length; j++) {
        next.add(
          [
            row[j] + 1,
            next[j - 1] + 1,
            row[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
          ].reduce(min),
        );
      }
      row = next;
    }
    return row[b.length];
  }

  (String, String) get _text => switch (_step) {
    _Step.meet => (
      'Meet Tyrell',
      'You meet people one at a time. Take in the face, the name, what they '
          'do and one thing about them.',
    ),
    _Step.ask when _verdict == _Verdict.wrong => (
      'Not quite',
      'That’s fine. People you forget come back sooner, so there’s another '
          'chance.',
    ),
    _Step.ask when _verdict == _Verdict.close => (
      'Close enough',
      'Small typos are forgiven. You’ll be shown how it’s spelt.',
    ),
    _Step.ask when _verdict == _Verdict.right => (
      'Correct',
      _question + 1 < NamesQuestion.values.length
          ? 'Next question about him.'
          : 'That’s all three kinds of question.',
    ),
    _Step.ask => (
      _asking.prompt,
      switch (_asking) {
        NamesQuestion.name =>
          'Right after meeting someone, you’re asked about them. Type the '
              'answer.',
        NamesQuestion.profession => 'The key words are enough.',
        NamesQuestion.detail => 'And the one thing you learned about them.',
      },
    ),
    _Step.review => (
      'Reviews spread out',
      'People you met before come back for review. Remember them and they '
          'return less and less often. Forget, and they’re back tomorrow.',
    ),
    _Step.ready => (
      'Ready?',
      'Today’s new people first, one at a time, then anyone due for review.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (title, body) = _text;
    return TutorialFrame(
      step: _step.index,
      steps: _Step.values.length,
      color: c.memory,
      title: title,
      body: body,
      titleColor: switch (_verdict) {
        _ when _step != _Step.ask => null,
        _Verdict.right || _Verdict.close => c.improving,
        _Verdict.wrong => c.declining,
        null => null,
      },
      onSkip: widget.onDone,
      footerHeight: 50,
      footer: switch (_step) {
        _Step.meet => TutorialButton(label: 'Ask me', onPressed: () => _ask(0)),
        _Step.ask when _verdict != null => TutorialButton(
          label: 'Next',
          onPressed: _next,
        ),
        _Step.review => TutorialButton(
          label: 'Next',
          onPressed: () => setState(() => _step = _Step.ready),
        ),
        _Step.ready => TutorialButton(
          label: 'Got it',
          onPressed: widget.onDone,
        ),
        _ => null,
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_step) {
          _Step.meet => _meet(),
          _Step.ask => _askView(),
          _Step.review || _Step.ready => _schedule(),
        },
      ),
    );
  }

  Widget _portrait(double size) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Container(
      color: Colors.white,
      child: Image.asset(
        _logo,
        key: const ValueKey('tutorial-face'),
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    ),
  );

  Widget _meet() {
    final c = context.colors;
    Widget fact(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: c.memory),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: AppText.listTitle)),
        ],
      ),
    );
    return Column(
      key: const ValueKey('meet'),
      children: [
        _portrait(200),
        const SizedBox(height: 14),
        Text(_name, style: AppText.display.copyWith(fontSize: 38, height: 1.1)),
        fact(Icons.work_outline, _profession),
        fact(Icons.favorite_border, _detail),
      ],
    );
  }

  Widget _askView() {
    final c = context.colors;
    final verdict = _verdict;
    final meta = AppText.mono12.copyWith(color: c.textSecondary);
    return Column(
      // A new field for each question, so nothing carries over.
      key: ValueKey('ask-$_question'),
      children: [
        Row(
          children: [
            Text('NEW PEOPLE', style: meta.copyWith(color: c.memory)),
            const Spacer(),
            Text(
              '${_question + 1} OF ${NamesQuestion.values.length}',
              style: meta,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _portrait(150),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('tutorial-answer'),
          controller: _input,
          focusNode: _inputFocus,
          enabled: verdict == null,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: _asking == NamesQuestion.name
              ? TextCapitalization.words
              : TextCapitalization.none,
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
          style: AppText.body.copyWith(color: c.textPrimary, fontSize: 18),
          decoration: InputDecoration(
            filled: true,
            fillColor: c.elevated,
            hintText: 'Type your answer',
            hintStyle: AppText.body.copyWith(color: c.textMuted),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (verdict == null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PillButton(
                label: "Don't know",
                outlined: true,
                width: 140,
                height: 42,
                onPressed: () => _submit(''),
              ),
              const SizedBox(width: 12),
              PillButton(
                label: 'Answer',
                width: 140,
                height: 42,
                onPressed: () => _submit(_input.text),
              ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (verdict == _Verdict.wrong ? c.declining : c.improving)
                  .withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  verdict == _Verdict.wrong ? Icons.cancel : Icons.check_circle,
                  color: verdict == _Verdict.wrong ? c.declining : c.improving,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(switch (verdict) {
                    _Verdict.right => 'Correct',
                    _Verdict.close => 'Correct. It is spelt "$_expected".',
                    _Verdict.wrong => 'It was: $_expected',
                  }, style: AppText.listTitle),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Growing gaps between reviews, and what forgetting does.
  Widget _schedule() {
    final c = context.colors;
    Widget chip(String label, {required Color color, required IconData icon}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: AppText.label.copyWith(color: c.textPrimary)),
            ],
          ),
        );

    return Column(
      key: const ValueKey('schedule'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _portrait(110)),
        const SizedBox(height: 20),
        Text(
          'REMEMBERED: NEXT REVIEW',
          textAlign: TextAlign.center,
          style: AppText.mono12.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 8,
          children: [
            for (final (i, gap) in _gaps.indexed) ...[
              if (i > 0)
                Icon(Icons.chevron_right, size: 16, color: c.textMuted),
              chip(gap, color: c.improving, icon: Icons.check),
            ],
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'FORGOTTEN',
          textAlign: TextAlign.center,
          style: AppText.mono12.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 10),
        Center(
          child: chip('Back tomorrow', color: c.declining, icon: Icons.close),
        ),
      ],
    );
  }
}
