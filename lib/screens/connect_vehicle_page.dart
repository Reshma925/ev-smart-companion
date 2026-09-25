import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/vehicle.dart';
import '../widgets/common_widgets.dart';
import 'bluetooth_scanning_page.dart';

class ConnectVehiclePage extends StatelessWidget {
  const ConnectVehiclePage({super.key, required this.vehicle});

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
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3FC),
                  borderRadius: BorderRadius.circular(42),
                ),
                child: const Icon(
                  Icons.electric_car,
                  size: 82,
                  color: AppTheme.blue,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Vehicle Verified ✓',
                style: TextStyle(
                  color: Color(0xFF20A36A),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                vehicle.model,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Ready to Connect',
                style: TextStyle(color: AppTheme.mutedBlue, fontSize: 15),
              ),
              const SizedBox(height: 36),
              PrimaryButton(
                label: 'Connect Vehicle',
                icon: Icons.bluetooth,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BluetoothScanningPage(vehicle: vehicle),
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
