import 'package:flutter/material.dart';

import '../config/color_config.dart';
import '../config/domain_config.dart';
import '../models/game.dart';

/// Placeholder artwork for a game: a flat tile laid out like a playing card,
/// with the domain color as the "suit".
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
              color: c.surface,
              shape: circle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: circle ? null : BorderRadius.circular(radius),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (game.image case final image?)
                  Image.asset(
                    image,
                    width: s * 0.6,
                    height: s * 0.6,
                    filterQuality: FilterQuality.medium,
                  )
                else
                  Icon(game.icon, size: s * 0.42, color: color),
                if (!circle) ...[
                  Positioned(
                    top: s * 0.08,
                    left: s * 0.08,
                    child: _Pip(color, s * 0.07),
                  ),
                  Positioned(
                    bottom: s * 0.08,
                    right: s * 0.08,
                    child: _Pip(color, s * 0.07),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Pip extends StatelessWidget {
  const _Pip(this.color, this.size);

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.785398, // 45°, a diamond
    child: Container(width: size, height: size, color: color),
  );
}
