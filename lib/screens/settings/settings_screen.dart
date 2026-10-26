import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/color_config.dart';
import '../../data/session.dart';
import '../../routing/routes.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/user_avatar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget link(String label, String route, {required String key}) => Column(
      children: [
        GestureDetector(
          key: ValueKey(key),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(child: Text(label, style: AppText.listTitle)),
                Icon(Icons.chevron_right_rounded, color: c.textMuted),
              ],
            ),
          ),
        ),
        const Divider(),
      ],
    );

    return DetailScaffold(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(27, 12, 27, 24),
        children: [
          // The player, with their photo: tap to edit.
          ListenableBuilder(
            listenable: Session.instance,
            builder: (context, _) {
              final user = Session.instance.user;
              if (user == null) return const SizedBox.shrink();
              return GestureDetector(
                key: const ValueKey('settings-profile'),
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push(Routes.profile),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      const UserAvatar(size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, style: AppText.sectionTitle),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: AppText.mono12.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: c.textMuted),
                    ],
                  ),
                ),
              );
            },
          ),
          const Divider(),
          link('Edit profile', Routes.profile, key: 'settings-edit-profile'),
          link('Daily reminder', Routes.reminder, key: 'settings-reminder'),
          link('About Kognitiv', Routes.about, key: 'settings-about'),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // The router sends a logged-out player to the start screen.
            onTap: Session.instance.logout,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Log out',
                style: AppText.listTitle.copyWith(color: c.declining),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
