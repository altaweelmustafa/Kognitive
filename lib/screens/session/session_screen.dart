import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/color_config.dart';
import '../../data/progress.dart';
import '../../models/progress_models.dart';
import '../../routing/routes.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/domain_label.dart';
import '../../widgets/game_art.dart';
import '../../widgets/pill_button.dart';

/// Today's four games, in play order, with why each one is there.
class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: "Today's Session",
      child: ListenableBuilder(
        listenable: Progress.instance,
        builder: (context, _) {
          final c = context.colors;
          final plan = Progress.instance.plan;
          if (plan == null) {
            return Center(
              child: Progress.instance.failed
                  ? Text(
                      "Can't load today's session.",
                      style: AppText.listTitle,
                    )
                  : CircularProgressIndicator(color: c.brandAccent),
            );
          }
          final next = plan.next;
          return ListView(
            padding: const EdgeInsets.fromLTRB(27, 12, 27, 24),
            children: [
              Text(
                '${plan.games.length} games · ~15 min',
                style: AppText.mono12.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: 20),
              for (final (i, planned) in plan.games.indexed)
                _row(context, i, planned),
              const SizedBox(height: 20),
              Center(
                child: PillButton(
                  label: plan.completed
                      ? 'Done for today'
                      : (plan.games.any((g) => g.done) ? 'Continue' : 'Start'),
                  width: 187,
                  height: 42,
                  onPressed: next == null
                      ? null
                      : () => context.push(Routes.play(next.game.id)!),
                ),
              ),
              if (plan.games.any((g) => !g.playable)) ...[
                const SizedBox(height: 16),
                Text(
                  'Games marked "soon" are not built yet and are skipped.',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: c.textMuted),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, int i, PlannedGame planned) {
    final c = context.colors;
    final game = planned.game;
    final (state, stateColor) = switch (planned) {
      _ when planned.done => ('done', c.improving),
      _ when !planned.playable => ('soon', c.textMuted),
      _ => ('', c.textMuted),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text('${i + 1}', style: AppText.mono16.copyWith(color: c.textMuted)),
          const SizedBox(width: 12),
          SizedBox(width: 44, child: GameArt(game: game, circle: true)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(game.name, style: AppText.listTitle),
                Row(
                  children: [
                    DomainLabel(game.domain, mono: true),
                    Flexible(
                      child: Text(
                        ' · ${planned.why}',
                        overflow: TextOverflow.ellipsis,
                        style: AppText.mono12.copyWith(color: c.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (planned.done)
            Icon(Icons.check_circle, size: 18, color: stateColor),
          if (state.isNotEmpty && !planned.done)
            Text(state, style: AppText.mono12.copyWith(color: stateColor)),
        ],
      ),
    );
  }
}
