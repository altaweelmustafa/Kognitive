import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/color_config.dart';
import '../config/domain_config.dart';
import '../models/game.dart';

/// Artwork for a game: its icon standing on the wide banner of its domain,
/// hanging a little below the banner's bottom edge so it reads as lifted
/// off it. With [circle] it is the bare icon in a circle instead.
class GameArt extends StatelessWidget {
  const GameArt({
    super.key,
    required this.game,
    this.circle = false,
    this.rounded = true,
  });

  final Game game;
  final bool circle;

  /// False for a banner that runs edge to edge and needs square corners.
  final bool rounded;

  /// Banner width over height.
  static const _bannerRatio = 16 / 9;

  /// How far the icon hangs below the banner and how far it starts beneath
  /// the banner's top edge, both as fractions of the banner's height.
  static const _drop = 0.13;
  static const _inset = 0.09;

  /// Width over height of the whole artwork, drop included.
  static const aspectRatio = _bannerRatio / (1 + _drop);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = game.domain.color(c);

    if (circle) {
      return AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, box) {
            final s = box.maxWidth;
            return Center(
              child: switch (game.image) {
                // A circle only has room for the square inscribed in it.
                final image? => Image.asset(
                  image,
                  width: s * 0.7,
                  height: s * 0.7,
                  filterQuality: FilterQuality.medium,
                ),
                null => Icon(game.icon, size: s * 0.42, color: color),
              },
            );
          },
        ),
      );
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = w / _bannerRatio;
          final top = h * _inset;
          final iconHeight = h * (1 + _drop - _inset);
          final iconWidth = w * 0.8;
          final radius = rounded
              ? BorderRadius.circular(w * 0.05)
              : BorderRadius.zero;
          // The shadow the icon casts on the banner, down and to the right.
          final cast = Offset(h * 0.035, h * 0.06);

          final image = game.image;
          Widget icon(Color? tint) => image != null
              ? Image.asset(
                  image,
                  width: iconWidth,
                  height: iconHeight,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  color: tint,
                  filterQuality: FilterQuality.medium,
                )
              : SizedBox(
                  width: iconWidth,
                  height: iconHeight,
                  // A flat glyph has no depth to show: keep it on the banner.
                  child: Align(
                    alignment: const Alignment(0, -0.65),
                    child: Icon(
                      game.icon,
                      size: h * 0.7,
                      color: tint ?? Colors.white,
                    ),
                  ),
                );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: h,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: h * 0.12,
                        offset: Offset(0, h * 0.05),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: color,
                          child: Image.asset(
                            game.domain.banner,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                        // Top light, bottom shade: a gentle bevel.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.16),
                                Colors.white.withValues(alpha: 0),
                                Colors.black.withValues(alpha: 0.18),
                              ],
                              stops: const [0, 0.45, 1],
                            ),
                          ),
                        ),
                        // Clipped to the banner, so the shadow stays on it
                        // while the icon itself carries on past the edge.
                        Positioned(
                          left: (w - iconWidth) / 2 + cast.dx,
                          top: top + cast.dy,
                          child: ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: h * 0.035,
                              sigmaY: h * 0.035,
                            ),
                            child: icon(Colors.black.withValues(alpha: 0.38)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (w - iconWidth) / 2,
                top: top,
                child: icon(null),
              ),
            ],
          );
        },
      ),
    );
  }
}
