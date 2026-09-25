import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/mock_service.dart';
import '../widgets/common_widgets.dart';
import 'vehicle_details_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final mobile = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    mobile.dispose();
    password.dispose();
    super.dispose();
  }

  void createAccount() {
    if (!formKey.currentState!.validate()) {
      showErrorDialog(
        context,
        'Please fill in every required field correctly.',
      );
      return;
    }
    MockService.accountName = name.text.trim();
    MockService.accountEmail = email.text.trim();
    MockService.accountMobile = mobile.text.trim();
    MockService.accountPassword = password.text;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VehicleDetailsPage()),
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
                  title: 'Create Your Account',
                  subtitle: 'Join EV Smart Companion',
                ),
                const SizedBox(height: 34),
                TextInputField(
                  controller: name,
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  icon: Icons.person_outline,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter your full name'
                      : null,
                ),
                const SizedBox(height: 18),
                TextInputField(
                  controller: email,
                  label: 'Email',
                  hint: 'Enter your email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 18),
                TextInputField(
                  controller: mobile,
                  label: 'Mobile Number',
                  hint: 'Enter your mobile number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.trim().length < 10
                      ? 'Enter a valid mobile number'
                      : null,
                ),
                const SizedBox(height: 18),
                PasswordInputField(
                  controller: password,
                  label: 'Password',
                  hint: 'Create a password',
                  validator: (v) => v == null || v.length < 6
                      ? 'Use at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 30),
                PrimaryButton(
                  label: 'Create Account',
                  onPressed: createAccount,
                ),
                const SizedBox(height: 19),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Already have an account?',
                      style: TextStyle(color: AppTheme.mutedBlue),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Log In',
                        style: TextStyle(
                          color: AppTheme.blue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
