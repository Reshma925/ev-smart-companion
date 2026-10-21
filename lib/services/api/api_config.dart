import 'package:flutter/foundation.dart';

/// Base URL of the EV Smart Companion backend.
///
/// Override at build time:
/// `--dart-define=API_BASE_URL=https://your-service.onrender.com`
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8081',
);

/// Release builds must talk to the backend over HTTPS.
void warnIfInsecureApiBaseUrl() {
  if (kReleaseMode && !apiBaseUrl.startsWith('https://')) {
    debugPrint(
      '[API] WARNING: release build uses a non-HTTPS API_BASE_URL. '
      'Build with --dart-define=API_BASE_URL=https://...',
    );
  }
}
