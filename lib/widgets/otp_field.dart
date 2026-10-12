import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/color_config.dart';
import '../theme/app_text.dart';

/// One-time code input: one box per digit.
/// A single invisible text field sits on top and owns focus and the keyboard.
class OtpField extends StatelessWidget {
  const OtpField({
    super.key,
    required this.controller,
    required this.length,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final text = controller.text;
        return Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < length; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.elevated,
                        borderRadius: BorderRadius.circular(4),
                        // Marks the box the next digit lands in.
                        border: Border.all(
                          color: i == text.length ? c.brandAccent : c.elevated,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        i < text.length ? text[i] : '',
                        style: AppText.mono16.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(length),
                  ],
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  expands: true,
                  maxLines: null,
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
