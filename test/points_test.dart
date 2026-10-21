import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/games/points/points_screen.dart';
import 'package:kognitiv/games/points/points_tutorial.dart';
import 'package:kognitiv/theme/app_theme.dart';

import 'fake_backend.dart';

void main() {
  testWidgets(
    'one round at the level the server gives, then the result is saved',
    (tester) async {
      tester.view.physicalSize = const Size(428, 926);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final backend = FakeBackend();
      await backend.install(loggedIn: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: PointsScreen(random: Random(3)),
        ),
      );
      await tester.tap(find.text('Skip'));
      await tester.pump(); // the level request
      await tester.pump(const Duration(milliseconds: 50));

      // The level comes from the server: it carries over between sessions.
      expect(find.text('LEVEL 3'), findsOneWidget);
      expect(find.text('Set the toggles'), findsOneWidget);
      const frame = Duration(milliseconds: 100);
      var frames = 0;
      while (find.text('Set the toggles').evaluate().isNotEmpty) {
        // Flip the first switch now and then, like a distracted player.
        if (frames % 25 == 10) {
          await tester.tap(find.byKey(const ValueKey('switch-0')));
        }
        await tester.pump(frame);
        expect(++frames, lessThan(900), reason: 'the round never ended');
      }
      expect(find.textContaining('of 10 delivered'), findsOneWidget);
      await tester.pump(PointsScreen.betweenRoundsFor);
      await tester.pumpAndSettle();

      // One round, then straight to the score.
      final round = backend.pointsRounds!.single;
      expect(round['level'], 3);
      expect(round['points'], 10);
      expect(round['correct'], inInclusiveRange(0, 10));
      expect(round['duration_ms'], greaterThan(20000));
      expect(find.text('613'), findsOneWidget); // score from the server (612.5)
      expect(find.text('Points delivered'), findsOneWidget);
    },
  );

  testWidgets('the tutorial: watch, steer one point, practise, then Start', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await backend.install(loggedIn: true);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: PointsScreen()),
    );
    expect(find.byType(PointsTutorial), findsOneWidget);

    Future<void> runUntil(Finder finder) async {
      for (var frames = 0; finder.evaluate().isEmpty; frames++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(frames, lessThan(400), reason: 'never showed $finder');
      }
    }

    expect(find.text('Follow the lines'), findsOneWidget);
    await runUntil(find.text('Delivered'));
    await tester.pump(const Duration(milliseconds: 1200));

    // Left alone, the toggles send the 2 to the wrong target.
    expect(find.text('Flip the toggles'), findsOneWidget);
    await runUntil(find.text('Wrong target'));
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('Try again'), findsOneWidget);

    // Both toggles flipped: the first to the right, the second to the left.
    await tester.tap(find.byKey(const ValueKey('switch-0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('switch-2')));
    await tester.pump();
    expect(find.text('All set'), findsOneWidget);
    await runUntil(find.text('Delivered'));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Your turn'), findsOneWidget);
    await runUntil(find.textContaining('of 3 delivered'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Ready?'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump(); // the level request
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PointsTutorial), findsNothing);
    expect(find.text('Set the toggles'), findsOneWidget);
  });
}
