import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    final emulatorHost = kIsWeb
        ? '127.0.0.1'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => '10.0.2.2',
            _ => '127.0.0.1',
          };
    FirebaseFunctions.instance.useFunctionsEmulator(emulatorHost, 5001);
    debugPrint('[Firebase DEBUG] Functions emulator: $emulatorHost:5001');
  }
  runApp(const EVSmartCompanionApp());
}

class EVSmartCompanionApp extends StatelessWidget {
  const EVSmartCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.data,
      themeMode: ThemeMode.light,
      home: const EVHomePage(),
    );
  }
}

class EVHomePage extends StatefulWidget {
  const EVHomePage({super.key});

  @override
  State<EVHomePage> createState() => _EVHomePageState();
}

class _EVHomePageState extends State<EVHomePage> with TickerProviderStateMixin {
  late AnimationController logoController;
  late AnimationController textController;

  late Animation<double> logoScale;
  late Animation<double> logoFade;

  late Animation<double> titleFade;
  late Animation<Offset> titleSlide;

  late Animation<double> subtitleFade;
  late Animation<Offset> subtitleSlide;

  @override
  void initState() {
    super.initState();

    // ============================================================
    // LOGO ANIMATION
    // ============================================================

    logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: logoController, curve: Curves.easeOutBack),
    );

    logoFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: logoController, curve: Curves.easeIn));

    // ============================================================
    // TEXT ANIMATION
    // ============================================================

    textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    titleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: textController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          ),
        );

    subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: textController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeIn),
      ),
    );

    subtitleSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: textController,
            curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
          ),
        );

    // ============================================================
    // START LOGO
    // ============================================================

    logoController.forward();

    // ============================================================
    // START TEXT AFTER LOGO HAS STARTED
    // ============================================================

    Future.delayed(const Duration(milliseconds: 700), () async {
      if (!mounted) return;

      await textController.forward();

      if (!mounted) return;

      // ========================================================
      // 1 SECOND PAUSE AFTER ANIMATION
      // ========================================================

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      // ========================================================
      // SMOOTH TRANSITION TO LOGIN PAGE
      // ========================================================

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),

          pageBuilder: (context, animation, secondaryAnimation) {
            return const AuthGate();
          },

          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    logoController.dispose();
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ==================================================
                // ANIMATED LOGO
                // ==================================================
                FadeTransition(
                  opacity: logoFade,
                  child: ScaleTransition(
                    scale: logoScale,
                    child: SizedBox(
                      width: 340,
                      height: 340 * 480 / 650,
                      child: CustomPaint(painter: EVLogoPainter()),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ==================================================
                // ANIMATED TITLE
                // ==================================================
                FadeTransition(
                  opacity: titleFade,
                  child: SlideTransition(
                    position: titleSlide,
                    child: const Text(
                      "EV Smart Companion",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF071326),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ==================================================
                // ANIMATED SUBTITLE
                // ==================================================
                FadeTransition(
                  opacity: subtitleFade,
                  child: SlideTransition(
                    position: subtitleSlide,
                    child: const Text(
                      "DRIVE SMARTER. CHARGE SIMPLER.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6F8EAF),
                        letterSpacing: 2.2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// EV LOGO PAINTER
// ================================================================

class EVLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Preserve the supplied logo's 650 × 480 design geometry.
    canvas.scale(size.width / 650, size.height / 480);

    final bgPaint = Paint()..color = const Color(0xFF0B1524);
    canvas.drawCircle(const Offset(325, 232), 232, bgPaint);

    final outline = Paint()
      ..color = const Color(0xFF5B7FA8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final body = Path()
      ..moveTo(180, 370)
      ..cubicTo(120, 320, 108, 260, 108, 200)
      ..cubicTo(108, 110, 200, 62, 325, 62)
      ..cubicTo(450, 62, 542, 110, 542, 200)
      ..cubicTo(542, 260, 530, 320, 468, 370)
      ..lineTo(468, 402)
      ..quadraticBezierTo(468, 420, 450, 420)
      ..lineTo(430, 420)
      ..quadraticBezierTo(412, 420, 412, 402)
      ..lineTo(412, 388)
      ..lineTo(238, 388)
      ..lineTo(238, 402)
      ..quadraticBezierTo(238, 420, 220, 420)
      ..lineTo(200, 420)
      ..quadraticBezierTo(180, 420, 180, 402)
      ..close();
    canvas.drawPath(body, outline);

    canvas.drawCircle(const Offset(200, 332), 22, outline);
    canvas.drawCircle(const Offset(448, 332), 22, outline);

    final bolt = Path()
      ..moveTo(358, 118)
      ..lineTo(273, 247)
      ..lineTo(322, 247)
      ..lineTo(289, 348)
      ..lineTo(388, 217)
      ..lineTo(340, 217)
      ..close();

    final boltPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3A9AD9), Color(0xFF2DBE8E)],
      ).createShader(const Rect.fromLTWH(273, 118, 115, 230));
    canvas.drawPath(bolt, boltPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
