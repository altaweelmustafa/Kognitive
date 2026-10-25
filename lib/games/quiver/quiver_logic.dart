import 'dart:math';

import 'package:flutter/painting.dart';

/// The four ways an arrow can point, move or be swiped.
enum Dir {
  up,
  right,
  down,
  left;

  /// Screen angle in radians: right is 0, down is a quarter turn.
  double get angle => switch (this) {
    Dir.right => 0,
    Dir.down => pi / 2,
    Dir.left => pi,
    Dir.up => -pi / 2,
  };

  /// A unit step in this direction, in screen coordinates.
  Offset get unit => switch (this) {
    Dir.right => const Offset(1, 0),
    Dir.down => const Offset(0, 1),
    Dir.left => const Offset(-1, 0),
    Dir.up => const Offset(0, -1),
  };

  /// The direction of a swipe or drag, by its larger component.
  static Dir of(Offset delta) => delta.dx.abs() >= delta.dy.abs()
      ? (delta.dx >= 0 ? Dir.right : Dir.left)
      : (delta.dy >= 0 ? Dir.down : Dir.up);
}

/// One screen of arrows. They all share a colour, the way they point and the
/// way they drift.
class QuiverTrial {
  const QuiverTrial({
    required this.red,
    required this.points,
    required this.moves,
    required this.count,
  });

  /// Red: swipe the way they move. Green: swipe the way they point.
  final bool red;
  final Dir points;
  final Dir moves;
  final int count;

  Dir get answer => red ? moves : points;
}

/// Rules of Quiver, Kognitiv's take on Ebb and Flow: 45 seconds of arrows.
/// Green arrows are swiped the way they point; red ones the way they move.
abstract final class Quiver {
  static const seconds = 45;

  /// Points for a right answer, before the streak multiplier.
  static const base = 25;
  static const maxMultiplier = 5;

  /// Every [streakStep] right answers in a row raise the multiplier by one.
  static const streakStep = 4;

  /// How long a wrong answer locks the board, so swipes can't be spammed.
  static const wrongLock = Duration(milliseconds: 450);

  /// How long the right / wrong flash stays.
  static const flashFor = Duration(milliseconds: 320);

  static int multiplier(int streak) =>
      min(maxMultiplier, 1 + streak ~/ streakStep);

  static int points(int streak) => base * multiplier(streak);

  /// Drift speed, in board widths per second. Faster as the player gets more
  /// right, so the motion is harder to ignore.
  static double speed(int correct) => 0.07 + min(correct, 30) * 0.0035;

  /// The next trial. Difficulty follows how many have been answered right so
  /// far: more arrows, and more often pointing one way while moving another.
  static QuiverTrial trial(Random random, int correct, [QuiverTrial? last]) {
    final (low, high, conflict) = switch (correct) {
      < 4 => (1, 2, 0.45),
      < 10 => (2, 4, 0.65),
      < 20 => (3, 5, 0.8),
      _ => (3, 6, 0.9),
    };
    final count = low + random.nextInt(high - low + 1);

    final red = random.nextBool();

    final points = Dir.values[random.nextInt(4)];
    Dir moves;
    if (random.nextDouble() < conflict) {
      final others = Dir.values.where((d) => d != points).toList();
      moves = others[random.nextInt(others.length)];
    } else {
      moves = points;
    }

    final next = QuiverTrial(
      red: red,
      points: points,
      moves: moves,
      count: count,
    );
    // A screen identical to the last one would look like nothing happened.
    if (last != null &&
        last.red == next.red &&
        last.points == next.points &&
        last.moves == next.moves) {
      return trial(random, correct, last);
    }
    return next;
  }
}
