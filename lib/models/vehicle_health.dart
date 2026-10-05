import 'package:cloud_firestore/cloud_firestore.dart';

import 'vehicle_telemetry.dart';

enum VehicleHealthComponent { battery, motor, tires, brakes, software }

enum VehicleHealthStatus { healthy, attention, critical, unavailable }

class ComponentHealth {
  const ComponentHealth({
    required this.component,
    required this.score,
    required this.status,
  });

  final VehicleHealthComponent component;
  final double? score;
  final VehicleHealthStatus status;

  String get label => switch (component) {
    VehicleHealthComponent.battery => 'Battery',
    VehicleHealthComponent.motor => 'Motor',
    VehicleHealthComponent.tires => 'Tires',
    VehicleHealthComponent.brakes => 'Brakes',
    VehicleHealthComponent.software => 'Software',
  };

  static VehicleHealthStatus statusFor(double? score) {
    if (score == null || !score.isFinite) return VehicleHealthStatus.unavailable;
    if (score < 60) return VehicleHealthStatus.critical;
    if (score < 80) return VehicleHealthStatus.attention;
    return VehicleHealthStatus.healthy;
  }
}

class VehicleHealthData {
  VehicleHealthData.fromTelemetry(this.telemetry)
    : components = _componentsFrom(telemetry),
      score = _scoreFrom(telemetry);

  final VehicleData telemetry;
  final List<ComponentHealth> components;
  final double score;

  String get overallStatus => switch (ComponentHealth.statusFor(score)) {
    VehicleHealthStatus.healthy => 'GOOD HEALTH',
    VehicleHealthStatus.attention => 'NEEDS ATTENTION',
    VehicleHealthStatus.critical => 'REQUIRES SERVICE',
    VehicleHealthStatus.unavailable => 'STATUS UNAVAILABLE',
  };

  ComponentHealth component(VehicleHealthComponent component) =>
      components.firstWhere((value) => value.component == component);

  List<String> get drivingTips {
    final tips = <String>[];
    final ecoScore = telemetry.ecoScore;
    if (ecoScore != null && ecoScore < 75) {
      tips.add('Gentler acceleration can help improve your efficiency score.');
    }
    final brakingEvents = telemetry.hardBrakingEvents;
    if (brakingEvents != null && brakingEvents > 0) {
      tips.add(
        'Leave a little more space to reduce hard-braking events and recover more energy.',
      );
    }
    final efficiency = telemetry.efficiencyKmPerKwh;
    if (efficiency != null && efficiency > 0 && efficiency < 5) {
      tips.add(
        'A steady pace can help improve your recent ${efficiency.toStringAsFixed(1)} km/kWh efficiency.',
      );
    }
    final recovered = telemetry.regenerativeEnergyKwh;
    if (recovered != null && recovered > 0) {
      tips.add(
        'You recovered ${recovered.toStringAsFixed(1)} kWh through regenerative braking in the reported period.',
      );
    }
    return tips;
  }

  static List<ComponentHealth> _componentsFrom(VehicleData telemetry) {
    final pressures = [
      telemetry.tirePressureFlPsi,
      telemetry.tirePressureFrPsi,
      telemetry.tirePressureRlPsi,
      telemetry.tirePressureRrPsi,
    ].whereType<double>().toList();
    final tireScore = pressures.isEmpty
        ? null
        : pressures
                  .map((pressure) {
                    final deviation = (pressure - 35).abs();
                    return (100 - deviation * 8).clamp(0, 100).toDouble();
                  })
                  .reduce((first, second) => first + second) /
              pressures.length;
    final scores = <VehicleHealthComponent, double?>{
      VehicleHealthComponent.battery: _boundedScore(telemetry.batteryHealth),
      VehicleHealthComponent.motor: _boundedScore(telemetry.motorHealth),
      VehicleHealthComponent.tires: tireScore,
      VehicleHealthComponent.brakes: _boundedScore(telemetry.brakeHealth),
      VehicleHealthComponent.software: _boundedScore(telemetry.softwareHealth),
    };
    return scores.entries
        .map(
          (entry) => ComponentHealth(
            component: entry.key,
            score: entry.value,
            status: ComponentHealth.statusFor(entry.value),
          ),
        )
        .toList(growable: false);
  }

  static double _scoreFrom(VehicleData telemetry) {
    final componentScores = _componentsFrom(
      telemetry,
    ).map((component) => component.score).whereType<double>().toList();
    if (componentScores.isEmpty) return telemetry.healthScore.toDouble();
    return componentScores.reduce((first, second) => first + second) /
        componentScores.length;
  }

  static double? _boundedScore(double? score) {
    if (score == null || !score.isFinite) return null;
    return score.clamp(0, 100).toDouble();
  }
}

class VehicleMaintenanceRecord {
  const VehicleMaintenanceRecord({
    required this.id,
    required this.serviceType,
    required this.status,
    this.serviceDate,
    this.nextServiceDate,
    this.serviceCenter,
    this.notes,
  });

  final String id;
  final String serviceType;
  final String status;
  final DateTime? serviceDate;
  final DateTime? nextServiceDate;
  final String? serviceCenter;
  final String? notes;

  factory VehicleMaintenanceRecord.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) => VehicleMaintenanceRecord(
    id: id,
    serviceType: map['serviceType'] as String? ?? 'Service',
    status: map['status'] as String? ?? 'Completed',
    serviceDate: _date(map['serviceDate']),
    nextServiceDate: _date(map['nextServiceDate']),
    serviceCenter: map['serviceCenter'] as String?,
    notes: map['notes'] as String?,
  );

  static DateTime? _date(Object? value) => switch (value) {
    Timestamp() => value.toDate(),
    DateTime() => value,
    _ => null,
  };
}
