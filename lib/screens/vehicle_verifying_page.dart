import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/vehicle.dart';
import 'vehicle_failed_page.dart';
import 'vehicle_verified_page.dart';

class VehicleVerifyingPage extends StatefulWidget {
  const VehicleVerifyingPage({super.key, required this.vehicle});

  final Vehicle? vehicle;

  @override
  State<VehicleVerifyingPage> createState() => _VehicleVerifyingPageState();
}

class _VehicleVerifyingPageState extends State<VehicleVerifyingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => widget.vehicle == null
              ? const VehicleFailedPage()
              : VehicleVerifiedPage(vehicle: widget.vehicle!),
        ),
      );
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RotationTransition(
                turns: controller,
                child: const SizedBox(
                  width: 88,
                  height: 88,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    color: AppTheme.blue,
                  ),
                ),
              ),
              const SizedBox(height: 34),
              const Text(
                'Verifying Vehicle',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Checking your vehicle details...',
                style: TextStyle(color: AppTheme.mutedBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
