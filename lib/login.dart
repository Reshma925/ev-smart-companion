import 'package:flutter/material.dart';
import 'signup.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 35,
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ==================================================
              // SMALL LOGO
              // ==================================================

              Center(
                child: Container(
                  width: 75,
                  height: 75,

                  decoration: const BoxDecoration(
                    color: Color(0xFF071326),
                    shape: BoxShape.circle,
                  ),

                  child: const Icon(
                    Icons.bolt,
                    color: Color(0xFF35A9E1),
                    size: 43,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // TITLE
              // ==================================================

              const Center(
                child: Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF071326),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              const Center(
                child: Text(
                  "Login to continue with your EV",
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6F8EAF),
                  ),
                ),
              ),

              const SizedBox(height: 38),

              // ==================================================
              // EMAIL
              // ==================================================

              const Text(
                "Email or Mobile Number",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF071326),
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                decoration: InputDecoration(
                  hintText: "Enter email or mobile number",

                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF6383AA),
                  ),

                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // PASSWORD
              // ==================================================

              const Text(
                "Password",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF071326),
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                obscureText: true,

                decoration: InputDecoration(
                  hintText: "Enter your password",

                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Color(0xFF6383AA),
                  ),

                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              // ==================================================
              // FORGOT PASSWORD
              // ==================================================

              Align(
                alignment: Alignment.centerRight,

                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(
                      color: Color(0xFF2388D9),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 5),

              // ==================================================
              // LOGIN BUTTON
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 54,

                child: ElevatedButton(
                  onPressed: () {
                    // Login functionality will be added later.
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF071326),
                    foregroundColor: Colors.white,
                    elevation: 0,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),

                  child: const Text(
                    "Log In",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // ==================================================
              // OR
              // ==================================================

              Row(
                children: [

                  const Expanded(
                    child: Divider(
                      color: Color(0xFFD9E0E8),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                    ),

                    child: Text(
                      "OR",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  const Expanded(
                    child: Divider(
                      color: Color(0xFFD9E0E8),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // ==================================================
              // GOOGLE
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 54,

                child: OutlinedButton.icon(
                  onPressed: () {},

                  icon: const Icon(
                    Icons.g_mobiledata,
                    size: 30,
                    color: Colors.black,
                  ),

                  label: const Text(
                    "Continue with Google",
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF071326),
                    ),
                  ),

                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFFD9E0E8),
                    ),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // SIGN UP
              // ==================================================

              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    const Text(
                      "Don't have an account?",
                      style: TextStyle(
                        color: Color(0xFF6F8EAF),
                      ),
                    ),

                    TextButton(
                      onPressed: () {

                        // GO TO SIGN UP PAGE
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const SignUpPage(),
                          ),
                        );

                      },

                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          color: Color(0xFF2388D9),
                          fontWeight: FontWeight.w600,
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
    );
  }
}
