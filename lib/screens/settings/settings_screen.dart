import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../data/session.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _items = [
    'Account',
    'Daily reminder',
    'Sound',
    'About Kognitiv',
  ];

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
