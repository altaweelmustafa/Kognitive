import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';
import '../shared/tutorial_frame.dart';
import 'memory_matrix_logic.dart';

enum _Step { watch, recall, perfect, miss, ready }

/// Interactive first-play tutorial: the player watches a small pattern,
/// taps it back, then sees what a perfect round and a miss do.
class MemoryMatrixTutorial extends StatefulWidget {
  const MemoryMatrixTutorial({super.key, required this.onDone});

  /// Called by Start at the end, or by Skip.
  final VoidCallback onDone;

  @override
  State<MemoryMatrixTutorial> createState() => _MemoryMatrixTutorialState();
}

class _MemoryMatrixTutorialState extends State<MemoryMatrixTutorial>
    with TutorialTimers {
  /// The pattern the player practises on.
  static const _pattern = [6, 12, 18];

  /// The miss demo: these were lit, two get found, then [_missWrong].
  static const _missPattern = [7, 11, 17, 23];
  static const _missWrong = 13;

  /// The pattern on the last screen, as many tiles as round one.
  static const _readyPattern = [0, 3, 6, 9, 12, 16, 20, 24];

  static const _stagger = Duration(milliseconds: 260);
  static const _hintAfter = Duration(seconds: 4);

  Timer? _hintTimer;

  _Step _step = _Step.watch;
  List<int> _shown = const []; // the pattern on the grid this step
  int _lit = 0; // how many of [_shown] are lit right now
  bool _faintRest = false; // show unlit pattern tiles faintly
  final _found = <int>{};
  int? _wrong;
  int _shakes = 0;
  bool _retry = false; // the player missed and is watching again
  bool _hint = false;
  int _count = 0; // the tile counter in the perfect and miss steps

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  /// Lights [tiles] one after another, starting after [delay].
  /// Returns when the last one is lit.
  Duration _popIn(List<int> tiles, Duration delay) {
    for (var i = 0; i < tiles.length; i++) {
      after(delay + _stagger * i, () => setState(() => _lit = i + 1));
    }
    return delay + _stagger * (tiles.length - 1);
  }

  void _watch() {
    cancelTimers();
    _stopHint();
    setState(() {
      _step = _Step.watch;
      _shown = _pattern;
      _lit = 0;
      _faintRest = false;
      _found.clear();
      _wrong = null;
    });
    final lit = _popIn(_pattern, const Duration(milliseconds: 500));
    after(lit + MemoryMatrix.showFor, () {
      setState(() {
        _step = _Step.recall;
        _lit = 0;
      });
      _armHint();
    });
  }

  void _onTap(int cell) {
    if (_step != _Step.recall || _wrong != null || _found.contains(cell)) {
      return;
    }
    _stopHint();
    if (!_pattern.contains(cell)) {
      setState(() {
        _wrong = cell;
        _retry = true;
        _faintRest = true;
        _shakes++;
      });
      after(const Duration(milliseconds: 1300), _watch);
      return;
    }
    setState(() => _found.add(cell));
    if (_found.length < _pattern.length) {
      _armHint();
      return;
    }
    after(const Duration(milliseconds: 450), _perfect);
  }

  void _armHint() {
    _hintTimer?.cancel();
    _hintTimer = Timer(_hintAfter, () {
      if (mounted && _step == _Step.recall) setState(() => _hint = true);
    });
  }

  void _stopHint() {
    _hintTimer?.cancel();
    if (_hint) setState(() => _hint = false);
  }

  void _perfect() {
    setState(() {
      _step = _Step.perfect;
      _count = _pattern.length;
    });
    after(
      const Duration(milliseconds: 700),
      () => setState(() => _count = _pattern.length + 1),
    );
  }

  /// Plays a miss: two tiles found, then a wrong one.
  void _miss() {
    cancelTimers();
    setState(() {
      _step = _Step.miss;
      _shown = _missPattern;
      _lit = 0;
      _faintRest = false;
      _found.clear();
      _wrong = null;
      _count = _missPattern.length;
    });
    const step = Duration(milliseconds: 450);
    var t = const Duration(milliseconds: 500);
    for (final cell in _missPattern.take(2)) {
      after(t, () => setState(() => _found.add(cell)));
      t += step;
    }
    after(t, () {
      setState(() {
        _wrong = _missWrong;
        _faintRest = true;
        _shakes++;
      });
    });
    after(
      t + const Duration(milliseconds: 700),
      () => setState(() => _count = _missPattern.length - 1),
    );
  }

  void _ready() {
    cancelTimers();
    setState(() {
      _step = _Step.ready;
      _shown = _readyPattern;
      _lit = 0;
      _faintRest = false;
      _found.clear();
      _wrong = null;
    });
    _popIn(_readyPattern, const Duration(milliseconds: 300));
  }

  (String, String) get _text => switch (_step) {
    _Step.watch when _retry => (
      'Watch again',
      'Take your time. Remember where they are.',
    ),
    _Step.watch => (
      'Watch',
      'Tiles light up for a moment. Remember where they are.',
    ),
    _Step.recall when _wrong != null => (
      'Not that one',
      'One wrong tap ends the round. Let’s see them again.',
    ),
    _Step.recall => ('Your turn', 'Tap every tile that was lit.'),
    _Step.perfect => (
      'All correct',
      'Get them all and the next round adds a tile.',
    ),
    _Step.miss => (
      'One wrong tap',
      'A wrong tap ends the round, and the next one has a tile fewer.',
    ),
    _Step.ready => (
      'Ready?',
      '${MemoryMatrix.rounds} rounds, starting with '
          '${MemoryMatrix.startTiles} tiles.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (title, body) = _text;
    return TutorialFrame(
      step: switch (_step) {
        _Step.watch || _Step.recall => 0,
        _Step.perfect => 1,
        _Step.miss => 2,
        _Step.ready => 3,
      },
      steps: 4,
      color: c.memory,
      title: title,
      body: body,
      titleColor: _wrong != null && _step == _Step.recall ? c.declining : null,
      onSkip: widget.onDone,
      footer: _footer(),
      child: TutorialShake(
        trigger: _shakes,
        child: AspectRatio(
          aspectRatio: 1,
          child: GridView.count(
            crossAxisCount: MemoryMatrix.side,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            physics: const NeverScrollableScrollPhysics(),
            children: [for (var i = 0; i < MemoryMatrix.cells; i++) _tile(i)],
          ),
        ),
      ),
    );
  }

  Widget _tile(int i) {
    final c = context.colors;
    final index = _shown.indexOf(i);
    final inPattern = index >= 0;
    final lit = inPattern && index < _lit;
    final perfectGlow = _step == _Step.perfect && _pattern.contains(i);

    final Color color;
    if (i == _wrong) {
      color = c.declining;
    } else if (lit || _found.contains(i) || perfectGlow) {
      color = perfectGlow ? c.improving : c.memory;
    } else if (_faintRest && inPattern) {
      color = Color.alphaBlend(c.memory.withValues(alpha: 0.35), c.surface);
    } else {
      color = c.surface;
    }
    final up = lit || _found.contains(i) || perfectGlow || i == _wrong;

    return GestureDetector(
      key: ValueKey('tutorial-tile-$i'),
      onTap: () => _onTap(i),
      child: TutorialPulse(
        active: _hint && _pattern.contains(i) && !_found.contains(i),
        color: c.memory,
        child: AnimatedScale(
          scale: up ? 1 : 0.92,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _footer() {
    final c = context.colors;
    TutorialCount tiles(Color color) => TutorialCount(
      before: 'NEXT ROUND · ',
      count: _count,
      after: ' TILES',
      color: color,
    );
    return switch (_step) {
      _Step.watch => null,
      _Step.recall => Align(
        alignment: Alignment.topCenter,
        child: Text(
          '${_found.length} of ${_pattern.length}',
          style: AppText.mono12.copyWith(color: c.textSecondary),
        ),
      ),
      _Step.perfect => TutorialButton(
        label: 'Next',
        onPressed: _miss,
        above: tiles(c.improving),
      ),
      _Step.miss => TutorialButton(
        label: 'Next',
        onPressed: _ready,
        above: tiles(c.declining),
      ),
      _Step.ready => TutorialButton(label: 'Start', onPressed: widget.onDone),
    };
  }
}
