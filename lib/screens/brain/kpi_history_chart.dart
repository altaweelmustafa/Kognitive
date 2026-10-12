import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';

/// Line chart with a left and bottom axis and one label per point.
class KpiHistoryChart extends StatelessWidget {
  const KpiHistoryChart({
    super.key,
    required this.values,
    required this.labels,
  });

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: CustomPaint(
            painter: _ChartPainter(
              values: values,
              axis: c.textMuted,
              line: c.brandAccent,
              dot: c.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final l in labels)
              Text(l, style: AppText.mono16.copyWith(color: c.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.values,
    required this.axis,
    required this.line,
    required this.dot,
  });

  final List<double> values;
  final Color axis;
  final Color line;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = axis
      ..strokeWidth = 2;
    canvas.drawLine(Offset.zero, Offset(0, size.height), axisPaint);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );
    if (values.length < 2) return;

    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final span = hi == lo ? 1.0 : hi - lo;
    // Keep the line clear of the axes.
    const padX = 20.0;
    final top = size.height * 0.25;
    final bottom = size.height * 0.68;

    final points = [
      for (final (i, v) in values.indexed)
        Offset(
          padX + (size.width - padX * 2) * i / (values.length - 1),
          bottom - (bottom - top) * (v - lo) / span,
        ),
    ];

    canvas.drawPath(
      Path()..addPolygon(points, false),
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (final p in points) {
      canvas.drawCircle(p, 3.5, Paint()..color = line);
      canvas.drawCircle(p, 2, Paint()..color = dot);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.values != values ||
      old.axis != axis ||
      old.line != line ||
      old.dot != dot;
}
