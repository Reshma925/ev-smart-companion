import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/services/vehicle_controls_preferences_error.dart';

void main() {
  group('vehicle controls preference errors', () {
    test('explains scoped Firestore permission denial and offers retry', () {
      final message = vehicleControlsPreferencesErrorMessage(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );

      expect(message, contains('signed-in account'));
      expect(message, contains('active vehicle'));
      expect(message, contains('rules are deployed'));
      expect(message, contains('No preferences were replaced'));
    });

    test('distinguishes an expired sign-in', () {
      expect(
        vehicleControlsPreferencesErrorMessage(
          FirebaseException(plugin: 'cloud_firestore', code: 'unauthenticated'),
        ),
        contains('Sign in again'),
      );
    });

    test('distinguishes retryable Firestore availability errors', () {
      expect(
        vehicleControlsPreferencesErrorMessage(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        contains('temporarily unreachable'),
      );
    });
  });
}
