import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/color_config.dart';
import '../../config/domain_config.dart';
import '../../data/games.dart';
import '../../models/cognitive_domain.dart';
import '../../routing/routes.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/game_art.dart';

/// Every game in one domain.
class DomainGamesScreen extends StatelessWidget {
  const DomainGamesScreen({super.key, required this.domain});

  final CognitiveDomain domain;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DetailScaffold(
      title: domain.fullLabel,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(27, 12, 27, 24),
        children: [
          Text(
            domain.alwaysInSession
                ? 'In every daily session'
                : 'Picked when it needs the work',
            style: AppText.mono12.copyWith(color: domain.color(c)),
          ),
          const SizedBox(height: 20),
          for (final game in gamesIn(domain))
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push(Routes.game(game.id)),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    SizedBox(width: 112, child: GameArt(game: game)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(game.name, style: AppText.cardTitle),
                          const SizedBox(height: 4),
                          Text(
                            game.tagline,
                            style: AppText.label.copyWith(
                              color: c.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
