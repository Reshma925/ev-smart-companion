import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/vehicle.dart';
import 'vehicle_connected_page.dart';

class BluetoothScanningPage extends StatefulWidget {
  const BluetoothScanningPage({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<BluetoothScanningPage> createState() => _BluetoothScanningPageState();
}

class _BluetoothScanningPageState extends State<BluetoothScanningPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  bool found = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => found = true);
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
          child: Column(
            children: [
              const Text(
                'Connect Vehicle',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 35),
              RotationTransition(
                turns: controller,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F3FC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bluetooth_searching,
                    size: 55,
                    color: AppTheme.blue,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                found ? 'Vehicle Found' : 'Searching for nearby vehicle...',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 25),
              if (found)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDCE6F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.directions_car_outlined,
                        color: AppTheme.blue,
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EV-Simulator-01',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.navy,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Available',
                              style: TextStyle(
                                color: Color(0xFF20A36A),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 95,
                        height: 42,
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VehicleConnectedPage(vehicle: widget.vehicle),
                            ),
                          ),
                          child: const Text(
                            'CONNECT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Text(
                  'Make sure your vehicle is nearby and ready to connect.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.mutedBlue),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
