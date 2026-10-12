import 'package:flutter/material.dart';

/// Font families (bundled in assets/fonts) and the app's text styles.
/// Styles carry no color: they inherit textPrimary from the theme.
abstract final class AppText {
  static const sans = 'Zilla Slab';
  static const mono = 'Ubuntu Mono';

  static const display = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );
  static const screenTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
  );
  static const sectionTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );
  static const cardTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );
  static const listTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w500);
  static const body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
  static const button = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w400);

  static const mono12 = TextStyle(
    fontFamily: mono,
    fontSize: 13,
    letterSpacing: 0.3,
  );
  static const mono16 = TextStyle(
    fontFamily: mono,
    fontSize: 16,
    letterSpacing: 0.3,
  );
}
