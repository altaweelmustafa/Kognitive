import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../config/domain_config.dart';
import '../../data/progress.dart';
import '../../games/sudoku/sudoku_models.dart';
import '../../models/cognitive_domain.dart';
import '../../models/progress_models.dart';
import '../../theme/app_text.dart';
import 'domain_history_card.dart';
import 'kpi_history_chart.dart';
import 'session_calendar.dart';

/// The player's numbers. Everything here comes from the backend.
class BrainScreen extends StatelessWidget {
  const BrainScreen({super.key});

  /// Top of the KPI bar scale.
  static const kpiScaleMax = 1800;
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Progress.instance,
        builder: (context, _) =>
            _content(context, Progress.instance.performance),
      ),
    );
  }

  Widget _content(BuildContext context, Performance? performance) {
    final c = context.colors;
    final subtitle = AppText.listTitle.copyWith(fontWeight: FontWeight.w600);
    final history = performance?.history ?? const <ScorePoint>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(25, 36, 20, 24),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text('Your Brain', style: AppText.screenTitle),
        ),
        const SizedBox(height: 24),
        _KpiCard(performance: performance),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 16),
        Text('KPI History', style: subtitle),
        const SizedBox(height: 24),
        if (history.length < 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Play on two different days to see your history.',
              style: AppText.body.copyWith(color: c.textSecondary),
            ),
          )
        else
          KpiHistoryChart(
            values: [for (final p in history) p.score],
            labels: [for (final p in history) _weekdays[p.day.weekday - 1]],
          ),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 16),
        Text('Session Calendar', style: subtitle),
        const SizedBox(height: 16),
        SessionCalendar(month: DateTime.now()),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 16),
        Text('Domain History', style: subtitle),
        const SizedBox(height: 16),
        if (performance != null) ...[
          for (final domain in CognitiveDomain.values)
            DomainHistoryCard(
              domain: domain,
              performance: performance.domains[domain]!,
            ),
          // Chess, Sudoku and Quick Math sit outside the session and the KPI.
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Text('More Games', style: subtitle),
          const SizedBox(height: 4),
          Text(
            'Played any day. Not part of your KPI.',
            style: AppText.label.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          _PuzzleCard(
            title: 'Chess Puzzles',
            color: c.planning,
            stats: [
              ('Estimated Elo', performance.chessElo?.toString() ?? '–'),
              ('Puzzles solved', '${performance.chessSolved}'),
            ],
          ),
          _PuzzleCard(
            title: 'Sudoku',
            color: c.reasoning,
            stats: [
              for (final d in SudokuDifficulty.values)
                ('${d.label} solved', '${performance.sudokuSolved[d]}'),
            ],
          ),
          _PuzzleCard(
            title: 'Quick Math',
            color: c.reasoning,
            note: 'Best is the most correct answers in one 60-second run.',
            stats: [
              ('Best', performance.mathBest?.toString() ?? '–'),
              ('Runs played', '${performance.mathGames}'),
              (
                'Accuracy',
                performance.mathAccuracy == null
                    ? '–'
                    : '${performance.mathAccuracy}%',
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Chess, Sudoku or Quick Math: a few numbers of their own. These games are
/// outside the session, so they have no KPI, trend or forecast.
class _PuzzleCard extends StatelessWidget {
  const _PuzzleCard({
    required this.title,
    required this.color,
    required this.stats,
    this.note = 'Practice puzzles only. Daily puzzles are not counted.',
  });

  final String title;
  final Color color;

  /// (label, value) pairs.
  final List<(String, String)> stats;
  final String note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
              Text(
                title,
                style: AppText.listTitle.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (label, value) in stats)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: AppText.mono16.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: AppText.caption.copyWith(color: c.textMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(note, style: AppText.caption.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

/// The headline card: the overall KPI large on top, then one bar per domain.
class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.performance});

  /// Null while loading.
  final Performance? performance;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final overall = performance?.overall;
    final history = performance?.history ?? const <ScorePoint>[];
    final played =
        performance?.domains.values.where((d) => d.level != null).length ?? 0;

    // How the overall score moved between the last two days played.
    final change = history.length < 2
        ? null
        : (history.last.score - history[history.length - 2].score).round();
    final changeColor = switch (change) {
      null || 0 => c.textSecondary,
      > 0 => c.improving,
      _ => c.declining,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "KOGNITIV'S PERFORMANCE INDEX",
            style: AppText.mono12.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Shrinks to fit beside the change badge on narrow screens or
              // with large system text.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        overall?.round().toString() ?? '–',
                        key: const ValueKey('overall-kpi'),
                        style: AppText.mono16.copyWith(
                          fontSize: 68,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                          color: overall == null ? c.textMuted : c.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Text(
                          'KPI',
                          style: AppText.mono16.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: c.brandAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (change != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: changeColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              change > 0
                                  ? Icons.arrow_upward
                                  : (change < 0
                                        ? Icons.arrow_downward
                                        : Icons.arrow_forward),
                              size: 14,
                              color: changeColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              change > 0 ? '+$change' : '$change',
                              style: AppText.mono16.copyWith(
                                fontWeight: FontWeight.w700,
                                color: changeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'since last time',
                        style: AppText.caption.copyWith(color: c.textMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            overall == null
                ? 'Play a session game to get your first score.'
                : 'Overall, across the $played of ${CognitiveDomain.values.length} domains you have played.',
            style: AppText.label.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 18),
          for (final domain in CognitiveDomain.values)
            _KpiRow(domain: domain, value: performance?.domains[domain]?.level),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.domain, required this.value});

  final CognitiveDomain domain;

  /// Null until the domain has been played.
  final double? value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = this.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 111,
            child: Text(
              domain.label,
              style: AppText.mono16.copyWith(color: c.textSecondary),
            ),
          ),
          Expanded(
            child: Container(
              height: 34,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.elevated,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ((value ?? 0) / BrainScreen.kpiScaleMax).clamp(
                  0.0,
                  1.0,
                ),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: domain.color(c),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              value?.round().toString() ?? '–',
              textAlign: TextAlign.right,
              style: AppText.mono16.copyWith(
                color: value == null ? c.textMuted : c.brandAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
