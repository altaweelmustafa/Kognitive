import 'package:flutter/material.dart';

/// Saves or unsaves a library article. Pops a little when it changes.
class BookmarkButton extends StatelessWidget {
  const BookmarkButton({
    super.key,
    required this.saved,
    required this.color,
    required this.onTap,
    this.size = 20,
  });

  final bool saved;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: saved ? 'Remove from saved' : 'Save',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: a, child: child),
            child: Icon(
              saved ? Icons.bookmark : Icons.bookmark_border,
              key: ValueKey(saved),
              size: size,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
