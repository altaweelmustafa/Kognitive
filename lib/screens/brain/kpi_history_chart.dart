import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../models/progress_models.dart';
import '../../theme/app_text.dart';

/// Line chart of the overall KPI, one point per day played. Tap or drag
/// along it to read a day's score; tap the same day again to let go.
class KpiHistoryChart extends StatefulWidget {
  const KpiHistoryChart({super.key, required this.history});

  final List<ScorePoint> history;

  @override
  State<KpiHistoryChart> createState() => _KpiHistoryChartState();
}

class _KpiHistoryChartState extends State<KpiHistoryChart> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  int? _selected;

  @override
  void didUpdateWidget(KpiHistoryChart old) {
    super.didUpdateWidget(old);
    if (_selected case final s? when s >= widget.history.length) {
      _selected = null;
    }
  }

  /// The point nearest to [x], across the chart's width.
  int _nearest(double x, double width) {
    final n = widget.history.length;
    final t = ((x - _ChartPainter.padX) / (width - _ChartPainter.padX * 2))
        .clamp(0.0, 1.0);
    return (t * (n - 1)).round();
  }

  void _pick(int index, {bool toggle = false}) {
    setState(() => _selected = toggle && _selected == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final history = widget.history;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _readout(context),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, box) => GestureDetector(
            key: const ValueKey('kpi-chart'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                _pick(_nearest(d.localPosition.dx, box.maxWidth), toggle: true),
            onHorizontalDragStart: (d) =>
                _pick(_nearest(d.localPosition.dx, box.maxWidth)),
            onHorizontalDragUpdate: (d) =>
                _pick(_nearest(d.localPosition.dx, box.maxWidth)),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: CustomPaint(
                painter: _ChartPainter(
                  values: [for (final p in history) p.score],
                  selected: _selected,
                  axis: c.textMuted,
                  line: c.brandAccent,
                  dot: c.textPrimary,
                  guide: c.elevated,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final (i, p) in history.indexed)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _pick(i, toggle: true),
                child: Text(
                  _weekdays[p.day.weekday - 1],
                  style: AppText.mono16.copyWith(
                    color: i == _selected ? c.brandAccent : c.textSecondary,
                    fontWeight: i == _selected ? FontWeight.w700 : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// The chosen day's score and how it moved from the day before; the
  /// latest day while nothing is chosen.
  Widget _readout(BuildContext context) {
    final c = context.colors;
    final history = widget.history;
    final i = _selected ?? history.length - 1;
    final point = history[i];
    final change = i == 0 ? null : (point.score - history[i - 1].score).round();
    final changeColor = switch (change) {
      null || 0 => c.textSecondary,
      > 0 => c.improving,
      _ => c.declining,
    };
    final day = point.day;
    final label = _selected == null
        ? 'LATEST'
        : '${_weekdays[day.weekday - 1]} ${day.day} ${_months[day.month - 1]}'
              .toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              key: const ValueKey('kpi-readout-day'),
              style: AppText.mono12.copyWith(
                color: _selected == null ? c.textMuted : c.brandAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${point.score.round()}',
              key: const ValueKey('kpi-readout-score'),
              style: AppText.mono16.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        if (change != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              '${change > 0 ? '+' : ''}$change vs day before',
              style: AppText.mono12.copyWith(color: changeColor),
            ),
          ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.values,
    required this.selected,
    required this.axis,
    required this.line,
    required this.dot,
    required this.guide,
  });

  /// Keeps the line clear of the axes. Taps are mapped with it too.
  static const padX = 20.0;

  final List<double> values;
  final int? selected;
  final Color axis;
  final Color line;
  final Color dot;
  final Color guide;

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
    final top = size.height * 0.2;
    final bottom = size.height * 0.75;

    final points = [
      for (final (i, v) in values.indexed)
        Offset(
          padX + (size.width - padX * 2) * i / (values.length - 1),
          bottom - (bottom - top) * (v - lo) / span,
        ),
    ];

    if (selected case final s?) {
      canvas.drawLine(
        Offset(points[s].dx, 0),
        Offset(points[s].dx, size.height),
        Paint()
          ..color = guide
          ..strokeWidth = 2,
      );
    }
    canvas.drawPath(
      Path()..addPolygon(points, false),
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (final (i, p) in points.indexed) {
      final chosen = i == selected;
      canvas.drawCircle(p, chosen ? 7 : 3.5, Paint()..color = line);
      canvas.drawCircle(p, chosen ? 3.5 : 2, Paint()..color = dot);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.values != values ||
      old.selected != selected ||
      old.axis != axis ||
      old.line != line ||
      old.dot != dot ||
      old.guide != guide;
}
