import 'package:flutter/material.dart';
import '../services/mock_service.dart';
import '../widgets/common_widgets.dart';
import 'login_page.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final password = TextEditingController();
  final confirm = TextEditingController();

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  void reset() {
    if (!formKey.currentState!.validate()) return;
    MockService.accountPassword = password.text;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
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
                  title: 'Create New Password',
                  subtitle: 'Choose a strong password for your account.',
                ),
                const SizedBox(height: 42),
                PasswordInputField(
                  controller: password,
                  label: 'New Password',
                  hint: 'Enter new password',
                  validator: (v) => v == null || v.length < 6
                      ? 'Use at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 18),
                PasswordInputField(
                  controller: confirm,
                  label: 'Confirm Password',
                  hint: 'Re-enter new password',
                  validator: (v) =>
                      v != password.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 30),
                PrimaryButton(label: 'Save Password', onPressed: reset),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
