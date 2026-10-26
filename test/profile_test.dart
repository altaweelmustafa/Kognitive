import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/data/avatar_image.dart';
import 'package:kognitiv/data/session.dart';
import 'package:kognitiv/screens/library/article_screen.dart';
import 'package:kognitiv/screens/library/library_screen.dart';
import 'package:kognitiv/screens/profile/profile_screen.dart';
import 'package:kognitiv/screens/reminder/reminder_screen.dart';
import 'package:kognitiv/theme/app_theme.dart';

import 'fake_backend.dart';

/// A 1×1 red PNG.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==',
);

Future<FakeBackend> _start(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(428, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend = FakeBackend();
  await backend.install(loggedIn: true);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: screen),
    ),
  );
  await tester.pumpAndSettle();
  return backend;
}

void main() {
  test('photos become a small square PNG', () async {
    final png = await squareAvatar(_pixel, size: 64);
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('edit profile: name', (tester) async {
    final backend = await _start(tester, const ProfileScreen());
    expect(find.text('dash@example.com'), findsOneWidget);
    expect(find.text('D'), findsOneWidget); // the initial, with no photo

    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      'Dashiell',
    );
    await tester.pump();
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();
    expect(find.text('Name saved.'), findsOneWidget);
    expect(backend.account!['name'], 'Dashiell');
    expect(Session.instance.user!.name, 'Dashiell');
  });

  testWidgets('edit profile: photo, then remove it', (tester) async {
    final backend = await _start(
      tester,
      ProfileScreen(pickPhoto: () => squareAvatar(_pixel, size: 64)),
    );
    await tester.tap(find.byKey(const ValueKey('change-photo')));
    // Decoding the photo needs the real event loop, between frames.
    for (var i = 0; i < 20 && backend.avatar == null; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(backend.avatar, isNotNull);
    expect(backend.avatarVersion, 1);
    expect(Session.instance.avatar, isNotNull);
    expect(find.byKey(const ValueKey('avatar-photo')), findsOneWidget);
    expect(find.text('Change photo'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remove-photo')));
    await tester.pumpAndSettle();
    expect(backend.avatar, isNull);
    expect(Session.instance.avatar, isNull);
    expect(find.text('Add a photo'), findsOneWidget);
  });

  testWidgets('edit profile: password', (tester) async {
    final backend = await _start(tester, const ProfileScreen());
    final change = find.text('Change password');
    Future<void> fill(String current, String next, String again) async {
      await tester.enterText(
        find.byKey(const ValueKey('password-current')),
        current,
      );
      await tester.enterText(find.byKey(const ValueKey('password-new')), next);
      await tester.enterText(
        find.byKey(const ValueKey('password-retype')),
        again,
      );
      await tester.pump();
    }

    await fill('correct-horse', 'battery-staple', 'battery-stapler');
    expect(find.text("The new passwords don't match."), findsOneWidget);
    await fill('correct-horse', 'short', 'short');
    expect(find.textContaining('at least 8 characters'), findsOneWidget);

    await fill('wrong-horse', 'battery-staple', 'battery-staple');
    await tester.tap(change);
    await tester.pumpAndSettle();
    expect(find.text("Your current password isn't right."), findsOneWidget);
    expect(backend.account!['password'], 'correct-horse');

    await fill('correct-horse', 'battery-staple', 'battery-staple');
    await tester.tap(change);
    await tester.pumpAndSettle();
    expect(find.textContaining('Password changed'), findsOneWidget);
    expect(backend.account!['password'], 'battery-staple');
  });

  testWidgets('save articles from the library and the article itself', (
    tester,
  ) async {
    final backend = await _start(tester, const LibraryScreen());
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save-stress-less')));
    await tester.pumpAndSettle();
    expect(backend.favorites, ['stress-less']);
    expect(find.text('Saved · 1'), findsOneWidget);

    // The Saved filter shows only what was saved.
    await tester.tap(find.byKey(const ValueKey('saved-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Stress Less'), findsOneWidget);
    expect(find.text('Feed Your Brain'), findsNothing);

    // Unsaving empties it.
    await tester.tap(find.byKey(const ValueKey('save-stress-less')));
    await tester.pumpAndSettle();
    expect(backend.favorites, isEmpty);
    expect(find.textContaining('Nothing saved yet'), findsOneWidget);

    // From the article screen.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const ArticleScreen(id: 'feed-your-brain'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('article-save')));
    await tester.pumpAndSettle();
    expect(backend.favorites, ['feed-your-brain']);
    expect(find.text('Saved to your library'), findsOneWidget);
  });

  testWidgets('daily reminder in the phone app: time and switch', (
    tester,
  ) async {
    final backend = await _start(tester, const ReminderScreen());
    expect(find.text('7:00 PM'), findsOneWidget);
    // Not the web app: it explains where reminders arrive.
    expect(find.textContaining('through the Kognitiv web app'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reminder-switch')));
    await tester.pumpAndSettle();
    expect(backend.reminder['enabled'], isTrue);
    expect(backend.reminder['time'], '19:00');
  });
}
