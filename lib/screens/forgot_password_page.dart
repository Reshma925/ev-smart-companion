import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/common_widgets.dart';
import 'otp_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final identity = TextEditingController();

  @override
  void dispose() {
    identity.dispose();
    super.dispose();
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
                  label: 'Email or Mobile Number',
                  hint: 'Enter email or mobile number',
                  icon: Icons.person_outline,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter your email or mobile number'
                      : null,
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Send OTP',
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OtpPage()),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
