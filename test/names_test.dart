import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/games/names/names_logic.dart';
import 'package:kognitiv/games/names/names_screen.dart';
import 'package:kognitiv/games/names/names_tutorial.dart';
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
      MaterialApp(theme: AppTheme.dark, home: const NamesScreen()),
    );
    await tester.pumpAndSettle();
    return backend;
  }

  testWidgets(
    'one person at a time: meet them, answer about them, then the review',
    (tester) async {
      final backend = await open(tester);
      await tester.tap(find.text('Skip'));
      await tester.pump();

      // What today holds.
      expect(find.text('new today'), findsOneWidget);
      expect(find.text('review due'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.pump();

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

      var n = 0;
      Future<void> ask(String id, NamesQuestion question) async {
        n++;
        final key = '$id/${question.name}';
        expect(find.text('$n OF 7'), findsOneWidget);
        expect(find.text(n <= 6 ? 'NEW PEOPLE' : 'REVIEW'), findsOneWidget);
        expect(prompt(), question.prompt);
        expect(find.byKey(ValueKey('face-$id')), findsOneWidget);
        // Nothing about the person is on screen while they are being asked about.
        expect(find.text('Omar'), findsNothing);
        expect(find.text('nurse'), findsNothing);

        final answer = answers[key]!;
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
        // Not settling: that would run through the next study timer.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      // One person at a time: meet them, then their three questions.
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
        for (final question in NamesQuestion.values) {
          await ask(facts.$1, question);
        }
      }

      // Then the review of someone met before.
      await ask('016', NamesQuestion.profession);
      await tester.pumpAndSettle();

      expect(backend.namesAnswers.length, 7);
      expect(backend.namesAnswers.last['id'], '016'); // the review came last
      expect(backend.namesFinished, isTrue);
      expect(find.text('714'), findsOneWidget); // 5 of 7 right
      expect(find.text('5 of 7'), findsOneWidget);
      expect(find.text('Due tomorrow'), findsOneWidget);
      expect(find.text('Start over (testing)'), findsNothing);
    },
  );

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
    expect(find.byType(NamesTutorial), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('new today'), findsOneWidget);
  });

  testWidgets(
    'the tutorial: meet Tyrell, three questions at your own pace, Got it',
    (tester) async {
      tester.view.physicalSize = const Size(428, 926);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await FakeBackend().install(loggedIn: true);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark, home: const NamesScreen()),
      );
      await tester.pump(); // the session request
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(NamesTutorial), findsOneWidget);
      expect(find.text('Meet Tyrell'), findsOneWidget);
      expect(find.text('CTO of E Corp'), findsOneWidget);
      expect(find.text('Likes hacking'), findsOneWidget);

      // No timers: nothing moves on until the player does.
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Meet Tyrell'), findsOneWidget);
      await tester.tap(find.text('Ask me'));
      await tester.pumpAndSettle();

      Future<void> answer(String text) async {
        await tester.enterText(
          find.byKey(const ValueKey('tutorial-answer')),
          text,
        );
        await tester.tap(find.text('Answer'));
        await tester.pumpAndSettle();
      }

      Future<void> next() async {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      // The name, one letter off: still counts.
      expect(find.text("What is this person's name?"), findsOneWidget);
      expect(find.text('Tyrell'), findsNothing);
      await answer('Tyrel');
      expect(find.text('Close enough'), findsOneWidget);
      expect(find.text('Correct. It is spelt "Tyrell".'), findsOneWidget);
      await next();

      // What he does: the key words are enough.
      expect(find.text('What do they do?'), findsOneWidget);
      await answer('cto');
      expect(find.text('Correct'), findsNWidgets(2)); // title and verdict
      await next();

      // One thing about him, got wrong.
      expect(find.text('Tell me one thing about them.'), findsOneWidget);
      await answer('plays golf');
      expect(find.text('It was: Likes hacking'), findsOneWidget);
      await next();

      expect(find.text('Reviews spread out'), findsOneWidget);
      await next();
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      // The overview of today, ready to start.
      expect(find.byType(NamesTutorial), findsNothing);
      expect(find.text('new today'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
    },
  );
}
