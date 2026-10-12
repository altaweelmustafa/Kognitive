import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/games/towers/towers_logic.dart';
import 'package:kognitiv/games/towers/towers_screen.dart';
import 'package:kognitiv/theme/app_theme.dart';

import 'fake_backend.dart';

void main() {
  test(
    'the frozen colour cannot move, and the frost passes on after a move',
    () {
      const state = TowerState([
        [0, 1],
        [2],
        [],
      ], 1);
      // Ball 1 is on top of peg 0 and frozen: only ball 2 may move.
      expect(Towers.legalMoves(state), [(from: 1, to: 0), (from: 1, to: 2)]);
      final next = Towers.apply(state, (from: 1, to: 2));
      expect(next.layout, '01||2');
      expect(next.frozen, 2);
    },
  );

  test('if nothing can move, the frost passes on by itself', () {
    // One stack with the frozen ball on top: no move is possible.
    const stuck = TowerState([
      [0, 1, 2],
      [],
      [],
    ], 2);
    expect(Towers.legalMoves(stuck), isEmpty);
    expect(Towers.settle(stuck).frozen, 0);
  });

  test('every generated puzzle is solvable in exactly its level', () {
    expect(Towers.layouts.length, 36);
    final random = Random(5);
    for (var level = Towers.minLevel; level <= Towers.maxLevel; level++) {
      for (var i = 0; i < 20; i++) {
        final puzzle = Towers.generate(random, level);
        expect(puzzle.optimal, level);
        var state = puzzle.start;
        final path = Towers.solve(state, puzzle.goal);
        expect(path.length, level);
        for (final move in path) {
          expect(Towers.legalMoves(state), contains(move));
          state = Towers.apply(state, move);
        }
        expect(state.layout, Towers.layoutOf(puzzle.goal));
      }
    }
    expect(Towers.nextLevel(3, perfect: true), 4);
    expect(Towers.nextLevel(Towers.minLevel, perfect: false), Towers.minLevel);
    expect(Towers.nextLevel(Towers.maxLevel, perfect: true), Towers.maxLevel);
  });

  testWidgets('five puzzles: harder after a perfect solve, easier otherwise', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await backend.install(loggedIn: true);

    // The same seed here and in the game gives the same puzzles.
    final mirror = Random(11);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: TowersScreen(random: Random(11)),
      ),
    );
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    Future<void> play(TowerMove move) async {
      await tester.tap(find.byKey(ValueKey('peg-${move.from}')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('peg-${move.to}')));
      await tester.pumpAndSettle();
    }

    var level = Towers.startLevel;
    final expected = <(int, int, bool)>[]; // (optimal, moves, solved)
    for (var n = 1; n <= Towers.puzzles; n++) {
      final puzzle = Towers.generate(mirror, level);
      var state = puzzle.start;
      expect(find.text('PUZZLE $n OF 5'), findsOneWidget);
      expect(find.text('Match the goal in $level moves'), findsOneWidget);

      if (n == 1) {
        // A frozen ball won't lift, and says why.
        final frozenPeg = state.pegs.indexWhere(
          (p) => p.isNotEmpty && p.last == state.frozen,
        );
        if (frozenPeg >= 0) {
          await tester.tap(find.byKey(ValueKey('peg-$frozenPeg')));
          await tester.pump();
          expect(find.textContaining('frozen'), findsOneWidget);
          expect(find.text('MOVES 0 / ${puzzle.moveLimit}'), findsOneWidget);
        }
      }

      if (n == 2) {
        // Waste every move: shuffle without ever reaching the goal.
        var moves = 0;
        while (moves < puzzle.moveLimit) {
          final move = Towers.legalMoves(state).firstWhere(
            (m) =>
                Towers.apply(state, m).layout != Towers.layoutOf(puzzle.goal),
          );
          await play(move);
          state = Towers.apply(state, move);
          moves++;
        }
        expect(find.text('Out of moves'), findsOneWidget);
        expected.add((level, moves, false));
        level = Towers.nextLevel(level, perfect: false);
      } else if (n == 4) {
        // Start with the worst first move that still leaves time to finish,
        // then take the shortest way from there.
        int left(TowerMove m) =>
            Towers.solve(Towers.apply(state, m), puzzle.goal).length;
        final first = Towers.legalMoves(state)
            .where((m) => left(m) + 1 <= puzzle.moveLimit)
            .reduce((a, b) => left(b) > left(a) ? b : a);
        await play(first);
        state = Towers.apply(state, first);
        final rest = Towers.solve(state, puzzle.goal);
        for (final move in rest) {
          await play(move);
        }
        final moves = rest.length + 1;
        expect(
          moves == level
              ? find.text('Perfect')
              : find.textContaining('The best was $level'),
          findsOneWidget,
        );
        expected.add((level, moves, true));
        level = Towers.nextLevel(level, perfect: moves == level);
      } else {
        for (final move in Towers.solve(state, puzzle.goal)) {
          await play(move);
        }
        expect(find.text('Perfect'), findsOneWidget);
        expected.add((level, level, true));
        level = Towers.nextLevel(level, perfect: true);
      }
      await tester.pump(TowersScreen.feedbackFor);
      await tester.pumpAndSettle();
    }

    expect([
      for (final t in backend.towersTrials!)
        (t['optimal'], t['moves'], t['solved']),
    ], expected);
    expect([for (final (optimal, _, _) in expected) optimal].take(3), [
      3,
      4,
      3,
    ]);
    expect(find.text('840'), findsOneWidget); // score from the server
    expect(find.text('Perfect puzzles'), findsOneWidget);
  });
}
