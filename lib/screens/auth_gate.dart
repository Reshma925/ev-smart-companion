import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'bluetooth_scanning_page.dart';
import 'login_page.dart';
import 'signup_page.dart';

typedef AuthenticatedDestinationBuilder = Future<Widget> Function(User user);
typedef LoginPageBuilder = Widget Function(BuildContext context);
typedef SignOutAction = Future<void> Function();

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.authStateChanges,
    this.authenticatedDestinationBuilder,
    this.loginPageBuilder,
    this.signOutAction,
  });

  final Stream<User?>? authStateChanges;
  final AuthenticatedDestinationBuilder? authenticatedDestinationBuilder;
  final LoginPageBuilder? loginPageBuilder;

  /// Lets an account stuck in onboarding or a failed destination load reach
  /// Login again. Defaults to [AuthService.signOut].
  final SignOutAction? signOutAction;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  int _streamGeneration = 0;
  late Stream<_AuthStatus> _authStatusStream = _createAuthStatusStream();

  Stream<_AuthStatus> _createAuthStatusStream() =>
      (widget.authStateChanges ?? FirebaseAuth.instance.authStateChanges()).map(
        _AuthStatus.new,
      );

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authStateChanges != widget.authStateChanges) {
      _authStatusStream = _createAuthStatusStream();
      _streamGeneration++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_AuthStatus>(
      key: ValueKey(_streamGeneration),
      stream: _authStatusStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AuthInitializationError(
            onRetry: () => setState(() => _streamGeneration++),
          );
        }
        if (!snapshot.hasData) {
          return const _AuthLoading();
        }
        final user = snapshot.data!.user;
        if (user == null) {
          return widget.loginPageBuilder?.call(context) ?? const LoginPage();
        }
        // AuthService is created lazily so tests without Firebase can run.
        final signOut = widget.signOutAction ?? () => AuthService().signOut();
        return _AuthenticatedDestination(
          key: ValueKey(user.uid),
          user: user,
          destinationBuilder:
              widget.authenticatedDestinationBuilder ??
              (user) => _loadDestination(user, signOut),
          signOutAction: signOut,
        );
      },
    );
  }
}

class _AuthStatus {
  const _AuthStatus(this.user);

  final User? user;
}

Future<Widget> _loadDestination(User user, SignOutAction signOut) async {
  final firestore = DataService();
  final profile = await firestore.getUserProfile(user.uid);
  if (profile == null) {
    return SignUpPage(authenticatedOnboarding: true, signOutAction: signOut);
  }
  if (profile.vehicleId == null || profile.vehicleId!.isEmpty) {
    throw StateError(
      'Your Firestore profile has no vehicle mapping. Contact support.',
    );
  }

  final vehicle = await firestore.getCurrentUserVehicle(user.uid);
  if (vehicle == null) {
    throw StateError(
      'Your registered vehicle is unavailable or inactive. Contact support.',
    );
  }
  return BluetoothScanningPage(vehicle: vehicle);
}

class _AuthenticatedDestination extends StatefulWidget {
  const _AuthenticatedDestination({
    super.key,
    required this.user,
    required this.destinationBuilder,
    required this.signOutAction,
  });

  final User user;
  final AuthenticatedDestinationBuilder destinationBuilder;
  final SignOutAction signOutAction;

  @override
  State<_AuthenticatedDestination> createState() =>
      _AuthenticatedDestinationState();
}

class _AuthenticatedDestinationState extends State<_AuthenticatedDestination> {
  late Future<Widget> _destination;

  @override
  void initState() {
    super.initState();
    _destination = widget.destinationBuilder(widget.user);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _destination,
    builder: (context, snapshot) {
      if (snapshot.hasData) return snapshot.data!;
      if (snapshot.hasError) {
        return _DestinationLoadError(
          message: snapshot.error.toString(),
          onRetry: () => setState(
            () => _destination = widget.destinationBuilder(widget.user),
          ),
          onSignOut: widget.signOutAction,
        );
      }
      return const _AuthLoading();
    },
  );
}

class _AuthLoading extends StatelessWidget {
  const _AuthLoading();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _AuthInitializationError extends StatelessWidget {
  const _AuthInitializationError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not verify your sign-in status. Check your connection and retry.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );
}

class _DestinationLoadError extends StatelessWidget {
  const _DestinationLoadError({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final SignOutAction onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'We could not load your saved vehicle details.\n$message',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            const SizedBox(height: 6),
            // Signing out makes the auth stream emit null, so AuthGate shows Login.
            TextButton(onPressed: onSignOut, child: const Text('Sign out')),
          ],
        ),
      ),
    ),
  );
}
