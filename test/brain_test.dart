import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/data/progress.dart';
import 'package:kognitiv/data/session.dart';
import 'package:kognitiv/screens/brain/kpi_history_chart.dart';
import 'package:kognitiv/screens/brain/session_calendar.dart';
import 'package:kognitiv/theme/app_theme.dart';

import 'fake_backend.dart';

void main() {
  Future<FakeBackend> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await backend.install(loggedIn: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return backend;
  }

  testWidgets('tap or drag along the KPI history to read a day', (
    tester,
  ) async {
    await show(tester, const SizedBox());
    await Progress.instance.refresh();
    // Scores 880, 905, 940, 990, 1012.5 from Thursday 8 to Monday 12 October.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: KpiHistoryChart(
              history: Progress.instance.performance!.history,
            ),
          ),
        ),
      ),
    );
    String day() => tester
        .widget<Text>(find.byKey(const ValueKey('kpi-readout-day')))
        .data!;
    String score() => tester
        .widget<Text>(find.byKey(const ValueKey('kpi-readout-score')))
        .data!;

    // Nothing chosen: the latest day.
    expect(day(), 'LATEST');
    expect(score(), '1013');
    expect(find.text('+23 vs day before'), findsOneWidget);

    // A tap picks the nearest day.
    final chart = find.byKey(const ValueKey('kpi-chart'));
    await tester.tapAt(tester.getTopLeft(chart) + const Offset(5, 100));
    await tester.pump();
    expect(day(), 'THU 8 OCT');
    expect(score(), '880');
    expect(find.textContaining('vs day before'), findsNothing); // first day

    // Dragging scrubs across the days.
    final gesture = await tester.startGesture(
      tester.getTopLeft(chart) + const Offset(5, 100),
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveTo(tester.getCenter(chart));
    await tester.pump();
    expect(day(), 'SAT 10 OCT');
    expect(score(), '940');
    expect(find.text('+35 vs day before'), findsOneWidget);
    await gesture.up();

    // The weekday labels work too; tapping the chosen one lets go.
    await tester.tap(find.text('Sun'));
    await tester.pump();
    expect(score(), '990');
    await tester.tap(find.text('Sun'));
    await tester.pump();
    expect(day(), 'LATEST');
  });

  testWidgets('tap a played day on the calendar to see what was played', (
    tester,
  ) async {
    final backend = await show(
      tester,
      SessionCalendar(month: DateTime(2026, 10)),
    );
    await Session.instance.refreshActivity(); // played the 11th and 12th
    await tester.pumpAndSettle();

    // A day without play does nothing.
    await tester.tap(find.byKey(const ValueKey('day-13')));
    await tester.pumpAndSettle();
    expect(backend.requests.where((r) => r.contains('/me/day/')), isEmpty);

    await tester.tap(find.byKey(const ValueKey('day-12')));
    await tester.pumpAndSettle();
    expect(backend.requests, contains('GET /me/day/2026-10-12'));
    expect(find.text('Monday, 12 October'), findsOneWidget);
    expect(find.text('1013'), findsNWidgets(2)); // the day's KPI and the game
    expect(find.text('Memory Matrix'), findsOneWidget);
    expect(find.text('Best 27 · 2 runs'), findsOneWidget);
    expect(find.text('1 Easy solved'), findsOneWidget);

    // If the server has nothing for a day, the sheet says so.
    Navigator.of(tester.element(find.byType(SessionCalendar))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-11')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing played this day.'), findsOneWidget);
  });
}
