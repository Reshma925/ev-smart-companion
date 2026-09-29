import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/vehicle.dart';
import '../services/vehicle_simulator.dart';

class VehicleHealthPage extends StatefulWidget {
  const VehicleHealthPage({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  State<VehicleHealthPage> createState() => _VehicleHealthPageState();
}

class _VehicleHealthPageState extends State<VehicleHealthPage> {
  // Reads the same live data from Firebase that the dashboard shows
  late final stream = VehicleSimulator(vehicleId: widget.vehicle.id).stream;

  // Sample tyre pressures in PSI (recommended: 33 to 36)
  final tyres = {
    'Front Left': 35,
    'Front Right': 35,
    'Rear Left': 34,
    'Rear Right': 30,
  };

  String status(int score) => score >= 85
      ? 'Excellent'
      : score >= 70
      ? 'Good'
      : 'Needs attention';

  Color statusColor(int score) => score >= 85
      ? Colors.green
      : score >= 70
      ? AppTheme.blue
      : Colors.orange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Health')),
      body: StreamBuilder<VehicleData>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          final temp = d.isCharging ? 38.0 : 31.0; // simple estimate
          final lowTyres = tyres.entries.where((t) => t.value < 33).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Health score gauge
              Center(
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: d.healthScore / 100,
                        strokeWidth: 14,
                        color: statusColor(d.healthScore),
                        backgroundColor: Colors.grey.shade200,
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${d.healthScore}',
                              style: const TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.navy,
                              ),
                            ),
                            Text(
                              status(d.healthScore),
                              style: TextStyle(
                                color: statusColor(d.healthScore),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  widget.vehicle.model,
                  style: const TextStyle(color: AppTheme.mutedBlue),
                ),
              ),

              // Battery
              sectionTitle('Battery'),
              healthRow(
                Icons.favorite_outline,
                'Battery Health',
                '${d.batteryHealth.toStringAsFixed(1)}%',
                d.batteryHealth >= 80,
              ),
              healthRow(
                Icons.battery_std,
                'Charge Level',
                '${d.battery.toStringAsFixed(0)}%',
                d.battery > 20,
              ),
              healthRow(
                Icons.thermostat,
                'Battery Temperature',
                '${temp.toStringAsFixed(0)} °C',
                temp < 40,
              ),
              healthRow(
                Icons.power,
                'Charging',
                d.isCharging ? 'Charging' : 'Not charging',
                true,
              ),

              // Tyre Pressure
              sectionTitle('Tyre Pressure'),
              for (final t in tyres.entries)
                healthRow(
                  Icons.tire_repair,
                  t.key,
                  '${t.value} PSI',
                  t.value >= 33,
                ),
              if (lowTyres.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${lowTyres.map((t) => t.key).join(', ')} tyre pressure is low. '
                    'Low tyre pressure increases rolling resistance and reduces your range.',
                    style: const TextStyle(color: Colors.brown),
                  ),
                ),

              // Components
              sectionTitle('Components'),
              healthRow(Icons.electric_bolt, 'Electric Motor', 'Normal', true),
              healthRow(Icons.car_repair, 'Brakes', 'Normal', true),
              healthRow(Icons.ac_unit, 'Cooling System', 'Normal', true),
              healthRow(
                Icons.battery_charging_full,
                '12V Auxiliary Battery',
                'Normal',
                true,
              ),

              // Learning card
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school, color: AppTheme.blue),
                        SizedBox(width: 8),
                        Text(
                          'What is battery health?',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.navy,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Battery health shows how much energy your battery can hold '
                      'compared to when it was new. It drops slowly as the battery '
                      'ages. Avoiding frequent fast charging, extreme heat, and '
                      'keeping the charge between 20% and 80% helps it last longer.',
                      style: TextStyle(color: AppTheme.navy, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppTheme.navy,
      ),
    ),
  );

  Widget healthRow(IconData icon, String label, String value, bool ok) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9E0E8)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: AppTheme.navy)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            ok ? Icons.check_circle : Icons.warning_amber_rounded,
            color: ok ? Colors.green : Colors.orange,
            size: 20,
          ),
        ],
      ),
    );
  }
}
