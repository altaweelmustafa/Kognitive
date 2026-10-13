import 'package:flutter/material.dart';

import '../models/game.dart';
import '../theme/app_text.dart';
import 'domain_label.dart';
import 'game_art.dart';

/// Reusable game card: banner art, game name, optional domain label.
/// Takes the width of its parent.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    this.onTap,
    this.centered = false,
    this.showDomain = true,
    this.titleStyle = AppText.cardTitle,
  });

  final Game game;
  final VoidCallback? onTap;
  final bool centered;
  final bool showDomain;
  final TextStyle titleStyle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          GameArt(game: game),
          const SizedBox(height: 10),
          Text(
            game.name,
            style: titleStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
          ),
          if (showDomain) ...[
            const SizedBox(height: 2),
            DomainLabel(game.domain),
          ],
        ],
      ),
    );
  }
}
