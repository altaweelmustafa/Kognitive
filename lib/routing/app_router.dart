import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../data/games.dart';
import '../data/session.dart';
import '../games/apothecary/apothecary_screen.dart';
import '../games/between_lines/lines_screen.dart';
import '../games/chess/chess_puzzle_screen.dart';
import '../games/math/quick_math_screen.dart';
import '../games/memory_matrix/memory_matrix_screen.dart';
import '../games/sudoku/sudoku_screen.dart';
import '../games/towers/towers_screen.dart';
import '../games/names/names_screen.dart';
import '../games/points/points_screen.dart';
import '../games/quiver/quiver_screen.dart';
import '../models/cognitive_domain.dart';
import '../screens/about/about_screen.dart';
import '../screens/brain/brain_screen.dart';
import '../screens/game_detail/game_detail_screen.dart';
import '../screens/games/domain_games_screen.dart';
import '../screens/games/games_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/library/article_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/reminder/reminder_screen.dart';
import '../screens/session/session_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/signup/signup_screen.dart';
import '../screens/start/start_screen.dart';
import '../widgets/app_shell.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: Routes.home,
  // Logged-out players only see the start, sign-up and log-in screens;
  // logged-in players never do. Re-checked whenever the session changes.
  refreshListenable: Session.instance,
  redirect: (_, state) {
    const open = [Routes.start, Routes.signup, Routes.login];
    final onOpenScreen = open.contains(state.matchedLocation);
    if (!Session.instance.loggedIn) return onOpenScreen ? null : Routes.start;
    return onOpenScreen ? Routes.home : null;
  },
  routes: [
    GoRoute(path: Routes.start, builder: (_, _) => const StartScreen()),
    GoRoute(path: Routes.signup, builder: (_, _) => const SignupScreen()),
    GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),

    // Tabs, in bottom-nav order.
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(shell: shell),
      branches: [
        _tab(Routes.home, const HomeScreen()),
        _tab(Routes.brain, const BrainScreen()),
        _tab(Routes.games, const GamesScreen()),
        _tab(Routes.library, const LibraryScreen()),
      ],
    ),

    // Pushed above the tab bar.
    GoRoute(
      path: Routes.chessPuzzles,
      builder: (_, _) => const ChessPuzzleScreen(),
    ),
    GoRoute(
      path: Routes.sudoku,
      builder: (_, s) => SudokuScreen(resume: s.uri.queryParameters['resume']),
    ),
    GoRoute(path: Routes.towers, builder: (_, _) => const TowersScreen()),
    GoRoute(path: Routes.points, builder: (_, _) => const PointsScreen()),
    GoRoute(path: Routes.names, builder: (_, _) => const NamesScreen()),
    GoRoute(
      path: Routes.apothecary,
      builder: (_, _) => const ApothecaryScreen(),
    ),
    GoRoute(path: Routes.quickMath, builder: (_, _) => const QuickMathScreen()),
    GoRoute(path: Routes.quiver, builder: (_, _) => const QuiverScreen()),
    GoRoute(
      path: Routes.betweenTheLines,
      builder: (_, _) => const LinesScreen(),
    ),
    GoRoute(
      path: Routes.memoryMatrix,
      builder: (_, _) => const MemoryMatrixScreen(),
    ),
    GoRoute(path: Routes.session, builder: (_, _) => const SessionScreen()),
    GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
    GoRoute(path: Routes.about, builder: (_, _) => const AboutScreen()),
    GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
    GoRoute(path: Routes.reminder, builder: (_, _) => const ReminderScreen()),
    GoRoute(
      path: '/game/:id',
      builder: (_, s) =>
          GameDetailScreen(game: gameById(s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/domain/:name',
      builder: (_, s) => DomainGamesScreen(
        domain: CognitiveDomain.values.byName(s.pathParameters['name']!),
      ),
    ),
    GoRoute(
      path: '/article/:id',
      builder: (_, s) => ArticleScreen(id: s.pathParameters['id']!),
    ),
  ],
);

StatefulShellBranch _tab(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => screen)],
);
