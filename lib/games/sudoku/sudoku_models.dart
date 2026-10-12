enum SudokuDifficulty {
  easy('Easy'),
  medium('Medium'),
  hard('Hard');

  const SudokuDifficulty(this.label);
  final String label;
}

/// A game left unfinished, as stored on the server.
class SudokuSave {
  SudokuSave({
    required this.cells,
    required this.notes,
    required this.elapsed,
    required this.mistakes,
    required this.hints,
  });

  factory SudokuSave.fromJson(Map<String, dynamic> j) => SudokuSave(
    cells: SudokuPuzzle._digits(j['cells'] as String),
    notes: [
      for (final mask in (j['notes'] as List).cast<int>())
        {
          for (var d = 1; d <= 9; d++)
            if (mask >> (d - 1) & 1 == 1) d,
        },
    ],
    elapsed: Duration(milliseconds: j['elapsed_ms'] as int),
    mistakes: j['mistakes'] as int,
    hints: j['hints'] as int,
  );

  final List<int> cells;
  final List<Set<int>> notes;
  final Duration elapsed;
  final int mistakes;
  final int hints;

  /// Notes travel as one bitmask per cell: bit d-1 set means digit d is noted.
  Map<String, dynamic> toJson() => {
    'cells': cells.join(),
    'notes': [
      for (final marks in notes)
        marks.fold<int>(0, (mask, d) => mask | 1 << (d - 1)),
    ],
    'elapsed_ms': elapsed.inMilliseconds,
    'mistakes': mistakes,
    'hints': hints,
  };
}

/// One line in the "Continue" list.
class SudokuSaveSummary {
  SudokuSaveSummary.fromJson(Map<String, dynamic> j)
    : puzzleId = j['puzzle_id'] as String,
      difficulty = SudokuDifficulty.values.byName(j['difficulty'] as String),
      daily = j['daily'] as bool,
      elapsed = Duration(milliseconds: j['elapsed_ms'] as int),
      filled = j['filled'] as int;

  final String puzzleId;
  final SudokuDifficulty difficulty;
  final bool daily;
  final Duration elapsed;
  final int filled; // cells with a digit, out of 81
}

class SudokuPuzzle {
  SudokuPuzzle({
    required this.id,
    required this.difficulty,
    required this.givens,
    required this.solution,
    this.save,
  });

  factory SudokuPuzzle.fromJson(Map<String, dynamic> j) => SudokuPuzzle(
    id: j['id'] as String,
    difficulty: SudokuDifficulty.values.byName(j['difficulty'] as String),
    givens: _digits(j['puzzle'] as String),
    solution: _digits(j['solution'] as String),
    save: j['save'] == null
        ? null
        : SudokuSave.fromJson(j['save'] as Map<String, dynamic>),
  );

  final String id;
  final SudokuDifficulty difficulty;

  /// 81 cells, row by row. 0 is an empty cell.
  final List<int> givens;
  final List<int> solution;

  /// The player's unfinished game on this puzzle, if they left one.
  final SudokuSave? save;

  bool get isDaily => id.startsWith('daily-');

  static List<int> _digits(String s) => [
    for (final ch in s.split('')) int.parse(ch),
  ];
}

/// Whether two cells share a row, column or box.
bool sudokuPeers(int a, int b) =>
    a ~/ 9 == b ~/ 9 ||
    a % 9 == b % 9 ||
    (a ~/ 27 == b ~/ 27 && (a % 9) ~/ 3 == (b % 9) ~/ 3);
