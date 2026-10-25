import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/games/between_lines/lines_category.dart';
import 'package:kognitiv/games/between_lines/lines_fallback.dart';
import 'package:kognitiv/games/between_lines/lines_logic.dart';
import 'package:kognitiv/games/between_lines/lines_screen.dart';
import 'package:kognitiv/games/between_lines/lines_tutorial.dart';
import 'package:kognitiv/theme/app_theme.dart';

import 'fake_backend.dart';

void main() {
  test('a right answer earns 100 plus a bonus that fades with time', () {
    expect(Lines.points(right: false, took: Duration.zero), 0);
    expect(Lines.points(right: true, took: const Duration(seconds: 3)), 150);
    expect(Lines.points(right: true, took: const Duration(seconds: 15)), 125);
    expect(Lines.points(right: true, took: const Duration(minutes: 2)), 100);
  });

  test('Wikipedia intros lose their parentheses and citation marks', () {
    expect(
      Lines.cleanWiki(
        'Transport Layer Security (TLS) is a protocol [1] (see '
        '(below)) used widely .\nIt is common.',
      ),
      'Transport Layer Security is a protocol used widely. It is common.',
    );
  });

  test('sentences split at full stops but not after Mr.', () {
    expect(
      Lines.sentences('“Dinner, Mr. Stubb,” he said. Then he left! Why?'),
      ['“Dinner, Mr. Stubb,” he said.', 'Then he left!', 'Why?'],
    );
  });

  test('book slices keep only whole prose paragraphs', () {
    const prose =
        'She walked to the window and looked out at the rain, which had not '
        'stopped since morning. The garden was a sea of mud, and the roses '
        'hung their heads as if ashamed of themselves.';
    final slice = [
      'tail of a cut paragraph',
      'CHAPTER XII.',
      prose.replaceAll('. ', '.\r\n'),
      'head of a cut paragraph',
    ].join('\r\n\r\n');
    expect(Lines.bookParagraphs(slice), [prose]);
  });

  test('questions put the answer among four choices that fit its shape', () {
    final random = Random(3);
    for (final category in LinesCategory.values) {
      final passages = fallbackPassages(category);
      final pool = Lines.wordPool(passages.map((p) => p.text));
      for (final p in passages) {
        for (var i = 0; i < 20; i++) {
          final q = Lines.question(p, pool, random)!;
          expect(q.choices, hasLength(4));
          expect(q.choices.toSet(), hasLength(4));
          expect(q.choices, contains(q.answer));
          expect(q.before + q.answer + q.after, Lines.trim(p.text));
          final text = (q.before + q.after).toLowerCase();
          for (final wrong in q.choices.where((c) => c != q.answer)) {
            expect(Lines.shapeOf(wrong), Lines.shapeOf(q.answer));
            expect(RegExp('\\b$wrong\\b').hasMatch(text), isFalse);
          }
        }
      }
    }
  });

  testWidgets('pick a subject, answer, see results', (tester) async {
    tester.view.physicalSize = const Size(428, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await backend.install(loggedIn: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LinesScreen(random: Random(2)),
      ),
    );
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a subject'), findsOneWidget);
    for (final c in LinesCategory.values) {
      expect(find.text(c.label), findsOneWidget);
    }

    // The fake server doesn't answer for Wikipedia, so the round falls back
    // to the passages built into the app.
    await tester.tap(find.byKey(const ValueKey('category-medicine')));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't fetch new passages"), findsOneWidget);
    final total = fallbackPassages(LinesCategory.medicine).length;
    expect(find.text('1 / $total'), findsOneWidget);

    for (var i = 0; i < total; i++) {
      final choice = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('choice-'),
      );
      expect(choice, findsNWidgets(4));
      await tester.ensureVisible(choice.first);
      await tester.tap(choice.first);
      await tester.pumpAndSettle();
      expect(find.textContaining('· '), findsNothing); // a Kognitiv passage
      expect(find.text('A Kognitiv practice passage'), findsOneWidget);
      final next = find.text(i + 1 == total ? 'See results' : 'Next');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
    }

    expect(backend.linesResult?['category'], 'medicine');
    expect(backend.linesResult?['answered'], total);
    expect(find.text('SESSION SCORE'), findsOneWidget);
    expect(find.text('1080'), findsOneWidget); // from the server
    expect(find.text('Medicine'), findsOneWidget); // the subject played
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('the tutorial: a wrong pick, the right one, then Start', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(428, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await backend.install(loggedIn: true);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: LinesScreen()),
    );
    await tester.pump();
    expect(find.byType(LinesTutorial), findsOneWidget);
    expect(find.text('Find the missing word'), findsOneWidget);

    await tester.tap(find.text('compliments'));
    await tester.pumpAndSettle();
    expect(find.text('Not that one'), findsOneWidget);

    await tester.tap(find.text('acknowledgements'));
    await tester.pumpAndSettle();
    expect(find.text('Right'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('Real reading'), findsOneWidget);
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start'));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a subject'), findsOneWidget);
  });
}
