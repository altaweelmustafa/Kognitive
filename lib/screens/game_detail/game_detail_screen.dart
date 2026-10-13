import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/color_config.dart';
import '../../models/game.dart';
import '../../data/progress.dart';
import '../../routing/routes.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/domain_label.dart';
import '../../widgets/game_art.dart';
import '../../widgets/pill_button.dart';

/// Game landing page. The Flame game mounts here later.
class GameDetailScreen extends StatelessWidget {
  const GameDetailScreen({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DetailScaffold(
      title: game.name,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Edge to edge; everything below keeps the page margin.
          GameArt(game: game, rounded: false),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 27),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(game.name, style: AppText.screenTitle),
                const SizedBox(height: 4),
                DomainLabel(game.domain, mono: true),
                const SizedBox(height: 16),
                Text(
                  game.tagline,
                  style: AppText.body.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: 32),
                if (Routes.play(game.id) case final route?)
                  // A session game counts once a day.
                  ListenableBuilder(
                    listenable: Progress.instance,
                    builder: (context, _) {
                      final played =
                          Progress.instance.plan?.lockedToday(game.id) ?? false;
                      return Column(
                        children: [
                          PillButton(
                            label: played ? 'Played today' : 'Play',
                            width: 187,
                            height: 42,
                            onPressed: played
                                ? null
                                : () => context.push(route),
                          ),
                          if (played) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Come back tomorrow for your next session.',
                              style: AppText.label.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  )
                else
                  Text(
                    'Not playable yet.',
                    style: AppText.mono12.copyWith(color: c.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
