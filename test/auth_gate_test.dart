import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_2/screens/auth_gate.dart';
import 'package:flutter_application_2/services/auth_service.dart';
import 'package:flutter_application_2/screens/login_page.dart';
import 'package:flutter_test/flutter_test.dart';

const _testUser = AuthUser(
  uid: 'authenticated-test-user',
  email: 'driver@example.com',
);

void main() {
  testWidgets('unauthenticated startup displays Login and no vehicle screen', (
    tester,
  ) async {
    final authChanges = StreamController<AuthUser?>.broadcast();
    addTearDown(authChanges.close);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: authChanges.stream,
          authenticatedDestinationBuilder: (_) async =>
              const Text('Protected vehicle screen'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Protected vehicle screen'), findsNothing);

    authChanges.add(null);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Protected vehicle screen'), findsNothing);

    await tester.ensureVisible(find.text('Sign Up'));
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(find.text('Create Your Account'), findsOneWidget);

    await tester.ensureVisible(find.text('Log In'));
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('restored authenticated session loads its destination', (
    tester,
  ) async {
    final authChanges = StreamController<AuthUser?>.broadcast();
    addTearDown(authChanges.close);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: authChanges.stream,
          authenticatedDestinationBuilder: (_) async =>
              const Scaffold(body: Text('Vehicle connection')),
        ),
      ),
    );
    expect(find.text('Welcome Back'), findsNothing);

    authChanges.add(_testUser);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Vehicle connection'), findsOneWidget);
    expect(find.text('Welcome Back'), findsNothing);

    authChanges.add(null);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Vehicle connection'), findsNothing);
  });

  testWidgets('failed destination load can sign out and reach Login', (
    tester,
  ) async {
    final authChanges = StreamController<AuthUser?>.broadcast();
    addTearDown(authChanges.close);
    var signOutCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: authChanges.stream,
          authenticatedDestinationBuilder: (_) async =>
              throw StateError('Vehicle record unavailable.'),
          signOutAction: () async {
            signOutCalls++;
            authChanges.add(null);
          },
        ),
      ),
    );
    authChanges.add(_testUser);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('We could not load your saved vehicle details.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(signOutCalls, 1);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.textContaining('We could not load'), findsNothing);
  });

  testWidgets('successful Login follows the auth state into the app', (
    tester,
  ) async {
    final authChanges = StreamController<AuthUser?>.broadcast();
    addTearDown(authChanges.close);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: authChanges.stream,
          loginPageBuilder: (_) => LoginPage(
            emailLoginAction: (email, password) async {
              expect(email, 'driver@example.com');
              expect(password, 'CorrectHorse1');
              authChanges.add(_testUser);
            },
            errorMessageBuilder: (error) => error.toString(),
          ),
          authenticatedDestinationBuilder: (_) async =>
              const Scaffold(body: Text('Vehicle connection')),
        ),
      ),
    );
    authChanges.add(null);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'driver@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'CorrectHorse1');
    await tester.tap(find.text('LOG IN'));
    await tester.pumpAndSettle();

    expect(find.text('Vehicle connection'), findsOneWidget);
    expect(find.text('Welcome Back'), findsNothing);
  });

  testWidgets('failed Login remains on Login and displays an error', (
    tester,
  ) async {
    final authChanges = StreamController<AuthUser?>.broadcast();
    addTearDown(authChanges.close);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: authChanges.stream,
          loginPageBuilder: (_) => LoginPage(
            emailLoginAction: (_, _) async {
              throw StateError('Email or password is incorrect.');
            },
            errorMessageBuilder: (error) => error.toString(),
          ),
          authenticatedDestinationBuilder: (_) async =>
              const Scaffold(body: Text('Protected vehicle screen')),
        ),
      ),
    );
    authChanges.add(null);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'driver@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'incorrect');
    await tester.tap(find.text('LOG IN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(
      find.text('Bad state: Email or password is incorrect.'),
      findsOneWidget,
    );
    expect(find.text('Protected vehicle screen'), findsNothing);
  });
}
