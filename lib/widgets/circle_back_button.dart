import 'package:flutter/material.dart';

import '../config/color_config.dart';

class CircleBackButton extends StatelessWidget {
  const CircleBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
        child: Icon(Icons.chevron_left, size: 24, color: c.textPrimary),
      ),
    );
  }
}
