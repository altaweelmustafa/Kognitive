import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/progress.dart';
import '../../data/session.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/pill_button.dart';
import 'sudoku_api.dart';
import 'sudoku_board.dart';
import 'sudoku_models.dart';

/// Sudoku: a daily puzzle, then as many more as you like at any difficulty.
/// Wrong digits are marked as soon as they are entered. An unfinished game is
/// saved to the player's account and can be continued later, on any device.
class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key, this.api, this.resume});

  final SudokuApi? api;

  /// Id of an unfinished puzzle to open straight away, skipping the picker.
  final String? resume;

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

/// Board contents at one point in time, for undo.
typedef _Snapshot = ({List<int> values, List<Set<int>> notes});

class _SudokuScreenState extends State<SudokuScreen>
    with TickerProviderStateMixin {
  late final SudokuApi _api = widget.api ?? SudokuApi();
  final _clock = Stopwatch();
  final _focus = FocusNode();
  Timer? _ticker;

  /// Purple waves crossing the board right now.
  final _sweeps = <SudokuSweep>[];
  final _sweepControllers = <AnimationController>[];

  /// Rows, columns, boxes and digits finished by the move just made.
  final _justFinished = <Map<int, double>>[];

  SudokuPuzzle? _puzzle;
  bool _loading = false;

  /// What was last asked for, for Retry.
  Future<SudokuPuzzle> Function()? _lastFetch;

  /// Unfinished games, shown on the picker.
  List<SudokuSaveSummary> _saves = [];
  Timer? _saveTimer;

  /// Time already played before this visit, when continuing a saved game.
  Duration _played = Duration.zero;
  String? _error;

  List<int> _values = [];
  List<Set<int>> _notes = [];
  final _undo = <_Snapshot>[];
  int? _selected;
  bool _noteMode = false;
  bool _solved = false;
  int _mistakes = 0;
  int _hints = 0;
  SudokuDifficulty _nextDifficulty = SudokuDifficulty.medium;

  @override
  void initState() {
    super.initState();
    _loadSaves();
    if (widget.resume case final id?) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _open(() => _api.puzzle(id)),
      );
    }
    // Redraws the clock.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_clock.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final controller in _sweepControllers) {
      controller.dispose();
    }
    _saveTimer?.cancel();
    _saveNow();
    _focus.dispose();
    super.dispose();
  }

  /// Loads the daily puzzle, or a new one at [difficulty].
  Future<void> _load(SudokuDifficulty? difficulty) =>
      _open(() => difficulty == null ? _api.daily() : _api.next(difficulty));

  Future<void> _open(Future<SudokuPuzzle> Function() fetch) async {
    setState(() {
      _lastFetch = fetch;
      _loading = true;
      _error = null;
    });
    try {
      final puzzle = await fetch();
      if (!mounted) return;
      setState(() {
        _puzzle = puzzle;
        // Pick up where the player left off, if they did.
        final save = puzzle.save;
        _values = [...(save?.cells ?? puzzle.givens)];
        _notes = [
          for (var i = 0; i < 81; i++) {...?save?.notes[i]},
        ];
        _played = save?.elapsed ?? Duration.zero;
        _undo.clear();
        _selected = null;
        _noteMode = false;
        _solved = false;
        _mistakes = save?.mistakes ?? 0;
        _hints = save?.hints ?? 0;
        _nextDifficulty = puzzle.difficulty;
        _loading = false;
      });
      _clock
        ..reset()
        ..start();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Duration get _elapsed => _played + _clock.elapsed;

  Future<void> _loadSaves() async {
    try {
      final saves = await _api.saves();
      if (mounted) setState(() => _saves = saves);
    } on ApiException {
      // The picker simply shows no games to continue.
    }
  }

  /// Saves shortly after the last change, so a burst of moves is one request.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _saveNow);
  }

  /// Best effort: a failed save shouldn't interrupt the player.
  Future<void> _saveNow() async {
    _saveTimer?.cancel();
    final puzzle = _puzzle;
    if (puzzle == null || _solved) return;
    final untouched =
        _notes.every((n) => n.isEmpty) &&
        [
          for (var i = 0; i < 81; i++) _values[i] == puzzle.givens[i],
        ].every((same) => same);
    if (untouched) return;
    try {
      await _api.save(
        puzzle.id,
        SudokuSave(
          cells: _values,
          notes: _notes,
          elapsed: _elapsed,
          mistakes: _mistakes,
          hints: _hints,
        ),
      );
    } on ApiException {
      // Tried.
    }
    // Home lists unfinished games.
    Progress.instance.refresh();
  }

  /// Givens and correct entries can't be changed.
  bool _locked(int i) => _values[i] == _puzzle!.solution[i];

  /// Call before every change to the board.
  void _remember() {
    _undo.add((
      values: [..._values],
      notes: [
        for (final n in _notes) {...n},
      ],
    ));
    _scheduleSave();
  }

  void _enter(int digit) {
    final i = _selected;
    if (i == null || _solved || _locked(i)) return;
    setState(() {
      _remember();
      if (_noteMode) {
        _values[i] = 0;
        if (!_notes[i].remove(digit)) _notes[i].add(digit);
        return;
      }
      _place(i, digit);
      if (digit != _puzzle!.solution[i]) _mistakes++;
    });
    _checkSolved();
  }

  void _place(int i, int digit) {
    _values[i] = digit;
    _notes[i].clear();
    if (digit != _puzzle!.solution[i]) return;
    // The digit is settled: it can't be a candidate in its row, column or box.
    for (var j = 0; j < 81; j++) {
      if (sudokuPeers(i, j)) _notes[j].remove(digit);
    }

    // Did this digit finish its row, column, box, or the digit itself?
    bool done(Iterable<int> cells) => cells.every(_locked);
    final row = SudokuSweep.row(i ~/ 9);
    final column = SudokuSweep.column(i % 9);
    final box = SudokuSweep.box(i);
    final sameDigit = [
      for (var j = 0; j < 81; j++)
        if (_puzzle!.solution[j] == digit) j,
    ];
    _justFinished.addAll([
      if (done(row.keys)) row,
      if (done(column.keys)) column,
      if (done(box.keys)) box,
      if (done(sameDigit)) SudokuSweep.diagonal(sameDigit),
    ]);
  }

  /// Sends a purple wave over [cells].
  void _sweep(
    Map<int, double> cells, {
    required Duration duration,
    required double width,
  }) {
    final controller = AnimationController(vsync: this, duration: duration);
    final sweep = SudokuSweep(cells: cells, progress: controller, width: width);
    setState(() {
      _sweepControllers.add(controller);
      _sweeps.add(sweep);
    });
    controller.forward().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _sweeps.remove(sweep);
        _sweepControllers.remove(controller);
      });
      controller.dispose();
    });
  }

  void _erase() {
    final i = _selected;
    if (i == null || _solved || _locked(i)) return;
    if (_values[i] == 0 && _notes[i].isEmpty) return;
    setState(() {
      _remember();
      _values[i] = 0;
      _notes[i].clear();
    });
  }

  void _undoLast() {
    if (_undo.isEmpty || _solved) return;
    setState(() {
      final last = _undo.removeLast();
      _scheduleSave();
      _values = last.values;
      _notes = last.notes;
    });
  }

  /// Fills the selected cell, or a random open one if none is selected.
  void _hint() {
    if (_solved) return;
    var i = _selected;
    if (i == null || _locked(i)) {
      final open = [
        for (var j = 0; j < 81; j++)
          if (!_locked(j)) j,
      ];
      if (open.isEmpty) return;
      i = open[Random().nextInt(open.length)];
    }
    final cell = i;
    setState(() {
      _remember();
      _hints++;
      _selected = cell;
      _place(cell, _puzzle!.solution[cell]);
    });
    _checkSolved();
  }

  void _checkSolved() {
    final puzzle = _puzzle!;
    for (var i = 0; i < 81; i++) {
      if (_values[i] != puzzle.solution[i]) {
        // Not solved yet: celebrate whatever this move finished.
        for (final cells in _justFinished) {
          _sweep(
            cells,
            duration: const Duration(milliseconds: 800),
            width: 0.45,
          );
        }
        _justFinished.clear();
        return;
      }
    }
    // Solved: one wave over the whole board instead.
    _justFinished.clear();
    _sweep(
      SudokuSweep.diagonal(List.generate(81, (i) => i)),
      duration: const Duration(milliseconds: 1400),
      width: 0.3,
    );
    _clock.stop();
    _saveTimer?.cancel();
    setState(() {
      _solved = true;
      _selected = null;
    });
    // Best effort: a lost stat shouldn't interrupt the player.
    _api
        .recordAttempt(
          puzzle.id,
          solved: true,
          mistakes: _mistakes,
          hints: _hints,
          duration: _elapsed,
        )
        .then((_) => Session.instance.refreshActivity())
        .catchError((_) {});
  }

  int _placed(int digit) {
    var n = 0;
    for (var i = 0; i < 81; i++) {
      if (_values[i] == digit && _locked(i)) n++;
    }
    return n;
  }

  /// Keyboard play on desktop: digits, arrows, backspace, N for notes.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _puzzle == null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final digit = int.tryParse(event.character ?? '');
    if (digit != null && digit > 0) {
      _enter(digit);
    } else if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _erase();
    } else if (key == LogicalKeyboardKey.keyN) {
      setState(() => _noteMode = !_noteMode);
    } else if (_arrows[key] case final step?) {
      final i = _selected ?? 40;
      final row = (i ~/ 9 + step.$1).clamp(0, 8);
      final col = (i % 9 + step.$2).clamp(0, 8);
      setState(() => _selected = row * 9 + col);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static final _arrows = {
    LogicalKeyboardKey.arrowUp: (-1, 0),
    LogicalKeyboardKey.arrowDown: (1, 0),
    LogicalKeyboardKey.arrowLeft: (0, -1),
    LogicalKeyboardKey.arrowRight: (0, 1),
  };

  String get _time => _clockText(_elapsed);

  static String _clockText(Duration t) =>
      '${t.inMinutes}:${(t.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final puzzle = _puzzle;
    return DetailScaffold(
      title: 'Sudoku',
      // Back from a puzzle returns to the picker.
      onBack: puzzle == null && !_loading && _error == null ? null : _toPicker,
      child: _loading || _error != null
          ? _loadingOrError()
          : puzzle == null
          ? _picker()
          : Focus(
              focusNode: _focus,
              autofocus: true,
              onKeyEvent: _onKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
                children: [
                  _header(puzzle),
                  const SizedBox(height: 20),
                  SudokuBoard(
                    givens: puzzle.givens,
                    values: _values,
                    solution: puzzle.solution,
                    notes: _notes,
                    selected: _selected,
                    sweeps: _sweeps,
                    onTap: (i) {
                      _focus.requestFocus();
                      if (!_solved) setState(() => _selected = i);
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_solved)
                    _summary()
                  else ...[
                    _actions(),
                    const SizedBox(height: 16),
                    _pad(),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _toPicker() async {
    _clock.stop();
    final saving = _saveNow();
    setState(() {
      _puzzle = null;
      _loading = false;
      _error = null;
    });
    await saving;
    await _loadSaves();
  }

  /// First screen: the daily puzzle, or a practice puzzle at any difficulty.
  Widget _picker() {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(27, 20, 27, 24),
      children: [
        const Text('Choose a puzzle', style: AppText.screenTitle),
        const SizedBox(height: 20),
        if (_saves.isNotEmpty) ...[
          Text(
            'CONTINUE',
            style: AppText.mono12.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final save in _saves)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _choice(
                key: 'continue-${save.puzzleId}',
                title: save.daily
                    ? 'Daily puzzle'
                    : '${save.difficulty.label} puzzle',
                subtitle:
                    '${_clockText(save.elapsed)} played · ${save.filled} of 81 filled',
                icon: Icons.play_circle_outline,
                color: c.brandAccent,
                onTap: () => _open(() => _api.puzzle(save.puzzleId)),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            'NEW',
            style: AppText.mono12.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
        ],
        _choice(
          key: 'daily',
          title: 'Daily puzzle',
          subtitle: 'Medium. A new one every day.',
          icon: Icons.today_outlined,
          color: c.brandAccent,
          onTap: () => _load(null),
        ),
        const SizedBox(height: 24),
        Text(
          'PRACTICE',
          style: AppText.mono12.copyWith(
            color: c.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (final (d, subtitle, bars) in [
          (SudokuDifficulty.easy, 'Plenty of clues. A warm-up.', 1),
          (SudokuDifficulty.medium, 'A steady challenge.', 2),
          (SudokuDifficulty.hard, 'Few clues. Take your time.', 3),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _choice(
              key: d.name,
              title: d.label,
              subtitle: subtitle,
              bars: bars,
              color: c.reasoning,
              onTap: () => _load(d),
            ),
          ),
      ],
    );
  }

  Widget _choice({
    required String key,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
    int bars = 0,
  }) {
    final c = context.colors;
    return GestureDetector(
      key: ValueKey('choose-$key'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: icon != null
                  ? Icon(icon, size: 28, color: color)
                  // Difficulty meter: three bars, filled up to the level.
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 1; i <= 3; i++)
                          Container(
                            width: 7,
                            height: 8.0 + i * 7,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: i <= bars ? color : c.elevated,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.cardTitle),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppText.label.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _loadingOrError() {
    final c = context.colors;
    final error = _error;
    if (error == null) {
      return Center(child: CircularProgressIndicator(color: c.brandAccent));
    }
    return Padding(
      padding: const EdgeInsets.all(27),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(error, textAlign: TextAlign.center, style: AppText.listTitle),
          const SizedBox(height: 8),
          Text(
            'Check that the backend is running, then try again.',
            textAlign: TextAlign.center,
            style: AppText.label.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 24),
          PillButton(
            label: 'Retry',
            width: 140,
            height: 42,
            onPressed: () => _open(_lastFetch!),
          ),
        ],
      ),
    );
  }

  Widget _header(SudokuPuzzle puzzle) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                puzzle.isDaily ? 'DAILY PUZZLE' : 'PRACTICE PUZZLE',
                style: AppText.mono12.copyWith(
                  color: c.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _solved ? 'Solved' : puzzle.difficulty.label,
                style: AppText.sectionTitle.copyWith(
                  color: _solved ? c.improving : c.brandAccent,
                ),
              ),
            ],
          ),
          const Spacer(),
          Icon(Icons.timer_outlined, size: 16, color: c.textSecondary),
          const SizedBox(width: 4),
          Text(_time, style: AppText.mono16.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        _action(Icons.undo_rounded, 'Undo', _undo.isEmpty ? null : _undoLast),
        _action(Icons.backspace_outlined, 'Erase', _erase),
        _action(
          Icons.edit_outlined,
          'Notes',
          () => setState(() => _noteMode = !_noteMode),
          active: _noteMode,
        ),
        _action(Icons.lightbulb_outline, 'Hint', _hint),
      ],
    );
  }

  Widget _action(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool active = false,
  }) {
    final c = context.colors;
    final color = onTap == null
        ? c.textMuted
        : (active ? c.brandAccent : c.textPrimary);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active ? c.brandFill.withValues(alpha: 0.25) : c.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppText.caption.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  /// Digits 1-9. A digit greys out once all nine are placed.
  Widget _pad() {
    final c = context.colors;
    return Row(
      children: [
        for (var d = 1; d <= 9; d++) ...[
          if (d > 1) const SizedBox(width: 6),
          Expanded(
            child: Builder(
              builder: (context) {
                final done = _placed(d) == 9;
                return GestureDetector(
                  key: ValueKey('digit-$d'),
                  onTap: done ? null : () => _enter(d),
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$d',
                      style: AppText.mono16.copyWith(
                        fontSize: 26,
                        letterSpacing: 0,
                        color: done
                            ? c.elevated
                            : (_noteMode ? c.textSecondary : c.brandAccent),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _summary() {
    final c = context.colors;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_stat('Time', _time), _stat('Hints', '$_hints')],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final d in SudokuDifficulty.values)
              GestureDetector(
                onTap: () => setState(() => _nextDifficulty = d),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.elevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: d == _nextDifficulty ? c.brandAccent : c.elevated,
                    ),
                  ),
                  child: Text(
                    d.label,
                    style: AppText.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: d == _nextDifficulty
                          ? c.textPrimary
                          : c.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        PillButton(
          label: 'Next puzzle',
          width: 187,
          height: 42,
          onPressed: () => _load(_nextDifficulty),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    final c = context.colors;
    return Column(
      children: [
        Text(
          value,
          style: AppText.mono16.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppText.caption.copyWith(color: c.textMuted)),
      ],
    );
  }
}
