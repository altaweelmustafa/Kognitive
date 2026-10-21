import '../data/games.dart';
import '../games/sudoku/sudoku_models.dart';
import 'cognitive_domain.dart';
import 'game.dart';

enum Trend { improving, plateau, declining, none }

/// What Home shows about the games outside the session.
class TodayStatus {
  TodayStatus.fromJson(Map<String, dynamic> j)
    : dailySolved = (j['daily_solved'] as List).cast<String>().toSet(),
      sudokuInProgress = [
        for (final s in j['sudoku_in_progress'] as List)
          SudokuSaveSummary.fromJson(s as Map<String, dynamic>),
      ];

  /// Ids of the games whose daily puzzle is solved today.
  final Set<String> dailySolved;

  /// Sudoku games left unfinished, most recent first.
  final List<SudokuSaveSummary> sudokuInProgress;
}

/// One game in today's session, as chosen by the backend.
class PlannedGame {
  PlannedGame.fromJson(Map<String, dynamic> j)
    : game = gameById(j['game_id'] as String),
      always = j['always'] as bool,
      why = j['why'] as String,
      playable = j['playable'] as bool,
      done = j['done'] as bool;

  final Game game;

  /// Memory and Attention are in every session; the rest are picked.
  final bool always;

  /// Why it is in the session: "Always included", "Declining", ...
  final String why;
  final bool playable;
  final bool done;
}

class SessionPlan {
  SessionPlan.fromJson(Map<String, dynamic> j)
    : games = [
        for (final g in j['games'] as List)
          PlannedGame.fromJson(g as Map<String, dynamic>),
      ],
      playedToday = (j['played_today'] as List).cast<String>().toSet(),
      replaysAllowed = j['replays_allowed'] as bool? ?? false,
      completed = j['completed'] as bool;

  final List<PlannedGame> games;

  /// Ids of session games already played today. Each counts once a day.
  final Set<String> playedToday;

  /// Testing switch on the server: session games can be played again today.
  final bool replaysAllowed;

  /// Whether [gameId] is closed until tomorrow.
  bool lockedToday(String gameId) =>
      !replaysAllowed && playedToday.contains(gameId);
  final bool completed;

  /// The next game the player can actually play, if any is left.
  PlannedGame? get next =>
      games.where((g) => g.playable && !g.done).firstOrNull;
}

class ScorePoint {
  ScorePoint.fromJson(Map<String, dynamic> j)
    : day = DateTime.parse(j['day'] as String),
      score = (j['score'] as num).toDouble();

  final DateTime day;
  final double score;
}

/// A domain's level, forecast and trend, worked out on the backend.
class DomainPerformance {
  DomainPerformance.fromJson(Map<String, dynamic> j)
    : days = j['n'] as int,
      level = (j['level'] as num?)?.toDouble(),
      forecast = (j['forecast'] as num?)?.toDouble(),
      trend = Trend.values.byName(j['trend'] as String),
      method = j['method'] as String,
      history = [
        for (final p in j['history'] as List)
          ScorePoint.fromJson(p as Map<String, dynamic>),
      ];

  final int days; // days played
  final double? level; // null until the domain has been played
  final double? forecast; // expected score next session
  final Trend trend;
  final String method; // arima | linear | average | none
  final List<ScorePoint> history;
}

class Performance {
  Performance.fromJson(Map<String, dynamic> j)
    : overall = (j['overall'] as num?)?.toDouble(),
      history = [
        for (final p in j['history'] as List)
          ScorePoint.fromJson(p as Map<String, dynamic>),
      ],
      mathBest =
          (j['puzzles'] as Map<String, dynamic>)['quick_math']['best'] as int?,
      mathGames =
          (j['puzzles'] as Map<String, dynamic>)['quick_math']['games'] as int,
      mathAccuracy =
          (j['puzzles'] as Map<String, dynamic>)['quick_math']['accuracy']
              as int?,
      chessElo = (j['puzzles'] as Map<String, dynamic>)['chess']['elo'] as int?,
      chessSolved =
          (j['puzzles'] as Map<String, dynamic>)['chess']['solved'] as int,
      sudokuSolved = {
        for (final d in SudokuDifficulty.values)
          d: (j['puzzles'] as Map<String, dynamic>)['sudoku'][d.name] as int,
      },
      domains = {
        for (final d in CognitiveDomain.values)
          d: DomainPerformance.fromJson(
            (j['domains'] as Map<String, dynamic>)[d.name]
                as Map<String, dynamic>,
          ),
      };

  final double? overall;
  final List<ScorePoint> history; // overall, last days played
  final Map<CognitiveDomain, DomainPerformance> domains;

  // Chess and Sudoku sit outside the KPI. Practice puzzles only: the daily
  // puzzles aren't counted in any of these.

  /// Estimated from the ratings of the puzzles solved. Null until one is.
  final int? chessElo;
  final int chessSolved;
  final Map<SudokuDifficulty, int> sudokuSolved;

  /// Quick Math: most correct answers in one run, runs played, and the share
  /// of all answers that were right, in percent.
  final int? mathBest;
  final int mathGames;
  final int? mathAccuracy;
}

/// One session game played on a day, and its score.
typedef DayGame = ({String gameId, CognitiveDomain domain, double score});

/// Everything the player did on one day, for a tap on the calendar.
class DaySummary {
  DaySummary.fromJson(Map<String, dynamic> j)
    : day = DateTime.parse(j['day'] as String),
      kpi = (j['kpi'] as num?)?.toDouble(),
      games = [
        for (final g in j['games'] as List)
          (
            gameId: g['game_id'] as String,
            domain: CognitiveDomain.values.byName(g['domain'] as String),
            score: (g['score'] as num).toDouble(),
          ),
      ],
      mathRuns = j['quick_math']['runs'] as int,
      mathBest = j['quick_math']['best'] as int?,
      chessSolved = j['chess_solved'] as int,
      sudokuSolved = {
        for (final d in SudokuDifficulty.values)
          d: (j['sudoku_solved'] as Map<String, dynamic>)[d.name] as int,
      };

  final DateTime day;

  /// That day's KPI, from the session games. Null if none was played.
  final double? kpi;
  final List<DayGame> games;
  final int mathRuns;
  final int? mathBest;
  final int chessSolved;
  final Map<SudokuDifficulty, int> sudokuSolved;

  bool get isEmpty =>
      games.isEmpty &&
      mathRuns == 0 &&
      chessSolved == 0 &&
      sudokuSolved.values.every((n) => n == 0);
}
