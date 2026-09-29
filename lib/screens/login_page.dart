import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/common_widgets.dart';
import 'bluetooth_scanning_page.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final identityController = TextEditingController();
  final passwordController = TextEditingController();
  late final authService = AuthService();
  late final firestoreService = FirestoreService();
  bool isLoading = false;

  @override
  void dispose() {
    identityController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (isLoading) return;
    if (!formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    try {
      final credential = await authService.signInWithEmail(
        email: identityController.text,
        password: passwordController.text,
      );
      final user = credential.user;
      if (user == null) throw StateError('Firebase returned no user.');
      final profile = await firestoreService.getUserProfile(user.uid);
      if (!mounted) return;
      if (profile == null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const SignUpPage(authenticatedOnboarding: true),
          ),
          (route) => false,
        );
        return;
      }
      if (profile.vehicleId == null || profile.vehicleId!.isEmpty) {
        throw StateError(
          'Your Firestore profile has no vehicle mapping. Contact support.',
        );
      }
      final vehicle = await firestoreService.getCurrentUserVehicle(user.uid);
      if (!mounted) return;
      if (vehicle == null) {
        throw StateError(
          'Your registered vehicle is unavailable. Contact support to restore access.',
        );
      }
      final destination = BluetoothScanningPage(vehicle: vehicle);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          authService.messageFor(error),
          title: 'Login failed',
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> continueWithGoogle() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final credential = await authService.signInWithGoogle();
      final user = credential?.user;
      if (user == null) return;
      final profile = await firestoreService.getUserProfile(user.uid);
      if (!mounted) return;
      if (profile == null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const SignUpPage(authenticatedOnboarding: true),
          ),
          (route) => false,
        );
        return;
      }
      if (profile.vehicleId == null || profile.vehicleId!.isEmpty) {
        throw StateError(
          'Your Firestore profile has no vehicle mapping. Contact support.',
        );
      }
      final vehicle = await firestoreService.getCurrentUserVehicle(user.uid);
      if (!mounted) return;
      if (vehicle == null) {
        throw StateError(
          'Your registered vehicle is unavailable. Contact support to restore access.',
        );
      }
      final destination = BluetoothScanningPage(vehicle: vehicle);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          '${authService.messageFor(error)}\n\nDetails: $error',
          title: 'Google sign-in failed',
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 35, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: AppLogo()),
                const SizedBox(height: 28),
                const Center(
                  child: Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                const Center(
                  child: Text(
                    'Login to continue with your EV',
                    style: TextStyle(fontSize: 14, color: AppTheme.mutedBlue),
                  ),
                ),
                const SizedBox(height: 38),
                TextInputField(
                  controller: identityController,
                  label: 'Email',
                  hint: 'Enter your email',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      value == null ||
                          !RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(value.trim())
                      ? 'Enter a valid email address'
                      : null,
                ),
                const SizedBox(height: 20),
                PasswordInputField(
                  controller: passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your password'
                      : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordPage(),
                            ),
                          ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: AppTheme.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                PrimaryButton(
                  label: 'Log In',
                  onPressed: login,
                  isLoading: isLoading,
                ),
                const SizedBox(height: 29),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFFD9E0E8))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFFD9E0E8))),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : continueWithGoogle,
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.g_mobiledata,
                            size: 28,
                            color: Colors.black,
                          ),
                    label: Text(
                      isLoading ? 'Please wait…' : 'Continue with Google',
                      style: const TextStyle(color: AppTheme.navy),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD9E0E8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?",
                        style: TextStyle(color: AppTheme.mutedBlue),
                      ),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignUpPage(),
                                ),
                              ),
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: AppTheme.blue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
