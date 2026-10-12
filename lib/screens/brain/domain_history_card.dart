import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../config/domain_config.dart';
import '../../models/cognitive_domain.dart';
import '../../models/progress_models.dart';
import '../../theme/app_text.dart';
import '../../widgets/sparkline.dart';

/// One domain's recent scores: level, trend, sparkline, and the forecast for
/// the next session. Trend and forecast come from the backend's model.
class DomainHistoryCard extends StatelessWidget {
  const DomainHistoryCard({
    super.key,
    required this.domain,
    required this.performance,
  });

  final CognitiveDomain domain;
  final DomainPerformance performance;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = domain.color(c);
    final p = performance;
    final scores = [for (final point in p.history) point.score];

    final (trendIcon, trendLabel, trendColor) = switch (p.trend) {
      Trend.improving => (Icons.arrow_upward, 'Improving', c.improving),
      Trend.declining => (Icons.arrow_downward, 'Declining', c.declining),
      Trend.plateau => (Icons.arrow_forward, 'Plateau', c.textSecondary),
      Trend.none => (Icons.remove, 'No data', c.textMuted),
    };
    final method = switch (p.method) {
      'arima' => 'ARIMA forecast',
      'linear' => 'Trend line, ${p.days} days',
      'average' => 'Needs 3 days for a trend',
      _ => '',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  domain.fullLabel,
                  style: AppText.listTitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(trendIcon, size: 14, color: trendColor),
              const SizedBox(width: 4),
              Text(
                trendLabel,
                style: AppText.label.copyWith(
                  color: trendColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (p.level == null)
            Text(
              'Not played yet.',
              style: AppText.label.copyWith(color: c.textMuted),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 84,
                  child: Text(
                    '${p.level!.round()}',
                    style: AppText.mono16.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: Sparkline(values: scores, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat('Days', '${p.days}'),
                _Stat(
                  'Best',
                  '${scores.reduce((a, b) => a > b ? a : b).round()}',
                ),
                _Stat(
                  'Low',
                  '${scores.reduce((a, b) => a < b ? a : b).round()}',
                ),
                _Stat('Next', '${p.forecast!.round()}', color: trendColor),
              ],
            ),
            const SizedBox(height: 10),
            Text(method, style: AppText.caption.copyWith(color: c.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption.copyWith(color: c.textMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppText.mono16.copyWith(color: color ?? c.textPrimary),
          ),
        ],
      ),
    );
  }
}
