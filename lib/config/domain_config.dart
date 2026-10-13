import 'package:flutter/material.dart';

import '../models/cognitive_domain.dart';
import 'color_config.dart';

/// Domain → label / color / icon mapping.
extension CognitiveDomainConfig on CognitiveDomain {
  String get label => switch (this) {
    CognitiveDomain.memory => 'Memory',
    CognitiveDomain.attention => 'Attention',
    CognitiveDomain.reasoning => 'Reasoning',
    CognitiveDomain.planning => 'Planning',
    CognitiveDomain.flexibility => 'Flexibility',
  };

  String get fullLabel => switch (this) {
    CognitiveDomain.reasoning => 'Reasoning & Logic',
    _ => label,
  };

  Color color(AppColors c) => switch (this) {
    CognitiveDomain.memory => c.memory,
    CognitiveDomain.attention => c.attention,
    CognitiveDomain.reasoning => c.reasoning,
    CognitiveDomain.planning => c.planning,
    CognitiveDomain.flexibility => c.flexibility,
  };

  /// Wide backdrop the domain's game icons stand on.
  String get banner => 'assets/game_banners/$name.png';

  IconData get icon => switch (this) {
    CognitiveDomain.memory => Icons.grid_view_rounded,
    CognitiveDomain.attention => Icons.center_focus_strong_outlined,
    CognitiveDomain.reasoning => Icons.calculate_outlined,
    CognitiveDomain.planning => Icons.route_outlined,
    CognitiveDomain.flexibility => Icons.swap_horiz_rounded,
  };

  /// Memory and Attention are in every session; the rest are ARIMA picks.
  bool get alwaysInSession =>
      this == CognitiveDomain.memory || this == CognitiveDomain.attention;
}
