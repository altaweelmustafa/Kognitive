import 'dart:collection';
import 'dart:math';

/// Take the top ball of peg [from] and put it on peg [to].
typedef TowerMove = ({int from, int to});

/// Where the balls are, and which colour is frozen.
class TowerState {
  const TowerState(this.pegs, this.frozen);

  /// One list per peg, bottom ball first. Balls are 0, 1, 2 (their colour).
  final List<List<int>> pegs;

  /// The colour that can't be moved right now.
  final int frozen;

  /// The arrangement alone, e.g. `01|2|`.
  String get layout => Towers.layoutOf(pegs);
}

class TowerPuzzle {
  const TowerPuzzle({
    required this.start,
    required this.goal,
    required this.optimal,
  });

  final TowerState start;
  final List<List<int>> goal;

  /// Fewest moves that reach the goal.
  final int optimal;

  /// The puzzle is lost when this many moves are used up.
  int get moveLimit => optimal + Towers.spareMoves;
}

/// Rules of Towers of Stockholm: the Tower of London, with frost.
///
/// Three pegs hold 3, 2 and 1 balls. One colour is frozen and can't be moved;
/// after every move the frost passes to the next colour, in a fixed order.
/// If nothing at all can move, the frost passes on by itself.
abstract final class Towers {
  static const capacities = [3, 2, 1];
  static const colours = 3;

  static const puzzles = 5;
  static const startLevel = 3; // optimal moves of the first puzzle
  static const minLevel = 2;
  static const spareMoves = 4;

  static String layoutOf(List<List<int>> pegs) =>
      pegs.map((p) => p.join()).join('|');

  static List<TowerMove> legalMoves(TowerState s) => [
    for (var from = 0; from < s.pegs.length; from++)
      if (s.pegs[from].isNotEmpty && s.pegs[from].last != s.frozen)
        for (var to = 0; to < s.pegs.length; to++)
          if (to != from && s.pegs[to].length < capacities[to])
            (from: from, to: to),
  ];

  /// Passes the frost on until something can move.
  static TowerState settle(TowerState s) {
    var state = s;
    while (legalMoves(state).isEmpty) {
      state = TowerState(state.pegs, (state.frozen + 1) % colours);
    }
    return state;
  }

  static TowerState apply(TowerState s, TowerMove move) {
    final pegs = [
      for (final peg in s.pegs) [...peg],
    ];
    pegs[move.to].add(pegs[move.from].removeLast());
    return settle(TowerState(pegs, (s.frozen + 1) % colours));
  }

  /// Breadth-first search from [start]: the shortest way to every layout.
  static Map<String, List<TowerMove>> _paths(TowerState start) {
    final paths = <String, List<TowerMove>>{start.layout: const []};
    final seen = {'${start.layout}/${start.frozen}'};
    final queue = Queue<(TowerState, List<TowerMove>)>()
      ..add((start, const []));
    while (queue.isNotEmpty) {
      final (state, path) = queue.removeFirst();
      for (final move in legalMoves(state)) {
        final next = apply(state, move);
        if (!seen.add('${next.layout}/${next.frozen}')) continue;
        final nextPath = [...path, move];
        paths.putIfAbsent(next.layout, () => nextPath);
        queue.add((next, nextPath));
      }
    }
    return paths;
  }

  /// A shortest sequence of moves from [start] to the [goal] layout.
  static List<TowerMove> solve(TowerState start, List<List<int>> goal) =>
      _paths(start)[layoutOf(goal)]!;

  /// Every way to place the three balls on the pegs.
  static final List<List<List<int>>> layouts = () {
    final found = <List<List<int>>>[];
    void place(List<List<int>> pegs, List<int> left) {
      if (left.isEmpty) {
        found.add([
          for (final peg in pegs) [...peg],
        ]);
        return;
      }
      for (final ball in left) {
        for (var p = 0; p < pegs.length; p++) {
          if (pegs[p].length == capacities[p]) continue;
          pegs[p].add(ball);
          place(pegs, [...left]..remove(ball));
          pegs[p].removeLast();
        }
      }
    }

    place([[], [], []], [0, 1, 2]);
    // The same layout is reached by placing balls in different orders.
    final unique = <String, List<List<int>>>{
      for (final l in found) layoutOf(l): l,
    };
    return unique.values.toList();
  }();

  /// The hardest puzzle there is: the most moves any optimal solution needs.
  static final int maxLevel = () {
    var hardest = 0;
    for (final layout in layouts) {
      for (var frozen = 0; frozen < colours; frozen++) {
        for (final path in _paths(settle(TowerState(layout, frozen))).values) {
          hardest = max(hardest, path.length);
        }
      }
    }
    return hardest;
  }();

  /// A random puzzle whose shortest solution takes exactly [level] moves.
  static TowerPuzzle generate(Random random, int level) {
    final wanted = level.clamp(minLevel, maxLevel);
    while (true) {
      final start = settle(
        TowerState(
          layouts[random.nextInt(layouts.length)],
          random.nextInt(colours),
        ),
      );
      final goals = [
        for (final entry in _paths(start).entries)
          if (entry.value.length == wanted) entry.key,
      ];
      if (goals.isEmpty) continue; // not every start has a goal that far away
      final goal = goals[random.nextInt(goals.length)];
      return TowerPuzzle(
        start: start,
        goal: layouts.firstWhere((l) => layoutOf(l) == goal),
        optimal: wanted,
      );
    }
  }

  /// A perfect solve makes the next puzzle one move longer; anything else,
  /// one move shorter.
  static int nextLevel(int level, {required bool perfect}) =>
      (perfect ? level + 1 : level - 1).clamp(minLevel, maxLevel);
}

/// One finished puzzle.
class TowerTrial {
  const TowerTrial({
    required this.optimal,
    required this.moves,
    required this.solved,
    required this.duration,
  });

  final int optimal;
  final int moves;
  final bool solved;
  final Duration duration;

  bool get perfect => solved && moves == optimal;

  Map<String, dynamic> toJson() => {
    'optimal': optimal,
    'moves': moves,
    'solved': solved,
    'duration_ms': duration.inMilliseconds,
  };
}
