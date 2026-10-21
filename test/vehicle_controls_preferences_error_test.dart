import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/services/api/api_client.dart';
import 'package:flutter_application_2/services/vehicle_controls_preferences_error.dart';

void main() {
  group('vehicle controls preference errors', () {
    test('explains a vehicle the account cannot access and offers retry', () {
      final message = vehicleControlsPreferencesErrorMessage(
        const ApiException(
          404,
          'vehicle_not_found',
          "You don't have access to this vehicle.",
        ),
      );

      expect(message, contains('signed-in account'));
      expect(message, contains('active'));
      expect(message, contains('No preferences were replaced'));
    });

    test('distinguishes an expired sign-in', () {
      expect(
        vehicleControlsPreferencesErrorMessage(
          const ApiException(401, 'unauthenticated', 'Sign in to continue.'),
        ),
        contains('Sign in again'),
      );
    });

    test('distinguishes retryable availability errors', () {
      expect(
        vehicleControlsPreferencesErrorMessage(
          const ApiException(
            0,
            'timeout',
            'Server is waking up, please try again.',
          ),
        ),
        contains('temporarily unreachable'),
      );
    });
  });
}
