import 'package:cloud_firestore/cloud_firestore.dart';

String vehicleControlsPreferencesErrorMessage(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'Your signed-in account could not access controls for this vehicle. Confirm your Firestore user profile points to this active vehicle and that the current Firestore rules are deployed. No preferences were replaced.',
      'unauthenticated' =>
        'Your sign-in expired. Sign in again to load vehicle controls.',
      'unavailable' || 'deadline-exceeded' =>
        'Firestore is temporarily unreachable. Check the network and retry.',
      _ =>
        'Vehicle preferences could not be loaded from Firestore (${error.code}). Retry to try again.',
    };
  }
  if (error is StateError) {
    return 'Vehicle preferences could not be loaded: ${error.message}';
  }
  return 'Vehicle preferences could not be loaded. Retry or contact support if the problem continues.';
}
