import 'package:flutter/widgets.dart';

import 'cognitive_domain.dart';

class Game {
  const Game({
    required this.id,
    required this.name,
    required this.domain,
    required this.icon,
    required this.tagline,
    this.inSessions = true,
    this.image,
  });

  final String id;
  final String name;
  final CognitiveDomain domain;
  final IconData icon;
  final String tagline;

  /// False for games that are never part of the daily session but can be
  /// played on their own every day.
  final bool inSessions;

  /// Asset path of the game's own icon. Falls back to [icon] when null.
  final String? image;
}
