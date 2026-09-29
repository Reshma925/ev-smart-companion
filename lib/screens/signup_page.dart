import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_theme.dart';
import '../models/user_model.dart';
import '../widgets/common_widgets.dart';
import 'vehicle_details_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key, this.authenticatedOnboarding = false});

  final bool authenticatedOnboarding;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final mobile = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.authenticatedOnboarding) {
      final user = FirebaseAuth.instance.currentUser;
      name.text = user?.displayName ?? '';
      email.text = user?.email ?? '';
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    mobile.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  void continueToVehicleRegistration() {
    if (isLoading) return;
    if (!formKey.currentState!.validate()) {
      return;
    }
    final emailAddress = widget.authenticatedOnboarding
        ? FirebaseAuth.instance.currentUser?.email
        : email.text.trim();
    if (emailAddress == null || emailAddress.isEmpty) {
      showErrorDialog(
        context,
        'The authenticated account email is unavailable.',
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VehicleDetailsPage(
          pendingSignup: PendingSignup(
            name: name.text.trim(),
            email: emailAddress,
            mobile: mobile.text.trim(),
            password: widget.authenticatedOnboarding ? null : password.text,
          ),
        ),
      ),
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
                ScreenHeader(
                  title: widget.authenticatedOnboarding
                      ? 'Complete Your Profile'
                      : 'Create Your Account',
                  subtitle: widget.authenticatedOnboarding
                      ? 'Add your details and register an existing vehicle.'
                      : 'Join EV Smart Companion',
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
                if (!widget.authenticatedOnboarding) ...[
                  TextInputField(
                    controller: email,
                    label: 'Email',
                    hint: 'Enter your email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        v == null ||
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(v.trim())
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 18),
                ] else ...[
                  TextFormField(
                    initialValue: email.text,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Authenticated account email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                TextInputField(
                  controller: mobile,
                  label: 'Mobile Number',
                  hint: 'Enter your mobile number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.replaceAll(RegExp(r'\D'), '').length < 10
                      ? 'Enter a valid mobile number'
                      : null,
                ),
                if (!widget.authenticatedOnboarding) ...[
                  const SizedBox(height: 18),
                  PasswordInputField(
                    controller: password,
                    label: 'Password',
                    hint: 'Create a password',
                    validator: (v) =>
                        v == null ||
                            !RegExp(
                              r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$',
                            ).hasMatch(v)
                        ? 'Use 8+ characters with uppercase, lowercase, and a number'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  PasswordInputField(
                    controller: confirmPassword,
                    label: 'Confirm Password',
                    hint: 'Re-enter your password',
                    validator: (v) =>
                        v != password.text ? 'Passwords do not match' : null,
                  ),
                ],
                const SizedBox(height: 30),
                PrimaryButton(
                  label: 'Continue',
                  onPressed: continueToVehicleRegistration,
                  isLoading: isLoading,
                ),
                if (!widget.authenticatedOnboarding) ...[
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
                        onPressed: isLoading
                            ? null
                            : () => Navigator.pop(context),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
