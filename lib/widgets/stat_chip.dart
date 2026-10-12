import 'package:flutter/material.dart';

import '../config/color_config.dart';
import '../theme/app_text.dart';

/// Small pill with an icon and a number (KPI, streak).
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            value,
            style: AppText.label.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
