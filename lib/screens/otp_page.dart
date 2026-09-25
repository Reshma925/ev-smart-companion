import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/mock_service.dart';
import '../widgets/common_widgets.dart';
import 'reset_password_page.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final otp = TextEditingController();

  @override
  void dispose() {
    otp.dispose();
    super.dispose();
  }

  void verify() {
    if (otp.text.trim() != MockService.otp) {
      showErrorDialog(
        context,
        'The verification code is invalid. Please try again.',
        title: 'Invalid OTP',
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
          child: Column(
            children: [
              const ScreenHeader(
                title: 'OTP Verification',
                subtitle: 'Enter the 6-digit code sent to you.',
              ),
              const SizedBox(height: 45),
              TextField(
                controller: otp,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 9,
                  color: AppTheme.navy,
                ),
                decoration: const InputDecoration(
                  hintText: '••••••',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 28),
              PrimaryButton(label: 'Verify OTP', onPressed: verify),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Resend code',
                  style: TextStyle(
                    color: AppTheme.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
