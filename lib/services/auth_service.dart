import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'api/api_client.dart';
import 'vehicle_ble_client.dart';

/// The signed-in account.
class AuthUser {
  const AuthUser({required this.uid, required this.email, this.name = ''});

  final String uid;
  final String email;
  final String name;
}

Future<String?> _noToken({bool forceRefresh = false}) async => null;

/// Email/password login against the EV Smart Companion backend.
///
/// Tokens are kept in memory only, so every app launch or page reload starts
/// at Login. The access token is short-lived and refreshed automatically; if
/// the session can no longer be refreshed the user is signed out, which sends
/// [authStateChanges] to null and AuthGate back to Login.
class AuthService {
  /// The app-wide session.
  factory AuthService() => instance;

  /// A separate session, e.g. for tests with a fake [httpClient].
  AuthService.withClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient,
      _baseUrl = baseUrl,
      _publicApi = ApiClient(
        httpClient: httpClient,
        baseUrl: baseUrl,
        tokenProvider: _noToken,
      );

  static final AuthService instance = AuthService.withClient();

  final http.Client? _httpClient;
  final String? _baseUrl;
  final ApiClient _publicApi;
  late final ApiClient _authedApi = ApiClient(
    httpClient: _httpClient,
    baseUrl: _baseUrl,
    tokenProvider: accessToken,
  );
  final _changes = StreamController<AuthUser?>.broadcast();

  AuthUser? _user;
  String? _accessToken;
  DateTime? _accessTokenExpiry;
  String? _refreshToken;
  Future<String?>? _refreshing;

  AuthUser? get currentUser => _user;

  /// Emits the current user immediately, then every sign-in and sign-out.
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  /// Creates the account and links the vehicle in one step. Does not sign in:
  /// the user logs in afterwards with the same email and password.
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String city,
    required String registrationNumber,
    required String model,
    required String ownerName,
    required String vin,
  }) async {
    await _publicApi.post('/v1/auth/signup', {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'phone': phone.trim(),
      'city': city.trim(),
      'registrationNumber': registrationNumber,
      'model': model,
      'ownerName': ownerName,
      'vin': vin,
    });
  }

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response =
        await _publicApi.post('/v1/auth/login', {
              'email': email.trim(),
              'password': password,
            })
            as Map;
    final user = Map<String, dynamic>.from(response['user'] as Map);
    _storeTokens(response);
    final signedIn = AuthUser(
      uid: user['uid'] as String,
      email: user['email'] as String? ?? email.trim().toLowerCase(),
      name: user['name'] as String? ?? '',
    );
    _setUser(signedIn);
    return signedIn;
  }

  /// Disconnects the vehicle, ends the session locally, then tells the server.
  Future<void> signOut() async {
    await VehicleBleClient.shared.disconnect();
    final refreshToken = _refreshToken;
    _clearSession();
    if (refreshToken == null) return;
    try {
      await _publicApi.post('/v1/auth/logout', {'refreshToken': refreshToken});
    } catch (error) {
      // The local session is already gone; server-side revocation is best effort.
      debugPrint('[Auth] Logout request failed: ${error.runtimeType}');
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_user == null) {
      throw StateError('Sign in to change your password.');
    }
    final response = await _authedApi.post('/v1/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    _storeTokens(response as Map);
  }

  /// A valid access token, refreshed when expired or when [forceRefresh] is
  /// set. Returns null when signed out.
  Future<String?> accessToken({bool forceRefresh = false}) async {
    if (_refreshToken == null) return null;
    final expiry = _accessTokenExpiry;
    final stillValid =
        _accessToken != null &&
        expiry != null &&
        DateTime.now().isBefore(expiry.subtract(const Duration(seconds: 30)));
    if (!forceRefresh && stillValid) return _accessToken;
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _refresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return null;
    try {
      final response = await _publicApi.post('/v1/auth/refresh', {
        'refreshToken': refreshToken,
      });
      _storeTokens(response as Map);
      return _accessToken;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        // The session ended (expired, revoked or reused): back to Login.
        await VehicleBleClient.shared.disconnect();
        _clearSession();
        return null;
      }
      rethrow;
    }
  }

  void _storeTokens(Map response) {
    _accessToken = response['accessToken'] as String;
    _refreshToken = response['refreshToken'] as String;
    final seconds = (response['accessTokenExpiresIn'] as num?)?.toInt() ?? 900;
    _accessTokenExpiry = DateTime.now().add(Duration(seconds: seconds));
  }

  void _setUser(AuthUser? user) {
    _user = user;
    _changes.add(user);
  }

  void _clearSession() {
    _accessToken = null;
    _accessTokenExpiry = null;
    _refreshToken = null;
    if (_user != null) _setUser(null);
  }

  String messageFor(Object error) {
    if (error is ApiException) return error.message;
    if (error is StateError) return error.message;
    if (error is ArgumentError) return error.message.toString();
    return 'Something went wrong. Please try again.';
  }
}
