import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'register.dart';
import 'forgot.dart';
import 'start.dart';
import 'dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final email = TextEditingController();
  final pass = TextEditingController();

  bool obscure = true;
  bool loading = false;

  late AnimationController _controller;
  late Animation<double> fadeAnimation;

  // DARK GREEN THEME
  static const Color cyberGreen = Color(0xFF00E676);
  static const Color neonGreen = Color(0xFF69F0AE);
  static const Color silver = Color(0xFFB8DCC5);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  Future<void> login() async {
    if (email.text.trim().isEmpty || pass.text.trim().isEmpty) {
      show("Please fill in all fields");
      return;
    }

    setState(() => loading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: pass.text.trim(),
      );

      final user = cred.user;

      if (user == null) {
        show("User not found");
        setState(() => loading = false);
        return;
      }

      if (!user.emailVerified) {
        await FirebaseAuth.instance.signOut();

        show(
          "Please verify your email before logging in.",
        );

        setState(() => loading = false);
        return;
      }

      // ✅ FIX: Check if widget is mounted before using BuildContext
      if (!mounted) return;

      setState(() => loading = false);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardPage(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String errorMsg = "Login failed";

      if (e.code == 'user-not-found') {
        errorMsg = "No account found for this email.";
      } else if (e.code == 'wrong-password') {
        errorMsg = "Incorrect password.";
      } else if (e.code == 'invalid-email') {
        errorMsg = "The email address is invalid.";
      }

      show(e.message ?? errorMsg);

      setState(() => loading = false);
    } catch (e) {
      show("An unexpected error occurred");
      setState(() => loading = false);
    }
  }

  void show(String msg) {
    // ✅ FIX: Check if widget is mounted before using BuildContext
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF08110D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // BACKGROUND
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF020A07),
                  Color(0xFF071A12),
                  Color(0xFF010403),
                ],
              ),
            ),
          ),

          // GREEN LIGHT GLOW TOP
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // ✅ FIX: Replaced withOpacity with withValues
                color: cyberGreen.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    // ✅ FIX: Replaced withOpacity with withValues
                    color: cyberGreen.withValues(alpha: 0.15),
                    blurRadius: 120,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // GREEN LIGHT GLOW BOTTOM
          Positioned(
            bottom: -120,
            left: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // ✅ FIX: Replaced withOpacity with withValues
                color: neonGreen.withValues(alpha: 0.05),
              ),
            ),
          ),

          // CYBER GRID
          Positioned.fill(
            child: CustomPaint(
              painter: CyberGridPainter(),
            ),
          ),

          // BACK BUTTON
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 10,
                top: 5,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StartPage(),
                    ),
                  );
                },
              ),
            ),
          ),

          // CONTENT
          SafeArea(
            child: FadeTransition(
              opacity: fadeAnimation,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome Back",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "Secure login to your MotoGuard system",
                        // ✅ FIX: Replaced withOpacity with withValues
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 35),

                      // GLASS CARD
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: 18,
                            sigmaY: 18,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              // ✅ FIX: Replaced withOpacity with withValues
                              color: Colors.white.withValues(alpha: 0.05),
                              border: Border.all(
                                // ✅ FIX: Replaced withOpacity with withValues
                                color: cyberGreen.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Column(
                              children: [
                                buildField(
                                  email,
                                  "Email Address",
                                  Icons.alternate_email_rounded,
                                ),

                                buildField(
                                  pass,
                                  "Password",
                                  Icons.lock_outline_rounded,
                                  obscure: obscure,
                                  toggle: () {
                                    setState(() {
                                      obscure = !obscure;
                                    });
                                  },
                                ),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ForgotPage(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      "Forgot Password?",
                                      style: TextStyle(
                                        color: cyberGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // LOGIN BUTTON
                                SizedBox(
                                  width: double.infinity,
                                  height: 58,
                                  child: ElevatedButton(
                                    onPressed: loading ? null : login,
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: cyberGreen,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.black,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            "LOGIN",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 18),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 14,
                                      // ✅ FIX: Replaced withOpacity with withValues
                                      color: silver.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "SECURE CONNECTION ACTIVE",
                                      style: TextStyle(
                                        // ✅ FIX: Replaced withOpacity with withValues
                                        color: Colors.white
                                            .withValues(alpha: 0.35),
                                        fontSize: 10,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // CREATE ACCOUNT
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "New here? ",
                              // ✅ FIX: Replaced withOpacity with withValues
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Create Account",
                                style: TextStyle(
                                  color: cyberGreen,
                                  fontWeight: FontWeight.bold,
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
          ),
        ],
      ),
    );
  }

  Widget buildField(
    TextEditingController c,
    String hint,
    IconData icon, {
    bool obscure = false,
    VoidCallback? toggle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        obscureText: obscure,
        style: const TextStyle(
          color: Colors.white,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: cyberGreen,
          ),
          hintText: hint,
          hintStyle: TextStyle(
            // ✅ FIX: Replaced withOpacity with withValues
            color: Colors.white.withValues(alpha: 0.35),
          ),
          filled: true,
          // ✅ FIX: Replaced withOpacity with withValues
          fillColor: Colors.white.withValues(alpha: 0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              // ✅ FIX: Replaced withOpacity with withValues
              color: cyberGreen.withValues(alpha: 0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: cyberGreen,
            ),
          ),
          suffixIcon: toggle != null
              ? IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white54,
                  ),
                  onPressed: toggle,
                )
              : null,
        ),
      ),
    );
  }
}

class CyberGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      // ✅ FIX: Replaced withOpacity with withValues
      ..color = Colors.greenAccent.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    const spacing = 45.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}