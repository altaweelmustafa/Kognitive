import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kognitiv/config/app_info.dart';
import 'package:kognitiv/routing/routes.dart';
import 'package:kognitiv/screens/about/about_screen.dart';
import 'package:kognitiv/screens/settings/settings_screen.dart';
import 'package:kognitiv/theme/app_theme.dart';

void main() {
  testWidgets('Settings opens About: logo, version, credits, licences', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: Routes.settings,
      routes: [
        GoRoute(
          path: Routes.settings,
          builder: (_, _) => const SettingsScreen(),
        ),
        GoRoute(path: Routes.about, builder: (_, _) => const AboutScreen()),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    );
    await tester.tap(find.byKey(const ValueKey('settings-about')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('logo'), skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text('Version ${AppInfo.version}'), findsOneWidget);
    expect(find.text('Reasoning & Logic'), findsOneWidget);

    final licences = find.text('Open-source licences');
    await tester.scrollUntilVisible(licences, 300);
    expect(find.text('Credits'), findsOneWidget);
    await tester.tap(licences);
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
