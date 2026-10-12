import 'package:flutter/material.dart';

/// Bare line chart: no axes, last point marked.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _SparklinePainter(values, color));
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final span = hi == lo ? 1.0 : hi - lo;
    const pad = 4.0;

    final points = [
      for (final (i, v) in values.indexed)
        Offset(
          pad + (size.width - pad * 2) * i / (values.length - 1),
          size.height - pad - (size.height - pad * 2) * (v - lo) / span,
        ),
    ];
    canvas.drawPath(
      Path()..addPolygon(points, false),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(points.last, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}
