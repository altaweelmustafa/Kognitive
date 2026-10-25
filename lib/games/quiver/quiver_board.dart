import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'quiver_logic.dart';

/// The square field of drifting arrows.
///
/// Each arrow is a bendable strip textured with the arrow artwork. Its weight
/// sits in the tip: when the trial changes, the tip swings to the new
/// direction on an underdamped spring (overshooting a little, then settling)
/// and the shaft and fletching trail behind it like a whip. The arrow turns
/// about its centre of mass, which is close to the tip, so the tail sweeps
/// the wide arc.
class QuiverBoard extends StatefulWidget {
  const QuiverBoard({
    super.key,
    required this.trial,
    required this.speed,
    required this.background,
    this.border,
    this.random,
  });

  final QuiverTrial trial;

  /// Drift speed, in board widths per second.
  final double speed;
  final Color background;

  /// The outline, for the right / wrong flash.
  final Color? border;
  final Random? random;

  /// Starts loading the arrow artwork, so it is ready when the board shows.
  static Future<void> preload() =>
      _ArrowArt.load().then((_) {}, onError: (_) {});

  @override
  State<QuiverBoard> createState() => _QuiverBoardState();
}

class _QuiverBoardState extends State<QuiverBoard>
    with SingleTickerProviderStateMixin {
  late final _world = _World(widget.random ?? Random());
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  (ui.Image, ui.Image)? _images;

  @override
  void initState() {
    super.initState();
    _world.apply(widget.trial, widget.speed, first: true);
    _ticker.start();
    // Until the artwork is in, the arrows are drawn as plain lines.
    _ArrowArt.load().then((images) {
      if (mounted) setState(() => _images = images);
    }, onError: (_) {});
  }

  @override
  void didUpdateWidget(QuiverBoard old) {
    super.didUpdateWidget(old);
    if (!identical(old.trial, widget.trial)) {
      _world.apply(widget.trial, widget.speed);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _world.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    // A long frame (a pause, a debugger) shouldn't fling the arrows.
    final dt = min((elapsed - _last).inMicroseconds / 1e6, 1 / 20);
    _last = elapsed;
    if (dt > 0) _world.step(dt);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: widget.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.border ?? widget.background,
            width: 3,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: CustomPaint(
            painter: _BoardPainter(_world, _images),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

/// The two arrow images, loaded once.
abstract final class _ArrowArt {
  static const green = 'assets/quiver/arrow_green.png';
  static const red = 'assets/quiver/arrow_red.png';

  /// Size of the artwork, and where along it the head begins.
  static const width = 476.0;
  static const height = 50.0;
  static const headStart = 410.0;

  static Future<(ui.Image, ui.Image)>? _loading;

  static Future<(ui.Image, ui.Image)> load() => _loading ??= _both();

  static Future<(ui.Image, ui.Image)> _both() async =>
      (await _one(green), await _one(red));

  static Future<ui.Image> _one(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }
}

// ── Physics ─────────────────────────────────────────────────

/// Segments along an arrow, tip first. Segment 0 is the rigid head.
const _segments = 14;

/// How much each segment weighs, for the centre of mass: a heavy head, a
/// light shaft, fletching in between.
final _mass = [
  for (var i = 0; i < _segments; i++)
    i == 0 ? 7.0 : (i >= _segments - 4 ? 0.9 : 0.3),
];

/// The tip's spring: stiff and underdamped, so it overshoots and settles.
const _tipStiffness = 300.0;
const _tipDamping = 2 * 0.42 * 17.3; // ζ ≈ 0.42 at ω = √300

/// The shaft follows the path the tip took: each segment is this many
/// seconds behind the one ahead of it. Behind the tip, the tail is about a
/// tenth of a second late, which is what bends the arrow as it turns.
const _lag = 0.0085;

/// The most one joint may bend, so the arrow curves but never folds.
const _maxBend = 0.075;

/// How long the new colour takes to run from the tip to the tail.
const _colourRun = 0.22;

/// How much thicker than the artwork's proportions arrows are drawn.
const _thicken = 1.45;

/// Physics runs in small fixed steps for stability.
const _substep = 1 / 240;

/// Tip angles kept, one per step: enough for the tail's lag.
final _history = (_lag * _segments / _substep).ceil() + 2;

class _Arrow {
  _Arrow({
    required this.pos,
    required double angle,
    required this.red,
    required this.phase,
  }) : target = angle,
       tip = angle,
       angles = List.filled(_segments, angle),
       _trail = List.filled(_history, angle),
       fromRed = red;

  /// Where its centre of mass is, in board widths.
  Offset pos;

  /// Unwrapped angle the tip is heading for.
  double target;

  /// The tip's angle and how fast it is turning.
  double tip;
  double spin = 0;

  /// Angle of each segment, tip first.
  final List<double> angles;

  /// The tip's recent angles, newest at [_head], as a ring.
  final List<double> _trail;
  int _head = 0;

  /// 0 → 1 as it pops in; back to 0 as it leaves.
  double appear = 0;
  bool leaving = false;

  /// Colour now and before. The new colour runs down from the tip;
  /// [colourT] is how far it has got, 0 to 1.
  bool red;
  bool fromRed;
  double colourT = 1;

  /// A change waiting to start, so the arrows don't all turn in lockstep.
  double delay = 0;
  double? pendingTarget;
  bool? pendingRed;

  /// Offset of its idle sway.
  final double phase;

  void schedule(double angle, bool toRed, double after, Random random) {
    // Turn the short way round; a half turn picks a side at random.
    final from = pendingTarget ?? target;
    var delta = (angle - from) % (2 * pi);
    if (delta > pi) delta -= 2 * pi;
    if ((delta.abs() - pi).abs() < 1e-6) {
      delta = random.nextBool() ? pi : -pi;
    }
    pendingTarget = from + delta;
    pendingRed = toRed;
    delay = after;
  }

  void step(double dt, double time) {
    if (pendingTarget != null) {
      delay -= dt;
      if (delay <= 0) {
        target = pendingTarget!;
        if (pendingRed != red) {
          // Mid-run, the colour that has the most of the arrow wins.
          if (colourT >= 0.5) fromRed = red;
          red = pendingRed!;
          colourT = 0;
        }
        pendingTarget = null;
        pendingRed = null;
      }
    }

    appear = (appear + (leaving ? -dt : dt) * 4.5).clamp(0.0, 1.0);
    colourT = min(1, colourT + dt / _colourRun);

    // A breath of sway keeps them alive between turns.
    final sway = 0.03 * sin(time * 1.9 + phase);

    // The heavy tip: a spring towards the target.
    spin += (_tipStiffness * (target + sway - tip) - _tipDamping * spin) * dt;
    tip += spin * dt;
    _head = (_head + 1) % _history;
    _trail[_head] = tip;

    // The shaft: each segment takes the angle the tip had a moment ago.
    angles[0] = tip;
    for (var i = 1; i < _segments; i++) {
      final back = i * _lag / _substep;
      final whole = back.floor();
      final t = back - whole;
      final a = _trail[(_head - whole) % _history];
      final b = _trail[(_head - whole - 1) % _history];
      var angle = a + (b - a) * t;
      final bend = angle - angles[i - 1];
      if (bend.abs() > _maxBend) angle = angles[i - 1] + _maxBend * bend.sign;
      angles[i] = angle;
    }
  }
}

class _World extends ChangeNotifier {
  _World(this.random);

  final Random random;
  final arrows = <_Arrow>[];

  /// Shared drift, in board widths per second, easing towards [_aim].
  Offset velocity = Offset.zero;
  Offset _aim = Offset.zero;
  double time = 0;
  double _pending = 0;

  void apply(QuiverTrial trial, double speed, {bool first = false}) {
    _aim = trial.moves.unit * speed;
    if (first) velocity = _aim;

    final alive = arrows.where((a) => !a.leaving).toList();
    // Too many: the extra ones drift off.
    for (final a in alive.skip(trial.count)) {
      a.leaving = true;
    }
    final staying = alive.take(trial.count).toList();
    for (final (i, a) in staying.indexed) {
      a.schedule(
        trial.points.angle,
        trial.red,
        i * 0.025 + random.nextDouble() * 0.025,
        random,
      );
    }
    // Too few: new ones pop in already facing the new way.
    for (var i = staying.length; i < trial.count; i++) {
      arrows.add(
        _Arrow(
          pos: _freeSpot(),
          angle: trial.points.angle,
          red: trial.red,
          phase: random.nextDouble() * 2 * pi,
        ),
      );
    }
  }

  /// The candidate spot furthest from every other arrow, on the wrapping board.
  Offset _freeSpot() {
    double gap(Offset a, Offset b) {
      var dx = (a.dx - b.dx).abs() % 1, dy = (a.dy - b.dy).abs() % 1;
      dx = min(dx, 1 - dx);
      dy = min(dy, 1 - dy);
      // Arrows are long and thin: crowd less side by side than end to end.
      return sqrt(dx * dx + dy * dy);
    }

    final others = arrows.where((a) => !a.leaving).map((a) => a.pos).toList();
    var best = Offset(random.nextDouble(), random.nextDouble());
    var bestGap = -1.0;
    for (var i = 0; i < 24; i++) {
      final p = Offset(
        0.15 + random.nextDouble() * 0.7,
        0.15 + random.nextDouble() * 0.7,
      );
      final g = others.isEmpty ? 1.0 : others.map((o) => gap(p, o)).reduce(min);
      if (g > bestGap) {
        best = p;
        bestGap = g;
      }
    }
    return best;
  }

  void step(double dt) {
    _pending += dt;
    while (_pending >= _substep) {
      _pending -= _substep;
      time += _substep;
      // Ebb into the new drift rather than snapping to it.
      velocity += (_aim - velocity) * (1 - exp(-_substep * 3.2));
      for (final a in arrows) {
        a.pos = Offset(
          (a.pos.dx + velocity.dx * _substep) % 1,
          (a.pos.dy + velocity.dy * _substep) % 1,
        );
        a.step(_substep, time);
      }
    }
    arrows.removeWhere((a) => a.leaving && a.appear == 0);
    notifyListeners();
  }
}

// ── Painting ────────────────────────────────────────────────

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.world, this.images) : super(repaint: world);

  final _World world;
  final (ui.Image, ui.Image)? images;

  /// Triangle indices of the strip: two triangles per segment.
  static final _indices = Uint16List.fromList([
    for (var i = 0; i < _segments; i++) ...[
      2 * i,
      2 * i + 1,
      2 * i + 2,
      2 * i + 1,
      2 * i + 3,
      2 * i + 2,
    ],
  ]);

  /// Where each joint sits along the artwork, tip first.
  static final _texX = [
    for (var j = 0; j <= _segments; j++)
      j == 0
          ? _ArrowArt.width
          : _ArrowArt.headStart * (1 - (j - 1) / (_segments - 1)),
  ];

  static final _texCoords = Float32List.fromList([
    for (final x in _texX) ...[x, 0, x, _ArrowArt.height],
  ]);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final length = s * 0.36;
    for (final a in world.arrows) {
      final scale = _easeOutBack(a.appear);
      if (scale <= 0.01) continue;
      // The faster the tip spins, the more the arrow stretches: a hint of
      // squash and stretch.
      final stretch = 1 + 0.07 * min(1.0, a.spin.abs() / 14);
      final joints = _joints(a, length * scale * stretch);
      final com = _centreOfMass(joints);
      final centre = Offset(a.pos.dx * s, a.pos.dy * s);
      // Wrap round the edges: draw a copy on the far side while it crosses.
      for (final ox in [-s, 0.0, s]) {
        for (final oy in [-s, 0.0, s]) {
          final c = centre + Offset(ox, oy);
          if (c.dx < -length || c.dx > s + length) continue;
          if (c.dy < -length || c.dy > s + length) continue;
          _drawArrow(canvas, a, joints, c - com, length * scale, scale);
        }
      }
    }
  }

  static double _easeOutBack(double t) {
    const c1 = 1.70158, c3 = c1 + 1;
    final u = t - 1;
    return 1 + c3 * u * u * u + c1 * u * u;
  }

  /// Joint positions, tip at the origin and working back to the tail.
  static List<Offset> _joints(_Arrow a, double length) {
    final unit = length / _ArrowArt.width;
    final points = <Offset>[Offset.zero];
    for (var i = 0; i < _segments; i++) {
      final segment = (_texX[i] - _texX[i + 1]) * unit;
      points.add(
        points.last - Offset(cos(a.angles[i]), sin(a.angles[i])) * segment,
      );
    }
    return points;
  }

  static Offset _centreOfMass(List<Offset> joints) {
    var sum = Offset.zero;
    var total = 0.0;
    for (var i = 0; i < _segments; i++) {
      final mid = (joints[i] + joints[i + 1]) / 2;
      sum += mid * _mass[i];
      total += _mass[i];
    }
    return sum / total;
  }

  void _drawArrow(
    Canvas canvas,
    _Arrow a,
    List<Offset> joints,
    Offset origin,
    double length,
    double opacity,
  ) {
    // A touch thicker than the artwork, so the head reads at a glance.
    final half = length * _ArrowArt.height / _ArrowArt.width / 2 * _thicken;
    final positions = Float32List((_segments + 1) * 4);
    for (var j = 0; j <= _segments; j++) {
      // The strip's edge at each joint is square to the average of the two
      // segments that meet there.
      final angle = j == 0
          ? a.angles[0]
          : j == _segments
          ? a.angles[_segments - 1]
          : (a.angles[j - 1] + a.angles[j]) / 2;
      final normal = Offset(-sin(angle), cos(angle)) * half;
      final p = origin + joints[j];
      positions
        ..[4 * j] = p.dx - normal.dx
        ..[4 * j + 1] = p.dy - normal.dy
        ..[4 * j + 2] = p.dx + normal.dx
        ..[4 * j + 3] = p.dy + normal.dy;
    }

    final images = this.images;
    if (images == null) {
      _drawPlain(canvas, a, joints, origin, half);
      return;
    }
    final (green, red) = images;
    final alpha = opacity.clamp(0.0, 1.0);
    if (alpha < 1) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }
    if (a.colourT < 1) {
      // The old colour underneath, the new one running down from the tip.
      _drawStrip(canvas, a.fromRed ? red : green, positions, _segments * 1.0);
      _drawStrip(canvas, a.red ? red : green, positions, _segments * a.colourT);
    } else {
      _drawStrip(canvas, a.red ? red : green, positions, _segments * 1.0);
    }
    if (alpha < 1) canvas.restore();
  }

  /// Draws the strip from the tip back over [segments] segments (fractions
  /// allowed), textured with [image].
  static void _drawStrip(
    Canvas canvas,
    ui.Image image,
    Float32List positions,
    double segments,
  ) {
    if (segments <= 0) return;
    final whole = segments.floor().clamp(0, _segments);
    final part = segments - whole;
    final joints = whole + 1 + (part > 0 && whole < _segments ? 1 : 0);
    final Float32List pos, tex;
    if (joints == _segments + 1) {
      pos = positions;
      tex = _texCoords;
    } else {
      pos = Float32List(joints * 4)
        ..setAll(0, positions.sublist(0, (whole + 1) * 4));
      tex = Float32List(joints * 4)
        ..setAll(0, _texCoords.sublist(0, (whole + 1) * 4));
      if (joints > whole + 1) {
        // The front edge, part of the way along the next segment.
        for (var k = 0; k < 4; k++) {
          final from = whole * 4 + k, to = from + 4;
          pos[to] = positions[from] + (positions[to] - positions[from]) * part;
          tex[to] =
              _texCoords[from] + (_texCoords[to] - _texCoords[from]) * part;
        }
      }
    }
    final vertices = ui.Vertices.raw(
      VertexMode.triangles,
      pos,
      textureCoordinates: tex,
      indices: _indices.sublist(0, (joints - 1) * 6),
    );
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..shader = ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().storage,
      );
    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
    vertices.dispose();
  }

  /// Until the artwork has loaded: a plain line with a head.
  void _drawPlain(
    Canvas canvas,
    _Arrow a,
    List<Offset> joints,
    Offset origin,
    double half,
  ) {
    final colour = a.red ? const Color(0xFFD62B2B) : const Color(0xFF13944A);
    final path = Path()..moveTo(origin.dx, origin.dy);
    for (final j in joints.skip(1)) {
      path.lineTo(origin.dx + j.dx, origin.dy + j.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = half
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BoardPainter old) => old.images != images;
}
