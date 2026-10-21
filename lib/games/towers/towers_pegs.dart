import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../shared/tutorial_frame.dart';
import 'towers_logic.dart';

/// Three pegs of heights 3, 2 and 1 with their balls.
class TowerPegs extends StatelessWidget {
  const TowerPegs({
    super.key,
    required this.pegs,
    required this.colors,
    required this.ball,
    this.frozen,
    this.lifted,
    this.onTap,
    this.highlight,
  });

  final List<List<int>> pegs;
  final List<Color> colors;
  final double ball; // diameter
  final int? frozen;
  final int? lifted;
  final ValueChanged<int>? onTap;

  /// A peg to point at with a pulsing outline, in tutorials.
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tallest = Towers.capacities.reduce((a, b) => a > b ? a : b);
    final rod = ball * 0.16;
    // Room above the tallest peg for a lifted ball.
    final height = ball * (tallest + (onTap == null ? 0.3 : 1.3));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: Row(
            mainAxisSize: onTap == null ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var p = 0; p < pegs.length; p++)
                _slot(
                  child: TutorialPulse(
                    active: highlight == p,
                    color: c.textSecondary,
                    radius: ball * 0.3,
                    child: GestureDetector(
                      key: onTap == null ? null : ValueKey('peg-$p'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onTap == null ? null : () => onTap!(p),
                      child: SizedBox(
                        width: ball * 1.35,
                        height: height,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              width: rod,
                              height: ball * (Towers.capacities[p] + 0.25),
                              decoration: BoxDecoration(
                                color: c.elevated,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(rod / 2),
                                ),
                              ),
                            ),
                            for (final (i, colour) in pegs[p].indexed)
                              AnimatedPositioned(
                                key: ValueKey('ball-$colour'),
                                duration: const Duration(milliseconds: 120),
                                // The top ball of a lifted peg floats above the rod.
                                bottom: lifted == p && i == pegs[p].length - 1
                                    ? ball * (Towers.capacities[p] + 0.3)
                                    : ball * i,
                                child: TowerBall(
                                  color: colors[colour],
                                  size: ball,
                                  frozen: colour == frozen,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          height: rod,
          width: onTap == null ? ball * 1.35 * pegs.length : double.infinity,
          decoration: BoxDecoration(
            color: c.elevated,
            borderRadius: BorderRadius.circular(rod / 2),
          ),
        ),
      ],
    );
  }

  Widget _slot({required Widget child}) =>
      onTap == null ? child : Expanded(child: Center(child: child));
}

/// A ball. Frozen ones are iced over and carry a snowflake, so the frost
/// doesn't depend on colour alone.
class TowerBall extends StatelessWidget {
  const TowerBall({
    super.key,
    required this.color,
    required this.size,
    this.frozen = false,
  });

  final Color color;
  final double size;
  final bool frozen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: frozen ? Color.lerp(color, Colors.white, 0.6) : color,
        shape: BoxShape.circle,
        border: frozen
            ? Border.all(color: Colors.white, width: size * 0.06)
            : null,
      ),
      child: frozen
          ? Icon(Icons.ac_unit, size: size * 0.55, color: c.background)
          : null,
    );
  }
}
