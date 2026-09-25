import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/vehicle.dart';
import '../widgets/common_widgets.dart';
import 'connect_vehicle_page.dart';

class VehicleVerifiedPage extends StatelessWidget {
  const VehicleVerifiedPage({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: Color(0xFFE5F8EF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF20A36A),
                  size: 55,
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                'Vehicle Verified ✓',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your vehicle details match our records.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.mutedBlue),
              ),
              const SizedBox(height: 32),
              VehicleCard(vehicle: vehicle),
              const SizedBox(height: 30),
              PrimaryButton(
                label: 'Continue',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConnectVehiclePage(vehicle: vehicle),
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
