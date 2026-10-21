import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'apothecary_logic.dart';

/// Colours the game draws with, taken from the app's palette.
class ApothecaryColours {
  const ApothecaryColours({
    required this.liquids,
    required this.glass,
    required this.stopper,
    required this.background,
  });

  final List<Color> liquids;
  final Color glass;
  final Color stopper;
  final Color background;
}

/// The Flame game for one Apothecary puzzle: bottles that lift, tilt and pour,
/// with liquid that stays level and sloshes as the glass moves.
class ApothecaryGame extends FlameGame {
  ApothecaryGame({
    required ApothecaryPuzzle puzzle,
    required this.colours,
    this.onPoured,
    this.onSolved,
    this.onSelect,
  }) : _start = Apothecary.copy(puzzle.bottles),
       state = Apothecary.copy(puzzle.bottles);

  final ApothecaryColours colours;

  /// After every pour, once it has finished animating.
  final VoidCallback? onPoured;
  final VoidCallback? onSolved;

  /// When a bottle is picked up or put down.
  final VoidCallback? onSelect;

  final List<List<int>> _start;

  /// Where the liquid is, in the rules' terms.
  final List<List<int>> state;
  final bottles = <BottleComponent>[];
  final _history = <List<List<int>>>[];

  int pours = 0;
  int? selected;
  _PourAnimation? _pouring;
  late final _stream = _StreamComponent();

  /// A pour is in the air; taps wait until it lands.
  bool get busy => _pouring != null;
  bool get solved => Apothecary.isSolved(state);
  bool get canUndo => _history.isNotEmpty && !busy;

  @override
  Color backgroundColor() => colours.background;

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < state.length; i++) {
      bottles.add(BottleComponent(index: i)..setLayers(state[i]));
    }
    await addAll(bottles);
    await add(_stream);
    _layout();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (bottles.isNotEmpty) _layout();
  }

  /// One row for up to five bottles, two rows beyond that.
  void _layout() {
    final rows = bottles.length <= 5 ? 1 : 2;
    final perRow = (bottles.length / rows).ceil();
    final cell = size.x / perRow;
    final rowHeight = size.y / rows;
    final width = min(min(cell * 0.56, 56.0), rowHeight * 0.2);
    final bottleSize = Vector2(width, width * 3.2);
    for (final (i, bottle) in bottles.indexed) {
      final row = i ~/ perRow, col = i % perRow;
      final inRow = row == rows - 1
          ? bottles.length - perRow * (rows - 1)
          : perRow;
      final left = (size.x - inRow * cell) / 2;
      bottle
        ..size = bottleSize
        // A little below centre: bottles need headroom to lift and pour.
        ..home = Vector2(left + cell * (col + 0.5), rowHeight * (row + 0.58))
        ..snapHome();
    }
  }

  void tapBottle(int index) {
    if (busy || solved) return;
    final from = selected;
    if (from == null) {
      if (state[index].isEmpty || Apothecary.isComplete(state[index])) {
        bottles[index].nudge();
      } else {
        _select(index);
      }
    } else if (from == index) {
      _select(null);
    } else if (Apothecary.pourable(state, from, index) > 0) {
      _startPour(from, index);
    } else {
      // Can't pour there: say so with a wobble, and pick that bottle up
      // instead if it has something to pour.
      bottles[index].nudge();
      _select(
        state[index].isEmpty || Apothecary.isComplete(state[index])
            ? null
            : index,
      );
    }
  }

  void _select(int? index) {
    if (selected case final old?) bottles[old].lifted = false;
    selected = index;
    if (index != null) bottles[index].lifted = true;
    onSelect?.call();
  }

  void _startPour(int from, int to) {
    _history.add(Apothecary.copy(state));
    final colour = state[from].last;
    final amount = Apothecary.pour(state, from, to);
    _select(null);
    _pouring = _PourAnimation(
      source: bottles[from],
      target: bottles[to],
      colour: colour,
      amount: amount,
    );
    bottles[from].priority = 20;
    _stream.priority = 10;
  }

  /// Takes back the last pour. The pour count stays: it measures effort.
  void undo() {
    if (!canUndo) return;
    _restore(_history.removeLast());
  }

  /// Back to the starting arrangement.
  void restart() {
    if (busy) return;
    _history.clear();
    _restore(_start);
  }

  void _restore(List<List<int>> to) {
    _select(null);
    for (final (i, bottle) in bottles.indexed) {
      state[i]
        ..clear()
        ..addAll(to[i]);
      bottle
        ..setLayers(state[i])
        ..nudge();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final pour = _pouring;
    if (pour == null) return;
    pour.update(dt, _stream);
    if (pour.done) {
      pour.source
        ..priority = 0
        ..setLayers(state[pour.source.index]);
      pour.target.setLayers(state[pour.target.index]);
      _pouring = null;
      pours++;
      onPoured?.call();
      if (solved) onSolved?.call();
    }
  }
}

/// A run of one colour inside a bottle. [amount] is in units and passes
/// through fractions while liquid is being poured.
class _Layer {
  _Layer(this.colour, this.amount);

  final int colour;
  double amount;
}

/// One bottle: glass, liquid, and the small physics that make it feel alive.
class BottleComponent extends PositionComponent
    with TapCallbacks, HasGameReference<ApothecaryGame> {
  BottleComponent({required this.index}) : super(anchor: Anchor.center);

  final int index;
  final _layers = <_Layer>[];

  /// Where it stands when left alone.
  Vector2 home = Vector2.zero();

  /// Picked up, waiting for somewhere to pour.
  bool lifted = false;

  /// Set while a pour drives position and angle directly.
  bool driven = false;

  // The liquid's surface is a damped spring: it tips when the glass moves
  // sideways and settles back to level.
  double _slosh = 0; // extra tilt of the surface, radians
  double _sloshSpeed = 0;
  double _lastX = 0;
  static const _stiffness = 90.0;
  static const _damping = 7.0;
  static const _sideways = 0.016; // how hard sideways movement pushes it

  double get fill => _layers.fold(0.0, (sum, l) => sum + l.amount);
  bool get complete =>
      _layers.length == 1 &&
      _layers.single.amount >= Apothecary.capacity - 0.001;

  void setLayers(List<int> units) {
    _layers.clear();
    for (final colour in units) {
      if (_layers.isNotEmpty && _layers.last.colour == colour) {
        _layers.last.amount += 1;
      } else {
        _layers.add(_Layer(colour, 1));
      }
    }
  }

  /// Takes [amount] off the top layer.
  void drain(double amount) {
    if (_layers.isEmpty) return;
    _layers.last.amount -= amount;
    if (_layers.last.amount <= 0.0001) _layers.removeLast();
  }

  /// Adds [amount] of [colour] on top.
  void receive(int colour, double amount) {
    if (_layers.isNotEmpty && _layers.last.colour == colour) {
      _layers.last.amount += amount;
    } else {
      _layers.add(_Layer(colour, amount));
    }
  }

  /// A wobble: "no", or "something just changed".
  void nudge() => _sloshSpeed += 3.2;

  void snapHome() {
    position = home.clone();
    _lastX = position.x;
  }

  /// Height of one unit of liquid.
  double get unit => size.y * 0.86 / Apothecary.capacity;

  /// Inside height: the part liquid can occupy.
  double get inner => unit * Apothecary.capacity;

  @override
  void onTapDown(TapDownEvent event) => game.tapBottle(index);

  @override
  void update(double dt) {
    if (!driven) {
      // Ease towards rest: home, or held up when picked.
      final rest = lifted ? home - Vector2(0, size.y * 0.2) : home;
      position += (rest - position) * min(1.0, dt * 14);
      angle += (0 - angle) * min(1.0, dt * 14);
    }
    final speed = dt > 0 ? (position.x - _lastX) / dt : 0.0;
    _lastX = position.x;
    _sloshSpeed +=
        (-_stiffness * _slosh - _damping * _sloshSpeed - speed * _sideways) *
        dt;
    _slosh = (_slosh + _sloshSpeed * dt).clamp(-0.5, 0.5);
  }

  @override
  void render(Canvas canvas) {
    final w = size.x, h = size.y;
    final top = h - inner; // liquid can rise this high
    final radius = Radius.circular(w * 0.42);
    final body = RRect.fromRectAndCorners(
      Rect.fromLTRB(0, 0, w, h),
      bottomLeft: radius,
      bottomRight: radius,
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
    );
    final colours = game.colours;

    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRRect(
      body,
      Paint()..color = colours.glass.withValues(alpha: 0.06),
    );

    // The surface stays level with the world while the glass tilts, so in the
    // bottle's own frame it slopes the other way.
    final slope = tan((angle + _slosh).clamp(-1.5, 1.5));
    double surfaceAt(double x, double height) =>
        h - height * unit - (x - w / 2) * slope;

    var below = 0.0;
    for (final (i, layer) in _layers.indexed) {
      final above = below + layer.amount;
      // The bottom layer fills down to the base however the bottle is tilted.
      final path = Path()
        ..moveTo(0, surfaceAt(0, above))
        ..lineTo(w, surfaceAt(w, above))
        ..lineTo(w, i == 0 ? h : surfaceAt(w, below))
        ..lineTo(0, i == 0 ? h : surfaceAt(0, below))
        ..close();
      canvas.drawPath(path, Paint()..color = colours.liquids[layer.colour]);
      below = above;
    }
    // A lighter line along the top surface.
    if (_layers.isNotEmpty) {
      canvas.drawLine(
        Offset(0, surfaceAt(0, below)),
        Offset(w, surfaceAt(w, below)),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..strokeWidth = 2,
      );
    }
    // Shine down the left of the glass.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, top * 0.5, w * 0.1, h * 0.62),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = const Color(0x22FFFFFF),
    );
    canvas.restore();

    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colours.glass.withValues(alpha: 0.55),
    );
    // A finished bottle is stoppered.
    if (complete) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.14, -w * 0.3, w * 0.72, w * 0.42),
          Radius.circular(w * 0.1),
        ),
        Paint()..color = colours.stopper,
      );
    }
  }
}

/// Carries one pour through: lift and tilt, pour, set back down.
class _PourAnimation {
  _PourAnimation({
    required this.source,
    required this.target,
    required this.colour,
    required this.amount,
  }) : _side = target.home.x >= source.home.x ? 1.0 : -1.0,
       _fillBefore = source.fill {
    source.driven = true;
    _from = source.position.clone();
  }

  final BottleComponent source;
  final BottleComponent target;
  final int colour;
  final int amount;

  /// +1 pours to the right (tilting clockwise), -1 to the left.
  final double _side;
  final double _fillBefore;
  late final Vector2 _from;

  static const _approach = 0.3;
  static const _perUnit = 0.26;
  static const _retreat = 0.3;

  double _time = 0;
  double _poured = 0;
  bool done = false;

  double get _pourTime => amount * _perUnit;

  /// The tilt at which liquid filled to [fill] units just reaches the lip.
  double _tiltFor(double fill) {
    final rise =
        source.inner - fill * source.unit + (source.size.y - source.inner);
    return min(atan2(2 * rise, source.size.x), 1.5);
  }

  /// Where the bottle's centre must be for its pouring lip to sit over the
  /// target's mouth at this tilt.
  Vector2 _centreAt(double tilt) {
    final lip = Vector2(_side * source.size.x / 2, -source.size.y / 2)
      ..rotate(tilt);
    final mouth = Vector2(
      target.home.x - _side * target.size.x * 0.12,
      target.home.y - target.size.y / 2 - target.size.y * 0.1,
    );
    return mouth - lip;
  }

  static double _ease(double t) => t * t * (3 - 2 * t);

  void update(double dt, _StreamComponent stream) {
    _time += dt;
    final startTilt = _side * _tiltFor(_fillBefore);
    final endTilt = _side * _tiltFor(_fillBefore - amount);

    if (_time < _approach) {
      final t = _ease(_time / _approach);
      source
        ..angle = startTilt * t
        ..position = _from + (_centreAt(startTilt * t) - _from) * t;
      stream.visible = false;
    } else if (_time < _approach + _pourTime) {
      final t = (_time - _approach) / _pourTime;
      final nowPoured = amount * t;
      source.drain(nowPoured - _poured);
      target.receive(colour, nowPoured - _poured);
      _poured = nowPoured;
      final tilt = startTilt + (endTilt - startTilt) * t;
      source
        ..angle = tilt
        ..position = _centreAt(tilt);

      // The stream falls from the lip to the liquid in the target.
      final lip =
          source.position +
          (Vector2(_side * source.size.x / 2, -source.size.y / 2)
            ..rotate(tilt));
      final surface =
          target.home.y + target.size.y / 2 - target.fill * target.unit;
      stream
        ..visible = true
        ..colour = source.game.colours.liquids[colour]
        ..from = Offset(lip.x, lip.y)
        ..to = Offset(lip.x, surface)
        ..width = source.size.x * 0.16;
    } else if (_time < _approach + _pourTime + _retreat) {
      // Whatever rounding left behind goes over in one last drop.
      if (_poured < amount) {
        source.drain(amount - _poured);
        target.receive(colour, amount - _poured);
        _poured = amount.toDouble();
      }
      final t = _ease((_time - _approach - _pourTime) / _retreat);
      final tilt = endTilt * (1 - t);
      final lifted = _centreAt(endTilt);
      source
        ..angle = tilt
        ..position = lifted + (source.home - lifted) * t;
      stream.visible = false;
    } else {
      source
        ..angle = 0
        ..position = source.home.clone()
        ..driven = false;
      stream.visible = false;
      target.nudge();
      done = true;
    }
  }
}

/// The falling liquid between two bottles.
class _StreamComponent extends Component {
  bool visible = false;
  Color colour = const Color(0x00000000);
  Offset from = Offset.zero;
  Offset to = Offset.zero;
  double width = 6;

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = colour
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }
}
