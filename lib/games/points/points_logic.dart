import 'dart:math';
import 'dart:ui';

/// Rules of Points of Thought, kept apart from the screen.
abstract final class PointsOfThought {
  /// A session is a single round. The level carries over between sessions:
  /// the server says which one to play.
  static const rounds = 1;
  static const dotsPerRound = 10;
  static const startLevel = 2;
  static const maxLevel = 8;

  /// Track coordinates run 0..[boardWidth] across and 0..[boardHeight] down.
  static const boardWidth = 100.0;
  static const boardHeight = 120.0;

  /// How fast dots run, in track units per second.
  static const speed = 14.0;

  /// Pause before the first dot of a round.
  static const firstDotAfter = 2.0;

  /// At or above this share of dots delivered, the next round is harder ...
  static const levelUpAt = 0.9;

  /// ... and below this share, easier.
  static const levelDownBelow = 0.7;

  /// Level → (targets, seconds between dots).
  static const _levels = [
    (3, 5.0),
    (4, 4.5),
    (4, 3.8),
    (5, 3.8),
    (5, 3.2),
    (6, 3.2),
    (6, 2.7),
    (6, 2.3),
  ];

  static int targetsAt(int level) => _levels[level - 1].$1;
  static double intervalAt(int level) => _levels[level - 1].$2;

  static int nextLevel(int level, {required int delivered}) {
    final share = delivered / dotsPerRound;
    final next = share >= levelUpAt
        ? level + 1
        : (share < levelDownBelow ? level - 1 : level);
    return next.clamp(1, maxLevel);
  }
}

/// A point on the track: a switch with two ways out, or a target.
class TrackNode {
  TrackNode.target(this.target, this.position) : left = null, right = null;
  TrackNode.junction(this.left, this.right, this.position) : target = null;

  /// Where it is drawn, in track units.
  final Offset position;

  /// Nodes this switch leads to. Null for a target.
  final int? left;
  final int? right;

  /// Which colour this target takes. Null for a switch.
  final int? target;

  bool get isSwitch => target == null;
}

/// The tracks of one level: a tree of switches with a target at every end.
class TrackLayout {
  TrackLayout._(this.nodes, this.root, this.targets);

  /// Where dots come out, above the first switch.
  static const origin = Offset(PointsOfThought.boardWidth / 2, 6);

  final List<TrackNode> nodes;
  final int root;
  final int targets;

  Iterable<int> get switches sync* {
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].isSwitch) yield i;
    }
  }

  // How the switches branch for each number of targets. 0 is a target.
  static const _shapes = <int, Object>{
    3: [
      0,
      [0, 0],
    ],
    4: [
      [0, 0],
      [0, 0],
    ],
    5: [
      [0, 0],
      [
        0,
        [0, 0],
      ],
    ],
    6: [
      [
        0,
        [0, 0],
      ],
      [
        [0, 0],
        0,
      ],
    ],
  };

  factory TrackLayout.forTargets(int targets) {
    final nodes = <TrackNode?>[];
    var nextTarget = 0;

    // Targets sit in a row along the bottom; a switch sits above the middle
    // of what it leads to, one row down for each level of branching.
    int build(Object shape, int depth) {
      final index = nodes.length;
      nodes.add(null);
      if (shape is! List) {
        final x = (nextTarget + 0.5) / targets * PointsOfThought.boardWidth;
        nodes[index] = TrackNode.target(nextTarget++, Offset(x, 106));
      } else {
        final left = build(shape[0] as Object, depth + 1);
        final right = build(shape[1] as Object, depth + 1);
        final x = (nodes[left]!.position.dx + nodes[right]!.position.dx) / 2;
        nodes[index] = TrackNode.junction(
          left,
          right,
          Offset(x, 22.0 + depth * 24),
        );
      }
      return index;
    }

    final root = build(_shapes[targets]!, 0);
    return TrackLayout._(nodes.cast<TrackNode>(), root, targets);
  }
}

class Dot {
  Dot(this.colour, this.from, this.to);

  /// The target it belongs at.
  final int colour;

  /// The stretch of track it is on.
  Offset from;
  int to; // node it is heading for

  /// How far along that stretch it is, in track units.
  double travelled = 0;

  Offset get position {
    final length = (toPosition - from).distance;
    return Offset.lerp(from, toPosition, length == 0 ? 1 : travelled / length)!;
  }

  late Offset toPosition;
}

/// A dot that has reached a target.
typedef Arrival = ({int target, bool correct, double at});

/// One round: dots leave the origin one after another and follow the
/// switches as they are set at the moment each dot reaches them.
class PointsRound {
  PointsRound({required this.level, required Random random})
    : _random = random,
      layout = TrackLayout.forTargets(PointsOfThought.targetsAt(level)),
      interval = PointsOfThought.intervalAt(level) {
    for (final node in layout.switches) {
      sendsRight[node] = random.nextBool();
    }
    _untilNextDot = PointsOfThought.firstDotAfter;
    nextColour = random.nextInt(layout.targets);
  }

  final int level;
  final TrackLayout layout;
  final double interval; // seconds between dots
  final Random _random;

  /// Switch node → whether it currently sends dots right.
  final sendsRight = <int, bool>{};
  final dots = <Dot>[];

  /// The most recent arrival at each target, for the flash of feedback.
  final lastArrival = <int, Arrival>{};

  /// The dot waiting in the origin, shown so the player can plan ahead.
  /// Null once the last one has left.
  int? nextColour;

  int sent = 0;
  int delivered = 0; // reached the right target
  int lost = 0; // reached a wrong one
  double clock = 0;
  late double _untilNextDot;

  bool get finished => sent == PointsOfThought.dotsPerRound && dots.isEmpty;

  void toggle(int node) => sendsRight[node] = !sendsRight[node]!;

  /// Moves everything forward by [dt] seconds.
  void update(double dt) {
    clock += dt;
    if (sent < PointsOfThought.dotsPerRound) {
      _untilNextDot -= dt;
      if (_untilNextDot <= 0) {
        _untilNextDot += interval;
        sent++;
        dots.add(
          Dot(nextColour!, TrackLayout.origin, layout.root)
            ..toPosition = layout.nodes[layout.root].position,
        );
        nextColour = sent < PointsOfThought.dotsPerRound
            ? _random.nextInt(layout.targets)
            : null;
      }
    }

    for (final dot in [...dots]) {
      var left = PointsOfThought.speed * dt;
      while (left > 0) {
        final length = (dot.toPosition - dot.from).distance;
        final remaining = length - dot.travelled;
        if (left < remaining) {
          dot.travelled += left;
          break;
        }
        left -= remaining;
        final node = layout.nodes[dot.to];
        if (!node.isSwitch) {
          final correct = node.target == dot.colour;
          correct ? delivered++ : lost++;
          lastArrival[node.target!] = (
            target: node.target!,
            correct: correct,
            at: clock,
          );
          dots.remove(dot);
          break;
        }
        // At a switch: follow it the way it points right now.
        dot
          ..from = node.position
          ..to = sendsRight[dot.to]! ? node.right! : node.left!
          ..travelled = 0;
        dot.toPosition = layout.nodes[dot.to].position;
      }
    }
  }
}

/// One finished round, as sent to the server.
class PointsRoundResult {
  const PointsRoundResult({
    required this.level,
    required this.delivered,
    required this.duration,
  });

  final int level;
  final int delivered;
  final Duration duration;

  Map<String, dynamic> toJson() => {
    'level': level,
    'points': PointsOfThought.dotsPerRound,
    'correct': delivered,
    'duration_ms': duration.inMilliseconds,
  };
}
