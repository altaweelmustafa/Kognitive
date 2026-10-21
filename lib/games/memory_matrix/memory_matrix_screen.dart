import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/progress.dart';
import '../../data/session.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/pill_button.dart';
import '../shared/session_game_views.dart';
import '../shared/tutorial_frame.dart';
import 'memory_matrix_logic.dart';
import 'memory_matrix_tutorial.dart';

enum _Phase { ready, showing, recall, feedback, done }

/// Memory Matrix: tiles light up on a 5×5 grid, then the player taps them
/// from memory. Eight rounds; a perfect round adds a tile, a miss removes one.
class MemoryMatrixScreen extends StatefulWidget {
  const MemoryMatrixScreen({super.key, this.random, this.api});

  /// For tests: fixes which tiles light up.
  final Random? random;
  final ApiClient? api;

  @override
  State<MemoryMatrixScreen> createState() => _MemoryMatrixScreenState();
}

class _MemoryMatrixScreenState extends State<MemoryMatrixScreen>
    with TutorialGate {
  @override
  String get tutorialId => 'memory-matrix';

  late final Random _random = widget.random ?? Random();
  late final ApiClient _api = widget.api ?? ApiClient();
  final _clock = Stopwatch();

  _Phase _phase = _Phase.ready;
  int _tiles = MemoryMatrix.startTiles;
  Set<int> _pattern = {};
  final _found = <int>{};
  int? _wrong;
  final _trials = <MatrixTrial>[];

  double? _score; // from the server, once saved
  String? _saveError;

  int get _round => _trials.length + 1;

  bool get _playedToday =>
      Progress.instance.plan?.lockedToday('memory-matrix') ?? false;

  Future<void> _startRound() async {
    setState(() {
      _pattern = MemoryMatrix.pattern(_random, _tiles);
      _found.clear();
      _wrong = null;
      _phase = _Phase.showing;
    });
    await Future<void>.delayed(MemoryMatrix.showFor);
    if (!mounted) return;
    setState(() => _phase = _Phase.recall);
    _clock
      ..reset()
      ..start();
  }

  void _onTap(int cell) {
    if (_phase != _Phase.recall || _found.contains(cell)) return;
    if (!_pattern.contains(cell)) {
      setState(() => _wrong = cell);
      _endRound();
    } else {
      setState(() => _found.add(cell));
      if (_found.length == _pattern.length) _endRound();
    }
  }

  Future<void> _endRound() async {
    _clock.stop();
    final trial = MatrixTrial(
      tiles: _tiles,
      found: _found.length,
      duration: _clock.elapsed,
    );
    setState(() => _phase = _Phase.feedback);
    await Future<void>.delayed(MemoryMatrix.feedbackFor);
    if (!mounted) return;
    _trials.add(trial);
    _tiles = MemoryMatrix.nextTiles(_tiles, perfect: trial.perfect);
    if (_trials.length < MemoryMatrix.rounds) {
      _startRound();
    } else {
      setState(() => _phase = _Phase.done);
      _save();
    }
  }

  Future<void> _save() async {
    setState(() => _saveError = null);
    try {
      final r = await _api.post('/games/memory-matrix/results', {
        'trials': [for (final t in _trials) t.toJson()],
      });
      if (!mounted) return;
      setState(() => _score = (r['score'] as num).toDouble());
      Session.instance.refreshActivity();
    } on ApiException catch (e) {
      if (mounted) setState(() => _saveError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Memory Matrix',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: switch (_phase) {
          // Already played today, and reached some other way than the Play button.
          _Phase.ready when _playedToday => const [
            PlayedTodayNotice(gameName: 'Memory Matrix'),
          ],
          _Phase.ready when showTutorial == null => const [],
          _Phase.ready when showTutorial! => [
            MemoryMatrixTutorial(onDone: () => finishTutorial(_startRound)),
          ],
          _Phase.ready => _intro(),
          _Phase.done => _summary(),
          _ => _play(),
        },
      ),
    );
  }

  List<Widget> _intro() {
    final c = context.colors;
    return [
      const SizedBox(height: 40),
      const Text(
        'Watch, then recall',
        style: AppText.screenTitle,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        'Tiles light up for a moment. When they go dark, tap every tile that was lit.\n\n'
        '${MemoryMatrix.rounds} rounds, starting with ${MemoryMatrix.startTiles} tiles. '
        'Get them all and the next round adds one. One wrong tap ends the round.',
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: 32),
      Center(
        child: PillButton(
          label: 'Start',
          width: 187,
          height: 42,
          onPressed: _startRound,
        ),
      ),
    ];
  }

  List<Widget> _play() {
    final c = context.colors;
    final perfect = _wrong == null && _found.length == _pattern.length;
    final (status, color) = switch (_phase) {
      _Phase.showing => ('Watch', c.textPrimary),
      _Phase.recall => ('Your turn', c.textPrimary),
      _ => perfect ? ('All correct', c.improving) : ('Missed', c.declining),
    };
    final meta = AppText.mono12.copyWith(color: c.textSecondary);

    return [
      Row(
        children: [
          Text('ROUND $_round OF ${MemoryMatrix.rounds}', style: meta),
          const Spacer(),
          Text(
            '${_pattern.length} TILES',
            style: meta.copyWith(color: c.memory),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(status, style: AppText.sectionTitle.copyWith(color: color)),
      const SizedBox(height: 24),
      AspectRatio(
        aspectRatio: 1,
        child: GridView.count(
          crossAxisCount: MemoryMatrix.side,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (var i = 0; i < MemoryMatrix.cells; i++) _tile(i)],
        ),
      ),
      const SizedBox(height: 20),
      if (_phase == _Phase.recall)
        Center(
          child: Text('${_found.length} of ${_pattern.length}', style: meta),
        ),
    ];
  }

  Widget _tile(int i) {
    final c = context.colors;
    final lit = _pattern.contains(i);
    final Color color;
    if (i == _wrong) {
      color = c.declining;
    } else if (_phase == _Phase.showing && lit || _found.contains(i)) {
      color = c.memory;
    } else if (_phase == _Phase.feedback && lit) {
      // The ones the player didn't get to.
      color = Color.alphaBlend(c.memory.withValues(alpha: 0.35), c.surface);
    } else {
      color = c.surface;
    }
    return GestureDetector(
      key: ValueKey('tile-$i'),
      onTap: () => _onTap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  List<Widget> _summary() {
    final perfect = _trials.where((t) => t.perfect).length;
    final most = _trials
        .where((t) => t.perfect)
        .fold(0, (best, t) => max(best, t.tiles));
    return [
      SessionScoreSummary(
        score: _score,
        color: context.colors.memory,
        stats: [
          ('Perfect rounds', '$perfect of ${MemoryMatrix.rounds}'),
          ('Most tiles', most == 0 ? '–' : '$most'),
        ],
        saveError: _saveError,
        onRetry: _save,
      ),
    ];
  }
}
