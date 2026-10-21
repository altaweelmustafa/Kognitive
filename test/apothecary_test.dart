import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/games/apothecary/apothecary_game.dart';
import 'package:kognitiv/games/apothecary/apothecary_logic.dart';
import 'package:kognitiv/games/apothecary/apothecary_screen.dart';
import 'package:kognitiv/games/apothecary/apothecary_tutorial.dart';
import 'package:kognitiv/theme/app_theme.dart';

import 'fake_backend.dart';

void main() {
  testWidgets('three puzzles played on the Flame board, then saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await backend.install(loggedIn: true);

    // The same seed here and in the game gives the same puzzles.
    final mirror = Random(8);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ApothecaryScreen(random: Random(8)),
      ),
    );
    await tester.tap(find.text('Skip'));
    await tester.pump(); // the level request
    await tester.pump(const Duration(milliseconds: 100));

    ApothecaryGame game() => tester
        .widget<GameWidget<ApothecaryGame>>(
          find.byType(GameWidget<ApothecaryGame>),
        )
        .game!;

    const frame = Duration(milliseconds: 50);
    Future<void> settle() async {
      await tester.pump(frame);
      var frames = 0;
      while (game().busy) {
        await tester.pump(frame);
        expect(++frames, lessThan(200), reason: 'a pour never finished');
      }
    }

    Future<void> tapBottle(int i) async {
      final origin = tester.getTopLeft(find.byType(GameWidget<ApothecaryGame>));
      final home = game().bottles[i].home;
      await tester.tapAt(origin + Offset(home.x, home.y));
      await tester.pump(frame);
    }

    Future<void> pour(Pour p) async {
      await tapBottle(p.from);
      expect(game().selected, p.from);
      await tapBottle(p.to);
      await settle();
    }

    var colours = 3; // from the server
    final expected = <(int, int, bool)>[]; // (colours, pours, solved)
    for (var n = 1; n <= Apothecary.puzzles; n++) {
      final puzzle = Apothecary.generate(mirror, colours);
      expect(find.text('PUZZLE $n OF 3'), findsOneWidget);
      expect(find.text('POURS 0 · PAR ${puzzle.par}'), findsOneWidget);
      expect(game().bottles.length, colours + 2);
      expect(game().state, puzzle.bottles);

      if (n == 1) {
        // An empty bottle can't be picked up; a pour that doesn't fit is refused.
        await tapBottle(colours);
        expect(game().selected, isNull);
        final refused = [
          for (var a = 0; a < colours; a++)
            for (var b = 0; b < colours; b++)
              if (a != b && Apothecary.pourable(puzzle.bottles, a, b) == 0)
                (from: a, to: b),
        ].first;
        await tapBottle(refused.from);
        await tapBottle(refused.to);
        await settle();
        expect(game().pours, 0);
        expect(game().state, puzzle.bottles);
        await tapBottle(game().selected!); // put it down
      }

      if (n == 2) {
        // One pour, taken back with Undo, then give up.
        final first = Apothecary.usefulPours(puzzle.bottles).first;
        await pour(first);
        expect(game().state, isNot(puzzle.bottles));
        await tester.tap(find.text('Undo'));
        await tester.pump(frame);
        expect(game().state, puzzle.bottles);
        expect(
          find.text('POURS 1 · PAR ${puzzle.par}'),
          findsOneWidget,
        ); // the count stays
        await tester.tap(find.text('Skip'));
        await tester.pump();
        expect(find.text('Skipped'), findsOneWidget);
        expected.add((colours, 1, false));
        colours = max(Apothecary.minColours, colours - 1);
      } else {
        final solution = Apothecary.solve(puzzle.bottles, maxDepth: 200)!;
        for (final p in solution) {
          await pour(p);
        }
        expect(game().solved, isTrue);
        expect(find.textContaining('Sorted'), findsOneWidget);
        expected.add((colours, solution.length, true));
        colours = Apothecary.nextColours(
          ApothecaryTrial(
            colours: colours,
            par: puzzle.par,
            moves: solution.length,
            solved: true,
            duration: Duration.zero,
          ),
        );
      }
      await tester.pump(ApothecaryScreen.feedbackFor);
      await tester.pump(frame);
    }
    await tester.pumpAndSettle();

    expect([
      for (final t in backend.apothecaryTrials!)
        (t['colours'], t['moves'], t['solved']),
    ], expected);
    expect(find.text('905'), findsOneWidget); // score from the server
    expect(find.text('2 of 3'), findsOneWidget);
  });

  testWidgets('the tutorial: one pour, a puzzle with an empty bottle, Start', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await backend.install(loggedIn: true);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: ApothecaryScreen()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ApothecaryTutorial), findsOneWidget);

    ApothecaryGame game() => tester
        .widget<GameWidget<ApothecaryGame>>(
          find.byType(GameWidget<ApothecaryGame>),
        )
        .game!;

    const frame = Duration(milliseconds: 50);
    Future<void> tapBottle(int i) async {
      final origin = tester.getTopLeft(find.byType(GameWidget<ApothecaryGame>));
      final home = game().bottles[i].home;
      await tester.tapAt(origin + Offset(home.x, home.y));
      await tester.pump(frame);
    }

    Future<void> pour(int from, int to) async {
      await tapBottle(from);
      await tapBottle(to);
      for (var frames = 0; game().busy; frames++) {
        await tester.pump(frame);
        expect(frames, lessThan(200), reason: 'a pour never finished');
      }
      await tester.pump(frame);
    }

    expect(find.text('Pick up a bottle'), findsOneWidget);
    await tapBottle(0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Now pour'), findsOneWidget);
    await tapBottle(2);
    for (var frames = 0; game().busy; frames++) {
      await tester.pump(frame);
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sorted'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 300));

    // Swap two colours through the empty bottle.
    expect(find.text('Same colour or empty'), findsOneWidget);
    await pour(0, 2);
    await pour(1, 0);
    await pour(2, 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('3 pours. The par was 3.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Aim for par'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ready?'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump(); // the level request
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ApothecaryTutorial), findsNothing);
    expect(find.text('PUZZLE 1 OF 3'), findsOneWidget);
  });
}
