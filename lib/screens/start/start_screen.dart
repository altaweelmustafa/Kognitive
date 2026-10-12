import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/color_config.dart';
import '../../routing/routes.dart';
import '../../theme/app_text.dart';
import '../../widgets/pill_button.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 46),
          child: Column(
            children: [
              const Spacer(flex: 22),
              // Logo placeholder.
              Container(
                width: 126,
                height: 136,
                color: c.brandFill,
                alignment: Alignment.center,
                child: Text(
                  'LOGO',
                  style: AppText.button.copyWith(color: c.onBrand),
                ),
              ),
              const Spacer(flex: 12),
              const Text(
                "Boost your Brain's Power.\nBecome Versatile.",
                textAlign: TextAlign.center,
                style: AppText.display,
              ),
              const Spacer(flex: 6),
              PillButton(
                label: 'Sign up',
                width: double.infinity,
                onPressed: () => context.push(Routes.signup),
              ),
              const SizedBox(height: 12),
              PillButton(
                label: 'Log in',
                outlined: true,
                width: double.infinity,
                onPressed: () => context.push(Routes.login),
              ),
              const Spacer(flex: 21),
            ],
          ),
        ),
      ),
    );
  }
}
