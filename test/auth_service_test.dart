import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_2/screens/auth_gate.dart';
import 'package:flutter_application_2/screens/login_page.dart';
import 'package:flutter_application_2/services/api/api_client.dart';
import 'package:flutter_application_2/services/auth_service.dart';
import 'package:flutter_application_2/services/vehicle_ble_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A stand-in for the backend's /v1/auth endpoints.
class _FakeAuthBackend {
  final requests = <http.Request>[];
  String password = 'Secret123';
  int expiresIn = 900;
  bool rejectRefresh = false;
  int _issued = 0;

  List<http.Request> to(String path) =>
      requests.where((request) => request.url.path == path).toList();

  Map<String, Object> _tokens() {
    _issued++;
    return {
      'accessToken': 'access-$_issued',
      'refreshToken': 'refresh-$_issued',
      'accessTokenExpiresIn': expiresIn,
    };
  }

  http.Response _json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status);

  late final client = MockClient((request) async {
    requests.add(request);
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    switch (request.url.path) {
      case '/v1/auth/signup':
        return _json({'message': 'Account created.'}, 201);
      case '/v1/auth/login':
        if (body['email'] != 'driver@example.com' ||
            body['password'] != password) {
          return _json({
            'error': {
              'code': 'invalid_credentials',
              'message': 'Email or password is incorrect.',
            },
          }, 401);
        }
        return _json({
          ..._tokens(),
          'user': {
            'uid': 'user-1',
            'email': 'driver@example.com',
            'name': 'Driver',
          },
        });
      case '/v1/auth/refresh':
        if (rejectRefresh) {
          return _json({
            'error': {'code': 'unauthenticated', 'message': 'expired'},
          }, 401);
        }
        return _json(_tokens());
      case '/v1/auth/logout':
        return http.Response('', 204);
    }
    return _json({
      'error': {'code': 'not_found', 'message': 'unknown'},
    }, 404);
  });

  AuthService service() =>
      AuthService.withClient(httpClient: client, baseUrl: 'http://api.test');
}

void main() {
  group('AuthService', () {
    test('sign-up sends every field and does not sign in', () async {
      final backend = _FakeAuthBackend();
      final auth = backend.service();

      await auth.signUp(
        name: 'Driver',
        email: 'driver@example.com',
        password: 'Secret123',
        phone: '9876543210',
        city: 'Chennai',
        registrationNumber: 'TN01AB1234',
        model: 'EV Smart X1',
        ownerName: 'Registered Vehicle Owner 1',
        vin: 'EVVIN001',
      );

      final sent = jsonDecode(backend.to('/v1/auth/signup').single.body) as Map;
      expect(sent, {
        'name': 'Driver',
        'email': 'driver@example.com',
        'password': 'Secret123',
        'phone': '9876543210',
        'city': 'Chennai',
        'registrationNumber': 'TN01AB1234',
        'model': 'EV Smart X1',
        'ownerName': 'Registered Vehicle Owner 1',
        'vin': 'EVVIN001',
      });
      expect(auth.currentUser, isNull);
      expect(await auth.accessToken(), isNull);
    });

    test('login keeps the session in memory and announces the user', () async {
      final auth = _FakeAuthBackend().service();
      final states = <String?>[];
      final subscription = auth.authStateChanges().listen(
        (user) => states.add(user?.email),
      );

      final user = await auth.signInWithEmail(
        email: ' driver@example.com ',
        password: 'Secret123',
      );
      await Future<void>.delayed(Duration.zero);

      expect(user.uid, 'user-1');
      expect(auth.currentUser?.email, 'driver@example.com');
      expect(await auth.accessToken(), 'access-1');
      expect(states, [null, 'driver@example.com']);
      await subscription.cancel();
    });

    test(
      'a wrong password gives a clear error and is sent only once',
      () async {
        final backend = _FakeAuthBackend();
        final auth = backend.service();

        await expectLater(
          auth.signInWithEmail(email: 'driver@example.com', password: 'nope'),
          throwsA(
            isA<ApiException>().having(
              (error) => auth.messageFor(error),
              'message',
              'Email or password is incorrect.',
            ),
          ),
        );
        expect(backend.to('/v1/auth/login'), hasLength(1));
        expect(auth.currentUser, isNull);
      },
    );

    test('an expired access token is refreshed automatically', () async {
      final backend = _FakeAuthBackend()..expiresIn = 0;
      final auth = backend.service();
      await auth.signInWithEmail(
        email: 'driver@example.com',
        password: 'Secret123',
      );

      expect(await auth.accessToken(), 'access-2');
      final refresh = jsonDecode(backend.to('/v1/auth/refresh').single.body);
      expect(refresh, {'refreshToken': 'refresh-1'});
    });

    test('a rejected refresh ends the session and returns to Login', () async {
      final backend = _FakeAuthBackend()
        ..expiresIn = 0
        ..rejectRefresh = true;
      final auth = backend.service();
      await auth.signInWithEmail(
        email: 'driver@example.com',
        password: 'Secret123',
      );

      expect(await auth.accessToken(), isNull);
      expect(auth.currentUser, isNull);
    });

    test('sign-out clears the session and tells the server', () async {
      final backend = _FakeAuthBackend();
      final auth = backend.service();
      await auth.signInWithEmail(
        email: 'driver@example.com',
        password: 'Secret123',
      );

      await auth.signOut();

      expect(auth.currentUser, isNull);
      expect(await auth.accessToken(), isNull);
      expect(jsonDecode(backend.to('/v1/auth/logout').single.body), {
        'refreshToken': 'refresh-1',
      });
      expect(VehicleBleClient.shared.isConnected, isFalse);
    });
  });

  testWidgets(
    'Login -> app -> logout -> Login, and a wrong password stays on Login',
    (tester) async {
      final auth = _FakeAuthBackend().service();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: auth.authStateChanges(),
            loginPageBuilder: (_) => LoginPage(
              emailLoginAction: (email, password) =>
                  auth.signInWithEmail(email: email, password: password),
              errorMessageBuilder: auth.messageFor,
            ),
            authenticatedDestinationBuilder: (_) async => Scaffold(
              body: TextButton(
                onPressed: auth.signOut,
                child: const Text('Vehicle connection · Sign out'),
              ),
            ),
            signOutAction: auth.signOut,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      // Google sign-in and password reset are not offered.
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Forgot Password?'), findsNothing);

      Future<void> logIn(String password) async {
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'driver@example.com',
        );
        await tester.enterText(find.byType(TextFormField).at(1), password);
        await tester.tap(find.text('LOG IN'));
        // The button spins until any error dialog is closed, so do not settle.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      await logIn('Wrong1234');
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      await tester.tap(find.text('OK').last);
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back'), findsOneWidget);

      await logIn('Secret123');
      await tester.pumpAndSettle();
      expect(find.text('Vehicle connection · Sign out'), findsOneWidget);

      await tester.tap(find.text('Vehicle connection · Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back'), findsOneWidget);
    },
  );

  test('the BLE client refuses to connect when nobody is logged in', () async {
    expect(AuthService().currentUser, isNull);
    await expectLater(
      VehicleBleClient.shared.start('EV001'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Sign in before connecting to a vehicle.',
        ),
      ),
    );
  });
}
