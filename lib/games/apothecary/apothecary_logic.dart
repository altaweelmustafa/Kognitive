import 'dart:math';

/// Pour from bottle [from] into bottle [to].
typedef Pour = ({int from, int to});

/// Rules of Apothecary (a liquid-sorting puzzle), kept apart from the game.
///
/// Every bottle holds up to [capacity] units of liquid, stacked bottom first.
/// A pour moves the whole run of one colour off the top of a bottle, as much
/// as fits, onto an empty bottle or onto the same colour. The puzzle is solved
/// when every bottle is empty or full of a single colour.
abstract final class Apothecary {
  static const capacity = 4;
  static const spareBottles = 2;

  static const puzzles = 3;
  static const minColours = 3;
  static const maxColours = 8; // ten bottles
  static const startColours = 4;

  /// Solving within this many times the reference solution counts as clean.
  static const cleanWithin = 1.25;

  /// How many units a pour from [from] to [to] would move. Zero if it can't
  /// be made.
  static int pourable(List<List<int>> bottles, int from, int to) {
    if (from == to || bottles[from].isEmpty) return 0;
    final source = bottles[from], target = bottles[to];
    final colour = source.last;
    if (target.isNotEmpty && target.last != colour) return 0;
    var run = 0;
    for (var i = source.length - 1; i >= 0 && source[i] == colour; i--) {
      run++;
    }
    return min(run, capacity - target.length);
  }

  /// Makes the pour in place and returns how many units moved.
  static int pour(List<List<int>> bottles, int from, int to) {
    final amount = pourable(bottles, from, to);
    for (var i = 0; i < amount; i++) {
      bottles[to].add(bottles[from].removeLast());
    }
    return amount;
  }

  static bool isComplete(List<int> bottle) =>
      bottle.length == capacity && bottle.every((c) => c == bottle.first);

  static bool isSolved(List<List<int>> bottles) =>
      bottles.every((b) => b.isEmpty || isComplete(b));

  /// Pours worth considering: nothing out of a finished bottle, and no moving
  /// a bottle of one colour into an empty one (it changes nothing).
  static List<Pour> usefulPours(List<List<int>> bottles) => [
    for (var from = 0; from < bottles.length; from++)
      if (bottles[from].isNotEmpty && !isComplete(bottles[from]))
        for (var to = 0; to < bottles.length; to++)
          if (pourable(bottles, from, to) > 0 &&
              !(bottles[to].isEmpty &&
                  bottles[from].every((c) => c == bottles[from].first)))
            (from: from, to: to),
  ];

  static List<List<int>> copy(List<List<int>> bottles) => [
    for (final b in bottles) [...b],
  ];

  /// The same arrangement whatever order the bottles stand in.
  static String _signature(List<List<int>> bottles) =>
      ([for (final b in bottles) b.join(',')]..sort()).join('|');

  /// A solution found by depth-first search, or null if none turns up within
  /// [nodeBudget] positions or [maxDepth] pours. Not necessarily the shortest.
  static List<Pour>? solve(
    List<List<int>> start, {
    int nodeBudget = 30000,
    int maxDepth = 120,
  }) {
    final bottles = copy(start);
    final seen = <String, int>{}; // signature → fewest pours it was reached in
    final path = <Pour>[];
    var nodes = 0;

    bool search(int depth) {
      if (isSolved(bottles)) return true;
      if (depth >= maxDepth || ++nodes > nodeBudget) return false;
      final signature = _signature(bottles);
      final known = seen[signature];
      if (known != null && known <= depth) return false;
      seen[signature] = depth;

      // Try pours onto liquid before pours into empty bottles: they tend to
      // make progress, where an empty bottle is a resource worth keeping.
      final pours = usefulPours(bottles)
        ..sort(
          (a, b) =>
              (bottles[a.to].isEmpty ? 1 : 0) - (bottles[b.to].isEmpty ? 1 : 0),
        );
      for (final p in pours) {
        final amount = pour(bottles, p.from, p.to);
        path.add(p);
        if (search(depth + 1)) return true;
        path.removeLast();
        for (var i = 0; i < amount; i++) {
          bottles[p.from].add(bottles[p.to].removeLast());
        }
      }
      return false;
    }

    return search(0) ? [...path] : null;
  }

  /// The reference number of pours for a puzzle: the shortest solution a few
  /// rounds of search can find.
  static int? par(List<List<int>> start) {
    var best = solve(start)?.length;
    if (best == null) return null;
    // Look for something shorter by capping the depth just below the best.
    for (var i = 0; i < 6; i++) {
      final shorter = solve(
        start,
        nodeBudget: 15000,
        maxDepth: best! - 1,
      )?.length;
      if (shorter == null) break;
      best = shorter;
    }
    return best;
  }

  /// A random solvable puzzle with [colours] colours.
  static ApothecaryPuzzle generate(Random random, int colours) {
    while (true) {
      final units = [
        for (var c = 0; c < colours; c++)
          for (var i = 0; i < capacity; i++) c,
      ]..shuffle(random);
      final bottles = [
        for (var b = 0; b < colours; b++)
          units.sublist(b * capacity, (b + 1) * capacity),
        for (var b = 0; b < spareBottles; b++) <int>[],
      ];
      // Nothing may come pre-sorted.
      if (bottles.any(isComplete)) continue;
      final reference = par(bottles);
      if (reference == null) continue;
      return ApothecaryPuzzle(
        bottles: bottles,
        colours: colours,
        par: reference,
      );
    }
  }

  /// Next puzzle's colour count: one more after a clean solve, one fewer
  /// after giving up, the same otherwise.
  static int nextColours(ApothecaryTrial trial) {
    final next = !trial.solved
        ? trial.colours - 1
        : (trial.moves <= trial.par * cleanWithin
              ? trial.colours + 1
              : trial.colours);
    return next.clamp(minColours, maxColours);
  }
}

class ApothecaryPuzzle {
  const ApothecaryPuzzle({
    required this.bottles,
    required this.colours,
    required this.par,
  });

  final List<List<int>> bottles;
  final int colours;

  /// Pours in the reference solution.
  final int par;
}

/// One finished puzzle.
class ApothecaryTrial {
  const ApothecaryTrial({
    required this.colours,
    required this.par,
    required this.moves,
    required this.solved,
    required this.duration,
  });

  final int colours;
  final int par;
  final int moves;
  final bool solved;
  final Duration duration;

  Map<String, dynamic> toJson() => {
    'colours': colours,
    'par': par,
    'moves': moves,
    'solved': solved,
    'duration_ms': duration.inMilliseconds,
  };
}
