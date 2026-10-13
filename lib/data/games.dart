import 'package:flutter/material.dart';

import '../models/cognitive_domain.dart';
import '../models/game.dart';

/// The full catalog: 5 domains, 12 games. Described in GAMES.md.
const games = <Game>[
  Game(
    id: 'memory-matrix',
    name: 'Memory Matrix',
    domain: CognitiveDomain.memory,
    icon: Icons.grid_on_rounded,
    tagline: 'Remember which tiles lit up, then rebuild the pattern.',
    image: 'assets/game_icons/Memory_Matrix.png',
  ),
  Game(
    id: 'suit-recall',
    name: 'Suit Recall',
    domain: CognitiveDomain.memory,
    icon: Icons.style_outlined,
    tagline: 'Hold a growing run of card suits in mind.',
  ),
  Game(
    id: 'whats-my-name',
    name: "What's My Name?",
    domain: CognitiveDomain.memory,
    icon: Icons.badge_outlined,
    tagline: 'Match names to the faces you just met.',
    image: 'assets/game_icons/Whats_My_Name.png',
  ),
  Game(
    id: 'odd-one-out',
    name: 'Odd One Out',
    domain: CognitiveDomain.attention,
    icon: Icons.filter_center_focus_rounded,
    tagline: 'Spot the card that breaks the pattern.',
  ),
  Game(
    id: 'points-of-thought',
    name: 'Points of Thought',
    domain: CognitiveDomain.attention,
    icon: Icons.call_split_rounded,
    tagline: 'Set the toggles to send every point home.',
    image: 'assets/game_icons/Points_of_Thought.png',
  ),
  Game(
    id: 'sudoku',
    name: 'Sudoku',
    domain: CognitiveDomain.reasoning,
    icon: Icons.apps_rounded,
    tagline: 'Fill the grid so every row, column and box holds 1 to 9.',
    inSessions: false,
    image: 'assets/game_icons/Sudoku.png',
  ),
  Game(
    id: '24-game',
    name: '24 Game',
    domain: CognitiveDomain.reasoning,
    icon: Icons.calculate_outlined,
    tagline: 'Combine four cards to make exactly 24.',
  ),
  Game(
    id: 'apothecary',
    name: 'Apothecary',
    domain: CognitiveDomain.planning,
    icon: Icons.science_outlined,
    tagline: 'Decant the tinctures until every bottle holds one colour.',
    image: 'assets/game_icons/Magic_Sort.png',
  ),
  Game(
    id: 'chess-puzzles',
    name: 'Chess Puzzles',
    domain: CognitiveDomain.planning,
    icon: Icons.extension_outlined,
    tagline: 'Find the winning line in puzzles from Lichess.',
    inSessions: false,
    image: 'assets/game_icons/chess.png',
  ),
  Game(
    id: 'towers-of-stockholm',
    name: 'Towers of Stockholm',
    domain: CognitiveDomain.flexibility,
    icon: Icons.swap_horiz_rounded,
    tagline: 'Rebuild the towers while the rules keep changing.',
    image: 'assets/game_icons/Towers_of_Stockholm.png',
  ),
  Game(
    id: 'suit-sort',
    name: 'Suit Sort',
    domain: CognitiveDomain.flexibility,
    icon: Icons.dashboard_customize_outlined,
    tagline: 'Sort cards by a hidden rule that changes without warning.',
  ),
  Game(
    id: 'quick-math',
    name: 'Quick Math',
    domain: CognitiveDomain.reasoning,
    icon: Icons.bolt_rounded,
    tagline: 'Sixty seconds. As many sums as you can.',
    inSessions: false,
    image: 'assets/game_icons/Quick_Math.png',
  ),
];

Game gameById(String id) => games.firstWhere((g) => g.id == id);

List<Game> gamesIn(CognitiveDomain domain) =>
    games.where((g) => g.domain == domain).toList();

/// Outside the daily session, playable every day.
final moreGames = games.where((g) => !g.inSessions).toList();
