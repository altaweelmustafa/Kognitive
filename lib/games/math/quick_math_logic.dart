import 'dart:math';

typedef MathQuestion = ({String text, int answer});

/// Rules of Quick Math: answer as many sums as possible in 60 seconds.
abstract final class QuickMath {
  static const seconds = 60;

  /// How long the right / wrong flash stays after an answer. It doesn't hold
  /// the player up: the next question is already there.
  static const flashFor = Duration(milliseconds: 350);

  /// A question whose difficulty follows how many have been answered
  /// correctly so far. Answers are never negative and divisions are exact.
  static MathQuestion question(Random random, int correct) {
    int between(int low, int high) => low + random.nextInt(high - low + 1);

    MathQuestion add(int max) {
      final a = between(2, max), b = between(2, max);
      return (text: '$a + $b', answer: a + b);
    }

    MathQuestion subtract(int max) {
      final a = between(2, max), b = between(1, a);
      return (text: '$a − $b', answer: a - b);
    }

    MathQuestion multiply(int max) {
      final a = between(2, max), b = between(2, max);
      return (text: '$a × $b', answer: a * b);
    }

    MathQuestion divide(int max) {
      final b = between(2, max), answer = between(2, max);
      return (text: '${b * answer} ÷ $b', answer: answer);
    }

    // Warm-up, then tables, then everything.
    final kinds = switch (correct) {
      < 5 => [() => add(10), () => subtract(15)],
      < 12 => [() => add(50), () => subtract(60), () => multiply(9)],
      _ => [
        () => add(150),
        () => subtract(200),
        () => multiply(12),
        () => divide(12),
      ],
    };
    return kinds[random.nextInt(kinds.length)]();
  }
}
