import 'api/api_client.dart';

String vehicleControlsPreferencesErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.code == 'vehicle_not_found') {
      return 'Your signed-in account could not access controls for this vehicle. Confirm this vehicle is linked to your account and active. No preferences were replaced.';
    }
    if (error.statusCode == 401) {
      return 'Your sign-in expired. Sign in again to load vehicle controls.';
    }
    if (error.statusCode == 0 || error.statusCode >= 500) {
      return 'The server is temporarily unreachable. ${error.message} Retry in a moment.';
    }
    return 'Vehicle preferences could not be loaded (${error.message}). Retry to try again.';
  }
  if (error is StateError) {
    return 'Vehicle preferences could not be loaded: ${error.message}';
  }
  return 'Vehicle preferences could not be loaded. Retry or contact support if the problem continues.';
}
