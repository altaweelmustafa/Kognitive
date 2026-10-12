import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kognitiv/data/progress.dart';
import 'package:kognitiv/games/chess/chess_api.dart';
import 'package:kognitiv/games/chess/chess_models.dart';
import 'package:kognitiv/games/chess/chess_puzzle_screen.dart';
import 'package:kognitiv/models/progress_models.dart';
import 'package:kognitiv/theme/app_theme.dart';

Map<String, dynamic> state(
  String fen,
  String lastMove,
  int step, {
  List<String> legal = const [],
  bool solved = false,
}) => {
  'fen': fen,
  'last_move': lastMove,
  'legal_moves': legal,
  'check': false,
  'step': step,
  'total_steps': 2,
  'solved': solved,
};

// Lichess puzzle lmTZh: Nxc6 bxc6, Bxc5.
const start =
    'r1bqk2r/pp3ppp/2n2n2/2bp4/3N4/2P1B3/PP2BPPP/RN1QK2R w KQkq - 3 9';
const afterNxc6 =
    'r1bqk2r/pp3ppp/2N2n2/2bp4/8/2P1B3/PP2BPPP/RN1QK2R b KQkq - 0 9';
const afterBxc6 =
    'r1bqk2r/p4ppp/2p2n2/2bp4/8/2P1B3/PP2BPPP/RN1QK2R w KQkq - 0 10';
const afterBxc5 =
    'r1bqk2r/p4ppp/2p2n2/2Bp4/8/2P5/PP2BPPP/RN1QK2R b KQkq - 0 10';

void main() {
  test('FEN placement parses to squares', () {
    final s = ChessState.fromJson(state(start, 'g8f6', 0));
    expect(s.pieces['d4'], 'wn');
    expect(s.pieces['c5'], 'bb');
    expect(s.pieces['e8'], 'bk');
    expect(s.pieces.length, 28);
    expect(s.kingSquare, 'e1');
  });

  testWidgets('wrong move, hint, then solve', (tester) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final posted = <String>[];
    final client = MockClient((request) async {
      Map<String, dynamic> body;
      if (request.url.path.endsWith('/daily')) {
        body = {
          'id': 'lmTZh',
          'rating': 1331,
          'themes': ['short'],
          'player_color': 'white',
          'state': state(start, 'g8f6', 0, legal: ['d4c6', 'd4f5', 'e1g1']),
        };
      } else if (request.url.path.endsWith('/hint')) {
        body = {'from': 'd4', 'to': 'c6'};
      } else if (request.url.path.endsWith('/attempts')) {
        posted.add('attempt:${request.body}');
        body = {'ok': true};
      } else {
        final move = (jsonDecode(request.body) as Map)['move'] as String;
        posted.add(move);
        body = switch (move) {
          'd4c6' => {
            'correct': true,
            'after_move': state(afterNxc6, 'd4c6', 0),
            'state': state(afterBxc6, 'b7c6', 1, legal: ['e3c5', 'e3d4']),
          },
          'e3c5' => {
            'correct': true,
            'after_move': state(afterBxc5, 'e3c5', 1),
            'state': state(afterBxc5, 'e3c5', 2, solved: true),
          },
          _ => {
            'correct': false,
            'after_move': null,
            'state': state(start, 'g8f6', 0, legal: ['d4c6', 'd4f5', 'e1g1']),
          },
        };
      }
      return http.Response(jsonEncode(body), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChessPuzzleScreen(
          api: ChessApi(client: client, baseUrl: 'http://test'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('White to move. Find the best move.'), findsOneWidget);
    expect(find.text('1331 elo'), findsOneWidget);

    Future<void> tap(String square) async {
      await tester.tap(find.byKey(ValueKey('square-$square')));
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    await tap('a2'); // no legal moves from here: nothing is sent
    await tap('a3');
    expect(posted, isEmpty);

    // Dropping on a square the piece can't reach sends nothing.
    final d4 = tester.getCenter(find.byKey(const ValueKey('square-d4')));
    await tester.dragFrom(d4, const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(posted, isEmpty);
    await tap('d4'); // deselect

    await tap('d4');
    await tap('f5');
    expect(posted, ['d4f5']);
    expect(find.text("That's not the move. Try again."), findsOneWidget);

    await tester.tap(find.text('Hint'));
    await tester.pumpAndSettle();
    expect(find.text('Show move'), findsOneWidget);

    await tap('d4');
    await tap('c6');
    expect(find.text('Good. Keep going.'), findsOneWidget);

    // Drag the bishop from e3 to c5.
    final from = tester.getCenter(find.byKey(const ValueKey('square-e3')));
    final to = tester.getCenter(find.byKey(const ValueKey('square-c5')));
    await tester.dragFrom(from, to - from);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Solved'), findsOneWidget);
    expect(find.text('Next puzzle'), findsOneWidget);
    expect(
      posted.last,
      startsWith('attempt:{"solved":true,"mistakes":1,"hints":1'),
    );
  });

  testWidgets('once the daily is solved, Play opens a fresh puzzle', (
    tester,
  ) async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
        jsonEncode({
          'id': 'lmTZh',
          'rating': 1331,
          'themes': ['short'],
          'player_color': 'white',
          'state': state(start, 'g8f6', 0, legal: ['d4c6']),
        }),
        200,
      );
    });
    Progress.instance.today = TodayStatus.fromJson({
      'daily_solved': ['chess-puzzles'],
      'sudoku_in_progress': [],
    });
    addTearDown(Progress.instance.clear);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChessPuzzleScreen(
          api: ChessApi(client: client, baseUrl: 'http://test'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(paths, ['/chess/puzzles/next']);
    expect(find.text('PRACTICE PUZZLE'), findsOneWidget);
  });

  testWidgets('shows a retry when the server is down', (tester) async {
    final client = MockClient(
      (_) async => throw http.ClientException('refused'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChessPuzzleScreen(
          api: ChessApi(client: client, baseUrl: 'http://test'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Can't reach the Kognitiv server."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
