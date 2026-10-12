import 'package:flutter/material.dart';

/// Single source of truth for every color in the app.
/// Change a hex here and it changes everywhere. Source: palette.md.
///
/// Read colors in widgets with `context.colors.<role>`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.elevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brandAccent,
    required this.brandFill,
    required this.onBrand,
    required this.onAccent,
    required this.divider,
    required this.memory,
    required this.attention,
    required this.reasoning,
    required this.planning,
    required this.flexibility,
    required this.improving,
    required this.declining,
    required this.libraryFoods,
    required this.libraryToDo,
    required this.libraryToAvoid,
    required this.libraryBestPractices,
    required this.chessLight,
    required this.chessDark,
    required this.chessHighlightLight,
    required this.chessHighlightDark,
    required this.chessPiece,
    required this.liquidCyan,
  });

  // ── Core UI ──────────────────────────────────────────────
  final Color background; // app canvas
  final Color surface; // cards, tiles, inputs
  final Color elevated; // modals, sheets, chips, bar tracks
  final Color textPrimary; // headlines, scores
  final Color textSecondary; // labels, meta
  final Color textMuted; // placeholders, disabled
  final Color brandAccent; // icons, rings, active nav, chart strokes
  final Color brandFill; // button backgrounds
  final Color onBrand; // text on brandFill
  final Color onAccent; // text on domain / library color fills
  final Color divider;

  // ── Domain accents ───────────────────────────────────────
  final Color memory;
  final Color attention;
  final Color reasoning;
  final Color planning;
  final Color flexibility;

  // ── Trend scale (plateau uses textSecondary) ─────────────
  final Color improving;
  final Color declining;

  // ── Library categories ───────────────────────────────────
  final Color libraryFoods;
  final Color libraryToDo;
  final Color libraryToAvoid;
  final Color libraryBestPractices;

  // ── Chess board (from the Chess Simple Assets kit) ───────
  final Color chessLight; // light squares
  final Color chessDark; // dark squares
  final Color chessHighlightLight; // selected / last move / dot, on light
  final Color chessHighlightDark; // selected / last move / dot, on dark
  final Color chessPiece; // dark piece ink, used for labels on the board

  // ── Apothecary ───────────────────────────────────────────
  final Color liquidCyan; // the one liquid colour not already in the palette

  /// The eight liquids, in the order puzzles use them.
  List<Color> get liquids => [
    memory,
    planning,
    attention,
    flexibility,
    reasoning,
    brandAccent,
    declining,
    liquidCyan,
  ];

  static const dark = AppColors(
    background: Color(0xFF12151A),
    surface: Color(0xFF1A1F27),
    elevated: Color(0xFF232933),
    textPrimary: Color(0xFFEDEFF3),
    textSecondary: Color(0xFF9AA3B2),
    textMuted: Color(0xFF6B7280),
    brandAccent: Color(0xFF8A5CF0),
    brandFill: Color(0xFF6D3FD1),
    onBrand: Color(0xFFFFFFFF),
    onAccent: Color(0xFF12151A),
    divider: Color(0xFF232933),
    memory: Color(0xFFCC6A2E),
    attention: Color(0xFFE6C200),
    reasoning: Color(0xFF2F9B78),
    planning: Color(0xFF5B8DEF),
    flexibility: Color(0xFFCF5F82),
    improving: Color(0xFF0CA30C),
    declining: Color(0xFFD03B3B),
    libraryFoods: Color(0xFF2F9B78),
    libraryToDo: Color(0xFF5B8DEF),
    libraryToAvoid: Color(0xFFCF5F82),
    libraryBestPractices: Color(0xFFE6C200),
    chessLight: Color(0xFFE8EDF9),
    chessDark: Color(0xFFB7C0D8),
    chessHighlightLight: Color(0xFFB1A6FC),
    chessHighlightDark: Color(0xFF9890EC),
    chessPiece: Color(0xFF34364C),
    liquidCyan: Color(0xFF4FC3D9),
  );

  static const light = AppColors(
    background: Color(0xFFF7F5F2),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFFBFAF8),
    textPrimary: Color(0xFF15181D),
    textSecondary: Color(0xFF52586A),
    textMuted: Color(0xFF898781),
    brandAccent: Color(0xFF6D3FD1),
    brandFill: Color(0xFF6D3FD1),
    onBrand: Color(0xFFFFFFFF),
    onAccent: Color(0xFF15181D),
    divider: Color(0xFFE7E4DF),
    memory: Color(0xFFA8501E),
    attention: Color(0xFFFFDF00),
    reasoning: Color(0xFF1B8A63),
    planning: Color(0xFF3B6FD1),
    flexibility: Color(0xFFB8476A),
    improving: Color(0xFF0CA30C),
    declining: Color(0xFFD03B3B),
    libraryFoods: Color(0xFF1B8A63),
    libraryToDo: Color(0xFF3B6FD1),
    libraryToAvoid: Color(0xFFB8476A),
    libraryBestPractices: Color(0xFFFFDF00),
    chessLight: Color(0xFFE8EDF9),
    chessDark: Color(0xFFB7C0D8),
    chessHighlightLight: Color(0xFFB1A6FC),
    chessHighlightDark: Color(0xFF9890EC),
    chessPiece: Color(0xFF34364C),
    liquidCyan: Color(0xFF4FC3D9),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
