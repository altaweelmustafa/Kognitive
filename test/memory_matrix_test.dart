import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/app.dart';
import 'package:kognitiv/data/progress.dart';
import 'package:kognitiv/games/memory_matrix/memory_matrix_logic.dart';
import 'package:kognitiv/games/memory_matrix/memory_matrix_screen.dart';
import 'package:kognitiv/games/memory_matrix/memory_matrix_tutorial.dart';
import 'package:kognitiv/routing/app_router.dart';
import 'package:kognitiv/routing/routes.dart';
import 'package:kognitiv/theme/app_theme.dart';

import 'fake_backend.dart';

void main() {
  test('rules', () {
    final p = MemoryMatrix.pattern(Random(1), 8);
    expect(p.length, 8);
    expect(p.every((c) => c >= 0 && c < 25), isTrue);
    expect(MemoryMatrix.nextTiles(8, perfect: true), 9);
    expect(MemoryMatrix.nextTiles(8, perfect: false), 7);
    expect(
      MemoryMatrix.nextTiles(MemoryMatrix.minTiles, perfect: false),
      MemoryMatrix.minTiles,
    );
  });

  testWidgets('eight rounds: tiles go up on a perfect round, down on a miss', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await backend.install(loggedIn: true);

    // The same seed here and in the game gives the same patterns.
    final mirror = Random(7);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MemoryMatrixScreen(random: Random(7)),
      ),
    );
    await tester.tap(find.text('Skip'));
    await tester.pump();

    Future<void> tap(int cell) async {
      await tester.tap(find.byKey(ValueKey('tile-$cell')));
      await tester.pump();
    }

    var tiles = MemoryMatrix.startTiles;
    final expected = <(int, int)>[]; // (tiles, found) per round
    for (var round = 1; round <= MemoryMatrix.rounds; round++) {
      final pattern = MemoryMatrix.pattern(mirror, tiles).toList();
      expect(find.text('ROUND $round OF 8'), findsOneWidget);
      expect(find.text('$tiles TILES'), findsOneWidget);

      // Taps during the flash are ignored.
      expect(find.text('Watch'), findsOneWidget);
      await tap(pattern.first);
      await tester.pump(MemoryMatrix.showFor);
      expect(find.text('Your turn'), findsOneWidget);
      expect(find.text('0 of $tiles'), findsOneWidget);

      // Rounds 3 and 6: two right, then a wrong tile. The rest: all right.
      final miss = round == 3 || round == 6;
      if (miss) {
        await tap(pattern[0]);
        await tap(pattern[0]); // tapping a found tile again changes nothing
        await tap(pattern[1]);
        await tap(
          List.generate(25, (i) => i).firstWhere((c) => !pattern.contains(c)),
        );
        expect(find.text('Missed'), findsOneWidget);
        expected.add((tiles, 2));
      } else {
        for (final cell in pattern) {
          await tap(cell);
        }
        expect(find.text('All correct'), findsOneWidget);
        expected.add((tiles, tiles));
      }
      tiles = MemoryMatrix.nextTiles(tiles, perfect: !miss);
      await tester.pump(MemoryMatrix.feedbackFor);
    }
    await tester.pumpAndSettle();

    expect([
      for (final t in backend.matrixTrials!) (t['nodes'], t['found']),
    ], expected);
    expect([for (final (n, _) in expected) n], [8, 9, 10, 9, 10, 11, 10, 11]);
    expect(find.text('988'), findsOneWidget); // score from the server (987.5)
    expect(find.text('6 of 8'), findsOneWidget);
    expect(find.text('11'), findsOneWidget); // most tiles in a perfect round
  });

  testWidgets('the session screen starts the game and marks it done', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await backend.install(loggedIn: true);
    appRouter.go(Routes.home);
    await tester.pumpWidget(const KognitivApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Declining'), findsOneWidget);
    expect(find.text('soon'), findsNWidgets(3));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryMatrixTutorial), findsOneWidget);

    // Miss every round straight away.
    await tester.tap(find.text('Skip'));
    await tester.pump();
    for (var round = 0; round < MemoryMatrix.rounds; round++) {
      await tester.pump(MemoryMatrix.showFor);
      // Find a dark tile by trying tiles until the round ends.
      for (
        var cell = 0;
        cell < 25 && find.text('Your turn').evaluate().isNotEmpty;
        cell++
      ) {
        await tester.tap(find.byKey(ValueKey('tile-$cell')));
        await tester.pump();
      }
      await tester.pump(MemoryMatrix.feedbackFor);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(backend.matrixTrials, hasLength(8));
    expect(find.text('Done for today'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // No replay today: not from the session, the game's page, or its address.
    await tester.tap(find.text('Done for today'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryMatrixTutorial), findsNothing);

    appRouter.go(Routes.game('memory-matrix'));
    await tester.pumpAndSettle();
    expect(find.text('Played today'), findsOneWidget);
    await tester.tap(find.text('Played today'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryMatrixTutorial), findsNothing);

    appRouter.go(Routes.memoryMatrix);
    await tester.pumpAndSettle();
    expect(find.text('Played today'), findsOneWidget);
    expect(find.text('Start'), findsNothing);

    // With the server's testing switch on, it opens again from the game page.
    backend.replaysAllowed = true;
    await Progress.instance.refresh();
    appRouter.go(Routes.game('memory-matrix'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryMatrixTutorial), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
  testWidgets('the tutorial: watch, recall, a miss replays, then Start', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await backend.install(loggedIn: true);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: MemoryMatrixScreen()),
    );

    Future<void> tap(int cell) async {
      await tester.tap(find.byKey(ValueKey('tutorial-tile-$cell')));
      await tester.pump();
    }

    const pattern = [6, 12, 18];
    expect(find.text('Watch'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Your turn'), findsOneWidget);

    // A wrong tap shows the pattern again.
    await tap(pattern[0]);
    expect(find.text('1 of 3'), findsOneWidget);
    await tap(0);
    await tester.pumpAndSettle();
    expect(find.text('Not that one'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.text('Watch again'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    for (final cell in pattern) {
      await tap(cell);
    }
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('All correct'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget); // next round has a tile more

    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('One wrong tap'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // and a miss, one fewer

    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Ready?'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.byType(MemoryMatrixTutorial), findsNothing);
    expect(find.text('ROUND 1 OF 8'), findsOneWidget);
    await tester.pump(MemoryMatrix.showFor);
  });
}
