import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';
import 'lines_logic.dart';

/// The passage, with its gap. Once answered, the gap shows the word picked
/// and, if that was wrong, the right one beside it.
class LinesPassageCard extends StatelessWidget {
  const LinesPassageCard({super.key, required this.question, this.chosen});

  final LinesQuestion question;
  final String? chosen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = AppText.body.copyWith(fontSize: 17, height: 1.55);
    final answered = chosen != null;
    final right = chosen == question.answer;

    Widget chip(String word, Color colour, {bool struck = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        word,
        style: style.copyWith(
          color: colour,
          fontWeight: FontWeight.w700,
          decoration: struck ? TextDecoration.lineThrough : null,
          decorationColor: colour,
        ),
      ),
    );

    final gap = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: a, child: child),
      ),
      child: !answered
          ? Container(
              key: const ValueKey('gap'),
              // Always the same width, so the gap gives nothing away.
              width: 74,
              height: 22,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: c.reasoning, width: 2.5),
                ),
              ),
            )
          : Wrap(
              key: const ValueKey('filled'),
              spacing: 4,
              children: [
                if (!right) chip(chosen!, c.declining, struck: true),
                chip(question.answer, c.improving),
              ],
            ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(text: question.before),
            WidgetSpan(alignment: PlaceholderAlignment.middle, child: gap),
            TextSpan(text: question.after),
          ],
        ),
      ),
    );
  }
}

/// The four words to pick from. After a pick, the right one turns green and
/// a wrong pick red.
class LinesChoices extends StatelessWidget {
  const LinesChoices({
    super.key,
    required this.question,
    required this.chosen,
    required this.onPick,
    this.hint,
  });

  final LinesQuestion question;
  final String? chosen;
  final ValueChanged<String> onPick;

  /// A word to outline, for the tutorial.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        for (final word in question.choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Choice(
              key: ValueKey('choice-$word'),
              word: word,
              fill: switch (chosen) {
                null => null,
                _ when word == question.answer => c.improving,
                final pick when pick == word => c.declining,
                _ => null,
              },
              faded:
                  chosen != null && word != question.answer && word != chosen,
              outline: word == hint ? c.reasoning : null,
              onTap: chosen == null ? () => onPick(word) : null,
            ),
          ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.word,
    required this.fill,
    required this.faded,
    required this.outline,
    required this.onTap,
  });

  final String word;
  final Color? fill;
  final bool faded;
  final Color? outline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: faded ? 0.4 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill ?? c.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: outline ?? fill ?? c.elevated,
              width: outline != null ? 2.5 : 1.5,
            ),
          ),
          child: Text(
            word,
            style: AppText.button.copyWith(
              fontWeight: FontWeight.w600,
              color: fill != null ? c.onAccent : c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the passage came from, shown once the gap is filled.
class LinesSourceLine extends StatelessWidget {
  const LinesSourceLine({super.key, required this.passage});

  final Passage passage;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final by = passage.author == null ? '' : ' by ${passage.author}';
    return Text(
      passage.source == 'Kognitiv'
          ? 'A Kognitiv practice passage'
          : 'From “${passage.title}”$by · ${passage.source}',
      textAlign: TextAlign.center,
      style: AppText.caption.copyWith(color: c.textMuted),
    );
  }
}
