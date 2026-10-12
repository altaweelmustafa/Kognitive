import 'package:flutter/material.dart';

import '../config/color_config.dart';
import '../theme/app_text.dart';

/// Fully rounded button. Filled with the brand color, or outlined.
/// Pass `onPressed: null` to disable.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.width,
    this.height = 49,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    final fill = outlined
        ? Colors.transparent
        : (enabled ? c.brandFill : c.elevated);
    final text = outlined ? c.textPrimary : (enabled ? c.onBrand : c.textMuted);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(height / 2),
          border: outlined ? Border.all(color: c.textSecondary) : null,
        ),
        child: Text(label, style: AppText.button.copyWith(color: text)),
      ),
    );
  }
}
