import 'package:flutter/material.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF071326),
          ),

          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 10,
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ==================================================
              // TITLE
              // ==================================================

              const Center(
                child: Text(
                  "Create Your Account",
                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF071326),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              const Center(
                child: Text(
                  "Join EV Smart Companion",
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6F8EAF),
                  ),
                ),
              ),

              const SizedBox(height: 35),

              // ==================================================
              // NAME
              // ==================================================

              const Text(
                "Full Name",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF071326),
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                decoration: InputDecoration(
                  hintText: "Enter your full name",

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
              // EMAIL
              // ==================================================

              const Text(
                "Email",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF071326),
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                keyboardType: TextInputType.emailAddress,

                decoration: InputDecoration(
                  hintText: "Enter your email",

                  prefixIcon: const Icon(
                    Icons.email_outlined,
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
              // MOBILE
              // ==================================================

              const Text(
                "Mobile Number",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF071326),
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                keyboardType: TextInputType.phone,

                decoration: InputDecoration(
                  hintText: "Enter your mobile number",

                  prefixIcon: const Icon(
                    Icons.phone_outlined,
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
                  hintText: "Create a password",

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

              const SizedBox(height: 30),

              // ==================================================
              // CREATE ACCOUNT
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 54,

                child: ElevatedButton(
                  onPressed: () {
                    // Account creation will be connected later.
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
                    "Create Account",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // ==================================================
              // BACK TO LOGIN
              // ==================================================

              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [

                    const Text(
                      "Already have an account?",
                      style: TextStyle(
                        color: Color(0xFF6F8EAF),
                      ),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },

                      child: const Text(
                        "Log In",
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
