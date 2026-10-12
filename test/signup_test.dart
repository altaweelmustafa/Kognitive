import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kognitiv/app.dart';
import 'package:kognitiv/routing/app_router.dart';
import 'package:kognitiv/data/session.dart';
import 'package:kognitiv/routing/routes.dart';

import 'fake_backend.dart';

void main() {
  testWidgets('sign-up: name, gender, email, password, retype, code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(428, 926);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final backend = FakeBackend();
    await backend.install();
    appRouter.go(Routes.start);
    await tester.pumpWidget(const KognitivApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    Future<void> fill(
      String question,
      String text, {
      String button = 'Next',
    }) async {
      expect(find.text(question), findsOneWidget);
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
    }

    await fill("What's your name?", 'Dash');

    expect(find.text("What's your gender?"), findsOneWidget);
    await tester.tap(find.text('Next')); // disabled until a choice is made
    await tester.pumpAndSettle();
    expect(find.text("What's your gender?"), findsOneWidget);
    await tester.tap(find.text('Female'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await fill("What's your email?", 'dash@example.com');
    await fill('Create a password', 'correct-horse');

    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.pump();
    expect(find.text("Passwords don't match."), findsOneWidget);
    await fill('Retype your password', 'correct-horse');

    // The account is created here; the server hands the code back because it
    // has no email set up.
    expect(backend.account, {
      'name': 'Dash',
      'gender': 'female',
      'email': 'dash@example.com',
      'password': 'correct-horse',
    });
    expect(find.textContaining('Your code is 123456'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(find.text("That code isn't right."), findsOneWidget);

    await tester.tap(find.text('Resend code'));
    await tester.pumpAndSettle();
    await fill('Enter your code', '123456', button: 'Verify');
    expect(find.text("Today's Session"), findsOneWidget);
    expect(Session.instance.user?.name, 'Dash');
  });
}
