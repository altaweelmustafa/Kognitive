import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/games/names/names_logic.dart';
import 'package:kognitiv/games/names/names_screen.dart';
import 'package:kognitiv/theme/app_theme.dart';

import 'fake_backend.dart';

void main() {
  test('thirty portraits', () {
    expect(faceIds.length, 30);
    expect(faceIds.toSet().length, 30);
  });

  Future<FakeBackend> open(WidgetTester tester, {bool replays = false}) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend()..replaysAllowed = replays;
    await backend.install(loggedIn: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: NamesScreen(random: Random(2)),
      ),
    );
    await tester.pumpAndSettle();
    return backend;
  }

  testWidgets('study two new people, type the answers, then the review', (
    tester,
  ) async {
    final backend = await open(tester);

    // What today holds.
    expect(find.text('new today'), findsOneWidget);
    expect(find.text('review due'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump();

    // Study: each new person with name, profession and detail, six seconds each.
    for (final (i, facts) in [
      ('008', 'Omar', 'architect', 'collects vinyl records'),
      ('014', 'Clara', 'nurse', 'runs marathons'),
    ].indexed) {
      expect(find.text('MEET ${i + 1} OF 2'), findsOneWidget);
      expect(find.byKey(ValueKey('face-${facts.$1}')), findsOneWidget);
      expect(find.text(facts.$2), findsOneWidget);
      expect(find.text(facts.$3), findsOneWidget);
      expect(find.text(facts.$4), findsOneWidget);
      await tester.pump(studyFor);
      await tester.pump();
    }

    const answers = {
      '008/name': 'Omer', // a typo: accepted, with the spelling shown
      '008/profession': 'architect',
      '008/detail': 'vinyl',
      '014/name': '', // tapped "Don't know"
      '014/profession': 'nurse',
      '014/detail': 'plays chess', // wrong
      '016/profession': 'teacher',
    };
    String prompt() =>
        tester.widget<Text>(find.byKey(const ValueKey('prompt'))).data!;
    String face() => faceIds.firstWhere(
      (id) => find.byKey(ValueKey('face-$id')).evaluate().isNotEmpty,
    );

    // Six questions about the new people, in a mixed-up order, then the review.
    for (var n = 1; n <= 7; n++) {
      expect(find.text('$n OF 7'), findsOneWidget);
      expect(find.text(n <= 6 ? 'NEW PEOPLE' : 'REVIEW'), findsOneWidget);
      final question = NamesQuestion.values.firstWhere(
        (q) => q.prompt == prompt(),
      );
      final key = '${face()}/${question.name}';
      final answer = answers[key]!;
      // Nothing about the person is on screen while they are being asked about.
      expect(find.text('Omar'), findsNothing);
      expect(find.text('nurse'), findsNothing);

      if (answer.isEmpty) {
        await tester.tap(find.text("Don't know"));
      } else {
        await tester.enterText(find.byKey(const ValueKey('answer')), answer);
        await tester.tap(find.text('Answer'));
      }
      await tester.pumpAndSettle();

      final verdict = tester
          .widget<Text>(find.byKey(const ValueKey('verdict')))
          .data!;
      expect(verdict, switch (key) {
        '008/name' => 'Correct. It is spelt "Omar".',
        '014/name' => 'It was: Clara',
        '014/detail' => 'It was: runs marathons',
        _ => 'Correct',
      });
      await tester.tap(find.text(n < 7 ? 'Next' : 'Finish'));
      await tester.pumpAndSettle();
    }

    expect(backend.namesAnswers.length, 7);
    expect(backend.namesAnswers.last['id'], '016'); // the review came last
    expect(backend.namesFinished, isTrue);
    expect(find.text('714'), findsOneWidget); // 5 of 7 right
    expect(find.text('5 of 7'), findsOneWidget);
    expect(find.text('Due tomorrow'), findsOneWidget);
    expect(find.text('Start over (testing)'), findsNothing);
  });

  testWidgets('a finished day shows its result; testing can start over', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..replaysAllowed = true
      ..namesFinished = true;
    backend.namesAnswers.addAll([
      {
        'id': '016',
        'question': 'profession',
        'answer': 'teacher',
        'correct': true,
      },
    ]);
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await backend.install(loggedIn: true);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const NamesScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('1000'), findsOneWidget);
    expect(find.text('1 of 1'), findsOneWidget);
    await tester.tap(find.text('Start over (testing)'));
    await tester.pumpAndSettle();
    expect(backend.requests, contains('POST /games/whats-my-name/reset'));
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('new today'), findsOneWidget);
  });
}
