import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';
import 'sudoku_models.dart';

/// A purple wave passing over some cells: a finished row, column, box or
/// digit, or the whole board when the puzzle is solved.
class SudokuSweep {
  SudokuSweep({
    required this.cells,
    required this.progress,
    required this.width,
  });

  /// The finished row, left to right.
  static Map<int, double> row(int row) => {
    for (var c = 0; c < 9; c++) row * 9 + c: c / 8,
  };

  /// The finished column, top to bottom.
  static Map<int, double> column(int col) => {
    for (var r = 0; r < 9; r++) r * 9 + col: r / 8,
  };

  /// The finished 3×3 box, from its top-left corner to its bottom-right.
  static Map<int, double> box(int cell) {
    final top = cell ~/ 27 * 3, left = cell % 9 ~/ 3 * 3;
    return {
      for (var r = 0; r < 3; r++)
        for (var c = 0; c < 3; c++) (top + r) * 9 + left + c: (r + c) / 4,
    };
  }

  /// The given cells (all nine of one digit, or the whole board), from the
  /// board's top-left corner to its bottom-right.
  static Map<int, double> diagonal(Iterable<int> cells) => {
    for (final i in cells) i: (i ~/ 9 + i % 9) / 16,
  };

  /// Cell index → when the wave reaches it, from 0 (first) to 1 (last).
  final Map<int, double> cells;

  /// Runs 0 → 1 over the wave's lifetime.
  final Animation<double> progress;

  /// Width of the wave, as a share of the distance it travels.
  final double width;

  /// How strongly the wave colors cell [i] right now, 0 to 1.
  double strengthAt(int i) {
    final at = cells[i];
    final t = progress.value;
    if (at == null || t <= 0 || t >= 1) return 0;
    final crest = t * (1 + 2 * width) - width;
    return (1 - (crest - at).abs() / width).clamp(0.0, 1.0);
  }
}

/// Draws the grid. Holds no game state: the screen owns it.
class SudokuBoard extends StatelessWidget {
  const SudokuBoard({
    super.key,
    required this.givens,
    required this.values,
    required this.solution,
    required this.notes,
    required this.selected,
    required this.onTap,
    this.sweeps = const [],
  });

  final List<int> givens;
  final List<int> values;
  final List<int> solution;
  final List<Set<int>> notes;
  final int? selected;
  final ValueChanged<int> onTap;

  /// Purple waves currently crossing the board.
  final List<SudokuSweep> sweeps;

  /// How strongly the waves color cell [i] right now, 0 to 1.
  double _wave(int i) {
    var strongest = 0.0;
    for (final sweep in sweeps) {
      final strength = sweep.strengthAt(i);
      if (strength > strongest) strongest = strength;
    }
    return strongest;
  }

  static const _thin = 1.0;
  static const _thick = 3.0;

  @override
  Widget build(BuildContext context) {
    if (sweeps.isEmpty) return _grid(context);
    return AnimatedBuilder(
      animation: Listenable.merge([for (final sweep in sweeps) sweep.progress]),
      builder: (context, _) => _grid(context),
    );
  }

  Widget _grid(BuildContext context) {
    final c = context.colors;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        // The gaps between cells show this color: the grid lines.
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var row = 0; row < 9; row++) ...[
              if (row > 0) SizedBox(height: row % 3 == 0 ? _thick : _thin),
              Expanded(
                child: Row(
                  children: [
                    for (var col = 0; col < 9; col++) ...[
                      if (col > 0)
                        SizedBox(width: col % 3 == 0 ? _thick : _thin),
                      Expanded(child: _cell(context, row * 9 + col)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, int i) {
    final c = context.colors;
    final value = values[i];
    final given = givens[i] != 0;
    final wrong = value != 0 && value != solution[i];
    final sel = selected;
    final isSelected = sel == i;
    final sameDigit = sel != null && value != 0 && values[sel] == value;
    final peer = sel != null && sudokuPeers(sel, i);
    final wave = _wave(i);

    // Checkerboard: cells alternate between two shades.
    final base = (i ~/ 9 + i % 9).isEven ? c.surface : c.elevated;
    Color tint(double alpha) =>
        Color.alphaBlend(c.brandAccent.withValues(alpha: alpha), base);

    final Color fill;
    if (isSelected) {
      fill = wrong ? base : c.brandFill;
    } else if (sameDigit) {
      fill = tint(0.42);
    } else if (peer) {
      fill = tint(0.14);
    } else {
      fill = base;
    }

    final Color ink;
    if (wrong) {
      ink = c.declining;
    } else if (isSelected) {
      ink = c.onBrand;
    } else {
      ink = given ? c.textPrimary : c.brandAccent;
    }

    return GestureDetector(
      key: ValueKey('cell-$i'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(i),
      child: Container(
        color: Color.lerp(fill, c.brandFill, wave),
        alignment: Alignment.center,
        child: value != 0
            ? FittedBox(
                child: Text(
                  '$value',
                  style: AppText.mono16.copyWith(
                    fontSize: 26,
                    letterSpacing: 0,
                    fontWeight: given ? FontWeight.w700 : FontWeight.w400,
                    color: Color.lerp(ink, c.onBrand, wave),
                  ),
                ),
              )
            : _notes(context, notes[i], isSelected),
      ),
    );
  }

  /// Pencil marks: a 3×3 mini grid, each digit in its own spot.
  Widget _notes(BuildContext context, Set<int> marks, bool onBrand) {
    if (marks.isEmpty) return const SizedBox.expand();
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Column(
        children: [
          for (var r = 0; r < 3; r++)
            Expanded(
              child: Row(
                children: [
                  for (var d = r * 3 + 1; d <= r * 3 + 3; d++)
                    Expanded(
                      child: FittedBox(
                        child: Text(
                          marks.contains(d) ? '$d' : ' ',
                          style: AppText.mono12.copyWith(
                            letterSpacing: 0,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: onBrand ? c.onBrand : c.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
