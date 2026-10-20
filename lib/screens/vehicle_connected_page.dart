import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/vehicle.dart';
import '../widgets/common_widgets.dart';
import 'homescreen.dart';

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
                  color: Color(0xFFE8F3FC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bluetooth_disabled,
                  color: AppTheme.blue,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Vehicle profile ready',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 28),
              VehicleCard(vehicle: vehicle),
              const SizedBox(height: 10),
              Text(
                vehicle.bluetoothDeviceName.isEmpty
                    ? 'Bluetooth name unavailable'
                    : vehicle.bluetoothDeviceName,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (vehicle.bluetoothDeviceId.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  vehicle.bluetoothDeviceId,
                  style: const TextStyle(color: AppTheme.mutedBlue),
                ),
              ],
              const SizedBox(height: 18),
              const _StatusRow(
                icon: Icons.bluetooth_disabled,
                label: 'Bluetooth connection not established',
              ),
              const _StatusRow(
                icon: Icons.lock_outline,
                label: 'Vehicle identity loaded from Firestore',
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Continue',
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomeScreen(vehicle: vehicle),
                  ),
                  (route) => false,
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
        Icon(icon, color: AppTheme.blue, size: 21),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.navy,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
