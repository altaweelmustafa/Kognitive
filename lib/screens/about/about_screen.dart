import 'package:flutter/material.dart';

import '../../config/app_info.dart';
import '../../config/color_config.dart';
import '../../config/domain_config.dart';
import '../../data/games.dart';
import '../../models/cognitive_domain.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/kognitiv_logo.dart';
import '../../widgets/pill_button.dart';

/// What Kognitiv is, how the daily session works, and who made what.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Content the app uses that others made.
  static const _credits = [
    (
      'Reading passages',
      'Article intros from Wikipedia (CC BY-SA 4.0) and public-domain novels '
          'from Project Gutenberg, in Between the Lines.',
    ),
    (
      'Chess puzzles',
      'From the Lichess puzzle database (CC0), via the Lichess API.',
    ),
    (
      'Faces',
      "Face Research Lab London Set by Lisa DeBruine and Benedict Jones "
          "(CC BY 4.0), in What's My Name?. The names are invented.",
    ),
    ('Chess pieces', 'Chess Simple Assets, a Figma community kit.'),
    (
      'Fonts',
      'Zilla Slab by Typotheque for Mozilla (SIL Open Font License) and '
          'Ubuntu Mono by Dalton Maag (Ubuntu Font Licence).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = AppText.body.copyWith(color: c.textSecondary);
    final inSession = games.where((g) => g.inSessions).length;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 10),
      child: Text(text, style: AppText.sectionTitle),
    );

    return DetailScaffold(
      title: 'About',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(27, 16, 27, 32),
        children: [
          const Center(child: KognitivLogo(width: 120)),
          const SizedBox(height: 16),
          const Text(
            'Kognitiv',
            textAlign: TextAlign.center,
            style: AppText.screenTitle,
          ),
          const SizedBox(height: 4),
          Text(
            'Version ${AppInfo.version}',
            key: const ValueKey('version'),
            textAlign: TextAlign.center,
            style: AppText.mono12.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 20),
          Text(
            "Solo cognitive training. A few minutes a day of games that work "
            "your memory, attention, reasoning, planning and flexibility, "
            "with the daily picks aimed at the areas that need it most.",
            textAlign: TextAlign.center,
            style: body,
          ),

          heading('Five domains'),
          for (final d in CognitiveDomain.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: d.color(c).withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(d.icon, size: 18, color: d.color(c)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.fullLabel, style: AppText.listTitle),
                        Text(
                          _domainBlurb(d),
                          style: AppText.label.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          heading('Your daily session'),
          Text(
            'Four games a day. Memory and Attention are always in; the other '
            'two go to the domains your recent scores say need the most work. '
            'Each session game counts once a day and feeds your Brain score.\n\n'
            '${games.length} games in all: $inSession can come up in the '
            'session, and the rest you can play any day, as often as you like.',
            style: body,
          ),

          heading('Credits'),
          for (final (what, who) in _credits)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(what, style: AppText.listTitle),
                  const SizedBox(height: 2),
                  Text(
                    who,
                    style: AppText.label.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Center(
            child: PillButton(
              label: 'Open-source licences',
              outlined: true,
              width: 240,
              height: 42,
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Kognitiv',
                applicationVersion: AppInfo.version,
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(12),
                  child: KognitivLogo(width: 72),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _domainBlurb(CognitiveDomain d) => switch (d) {
    CognitiveDomain.memory => 'Holding on to what you have just seen.',
    CognitiveDomain.attention => 'Staying on what matters, ignoring the rest.',
    CognitiveDomain.reasoning => 'Working things out with numbers and words.',
    CognitiveDomain.planning => 'Thinking several moves ahead.',
    CognitiveDomain.flexibility => 'Switching rules quickly when they change.',
  };
}
