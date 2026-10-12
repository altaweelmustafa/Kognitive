import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/color_config.dart';
import '../theme/app_text.dart';

/// Hosts the four tabs and the bottom nav bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _tabs = [
    (icon: Icons.home_filled, label: 'Home'),
    (icon: Icons.psychology_outlined, label: 'Your Brain'),
    (icon: Icons.style_outlined, label: 'Games'),
    (icon: Icons.menu_book_outlined, label: 'Library'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: shell,
      bottomNavigationBar: ColoredBox(
        color: c.background,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (final (i, tab) in _tabs.indexed)
                  Expanded(
                    child: _NavItem(
                      icon: tab.icon,
                      label: tab.label,
                      color: i == shell.currentIndex
                          ? c.brandAccent
                          : c.textMuted,
                      onTap: () => shell.goBranch(
                        i,
                        initialLocation: i == shell.currentIndex,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(height: 4),
          Text(label, style: AppText.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}
