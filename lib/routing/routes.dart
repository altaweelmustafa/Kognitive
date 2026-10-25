/// Route paths. Use these instead of string literals.
abstract final class Routes {
  static const start = '/start';
  static const signup = '/signup';
  static const login = '/login';

  static const home = '/home';
  static const brain = '/brain';
  static const games = '/games';
  static const library = '/library';

  static const session = '/session';
  static const settings = '/settings';
  static const about = '/about';

  static const chessPuzzles = '/play/chess-puzzles';
  static const sudoku = '/play/sudoku';
  static const memoryMatrix = '/play/memory-matrix';
  static const towers = '/play/towers-of-stockholm';
  static const points = '/play/points-of-thought';
  static const quickMath = '/play/quick-math';
  static const apothecary = '/play/apothecary';
  static const names = '/play/whats-my-name';
  static const quiver = '/play/quiver';
  static const betweenTheLines = '/play/between-the-lines';

  /// Where a game is played, or null if it isn't built yet.
  static String? play(String gameId) => switch (gameId) {
    'chess-puzzles' => chessPuzzles,
    'sudoku' => sudoku,
    'memory-matrix' => memoryMatrix,
    'towers-of-stockholm' => towers,
    'points-of-thought' => points,
    'quick-math' => quickMath,
    'apothecary' => apothecary,
    'whats-my-name' => names,
    'quiver' => quiver,
    'between-the-lines' => betweenTheLines,
    _ => null,
  };

  /// Sudoku, opened straight on an unfinished game.
  static String sudokuResume(String puzzleId) => '$sudoku?resume=$puzzleId';

  static String game(String id) => '/game/$id';
  static String domain(String name) => '/domain/$name';
  static String article(String id) => '/article/$id';
}
