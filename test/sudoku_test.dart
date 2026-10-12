import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kognitiv/games/sudoku/sudoku_api.dart';
import 'package:kognitiv/games/sudoku/sudoku_board.dart';
import 'package:kognitiv/games/sudoku/sudoku_models.dart';
import 'package:kognitiv/games/sudoku/sudoku_screen.dart';
import 'package:kognitiv/theme/app_theme.dart';

const solution =
    '869457312243196758175382469638725194492813675517964283721539846354678921986241537';

/// The solution with cells 0, 1 and 80 blanked.
final puzzle = '00${solution.substring(2, 80)}0';

void main() {
  test('waves cover the right cells in the right order', () {
    expect(SudokuSweep.row(2).keys, [18, 19, 20, 21, 22, 23, 24, 25, 26]);
    expect(SudokuSweep.column(8).values.toList(), [
      for (var r = 0; r < 9; r++) r / 8,
    ]);
    final box = SudokuSweep.box(40); // the centre box
    expect(box.keys, [30, 31, 32, 39, 40, 41, 48, 49, 50]);
    expect((box[30], box[40], box[50]), (0, 0.5, 1));
    expect(SudokuSweep.diagonal([0, 80]), {0: 0.0, 80: 1.0});
  });

  test('peers share a row, column or box', () {
    expect(sudokuPeers(0, 8), isTrue); // row
    expect(sudokuPeers(0, 72), isTrue); // column
    expect(sudokuPeers(0, 20), isTrue); // box
    expect(sudokuPeers(0, 40), isFalse);
  });

  testWidgets('notes, wrong digit, undo, hint, solve, next', (tester) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final requests = <String>[];
    Map<String, dynamic>? saved; // what the server holds for the daily puzzle
    final client = MockClient((request) async {
      requests.add('${request.url.path}?${request.url.query} ${request.body}');
      if (request.url.path.endsWith('/attempts')) {
        saved = null;
        return http.Response('{"ok":true}', 201);
      }
      if (request.url.path.endsWith('/saves')) {
        return http.Response(
          jsonEncode({
            'saves': [
              if (saved != null)
                {
                  'puzzle_id': 'daily-2026-10-12',
                  'difficulty': 'medium',
                  'daily': true,
                  'elapsed_ms': saved!['elapsed_ms'],
                  'filled': 79,
                  'updated_at': '',
                },
            ],
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/save')) {
        saved = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"ok":true}', 200);
      }
      final daily = request.url.path.contains('/daily');
      return http.Response(
        jsonEncode({
          'id': daily ? 'daily-2026-10-12' : 'hard-0000beef',
          'difficulty': daily ? 'medium' : 'hard',
          'puzzle': puzzle,
          'solution': solution,
          'save': daily ? saved : null,
        }),
        200,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: SudokuScreen(
          api: SudokuApi(client: client, baseUrl: 'http://test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Starts on the picker; nothing is fetched until a choice is made.
    expect(find.text('Choose a puzzle'), findsOneWidget);
    expect(requests.where((r) => !r.contains('/saves')), isEmpty);
    await tester.tap(find.byKey(const ValueKey('choose-easy')));
    await tester.pumpAndSettle();
    expect(requests.last, startsWith('/sudoku/puzzles/next?difficulty=easy'));

    // Back returns to the picker instead of leaving the game.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('Choose a puzzle'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('choose-daily')));
    await tester.pumpAndSettle();
    expect(find.text('DAILY PUZZLE'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);

    final s = [for (final ch in solution.split('')) int.parse(ch)];
    // Only digits still missing from the board can be entered.
    final wrong = s[1];
    expect(wrong, isNot(s[0]));
    Future<void> cell(int i) async {
      await tester.tap(find.byKey(ValueKey('cell-$i')));
      await tester.pump();
    }

    Future<void> digit(int d) async {
      await tester.tap(find.byKey(ValueKey('digit-$d')));
      await tester.pump();
    }

    Finder inCell(int i, String text) => find.descendant(
      of: find.byKey(ValueKey('cell-$i')),
      matching: find.text(text),
    );

    // A given can't be overwritten.
    await cell(2);
    await digit(s[0]);
    expect(inCell(2, '${s[2]}'), findsOneWidget);

    // Notes: pencil in the right digit for cell 1, as a small mark.
    await cell(1);
    await tester.tap(find.text('Notes'));
    await tester.pump();
    await digit(s[0]);
    expect(inCell(1, '${s[0]}'), findsOneWidget);
    await tester.tap(find.text('Notes'));
    await tester.pump();

    // A wrong digit shows, then undo removes it.
    await cell(0);
    await digit(wrong);
    expect(inCell(0, '$wrong'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(inCell(0, '$wrong'), findsNothing);

    // The right digit clears that digit from the notes beside it.
    await digit(s[0]);
    expect(inCell(0, '${s[0]}'), findsOneWidget);
    expect(inCell(1, '${s[0]}'), findsNothing);

    // That digit finished column 1 and was the last of its kind: two waves,
    // one down the column and one across every cell holding that digit.
    List<SudokuSweep> sweeps() =>
        tester.widget<SudokuBoard>(find.byType(SudokuBoard)).sweeps;
    expect(sweeps(), hasLength(2));
    expect(sweeps()[0].cells.keys, [0, 9, 18, 27, 36, 45, 54, 63, 72]);
    expect(sweeps()[1].cells.keys.every((i) => s[i] == s[0]), isTrue);
    expect(sweeps()[1].cells, hasLength(9));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      sweeps()[0].strengthAt(36),
      greaterThan(0.5),
    ); // mid-column, mid-wave
    expect(sweeps()[0].strengthAt(1), 0); // not part of the column
    await tester.pumpAndSettle();
    expect(sweeps(), isEmpty);

    // Leaving saves the game: digits, notes and time. Coming back restores it.
    await cell(80);
    await tester.tap(find.text('Notes'));
    await tester.pump();
    await digit(s[1]);
    await tester.tap(find.text('Notes'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(saved!['cells'], '${s[0]}0${solution.substring(2, 80)}0');
    expect((saved!['notes'] as List).last, 1 << (s[1] - 1));
    expect(saved!['mistakes'], 1);
    expect(find.text('CONTINUE'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('choose-continue-daily-2026-10-12')),
    );
    await tester.pumpAndSettle();
    expect(requests.last, startsWith('/sudoku/puzzles/daily-2026-10-12?'));
    expect(inCell(0, '${s[0]}'), findsOneWidget);
    expect(inCell(80, '${s[1]}'), findsOneWidget);

    await cell(1);
    await tester.tap(find.text('Hint'));
    await tester.pump();
    expect(inCell(1, '${s[1]}'), findsOneWidget);

    await cell(80);
    await digit(s[80]);
    await tester.pumpAndSettle();
    expect(find.text('Solved'), findsOneWidget);
    expect(requests.last, contains('/daily-2026-10-12/attempts'));
    expect(requests.last, contains('"solved":true,"mistakes":1,"hints":1'));

    await tester.tap(find.text('Hard'));
    await tester.pump();
    await tester.tap(find.text('Next puzzle'));
    await tester.pumpAndSettle();
    expect(requests.last, startsWith('/sudoku/puzzles/next?difficulty=hard'));
    expect(find.text('PRACTICE PUZZLE'), findsOneWidget);
  });
}
