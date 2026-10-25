import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/color_config.dart';
import '../../data/session.dart';
import '../../routing/routes.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Not built yet, so not tappable.
  static const _items = ['Account', 'Daily reminder', 'Sound'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DetailScaffold(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(27, 12, 27, 24),
        children: [
          if (Session.instance.user case final user?) ...[
            Text(user.name, style: AppText.sectionTitle),
            const SizedBox(height: 2),
            Text(
              user.email,
              style: AppText.mono12.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 16),
            const Divider(),
          ],
          for (final item in _items) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(item, style: AppText.listTitle),
            ),
            const Divider(),
          ],
          GestureDetector(
            key: const ValueKey('settings-about'),
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(Routes.about),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('About Kognitiv', style: AppText.listTitle),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.textMuted),
                ],
              ),
            ),
          ),
          const Divider(),
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
