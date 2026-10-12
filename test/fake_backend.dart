import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kognitiv/data/api_client.dart';
import 'package:kognitiv/data/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the server in app-level tests: one account, one article.
class FakeBackend {
  static const code = '123456';
  static const token = 'test-token';

  /// `METHOD /path` of every request, in order.
  final requests = <String>[];
  Map<String, dynamic>? account; // set by sign-up
  bool verified = false;

  /// What the app posted after a Memory Matrix session.
  List<Map<String, dynamic>>? matrixTrials;
  bool matrixPlayed = false;

  /// The server's testing switch: session games can be replayed today.
  bool replaysAllowed = false;
  List<Map<String, dynamic>>? towersTrials;
  Map<String, dynamic>? mathResult;

  /// What's My Name?: every answer the app sent, with how it was judged.
  final namesAnswers = <Map<String, dynamic>>[];
  bool namesFinished = false;
  bool namesReset = false;

  /// Whether someone met on an earlier day is due for review today.
  bool namesMetBefore = true;

  double get _namesScore =>
      (1000 *
              namesAnswers.where((a) => a['correct'] as bool).length /
              namesAnswers.length)
          .roundToDouble();
  List<Map<String, dynamic>>? apothecaryTrials;

  /// Games whose daily puzzle counts as solved today, and whether a Sudoku
  /// was left unfinished.
  List<String> dailySolved = [];
  bool sudokuUnfinished = false;
  List<Map<String, dynamic>>? pointsRounds;

  /// Routes every [ApiClient] to this backend and starts logged out, or
  /// logged in as Dash when [loggedIn] is set.
  Future<void> install({bool loggedIn = false}) async {
    ApiClient.httpOverride = MockClient(_handle);
    SharedPreferences.setMockInitialValues({});
    await Session.instance.expire();
    if (loggedIn) {
      account = {
        'name': 'Dash',
        'gender': 'male',
        'email': 'dash@example.com',
        'password': 'correct-horse',
      };
      verified = true;
      await Session.instance.login('dash@example.com', 'correct-horse');
    }
  }

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Map<String, dynamic> get _user => {
    'id': 1,
    'name': account!['name'],
    'gender': account!['gender'],
    'email': account!['email'],
    'created_at': '2026-10-12 10:00:00',
  };

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    requests.add('${request.method} $path');
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;

    switch (path) {
      case '/auth/signup':
        account = body;
        verified = false;
        return _json({'ok': true, 'dev_code': code});
      case '/auth/resend':
        return _json({'ok': true, 'dev_code': code});
      case '/auth/verify':
        if (body['code'] != code) {
          return _json({'detail': "That code isn't right."}, 400);
        }
        verified = true;
        return _json({'token': token, 'user': _user});
      case '/auth/login':
        if (account == null ||
            !verified ||
            body['password'] != account!['password']) {
          return _json({'detail': 'Wrong email or password.'}, 401);
        }
        return _json({'token': token, 'user': _user});
      case '/auth/logout':
        return _json({'ok': true});
      case '/me/activity':
        return _json({
          'days': ['2026-10-11', '2026-10-12'],
          'streak': 2,
          'solved': {'chess': 1, 'sudoku': 1},
        });
      case '/library/articles':
        return _json({
          'articles': [
            _article..remove('body'),
            {
              'id': 'stress-less',
              'title': 'Stress Less',
              'category': 'to-avoid',
              'summary': 'Chronic stress wears down memory and attention.',
              'minutes': 5,
            },
          ],
        });
      case '/library/articles/feed-your-brain':
        return _json(_article);
      case '/me/today':
        return _json({
          'daily_solved': dailySolved,
          'sudoku_in_progress': [
            if (sudokuUnfinished)
              {
                'puzzle_id': 'daily-2026-10-12',
                'difficulty': 'medium',
                'daily': true,
                'elapsed_ms': 754000,
                'filled': 45,
                'updated_at': '',
              },
          ],
        });
      case '/sudoku/puzzles/daily-2026-10-12':
        const solution =
            '869457312243196758175382469638725194492813675517964283721539846354678921986241537';
        return _json({
          'id': 'daily-2026-10-12',
          'difficulty': 'medium',
          'puzzle': '0${solution.substring(1)}',
          'solution': solution,
          'save': null,
        });
      case '/session/today':
        return _json({
          'day': '2026-10-12',
          'completed': matrixPlayed,
          'played_today': [if (matrixPlayed) 'memory-matrix'],
          'replays_allowed': replaysAllowed,
          'games': [
            for (final (id, domain, always, why, playable) in [
              ('memory-matrix', 'memory', true, 'Always included', true),
              ('odd-one-out', 'attention', true, 'Always included', false),
              ('apothecary', 'planning', false, 'Declining', false),
              (
                'towers-of-stockholm',
                'flexibility',
                false,
                'No data yet',
                false,
              ),
            ])
              {
                'game_id': id,
                'domain': domain,
                'always': always,
                'why': why,
                'forecast': null,
                'playable': playable,
                'done': id == 'memory-matrix' && matrixPlayed,
              },
          ],
        });
      case '/me/performance':
        const none = {
          'n': 0,
          'level': null,
          'forecast': null,
          'change_per_day': null,
          'trend': 'none',
          'method': 'none',
          'history': [],
        };
        final history = [
          for (final (i, score) in [880.0, 905.0, 940.0, 990.0, 1012.5].indexed)
            {
              'day': '2026-10-${(8 + i).toString().padLeft(2, '0')}',
              'score': score,
            },
        ];
        return _json({
          'overall': 981,
          'puzzles': {
            'quick_math': {'games': 6, 'best': 31, 'accuracy': 88},
            'chess': {'elo': 1587, 'solved': 23},
            'sudoku': {'easy': 4, 'medium': 7, 'hard': 2},
          },
          'history': history,
          'domains': {
            'memory': {
              'n': 12,
              'level': 981,
              'forecast': 1040.2,
              'change_per_day': 21.5,
              'trend': 'improving',
              'method': 'arima',
              'history': history,
            },
            'attention': none,
            'reasoning': none,
            'planning': none,
            'flexibility': none,
          },
        });
      case '/games/towers-of-stockholm/results':
        towersTrials = (body['trials'] as List).cast<Map<String, dynamic>>();
        return _json({'score': 840}, 201);
      case '/games/apothecary/level':
        return _json({'colours': 3});
      case '/games/apothecary/results':
        apothecaryTrials = (body['trials'] as List)
            .cast<Map<String, dynamic>>();
        return _json({'score': 905}, 201);
      case '/games/whats-my-name/session':
        return _json({
          'day': '2026-10-12',
          'finished': namesFinished,
          'score': namesFinished ? _namesScore : null,
          'new': [
            {
              'id': '008',
              'name': 'Omar',
              'profession': 'architect',
              'detail': 'collects vinyl records',
            },
            {
              'id': '014',
              'name': 'Clara',
              'profession': 'nurse',
              'detail': 'runs marathons',
            },
          ],
          'reviews': namesMetBefore
              ? [
                  {'id': '016', 'question': 'profession'},
                ]
              : [],
          'answered': [
            for (final a in namesAnswers)
              {
                'id': a['id'],
                'question': a['question'],
                'correct': a['correct'],
              },
          ],
          'pool': {'people': 3, 'due_tomorrow': 2, 'still_to_meet': 27},
          'can_reset': replaysAllowed,
        });
      case '/games/whats-my-name/answer':
        const facts = {
          '008/name': 'Omar',
          '008/profession': 'architect',
          '008/detail': 'collects vinyl records',
          '014/name': 'Clara',
          '014/profession': 'nurse',
          '014/detail': 'runs marathons',
          '016/profession': 'teacher',
        };
        final expected = facts['${body['id']}/${body['question']}']!;
        final given = (body['answer'] as String).trim().toLowerCase();
        // "Omer" stands in for a typo the real server would forgive.
        final close = given == 'omer';
        final correct =
            close ||
            (given.isNotEmpty && expected.toLowerCase().contains(given));
        namesAnswers.add({...body, 'correct': correct});
        return _json({
          'correct': correct,
          'close': close,
          'expected': expected,
        });
      case '/games/whats-my-name/finish':
        namesFinished = true;
        return _json({
          'score': _namesScore,
          'correct': namesAnswers.where((a) => a['correct'] as bool).length,
          'asked': namesAnswers.length,
          'pool': {'people': 3, 'due_tomorrow': 2, 'still_to_meet': 27},
        });
      case '/games/whats-my-name/reset':
        namesAnswers.clear();
        namesFinished = false;
        namesReset = true;
        return _json({'ok': true});
      case '/games/quick-math/results':
        mathResult = body;
        return _json({'best': 31, 'new_best': false}, 201);
      case '/games/points-of-thought/level':
        return _json({'level': 3});
      case '/games/points-of-thought/results':
        pointsRounds = (body['rounds'] as List).cast<Map<String, dynamic>>();
        return _json({'score': 612.5}, 201);
      case '/games/memory-matrix/results':
        matrixPlayed = true;
        matrixTrials = (body['trials'] as List).cast<Map<String, dynamic>>();
        return _json({'score': 987.5}, 201);
      case '/sudoku/puzzles/saves':
        return _json({'saves': []});
    }
    return _json({'detail': 'Not Found'}, 404);
  }

  Map<String, dynamic> get _article => {
    'id': 'feed-your-brain',
    'title': 'Feed Your Brain',
    'category': 'foods',
    'summary': 'Leafy greens, berries and whole grains that support focus.',
    'minutes': 4,
    'body': 'Eat **well**.\n\n## What to eat\n\n- Leafy greens',
  };
}
