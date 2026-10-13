import 'package:flutter/material.dart';

import '../config/color_config.dart';
import '../config/domain_config.dart';
import '../models/game.dart';

/// Artwork for a game: its icon filling a square (or circle) with no
/// backing, or a domain-colored placeholder glyph when it has none.
class GameArt extends StatelessWidget {
  const GameArt({
    super.key,
    required this.game,
    this.radius = 6,
    this.circle = false,
  });

  final Game game;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = game.domain.color(c);

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final s = box.maxWidth;
          return Container(
            decoration: BoxDecoration(
              shape: circle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: circle ? null : BorderRadius.circular(radius),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: switch (game.image) {
              // A circle only has room for the square inscribed in it.
              final image? => Image.asset(
                image,
                width: circle ? s * 0.7 : s,
                height: circle ? s * 0.7 : s,
                filterQuality: FilterQuality.medium,
              ),
              null => Icon(game.icon, size: s * 0.42, color: color),
            },
          );
        },
      ),
    );
  }
}
