import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/data/games.dart';
import 'package:kognitiv/games/quiver/quiver_board.dart';
import 'package:kognitiv/games/quiver/quiver_logic.dart';
import 'package:kognitiv/games/quiver/quiver_screen.dart';
import 'package:kognitiv/games/quiver/quiver_tutorial.dart';
import 'package:kognitiv/theme/app_theme.dart';

import 'fake_backend.dart';

LogicalKeyboardKey _key(Dir d) => switch (d) {
  Dir.up => LogicalKeyboardKey.arrowUp,
  Dir.right => LogicalKeyboardKey.arrowRight,
  Dir.down => LogicalKeyboardKey.arrowDown,
  Dir.left => LogicalKeyboardKey.arrowLeft,
};

void main() {
  test('Quiver and Between the Lines are session games, not More Games', () {
    for (final id in ['quiver', 'between-the-lines']) {
      expect(gameById(id).inSessions, isTrue);
      expect(moreGames.map((g) => g.id), isNot(contains(id)));
    }
  });

  test('green answers where it points, red where it moves', () {
    const green = QuiverTrial(
      red: false,
      points: Dir.up,
      moves: Dir.left,
      count: 1,
    );
    const red = QuiverTrial(
      red: true,
      points: Dir.up,
      moves: Dir.left,
      count: 1,
    );
    expect(green.answer, Dir.up);
    expect(red.answer, Dir.left);
  });

  test('trials get busier, and never repeat the last screen', () {
    final random = Random(4);
    QuiverTrial? last;
    for (final correct in [0, 3, 4, 9, 10, 19, 20, 60]) {
      for (var i = 0; i < 300; i++) {
        final t = Quiver.trial(random, correct, last);
        final (low, high) = switch (correct) {
          < 4 => (1, 2),
          < 10 => (2, 4),
          < 20 => (3, 5),
          _ => (3, 6),
        };
        expect(t.count, inInclusiveRange(low, high));
        if (last != null) {
          expect(
            t.red == last.red &&
                t.points == last.points &&
                t.moves == last.moves,
            isFalse,
          );
        }
        last = t;
      }
    }
  });

  test('the multiplier climbs every four in a row, up to five', () {
    expect(Quiver.multiplier(0), 1);
    expect(Quiver.multiplier(3), 1);
    expect(Quiver.multiplier(4), 2);
    expect(Quiver.multiplier(15), 4);
    expect(Quiver.multiplier(16), 5);
    expect(Quiver.multiplier(100), 5);
    expect(Quiver.points(8), 75);
  });

  test('a swipe goes the way of its larger component', () {
    expect(Dir.of(const Offset(30, -10)), Dir.right);
    expect(Dir.of(const Offset(-30, 10)), Dir.left);
    expect(Dir.of(const Offset(5, 40)), Dir.down);
    expect(Dir.of(const Offset(-5, -40)), Dir.up);
  });

  testWidgets('swipes and keys score; a wrong answer resets the streak', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await backend.install(loggedIn: true);

    // The same seed here and in the game gives the same trials.
    final mirror = Random(11);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: QuiverScreen(random: Random(11)),
      ),
    );
    // Skipping the tutorial starts the game.
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(QuiverBoard), findsOneWidget);

    int score() => int.parse(
      tester.widget<Text>(find.byKey(const ValueKey('score'))).data!,
    );

    var trial = Quiver.trial(mirror, 0);
    var correct = 0, streak = 0, expected = 0;
    Future<void> answer(Dir dir, {bool drag = false}) async {
      if (drag) {
        await tester.drag(find.byType(QuiverBoard), dir.unit * 60);
      } else {
        await tester.sendKeyEvent(_key(dir));
      }
      final right = dir == trial.answer;
      if (right) {
        expected += Quiver.points(streak);
        streak++;
        correct++;
      } else {
        streak = 0;
      }
      trial = Quiver.trial(mirror, correct, trial);
      await tester.pump(const Duration(milliseconds: 500));
      expect(score(), expected);
    }

    for (var i = 0; i < 5; i++) {
      await answer(trial.answer);
    }
    expect(find.text('×2'), findsOneWidget);
    // Wrong on purpose: no points, multiplier back to ×1.
    await answer(Dir.values.firstWhere((d) => d != trial.answer));
    expect(find.text('×1'), findsOneWidget);
    // A drag works as well as a key.
    await answer(trial.answer, drag: true);

    // The clock runs out.
    await tester.pump(const Duration(seconds: 46));
    await tester.pumpAndSettle();
    expect(backend.quiverResult, {
      'score': expected,
      'correct': 6,
      'answered': 7,
    });
    expect(find.text('SESSION SCORE'), findsOneWidget);
    expect(find.text('813'), findsOneWidget); // from the server
    expect(find.text('$expected'), findsOneWidget); // the game's points
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('the tutorial: green, red, a mixed run, then Start', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await backend.install(loggedIn: true);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: QuiverScreen()),
    );
    await tester.pump();
    expect(find.byType(QuiverTutorial), findsOneWidget);
    expect(find.text('Green: follow the point'), findsOneWidget);

    Future<void> swipe(Dir d) async {
      await tester.sendKeyEvent(_key(d));
      await tester.pump(const Duration(milliseconds: 300));
    }

    // It drifts right but points up: right is wrong.
    await swipe(Dir.right);
    expect(find.text('Not quite'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await swipe(Dir.up);
    expect(find.text('Right'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Red: follow the path'), findsOneWidget);
    await swipe(Dir.left);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Check the colour first'), findsOneWidget);
    for (final d in [Dir.left, Dir.up, Dir.left, Dir.right]) {
      await swipe(d);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Ready?'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('seconds-left')), findsOneWidget);
    // Leave the screen so the board's ticker stops.
    await tester.pumpWidget(const SizedBox());
  });
}
