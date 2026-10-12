import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/color_config.dart';
import '../../theme/app_text.dart';
import '../../widgets/pill_button.dart';

/// Shown instead of a session game that was already played today.
class PlayedTodayNotice extends StatelessWidget {
  const PlayedTodayNotice({super.key, required this.gameName});

  final String gameName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        const SizedBox(height: 40),
        const Text(
          'Played today',
          style: AppText.screenTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          '$gameName counts once a day. Come back tomorrow for your next session.',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 32),
        PillButton(
          label: 'Back',
          width: 187,
          height: 42,
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}

/// End of a session game: the score from the server and a few numbers.
class SessionScoreSummary extends StatelessWidget {
  const SessionScoreSummary({
    super.key,
    required this.score,
    required this.color,
    required this.stats,
    required this.saveError,
    required this.onRetry,
  });

  /// Null while the result is being saved.
  final double? score;
  final Color color;

  /// (label, value) pairs shown under the score.
  final List<(String, String)> stats;
  final String? saveError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        const SizedBox(height: 40),
        Text(
          'SESSION SCORE',
          style: AppText.mono12.copyWith(
            color: c.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          score?.round().toString() ?? '…',
          style: AppText.mono16.copyWith(
            fontSize: 56,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Equal shares of the row; long labels shrink instead of overflowing.
            for (final (label, value) in stats)
              Expanded(
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: AppText.mono16.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: AppText.caption.copyWith(color: c.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),
        if (saveError case final error?) ...[
          Text(
            "$error Your result isn't saved yet.",
            textAlign: TextAlign.center,
            style: AppText.label.copyWith(color: c.declining),
          ),
          const SizedBox(height: 16),
          PillButton(
            label: 'Try again',
            width: 187,
            height: 42,
            onPressed: onRetry,
          ),
        ] else
          PillButton(
            label: 'Done',
            width: 187,
            height: 42,
            onPressed: score == null ? null : () => context.pop(),
          ),
      ],
    );
  }
}
