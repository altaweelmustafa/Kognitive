import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/color_config.dart';
import '../../config/domain_config.dart';
import '../../data/games.dart';
import '../../models/cognitive_domain.dart';
import '../../models/game.dart';
import '../../routing/routes.dart';
import '../../theme/app_text.dart';
import '../../widgets/game_card.dart';
import '../../widgets/search_field.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  static const _gap = 17.0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _query.trim().toLowerCase();
    final results = games
        .where((g) => g.name.toLowerCase().contains(q))
        .toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(27, 36, 27, 24),
        children: [
          const Text('Your Games', style: AppText.screenTitle),
          const SizedBox(height: 28),
          SearchField(onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 36),
          if (q.isEmpty)
            // One row per domain: two games, then a "More in" tile.
            for (final domain in CognitiveDomain.values) ...[
              _DomainHeader(domain: domain),
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: _row([
                  for (final g in gamesIn(domain).take(2)) _tile(g),
                  _MoreInTile(domain: domain),
                ]),
              ),
            ]
          else if (results.isEmpty)
            Text(
              'No games match "$_query".',
              style: AppText.body.copyWith(color: c.textSecondary),
            )
          else
            for (var i = 0; i < results.length; i += 3)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _row([
                  for (final g in results.skip(i).take(3)) _tile(g),
                ]),
              ),
        ],
      ),
    );
  }

  Widget _tile(Game game) => GameCard(
    game: game,
    centered: true,
    showDomain: false,
    titleStyle: AppText.label.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    onTap: () => context.push(Routes.game(game.id)),
  );

  /// Three equal columns; missing cells stay empty.
  Widget _row(List<Widget> cells) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: _gap),
        Expanded(child: i < cells.length ? cells[i] : const SizedBox()),
      ],
    ],
  );
}

class _DomainHeader extends StatelessWidget {
  const _DomainHeader({required this.domain});

  final CognitiveDomain domain;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = gamesIn(domain).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 4, height: 18, color: domain.color(c)),
          const SizedBox(width: 8),
          Expanded(child: Text(domain.fullLabel, style: AppText.sectionTitle)),
          Text(
            count == 1 ? '1 game' : '$count games',
            style: AppText.mono12.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _MoreInTile extends StatelessWidget {
  const _MoreInTile({required this.domain});

  final CognitiveDomain domain;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => context.push(Routes.domain(domain.name)),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: domain.color(c),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'More in\n${domain.label}',
            textAlign: TextAlign.center,
            style: AppText.label.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.onAccent,
            ),
          ),
        ),
      ),
    );
  }
}
