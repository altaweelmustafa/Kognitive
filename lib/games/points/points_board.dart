import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';
import '../shared/tutorial_frame.dart';
import 'points_logic.dart';

/// One colour per target, at most six.
List<Color> pointsColours(AppColors c) => [
  c.memory,
  c.attention,
  c.reasoning,
  c.planning,
  c.flexibility,
  c.brandAccent,
];

/// The tracks of a round, with a generous tap area over each switch.
class PointsBoard extends StatelessWidget {
  const PointsBoard({
    super.key,
    required this.round,
    required this.colours,
    this.onToggle,
    this.highlight,
  });

  final PointsRound round;
  final List<Color> colours;

  /// Null while switches can't be flipped.
  final ValueChanged<int>? onToggle;

  /// A switch to point at with a pulsing outline, in the tutorial.
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AspectRatio(
      aspectRatio: PointsOfThought.boardWidth / PointsOfThought.boardHeight,
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = box.maxWidth / PointsOfThought.boardWidth;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _TrackPainter(
                    round: round,
                    colours: colours,
                    palette: c,
                  ),
                ),
              ),
              for (final node in round.layout.switches)
                Positioned(
                  left: round.layout.nodes[node].position.dx * scale - 34,
                  top: round.layout.nodes[node].position.dy * scale - 28,
                  width: 68,
                  height: 56,
                  child: GestureDetector(
                    key: ValueKey('switch-$node'),
                    behavior: HitTestBehavior.opaque,
                    onTapDown: onToggle == null ? null : (_) => onToggle!(node),
                    child: Center(
                      child: TutorialPulse(
                        active: highlight == node,
                        color: c.attention,
                        radius: 18,
                        child: const SizedBox(width: 58, height: 38),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Draws the tracks, switches, targets and dots. Repainted every frame.
class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.round,
    required this.colours,
    required this.palette,
  });

  final PointsRound round;
  final List<Color> colours;
  final AppColors palette;

  static const _flashFor = 0.6; // seconds a target shows right / wrong
  static const _toggleWidth = 46.0;
  static const _toggleHeight = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / PointsOfThought.boardWidth;
    Offset at(Offset p) => p * scale;
    final layout = round.layout;

    final idle = Paint()
      ..color = palette.elevated
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final open = Paint()
      ..color = palette.textMuted
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    // Tracks: the way each switch points is drawn brighter, on top.
    canvas.drawLine(
      at(TrackLayout.origin),
      at(layout.nodes[layout.root].position),
      open,
    );
    for (final pass in [false, true]) {
      for (final i in layout.switches) {
        final node = layout.nodes[i];
        final right = round.sendsRight[i]!;
        for (final (child, taken) in [
          (node.left!, !right),
          (node.right!, right),
        ]) {
          if (taken == pass) {
            canvas.drawLine(
              at(node.position),
              at(layout.nodes[child].position),
              taken ? open : idle,
            );
          }
        }
      }
    }

    // Origin mouth, with the next dot waiting inside.
    final origin = at(TrackLayout.origin);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(center: origin, width: 58, height: 40),
        topLeft: const Radius.circular(29),
        topRight: const Radius.circular(29),
      ),
      Paint()..color = palette.surface,
    );
    if (round.nextColour case final next?) {
      canvas.drawCircle(origin, 12.5, Paint()..color = colours[next]);
      _label(canvas, origin, '${next + 1}', 15);
    }

    // Switches: a toggle, with its knob on the side dots are sent to.
    for (final i in layout.switches) {
      final centre = at(layout.nodes[i].position);
      final right = round.sendsRight[i]!;
      final pill = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: centre,
          width: _toggleWidth,
          height: _toggleHeight,
        ),
        const Radius.circular(_toggleHeight / 2),
      );
      canvas.drawRRect(pill.inflate(3), Paint()..color = palette.background);
      canvas.drawRRect(pill, Paint()..color = palette.brandFill);
      final travel = (_toggleWidth - _toggleHeight) / 2;
      canvas.drawCircle(
        centre + Offset(right ? travel : -travel, 0),
        _toggleHeight / 2 - 3,
        Paint()..color = palette.onBrand,
      );
    }

    // Targets, flashing green or red when a dot has just arrived.
    for (final node in layout.nodes) {
      if (node.isSwitch) continue;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: at(node.position), width: 40, height: 40),
        const Radius.circular(8),
      );
      final arrival = round.lastArrival[node.target];
      if (arrival != null && round.clock - arrival.at < _flashFor) {
        canvas.drawRRect(
          rect.inflate(5),
          Paint()
            ..color = arrival.correct ? palette.improving : palette.declining,
        );
      }
      canvas.drawRRect(rect, Paint()..color = colours[node.target!]);
      _label(canvas, at(node.position), '${node.target! + 1}', 20);
    }

    // Points.
    for (final dot in round.dots) {
      final centre = at(dot.position);
      canvas.drawCircle(centre, 15, Paint()..color = palette.background);
      canvas.drawCircle(centre, 12.5, Paint()..color = colours[dot.colour]);
      _label(canvas, centre, '${dot.colour + 1}', 15);
    }
  }

  /// The target number, so matching never depends on colour alone.
  void _label(Canvas canvas, Offset centre, String text, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppText.mono,
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: palette.background,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) => true;
}
