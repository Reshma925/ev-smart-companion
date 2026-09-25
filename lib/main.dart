import 'dart:math';
import 'package:flutter/material.dart';
import 'login.dart';
import 'app_theme.dart';

void main() {
  runApp(const EVSmartCompanionApp());
}

class EVSmartCompanionApp extends StatelessWidget {
  const EVSmartCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.data,
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
            return const LoginPage();
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
                      height: 340,
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
    final center = Offset(size.width / 2, size.height / 2);

    // ============================================================
    // MAIN DARK CIRCLE
    // ============================================================

    final double radius = size.width * 0.46;

    final Paint outerPaint = Paint()
      ..color = const Color(0xFF071326)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, outerPaint);

    // ============================================================
    // COMPLETE INNER CIRCLE
    // ============================================================

    final Paint linePaint = Paint()
      ..color = const Color(0xFF6383AA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Rect innerCircle = Rect.fromCircle(
      center: center,
      radius: radius * 0.80,
    );

    canvas.drawArc(innerCircle, 0, 2 * pi, false, linePaint);

    // ============================================================
    // LIGHTNING BOLT
    // ============================================================

    final Path lightning = Path();

    lightning.moveTo(center.dx + 42, center.dy - 110);

    lightning.lineTo(center.dx - 64, center.dy + 8);

    lightning.lineTo(center.dx - 10, center.dy + 8);

    lightning.lineTo(center.dx - 42, center.dy + 135);

    lightning.lineTo(center.dx + 82, center.dy - 32);

    lightning.lineTo(center.dx + 27, center.dy - 32);

    lightning.close();

    // ============================================================
    // LIGHTNING GRADIENT
    // ============================================================

    final Paint lightningPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF35A9E1), Color(0xFF20D0A0)],
      ).createShader(Rect.fromCenter(center: center, width: 160, height: 260));

    canvas.drawPath(lightning, lightningPaint);

    // ============================================================
    // CHARGING TERMINALS
    // ============================================================

    final Paint terminalPaint = Paint()
      ..color = const Color(0xFF6383AA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final Offset leftTerminal = Offset(center.dx - 78, center.dy + 100);

    canvas.drawCircle(leftTerminal, 25, terminalPaint);

    final Offset rightTerminal = Offset(center.dx + 78, center.dy + 100);

    canvas.drawCircle(rightTerminal, 25, terminalPaint);

    // ============================================================
    // LEFT CONNECTOR
    // ============================================================

    final Path leftConnector = Path();

    leftConnector.moveTo(center.dx - 102, center.dy + 120);

    leftConnector.lineTo(center.dx - 102, center.dy + 153);

    leftConnector.quadraticBezierTo(
      center.dx - 102,
      center.dy + 168,
      center.dx - 87,
      center.dy + 168,
    );

    leftConnector.lineTo(center.dx - 66, center.dy + 168);

    leftConnector.quadraticBezierTo(
      center.dx - 51,
      center.dy + 168,
      center.dx - 51,
      center.dy + 153,
    );

    leftConnector.lineTo(center.dx - 51, center.dy + 132);

    canvas.drawPath(leftConnector, terminalPaint);

    // ============================================================
    // RIGHT CONNECTOR
    // ============================================================

    final Path rightConnector = Path();

    rightConnector.moveTo(center.dx + 102, center.dy + 120);

    rightConnector.lineTo(center.dx + 102, center.dy + 153);

    rightConnector.quadraticBezierTo(
      center.dx + 102,
      center.dy + 168,
      center.dx + 87,
      center.dy + 168,
    );

    rightConnector.lineTo(center.dx + 66, center.dy + 168);

    rightConnector.quadraticBezierTo(
      center.dx + 51,
      center.dy + 168,
      center.dx + 51,
      center.dy + 153,
    );

    rightConnector.lineTo(center.dx + 51, center.dy + 132);

    canvas.drawPath(rightConnector, terminalPaint);

    // ============================================================
    // BOTTOM CONNECTION
    // ============================================================

    canvas.drawLine(
      Offset(center.dx - 51, center.dy + 153),
      Offset(center.dx + 51, center.dy + 153),
      terminalPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
