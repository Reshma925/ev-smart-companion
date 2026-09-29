import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../app_theme.dart';
import '../widgets/common_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final identity = TextEditingController();
  late final authService = AuthService();
  bool isLoading = false;

  @override
  void dispose() {
    identity.dispose();
    super.dispose();
  }

  Future<void> sendResetEmail() async {
    if (isLoading || !formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    try {
      await authService.sendPasswordResetEmail(identity.text.trim());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Check your email'),
          content: const Text(
            'If an account exists for that address, Firebase will send a password reset link.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          authService.messageFor(error),
          title: 'Unable to send reset email',
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
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
            child: Column(
              children: [
                const ScreenHeader(
                  title: 'Password Recovery',
                  subtitle: 'We will send a verification code to your account.',
                ),
                const SizedBox(height: 42),
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F3FC),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    size: 40,
                    color: AppTheme.blue,
                  ),
                ),
                const SizedBox(height: 30),
                TextInputField(
                  controller: identity,
                  label: 'Email',
                  hint: 'Enter your account email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null ||
                          !RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(v.trim())
                      ? 'Enter a valid email address'
                      : null,
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Send Reset Link',
                  onPressed: sendResetEmail,
                  isLoading: isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
