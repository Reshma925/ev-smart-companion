import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kIsWeb;

class AuthService {
  static Future<void>? _googleInitialization;

  AuthService({FirebaseAuth? firebaseAuth})
    : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      return credential;
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint('Firebase Auth error code: ${error.code}');
      debugPrint('Firebase Auth error message: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      return _auth.signInWithPopup(GoogleAuthProvider());
    }

    final googleSignIn = GoogleSignIn.instance;
    await (_googleInitialization ??= googleSignIn.initialize());
    if (!googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError(
        'Google Sign-In is not supported on this platform configuration.',
      );
    }

    GoogleSignInAccount account;
    try {
      account = await googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return an identity token. Please try again.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (kIsWeb) return;
    final googleSignIn = GoogleSignIn.instance;
    try {
      await (_googleInitialization ??= googleSignIn.initialize());
      await googleSignIn.signOut();
    } catch (_) {
      // Firebase sign-out is authoritative; clearing the provider session is best effort.
    }
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw StateError('Sign in with an email and password to change it.');
    }
    if (!user.providerData.any(
      (provider) => provider.providerId == 'password',
    )) {
      throw StateError(
        'This account does not use an email password. Use password reset if the account supports it.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'Enter a valid email address.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' => 'The email or password is incorrect.',
        'email-already-in-use' =>
          'An account already exists for this email. Please log in.',
        'weak-password' => 'Choose a stronger password.',
        'operation-not-allowed' =>
          'This sign-in method is not enabled in Firebase yet.',
        'network-request-failed' =>
          'Network error. Check your connection and try again.',
        'account-exists-with-different-credential' =>
          'An account already exists with this email using another sign-in method.',
        'missing-google-id-token' =>
          error.message ?? 'Google sign-in could not be completed.',
        'configuration-not-found' =>
          'Firebase Authentication is not initialized for this Firebase project. Enable it in Firebase Console → Authentication → Get started, then enable Email/Password.',
        _ => '${error.code}: ${error.message ?? 'Authentication failed.'}',
      };
    }
    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return 'Google sign-in was canceled.';
      }
      return error.description ?? 'Google sign-in failed. Please try again.';
    }
    if (error is UnsupportedError) return error.message.toString();
    if (error is StateError) return error.message;
    if (error is FirebaseException) {
      return '${error.code}: ${error.message ?? error.toString()}';
    }
    return 'Something went wrong. Please try again.';
  }
}
