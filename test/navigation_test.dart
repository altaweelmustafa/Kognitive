import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/app.dart';
import 'package:kognitiv/data/session.dart';
import 'package:kognitiv/routing/app_router.dart';
import 'package:kognitiv/routing/routes.dart';
import 'package:kognitiv/screens/home/greeting.dart';

import 'fake_backend.dart';

void main() {
  test('greeting follows the time of day and uses the first name', () {
    expect(
      Greeting.greetingFor(DateTime(2026, 10, 12, 8), 'Mustafa Altaweel'),
      'Good morning, Mustafa',
    );
    expect(
      Greeting.greetingFor(DateTime(2026, 10, 12, 14), 'Mustafa'),
      'Good afternoon, Mustafa',
    );
    expect(
      Greeting.greetingFor(DateTime(2026, 10, 12, 19), 'Mustafa'),
      'Good evening, Mustafa',
    );
    expect(
      Greeting.greetingFor(DateTime(2026, 10, 12, 2), 'Mustafa'),
      'Welcome back, Mustafa',
    );
    expect(
      Greeting.greetingFor(DateTime(2026, 10, 12, 8), null),
      'Good morning',
    );
  });

  setUp(() {
    appRouter.go(Routes.home);
  });

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const KognitivApp());
    await tester.pumpAndSettle();
  }

  testWidgets('logged out: only the start screens are reachable', (
    tester,
  ) async {
    await FakeBackend().install();
    await start(tester);
    expect(find.text('Sign up'), findsOneWidget);

    appRouter.go(Routes.brain);
    await tester.pumpAndSettle();
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('KPI History'), findsNothing);
  });

  testWidgets('home marks solved dailies and offers the unfinished sudoku', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..dailySolved = ['chess-puzzles']
      ..sudokuUnfinished = true;
    await backend.install(loggedIn: true);
    await start(tester);

    await tester.scrollUntilVisible(
      find.text('Chess Puzzles'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('daily-solved-chess-puzzles')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('daily-solved-sudoku')), findsNothing);
    expect(find.text(' · Daily solved'), findsOneWidget);

    expect(find.text('CONTINUE SUDOKU'), findsOneWidget);
    expect(find.text('12:34 played · 45 of 81 filled'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('continue-sudoku')));
    await tester.pumpAndSettle();
    // Straight into the puzzle, past the picker.
    expect(backend.requests, contains('GET /sudoku/puzzles/daily-2026-10-12'));
    expect(find.text('DAILY PUZZLE'), findsOneWidget);
    expect(find.text('Choose a puzzle'), findsNothing);
  });

  testWidgets('log in → every tab → article → log out', (tester) async {
    final backend = FakeBackend();
    await backend.install(loggedIn: true);
    await Session.instance.logout();
    await start(tester);

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'dash@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'wrong-password',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(GestureDetector, 'Log in').last);
    await tester.pumpAndSettle();
    expect(find.text('Wrong email or password.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'correct-horse',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(GestureDetector, 'Log in').last);
    await tester.pumpAndSettle();
    expect(find.text("Today's Session"), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // streak, from the server
    expect(find.text('981'), findsOneWidget); // overall KPI, from the server
    expect(
      find.text('Memory Matrix'),
      findsOneWidget,
    ); // today's session, from the server
    expect(find.textContaining(', Dash'), findsOneWidget); // greeting

    await tester.tap(find.text('Your Brain'));
    await tester.pumpAndSettle();
    expect(find.text('KPI History'), findsOneWidget);
    expect(find.text('981'), findsNWidgets(2)); // memory level and overall
    expect(
      find.text('+23'),
      findsOneWidget,
    ); // overall: 990 → 1012.5 between the last two days
    await tester.scrollUntilVisible(find.text('ARIMA forecast'), 400);
    expect(find.text('Improving'), findsOneWidget);
    expect(find.text('1040'), findsOneWidget); // forecast for the next session
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Not played yet.'), findsWidgets);

    // Chess and Sudoku get their own cards at the end.
    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('1587'), findsOneWidget);
    expect(find.text('Estimated Elo'), findsOneWidget);
    expect(find.text('More Games'), findsOneWidget); // their own section
    expect(find.text('23'), findsOneWidget);
    expect(find.text('Medium solved'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Quick Math'), findsOneWidget);
    expect(find.text('31'), findsOneWidget); // best run
    expect(find.text('88%'), findsOneWidget);

    await tester.tap(find.text('Games'));
    await tester.pumpAndSettle();
    expect(find.text('Your Games'), findsOneWidget);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('Feed Your Brain'), findsOneWidget);
    expect(find.text('Stress Less'), findsOneWidget);

    // Search matches title, summary or category, in any word order.
    await tester.enterText(find.byType(TextField), 'attention STRESS');
    await tester.pumpAndSettle();
    expect(find.text('Stress Less'), findsOneWidget);
    expect(find.text('Feed Your Brain'), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No articles match "zzz".'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'foods');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feed Your Brain'));
    await tester.pumpAndSettle();
    expect(find.text('What to eat'), findsOneWidget);
    expect(find.text('Leafy greens'), findsOneWidget);

    // A stored login survives a restart; logging out returns to the start.
    appRouter.go(Routes.settings);
    await tester.pumpAndSettle();
    expect(find.text('dash@example.com'), findsOneWidget);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign up'), findsOneWidget);
    expect(backend.requests, contains('POST /auth/logout'));
  });
}
