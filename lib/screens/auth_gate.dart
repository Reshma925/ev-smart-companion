import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'bluetooth_scanning_page.dart';
import 'login_page.dart';
import 'signup_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Widget> destination;

  @override
  void initState() {
    super.initState();
    destination = _resolveDestination();
  }

  Future<Widget> _resolveDestination() async {
    // Wait for Firebase to restore its persisted session before routing.
    final user = await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) return const LoginPage();

    final firestore = FirestoreService();
    final profile = await firestore.getUserProfile(user.uid);
    if (profile == null) {
      return const SignUpPage(authenticatedOnboarding: true);
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

  void _retry() {
    setState(() => destination = _resolveDestination());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: destination,
      builder: (context, snapshot) {
        if (snapshot.hasData) return snapshot.data!;
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'We could not load your saved vehicle details.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
