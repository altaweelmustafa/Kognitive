import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_text.dart';
import 'circle_back_button.dart';

/// Scaffold for pushed screens: circular back button + centered title.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(23, 12, 23, 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CircleBackButton(
                      onTap: onBack ?? () => context.pop(),
                    ),
                  ),
                  Text(
                    title,
                    style: AppText.listTitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
