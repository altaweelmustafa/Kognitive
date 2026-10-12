import 'dart:math';

/// Rules of Memory Matrix, kept apart from the screen.
abstract final class MemoryMatrix {
  static const side = 5;
  static const cells = side * side;
  static const rounds = 8;
  static const startTiles = 8;

  /// A perfect round adds a tile, a miss removes one, within these bounds.
  static const minTiles = 3;
  static const maxTiles = 20;

  /// How long the pattern stays lit.
  static const showFor = Duration(milliseconds: 1500);

  /// How long the outcome of a round stays on screen.
  static const feedbackFor = Duration(milliseconds: 1100);

  /// Which [tiles] cells light up.
  static Set<int> pattern(Random random, int tiles) =>
      (List.generate(cells, (i) => i)..shuffle(random)).take(tiles).toSet();

  static int nextTiles(int tiles, {required bool perfect}) =>
      (perfect ? tiles + 1 : tiles - 1).clamp(minTiles, maxTiles);
}

/// One finished round.
class MatrixTrial {
  const MatrixTrial({
    required this.tiles,
    required this.found,
    required this.duration,
  });

  final int tiles; // how many lit up
  final int found; // how many were tapped before a miss
  final Duration duration;

  bool get perfect => found == tiles;

  Map<String, dynamic> toJson() => {
    'nodes': tiles,
    'found': found,
    'duration_ms': duration.inMilliseconds,
  };
}
