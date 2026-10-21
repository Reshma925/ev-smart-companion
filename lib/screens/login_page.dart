import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/common_widgets.dart';
import 'signup_page.dart';

typedef EmailLoginAction = Future<void> Function(String email, String password);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.emailLoginAction, this.errorMessageBuilder});

  final EmailLoginAction? emailLoginAction;
  final String Function(Object error)? errorMessageBuilder;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final identityController = TextEditingController();
  final passwordController = TextEditingController();
  late final authService = AuthService();
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
      final action = widget.emailLoginAction;
      if (action != null) {
        await action(identityController.text, passwordController.text);
      } else {
        // On success AuthGate sees the new session and opens the app.
        await authService.signInWithEmail(
          email: identityController.text,
          password: passwordController.text,
        );
      }
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          widget.errorMessageBuilder?.call(error) ??
              authService.messageFor(error),
          title: 'Login failed',
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
                  maxLength: 254,
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
                const SizedBox(height: 18),
                const SizedBox(height: 5),
                PrimaryButton(
                  label: 'Log In',
                  onPressed: login,
                  isLoading: isLoading,
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
