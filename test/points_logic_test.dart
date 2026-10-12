import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/games/points/points_logic.dart';

/// Plays like a perfect player: each switch is set for whichever dot will
/// reach it next.
void steer(PointsRound round) {
  double remaining(Dot t) => (t.toPosition - t.from).distance - t.travelled;
  final next = <int, Dot>{};
  for (final dot in round.dots) {
    if (!round.layout.nodes[dot.to].isSwitch) continue;
    final known = next[dot.to];
    if (known == null || remaining(dot) < remaining(known)) {
      next[dot.to] = dot;
    }
  }
  next.forEach((node, dot) {
    round.sendsRight[node] = _leads(
      round.layout,
      round.layout.nodes[node].right!,
      dot.colour,
    );
  });
}

bool _leads(TrackLayout layout, int node, int target) {
  final n = layout.nodes[node];
  if (!n.isSwitch) return n.target == target;
  return _leads(layout, n.left!, target) || _leads(layout, n.right!, target);
}

void main() {
  test('every level has a target for each colour and one switch fewer', () {
    for (var level = 1; level <= PointsOfThought.maxLevel; level++) {
      final layout = TrackLayout.forTargets(PointsOfThought.targetsAt(level));
      final targets = [
        for (final n in layout.nodes)
          if (!n.isSwitch) n.target,
      ];
      expect(targets..sort(), List.generate(layout.targets, (i) => i));
      expect(layout.switches.length, layout.targets - 1);
      for (final n in layout.nodes) {
        expect(n.position.dx, inInclusiveRange(0, PointsOfThought.boardWidth));
        expect(n.position.dy, inInclusiveRange(0, PointsOfThought.boardHeight));
      }
    }
  });

  test('left alone, every dot still arrives somewhere', () {
    final round = PointsRound(level: 3, random: Random(1));
    var steps = 0;
    while (!round.finished && steps++ < 5000) {
      round.update(0.05);
    }
    expect(round.finished, isTrue);
    expect(round.sent, PointsOfThought.dotsPerRound);
    expect(round.delivered + round.lost, PointsOfThought.dotsPerRound);
    expect(round.lost, greaterThan(0)); // nobody was steering
  });

  test('a dot follows the switch as it is set when it gets there', () {
    final round = PointsRound(level: 1, random: Random(2));
    final root = round.layout.root;
    while (round.dots.isEmpty) {
      round.update(0.05);
    }
    final dot = round.dots.single;
    round.sendsRight[root] = false;
    round.toggle(root); // now right
    while (dot.to == root) {
      round.update(0.05);
    }
    expect(dot.to, round.layout.nodes[root].right);
  });

  test('a perfect player delivers every dot, at every level', () {
    for (var level = 1; level <= PointsOfThought.maxLevel; level++) {
      final round = PointsRound(level: level, random: Random(level));
      var steps = 0;
      while (!round.finished && steps++ < 20000) {
        steer(round);
        round.update(0.016);
      }
      // Two dots can need the same switch set opposite ways at once only if
      // they reach it at the same instant, which the spacing rules out.
      expect(
        round.delivered,
        PointsOfThought.dotsPerRound,
        reason: 'level $level',
      );
    }
  });

  test('levels follow how many dots were delivered', () {
    expect(PointsOfThought.nextLevel(2, delivered: 10), 3);
    expect(PointsOfThought.nextLevel(2, delivered: 9), 3);
    expect(PointsOfThought.nextLevel(2, delivered: 8), 2);
    expect(PointsOfThought.nextLevel(2, delivered: 6), 1);
    expect(PointsOfThought.nextLevel(1, delivered: 0), 1);
    expect(PointsOfThought.nextLevel(8, delivered: 10), 8);
  });
}
