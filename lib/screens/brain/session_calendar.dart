import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../data/session.dart';
import '../../theme/app_text.dart';
import 'day_sheet.dart';

/// Month grid. Days on which the player solved something get a flame;
/// tap one to see what was played.
class SessionCalendar extends StatelessWidget {
  const SessionCalendar({super.key, required this.month});

  /// Any date inside the month to show.
  final DateTime month;

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
  static const _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Session.instance,
    builder: (context, _) => _build(context),
  );

  /// The server records days in UTC, as `yyyy-mm-dd`.
  static bool playedOn(DateTime day) => Session.instance.playedDays.contains(
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
  );

  Widget _build(BuildContext context) {
    final c = context.colors;
    final streakDays = Session.instance.streak;
    final now = DateTime.now();
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday % 7; // Sunday-first
    final days = [
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(month.year, month.month, d),
    ];
    final played = days.where(playedOn).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_months[month.month - 1]} ${month.year}',
                  style: AppText.listTitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.local_fire_department, size: 16, color: c.memory),
              const SizedBox(width: 4),
              Text(
                '$streakDays-day streak',
                style: AppText.mono12.copyWith(color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: AppText.mono12.copyWith(color: c.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var row = 0; row * 7 < offset + daysInMonth; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: switch (row * 7 + col - offset) {
                      final i when i >= 0 && i < daysInMonth => _DayCell(
                        day: days[i],
                        played: playedOn(days[i]),
                        today: DateUtils.isSameDay(days[i], now),
                        future: days[i].isAfter(now),
                        onTap: playedOn(days[i])
                            ? () => showDaySheet(context, days[i])
                            : null,
                      ),
                      _ => const SizedBox(height: _DayCell.height),
                    },
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              played == 1
                  ? '1 day played this month'
                  : '$played days played this month',
              style: AppText.mono12.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.played,
    required this.today,
    required this.future,
    this.onTap,
  });

  static const height = 46.0;

  final DateTime day;
  final bool played;
  final bool today;
  final bool future;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: today ? c.elevated : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          key: ValueKey('day-${day.day}'),
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: _content(c),
        ),
      ),
    );
  }

  Widget _content(AppColors c) {
    return SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 18,
            child: played
                ? Icon(Icons.local_fire_department, size: 18, color: c.memory)
                : null,
          ),
          Text(
            '${day.day}',
            style: AppText.mono12.copyWith(
              color: future
                  ? c.textMuted
                  : (played ? c.textPrimary : c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
