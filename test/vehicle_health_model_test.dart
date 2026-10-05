import 'package:flutter_application_2/models/vehicle_health.dart';
import 'package:flutter_application_2/models/vehicle_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'averages reported component health without inventing missing scores',
    () {
      const telemetry = VehicleData(
        battery: 72,
        range: 300,
        batteryHealth: 90,
        healthScore: 87,
        isCharging: false,
        motorHealth: 80,
        brakeHealth: 70,
        softwareHealth: 100,
      );

      final health = VehicleHealthData.fromTelemetry(telemetry);

      expect(health.score, closeTo(85, 0.01));
      expect(health.component(VehicleHealthComponent.tires).score, isNull);
      expect(
        health.component(VehicleHealthComponent.tires).status,
        VehicleHealthStatus.unavailable,
      );
    },
  );

  test('derives tire status and tips only from reported values', () {
    const telemetry = VehicleData(
      battery: 72,
      range: 300,
      batteryHealth: 90,
      healthScore: 87,
      isCharging: false,
      tirePressureFlPsi: 35,
      tirePressureFrPsi: 29,
      ecoScore: 65,
      hardBrakingEvents: 2,
    );

    final health = VehicleHealthData.fromTelemetry(telemetry);

    expect(health.component(VehicleHealthComponent.tires).score, 76);
    expect(
      health.component(VehicleHealthComponent.tires).status,
      VehicleHealthStatus.attention,
    );
    expect(health.drivingTips, hasLength(2));
    expect(health.drivingTips.join(' '), contains('Gentler acceleration'));
  });

  test('preserves a reported zero as a critical component score', () {
    const telemetry = VehicleData(
      battery: 72,
      range: 300,
      batteryHealth: 0,
      healthScore: 87,
      isCharging: false,
    );

    final health = VehicleHealthData.fromTelemetry(telemetry);

    expect(health.score, 0);
    expect(
      health.component(VehicleHealthComponent.battery).status,
      VehicleHealthStatus.critical,
    );
  });
}
