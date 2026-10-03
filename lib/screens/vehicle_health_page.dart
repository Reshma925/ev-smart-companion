import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/vehicle.dart';
import '../models/vehicle_telemetry.dart';
import '../services/firestore_service.dart';

class VehicleHealthPage extends StatefulWidget {
  const VehicleHealthPage({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<VehicleHealthPage> createState() => _VehicleHealthPageState();
}

class _VehicleHealthPageState extends State<VehicleHealthPage> {
  late final Stream<Vehicle?> _vehicleStream = FirestoreService()
      .watchVehicleById(widget.vehicle.id);
  late final Stream<VehicleData?> _telemetryStream = FirestoreService()
      .watchVehicleTelemetry(widget.vehicle.id);

  String _scoreStatus(int score) {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Needs attention';
    return 'Critical';
  }

  Color _scoreColor(int score) {
    if (score >= 85) return const Color(0xFF1EA76A);
    if (score >= 70) return AppTheme.blue;
    if (score >= 50) return const Color(0xFFE4A22F);
    return const Color(0xFFD93C4E);
  }

  void _showMetricDetails(
    String title,
    String value,
    String description,
    String status,
    IconData icon,
    Color color,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                description,
                style: const TextStyle(
                  color: AppTheme.mutedBlue,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle health'),
        backgroundColor: AppTheme.background,
      ),
      backgroundColor: AppTheme.background,
      body: StreamBuilder<VehicleData?>(
        stream: _telemetryStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _LoadState(
              title: 'Unable to load vehicle health',
              message: 'Live telemetry is temporarily unavailable. Please retry.',
              onRetry: () => setState(() {}),
            );
          }
          if (!snap.hasData) {
            if (snap.connectionState == ConnectionState.active) {
              return _LoadState(
                title: 'Vehicle telemetry unavailable',
                message:
                    'No live vehicle telemetry is currently available in Firestore.',
                onRetry: () => setState(() {}),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!;
          final score = data.healthScore.clamp(0, 100);
          final status = _scoreStatus(score);
          final color = _scoreColor(score);
          final lastUpdated = data.updatedAt == null
              ? 'Not available'
              : '${MaterialLocalizations.of(context).formatMediumDate(data.updatedAt!.toLocal())} • ${TimeOfDay.fromDateTime(data.updatedAt!.toLocal()).format(context)}';

          final metrics = [
            _MetricCard(
              title: 'Battery health',
              value: '${data.batteryHealth.toStringAsFixed(0)}%',
              status: data.batteryHealth >= 80 ? 'Good' : 'Needs attention',
              icon: Icons.battery_charging_full_rounded,
              color: data.batteryHealth >= 80 ? const Color(0xFF1EA76A) : const Color(0xFFE4A22F),
              description: 'Battery health shows how much of the original capacity remains. A healthy battery supports better range and longer EV life.',
              onTap: () => _showMetricDetails(
                'Battery health',
                '${data.batteryHealth.toStringAsFixed(0)}%',
                'Battery health shows how much of the original capacity remains. A healthy battery supports better range and longer EV life.',
                data.batteryHealth >= 80 ? 'Good' : 'Needs attention',
                Icons.battery_charging_full_rounded,
                data.batteryHealth >= 80 ? const Color(0xFF1EA76A) : const Color(0xFFE4A22F),
              ),
            ),
            _MetricCard(
              title: 'Charging system',
              value: data.isCharging ? 'Charging' : 'Standby',
              status: data.isCharging ? 'Active' : 'Normal',
              icon: Icons.electric_bolt_rounded,
              color: data.isCharging ? const Color(0xFF2388D9) : const Color(0xFF1EA76A),
              description: 'The charging system is currently reporting whether the vehicle is actively charging or waiting in standby mode.',
              onTap: () => _showMetricDetails(
                'Charging system',
                data.isCharging ? 'Charging' : 'Standby',
                'The charging system is currently reporting whether the vehicle is actively charging or waiting in standby mode.',
                data.isCharging ? 'Active' : 'Normal',
                Icons.electric_bolt_rounded,
                data.isCharging ? const Color(0xFF2388D9) : const Color(0xFF1EA76A),
              ),
            ),
            _MetricCard(
              title: 'Vehicle system',
              value: '${data.healthScore}/100',
              status: status,
              icon: Icons.directions_car_rounded,
              color: color,
              description: 'This overall health score combines current battery condition, EV charge level, and live vehicle status into a simple overview.',
              onTap: () => _showMetricDetails(
                'Vehicle system',
                '${data.healthScore}/100',
                'This overall health score combines current battery condition, EV charge level, and live vehicle status into a simple overview.',
                status,
                Icons.directions_car_rounded,
                color,
              ),
            ),
          ];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE5EBF0)),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: 172,
                      height: 172,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: score / 100,
                            strokeWidth: 14,
                            color: color,
                            backgroundColor: const Color(0xFFEAF0F7),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${score.round()}',
                                  style: const TextStyle(
                                    color: AppTheme.navy,
                                    fontSize: 42,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '/ 100',
                                  style: TextStyle(
                                    color: AppTheme.mutedBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<Vehicle?>(
                      stream: _vehicleStream,
                      builder: (context, vehicleSnapshot) {
                        final vehicle = vehicleSnapshot.data;
                        if (vehicleSnapshot.hasError) {
                          return const Text(
                            'Could not refresh vehicle details from Firebase.',
                            style: TextStyle(color: Colors.redAccent),
                          );
                        }
                        if (vehicle == null) {
                          return const Text(
                            'Loading vehicle details from Firebase…',
                            style: TextStyle(color: AppTheme.mutedBlue),
                          );
                        }
                        return Column(
                          children: [
                            text(
                              vehicle.model.isEmpty
                                  ? 'Vehicle model not available'
                                  : vehicle.model,
                              20,
                              FontWeight.w700,
                              AppTheme.navy,
                            ),
                            const SizedBox(height: 4),
                            text(
                              vehicle.registrationNumber.isEmpty
                                  ? 'Registration not available'
                                  : vehicle.registrationNumber,
                              13,
                              FontWeight.w500,
                              AppTheme.mutedBlue,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, color: AppTheme.mutedBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Last updated: $lastUpdated',
                            style: const TextStyle(
                              color: AppTheme.mutedBlue,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Health overview',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...metrics.map((metric) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: metric,
                  )),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppTheme.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The health score uses the latest live telemetry from your vehicle. Values update automatically as Firestore telemetry changes.',
                        style: const TextStyle(
                          color: AppTheme.navy,
                          height: 1.5,
                        ),
                      ),
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

  Widget text(String value, double size, FontWeight weight, Color color) =>
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
        ),
      );
}

class _LoadState extends StatelessWidget {
  const _LoadState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, color: AppTheme.mutedBlue, size: 42),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.mutedBlue, height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.status,
    required this.icon,
    required this.color,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String value;
  final String status;
  final IconData icon;
  final Color color;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EBF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.mutedBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.mutedBlue),
        ],
      ),
    ),
  );
}
