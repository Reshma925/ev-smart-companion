import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/mock_service.dart';
import '../widgets/common_widgets.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';
import 'vehicle_details_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final identityController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    identityController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void login() {
    if (!formKey.currentState!.validate()) return;
    final identity = identityController.text.trim();
    final hasSavedAccount =
        MockService.accountEmail != null || MockService.accountMobile != null;
    final matchesAccount =
        identity.toLowerCase() == MockService.accountEmail?.toLowerCase() ||
        identity == MockService.accountMobile;
    if (hasSavedAccount &&
        (!matchesAccount ||
            passwordController.text != MockService.accountPassword)) {
      showErrorDialog(
        context,
        'The email/mobile number or password is incorrect.',
        title: 'Login failed',
      );
      return;
    }
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
                  label: 'Email or Mobile Number',
                  hint: 'Enter email or mobile number',
                  icon: Icons.person_outline,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your email or mobile number'
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
                    onPressed: () => Navigator.push(
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
                PrimaryButton(label: 'Log In', onPressed: login),
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
                    onPressed: () {},
                    icon: const Icon(
                      Icons.g_mobiledata,
                      size: 28,
                      color: Colors.black,
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(color: AppTheme.navy),
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
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignUpPage()),
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
