import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/color_config.dart';
import '../../data/games.dart';
import '../../data/progress.dart';
import '../../data/session.dart';
import '../../games/sudoku/sudoku_models.dart';
import '../../models/game.dart';
import '../../routing/routes.dart';
import '../../theme/app_text.dart';
import '../../widgets/domain_label.dart';
import '../../widgets/game_art.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/game_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/stat_chip.dart';
import 'greeting.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(top: 20, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                ListenableBuilder(
                  listenable: Progress.instance,
                  builder: (context, _) => StatChip(
                    icon: Icons.psychology,
                    iconColor: c.flexibility,
                    value:
                        Progress.instance.performance?.overall
                            ?.round()
                            .toString() ??
                        '–',
                  ),
                ),
                const SizedBox(width: 8),
                ListenableBuilder(
                  listenable: Session.instance,
                  builder: (context, _) => StatChip(
                    icon: Icons.local_fire_department,
                    iconColor: c.memory,
                    value: '${Session.instance.streak}',
                  ),
                ),
                const Spacer(),
                // Your photo opens Settings.
                GestureDetector(
                  key: const ValueKey('home-avatar'),
                  onTap: () => context.push(Routes.settings),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: UserAvatar(size: 36),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Greeting(),
          ),
          const SizedBox(height: 26),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text("Today's Session", style: AppText.sectionTitle),
          ),
          const SizedBox(height: 18),
          // Chosen by the backend each day from the player's results.
          SizedBox(
            height: 212,
            child: ListenableBuilder(
              listenable: Progress.instance,
              builder: (context, _) {
                final plan = Progress.instance.plan;
                if (plan == null) {
                  return Center(
                    child: Progress.instance.failed
                        ? Text(
                            "Can't load today's session.",
                            style: AppText.body.copyWith(
                              color: c.textSecondary,
                            ),
                          )
                        : CircularProgressIndicator(color: c.brandAccent),
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: plan.games.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 20),
                  itemBuilder: (context, i) {
                    final game = plan.games[i].game;
                    return SizedBox(
                      width: 204,
                      child: GameCard(
                        game: game,
                        onTap: () => context.push(Routes.game(game.id)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: PillButton(
              label: 'Start',
              width: 187,
              height: 42,
              onPressed: () => context.push(Routes.session),
            ),
          ),
          const SizedBox(height: 42),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 25),
            child: Divider(),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('More Games', style: AppText.sectionTitle),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
            child: Text(
              'Not part of your session. Play them any day.',
              style: AppText.label.copyWith(color: c.textSecondary),
            ),
          ),
          const SizedBox(height: 18),
          ListenableBuilder(
            listenable: Progress.instance,
            builder: (context, _) {
              final today = Progress.instance.today;
              final unfinished = today?.sudokuInProgress.firstOrNull;
              return Column(
                children: [
                  if (unfinished != null) _ContinueSudoku(save: unfinished),
                  for (final game in moreGames)
                    _MoreGameRow(
                      game: game,
                      dailySolved:
                          today?.dailySolved.contains(game.id) ?? false,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A game outside the session. Once its daily puzzle is solved, the icon gets
/// a green ring and a check mark.
class _MoreGameRow extends StatelessWidget {
  const _MoreGameRow({required this.game, required this.dailySolved});

  final Game game;
  final bool dailySolved;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(Routes.game(game.id)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 16, 21),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 61,
                  height: 61,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dailySolved ? c.improving : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: GameArt(game: game, circle: true),
                ),
                if (dailySolved)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      key: ValueKey('daily-solved-${game.id}'),
                      decoration: BoxDecoration(
                        color: c.background,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 22,
                        color: c.improving,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 9),
            // Takes the rest of the row, so a long name wraps.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.name, style: AppText.listTitle),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      DomainLabel(game.domain, mono: true),
                      if (dailySolved)
                        Text(
                          ' · Daily solved',
                          style: AppText.mono12.copyWith(color: c.improving),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The most recent unfinished Sudoku: tap to pick it up where it was left.
class _ContinueSudoku extends StatelessWidget {
  const _ContinueSudoku({required this.save});

  final SudokuSaveSummary save;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = save.elapsed;
    final time =
        '${t.inMinutes}:${(t.inSeconds % 60).toString().padLeft(2, '0')}';
    return GestureDetector(
      key: const ValueKey('continue-sudoku'),
      onTap: () => context.push(Routes.sudokuResume(save.puzzleId)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 22),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.play_circle_outline, size: 34, color: c.brandAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTINUE SUDOKU',
                    style: AppText.mono12.copyWith(
                      color: c.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    save.daily
                        ? 'Daily puzzle'
                        : '${save.difficulty.label} puzzle',
                    style: AppText.listTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$time played · ${save.filled} of 81 filled',
                    style: AppText.label.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}
