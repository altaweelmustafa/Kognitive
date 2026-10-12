import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/games/math/quick_math_logic.dart';
import 'package:kognitiv/games/math/quick_math_screen.dart';
import 'package:kognitiv/theme/app_theme.dart';

import 'fake_backend.dart';

void main() {
  test('questions are well-formed and get harder', () {
    final random = Random(1);
    for (final correct in [0, 4, 5, 11, 12, 40]) {
      for (var i = 0; i < 300; i++) {
        final q = QuickMath.question(random, correct);
        final parts = q.text.split(' ');
        final a = int.parse(parts[0]), b = int.parse(parts[2]);
        final expected = switch (parts[1]) {
          '+' => a + b,
          '−' => a - b,
          '×' => a * b,
          _ => a ~/ b,
        };
        expect(q.answer, expected, reason: q.text);
        expect(q.answer, greaterThanOrEqualTo(0), reason: q.text);
        if (parts[1] == '÷') expect(a % b, 0, reason: q.text);
        // The warm-up has no multiplication or division.
        if (correct < 5) expect(parts[1], anyOf('+', '−'));
      }
    }
  });

  testWidgets('right and wrong answers both move on; the clock ends the run', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await backend.install(loggedIn: true);

    // The same seed here and in the game gives the same questions.
    final mirror = Random(21);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: QuickMathScreen(random: Random(21)),
      ),
    );
    await tester.tap(find.text('Start'));
    await tester.pump();

    String shown() =>
        tester.widget<Text>(find.byKey(const ValueKey('question'))).data!;
    Future<void> type(String digits) async {
      for (final d in digits.split('')) {
        await tester.tap(find.byKey(ValueKey('key-$d')));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    var correct = 0;
    for (var i = 0; i < 6; i++) {
      final q = QuickMath.question(mirror, correct);
      expect(shown(), q.text);
      final answer = '${q.answer}';
      if (i == 2) {
        // A wrong answer with the right number of digits: no retry, next sum.
        await type(answer.replaceRange(0, 1, answer[0] == '9' ? '8' : '9'));
      } else if (i == 4) {
        // Erase a slip before the last digit, then answer properly.
        await type(answer[0] == '9' ? '8' : '9');
        if (answer.length > 1) {
          await tester.tap(find.byKey(const ValueKey('key-erase')));
          await tester.pump();
          await type(answer);
          correct++;
        }
      } else {
        await type(answer);
        correct++;
      }
      expect(find.text('CORRECT $correct'), findsOneWidget);
    }

    // Time runs out.
    await tester.pump(const Duration(seconds: 30));
    expect(find.byKey(const ValueKey('seconds-left')), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(backend.mathResult, {'correct': correct, 'answered': 6});
    expect(find.text('CORRECT ANSWERS'), findsOneWidget);
    expect(find.text('31'), findsOneWidget); // best, from the server
    expect(find.text('Play again'), findsOneWidget);

    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(find.text('CORRECT 0'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(backend.mathResult, {'correct': 0, 'answered': 0});
  });
}
