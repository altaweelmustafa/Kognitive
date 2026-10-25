import 'package:flutter/material.dart';

import '../config/color_config.dart';

/// On a wide screen (a browser on a PC, a desktop window), shows the app as a
/// phone-width column in the middle instead of stretching it across the
/// screen. Narrow screens get the app as it is.
class WideScreenFrame extends StatelessWidget {
  const WideScreenFrame({super.key, required this.child});

  /// The column's width. The layouts are designed for phones.
  static const width = 480.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= width + 48) return child;
    final c = context.colors;
    return ColoredBox(
      color: Color.lerp(c.background, Colors.black, 0.45)!,
      child: Center(
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: c.background,
            border: Border.symmetric(vertical: BorderSide(color: c.divider)),
          ),
          // Everything inside measures itself against the column, not the
          // whole window.
          child: MediaQuery(
            data: media.copyWith(size: Size(width, media.size.height)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
