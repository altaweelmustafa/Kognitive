import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/games/apothecary/apothecary_logic.dart';

void main() {
  test('a pour moves the whole top run, as much as fits', () {
    final bottles = [
      [0, 1, 1, 1],
      [2, 1],
      [2, 2, 0],
      <int>[],
    ];
    expect(Apothecary.pourable(bottles, 0, 1), 2); // three 1s, room for two
    expect(Apothecary.pourable(bottles, 0, 2), 0); // different colour on top
    expect(
      Apothecary.pourable(bottles, 0, 3),
      3,
    ); // empty bottle takes them all
    expect(Apothecary.pourable(bottles, 3, 0), 0); // nothing to pour
    expect(Apothecary.pour(bottles, 0, 1), 2);
    expect(bottles[0], [0, 1]);
    expect(bottles[1], [2, 1, 1, 1]);
  });

  test('solved means every bottle is empty or one full colour', () {
    expect(
      Apothecary.isSolved([
        [1, 1, 1, 1],
        [],
        [0, 0, 0, 0],
      ]),
      isTrue,
    );
    expect(
      Apothecary.isSolved([
        [1, 1, 1],
        [1],
        [0, 0, 0, 0],
      ]),
      isFalse,
    );
  });

  test('every generated puzzle is solvable in its par, at every size', () {
    final random = Random(3);
    for (
      var colours = Apothecary.minColours;
      colours <= Apothecary.maxColours;
      colours++
    ) {
      final watch = Stopwatch()..start();
      for (var i = 0; i < 4; i++) {
        final puzzle = Apothecary.generate(random, colours);
        expect(puzzle.bottles.length, colours + Apothecary.spareBottles);
        expect(puzzle.bottles.any(Apothecary.isComplete), isFalse);

        final bottles = Apothecary.copy(puzzle.bottles);
        final solution = Apothecary.solve(bottles, maxDepth: 200)!;
        for (final p in solution) {
          expect(Apothecary.pour(bottles, p.from, p.to), greaterThan(0));
        }
        expect(Apothecary.isSolved(bottles), isTrue);
        expect(puzzle.par, lessThanOrEqualTo(solution.length));
        expect(
          puzzle.par,
          greaterThanOrEqualTo(colours),
        ); // at least a pour per colour
      }
      // ignore: avoid_print
      print(
        '$colours colours: ${watch.elapsedMilliseconds ~/ 4} ms per puzzle',
      );
    }
  });

  test('the next puzzle follows how the last one went', () {
    ApothecaryTrial trial(int moves, {bool solved = true}) => ApothecaryTrial(
      colours: 5,
      par: 20,
      moves: moves,
      solved: solved,
      duration: Duration.zero,
    );
    expect(Apothecary.nextColours(trial(20)), 6);
    expect(Apothecary.nextColours(trial(25)), 6); // within a quarter of par
    expect(Apothecary.nextColours(trial(26)), 5);
    expect(Apothecary.nextColours(trial(9, solved: false)), 4);
  });
}
