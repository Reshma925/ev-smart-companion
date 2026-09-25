import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/vehicle.dart';
import '../widgets/common_widgets.dart';
import 'dashboard_placeholder.dart';

class VehicleConnectedPage extends StatelessWidget {
  const VehicleConnectedPage({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 35, 28, 24),
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
                  Icons.bluetooth_connected,
                  color: Color(0xFF20A36A),
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Connected ✓',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 28),
              VehicleCard(vehicle: vehicle),
              const SizedBox(height: 18),
              const _StatusRow(
                icon: Icons.bluetooth_connected,
                label: 'Bluetooth Connected',
              ),
              const _StatusRow(
                icon: Icons.lock_outline,
                label: 'Connection Secure',
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Continue',
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DashboardPlaceholder(),
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF20A36A), size: 21),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.navy,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        const Icon(Icons.check_circle, color: Color(0xFF20A36A), size: 18),
      ],
    ),
  );
}
