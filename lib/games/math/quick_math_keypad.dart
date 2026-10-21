import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';
import '../shared/tutorial_frame.dart';

/// The digit pad for Quick Math. Keys fire on press, not release: every
/// fraction of a second counts.
class MathKeypad extends StatelessWidget {
  const MathKeypad({
    super.key,
    required this.onDigit,
    required this.onErase,
    this.highlight,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onErase;

  /// A key to point at with a pulsing outline, in the tutorial.
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                  Expanded(
                    child: label.isEmpty
                        ? const SizedBox()
                        : _key(context, label),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _key(BuildContext context, String label) {
    final c = context.colors;
    final erase = label == '⌫';
    return GestureDetector(
      key: ValueKey(erase ? 'key-erase' : 'key-$label'),
      onTapDown: (_) => erase ? onErase() : onDigit(label),
      child: TutorialPulse(
        active: highlight == label,
        color: c.reasoning,
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
      ),
    );
  }
}
