import 'package:flutter/material.dart';

import 'routing/app_router.dart';
import 'theme/app_theme.dart';
import 'widgets/wide_screen_frame.dart';

class KognitivApp extends StatelessWidget {
  const KognitivApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kognitiv',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      builder: (context, child) => WideScreenFrame(child: child!),
    );
  }
}
