import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../config/domain_config.dart';
import '../../data/api_client.dart';
import '../../data/games.dart';
import '../../games/sudoku/sudoku_models.dart';
import '../../models/progress_models.dart';
import '../../theme/app_text.dart';
import '../../widgets/pill_button.dart';

/// What the player did on [day]: opened by a tap on the calendar.
Future<void> showDaySheet(BuildContext context, DateTime day) =>
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.elevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DaySheet(day: day),
    );

class DaySheet extends StatefulWidget {
  const DaySheet({super.key, required this.day, this.api});

  final DateTime day;
  final ApiClient? api;

  @override
  State<DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<DaySheet> {
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  late final ApiClient _api = widget.api ?? ApiClient();
  DaySummary? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The server keys days as `yyyy-mm-dd`, like the calendar.
  String get _key {
    final d = widget.day;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final summary = DaySummary.fromJson(await _api.get('/me/day/$_key'));
      if (mounted) setState(() => _summary = summary);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = widget.day;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}',
              style: AppText.sectionTitle,
            ),
            const SizedBox(height: 16),
            ..._body(),
          ],
        ),
      ),
    );
  }

  List<Widget> _body() {
    final c = context.colors;
    final summary = _summary;
    if (_error case final error?) {
      return [
        Text(error, style: AppText.label.copyWith(color: c.declining)),
        const SizedBox(height: 16),
        Center(
          child: PillButton(
            label: 'Try again',
            width: 160,
            height: 42,
            onPressed: _load,
          ),
        ),
      ];
    }
    if (summary == null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(color: c.brandAccent)),
        ),
      ];
    }
    if (summary.isEmpty) {
      return [
        Text(
          'Nothing played this day.',
          style: AppText.body.copyWith(color: c.textSecondary),
        ),
      ];
    }

    final meta = AppText.mono12.copyWith(
      color: c.textMuted,
      fontWeight: FontWeight.w700,
    );
    final sudoku = [
      for (final d in SudokuDifficulty.values)
        if (summary.sudokuSolved[d]! > 0)
          '${summary.sudokuSolved[d]} ${d.label}',
    ];
    final extras = <(String, String)>[
      if (summary.mathRuns > 0)
        (
          'Quick Math',
          summary.mathRuns == 1
              ? 'Best ${summary.mathBest} · 1 run'
              : 'Best ${summary.mathBest} · ${summary.mathRuns} runs',
        ),
      if (summary.chessSolved > 0)
        (
          'Chess Puzzles',
          summary.chessSolved == 1
              ? '1 solved'
              : '${summary.chessSolved} solved',
        ),
      if (sudoku.isNotEmpty) ('Sudoku', '${sudoku.join(', ')} solved'),
    ];

    return [
      if (summary.kpi case final kpi?) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${kpi.round()}',
              key: const ValueKey('day-kpi'),
              style: AppText.mono16.copyWith(
                fontSize: 40,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'KPI THAT DAY',
                style: meta.copyWith(color: c.brandAccent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],
      if (summary.games.isNotEmpty) ...[
        Text('SESSION GAMES', style: meta),
        const SizedBox(height: 8),
        for (final g in summary.games)
          _row(
            color: g.domain.color(c),
            title: _gameName(g.gameId),
            value: '${g.score.round()}',
          ),
        const SizedBox(height: 12),
      ],
      if (extras.isNotEmpty) ...[
        Text('MORE GAMES', style: meta),
        const SizedBox(height: 8),
        for (final (title, value) in extras)
          _row(color: c.textMuted, title: title, value: value),
      ],
    ];
  }

  static String _gameName(String id) =>
      games.where((g) => g.id == id).firstOrNull?.name ?? id;

  Widget _row({
    required Color color,
    required String title,
    required String value,
  }) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: AppText.listTitle)),
          Text(value, style: AppText.mono16.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}
