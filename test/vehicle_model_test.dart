import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/vehicle.dart';

void main() {
  test('parses a pre-registered vehicle document with Firestore identity', () {
    final vehicle = Vehicle.fromMap({
      'registrationNumber': 'TN01AB1234',
      'model': 'EV Smart X1',
      'ownerName': 'Registered Vehicle Owner 1',
      'vin': 'EVVIN001',
      'bluetoothDeviceId': 'EV-SIM-001',
      'bluetoothDeviceName': 'EV-Simulator-01',
      'isActive': true,
    }, id: 'EV001');

    expect(vehicle.id, 'EV001');
    expect(vehicle.registrationNumber, 'TN01AB1234');
    expect(vehicle.bluetoothDeviceId, 'EV-SIM-001');
    expect(vehicle.bluetoothDeviceName, 'EV-Simulator-01');
    expect(vehicle.isActive, isTrue);
  });

  test('does not treat an inactive vehicle document as active', () {
    final vehicle = Vehicle.fromMap({
      'registrationNumber': 'TN01AB1234',
      'model': 'EV Smart X1',
      'ownerName': 'Registered Vehicle Owner 1',
      'vin': 'EVVIN001',
      'bluetoothDeviceId': 'EV-SIM-001',
      'bluetoothDeviceName': 'EV-Simulator-01',
      'isActive': false,
    }, id: 'EV001');

    expect(vehicle.isActive, isFalse);
  });

  test('reads configured maximum range from known Firestore fields', () {
    final vehicle = Vehicle.fromMap({
      'registrationNumber': 'TN01AB1234',
      'model': 'EV Smart X1',
      'ownerName': 'Registered Vehicle Owner 1',
      'vin': 'EVVIN001',
      'isActive': true,
      'maximumRangeKm': 420,
      'estimatedRange': 210,
    }, id: 'EV001');

    expect(vehicle.maximumRangeKm, 420);
  });

  test('reads battery values stored on the registered Firestore vehicle', () {
    final vehicle = Vehicle.fromMap({
      'registrationNumber': 'TN01AB1234',
      'model': 'EV Smart X1',
      'ownerName': 'Registered Vehicle Owner 1',
      'vin': 'EVVIN001',
      'isActive': true,
      'battery': '54',
      'maximumRangeKm': 400,
    }, id: 'EV001');

    expect(vehicle.batteryPercentage, 54);
    expect(vehicle.maximumRangeKm, 400);
  });

  test(
    'skips malformed preferred values in favor of valid Firestore aliases',
    () {
      final vehicle = Vehicle.fromMap({
        'registrationNumber': 'TN01AB1234',
        'model': 'EV Smart X1',
        'ownerName': 'Registered Vehicle Owner 1',
        'vin': 'EVVIN001',
        'isActive': true,
        'batteryPercentage': 'unknown',
        'battery': 54,
        'maximumRangeKm': 'unknown',
        'maxRangeKm': 400,
      }, id: 'EV001');

      expect(vehicle.batteryPercentage, 54);
      expect(vehicle.maximumRangeKm, 400);
    },
  );

  test('does not invent a maximum range when Firestore has no range field', () {
    final vehicle = Vehicle.fromMap({
      'registrationNumber': 'TN01AB1234',
      'model': 'EV Smart X1',
      'ownerName': 'Registered Vehicle Owner 1',
      'vin': 'EVVIN001',
      'isActive': true,
    }, id: 'EV001');

    expect(vehicle.maximumRangeKm, isNull);
    expect(vehicle.batteryCapacityKwh, isNull);
  });

  test(
    'serializes configured vehicle range using its Firestore field name',
    () {
      const vehicle = Vehicle(
        model: 'EV Smart X1',
        registrationNumber: 'TN01AB1234',
        ownerName: 'Registered Vehicle Owner 1',
        vin: 'EVVIN001',
        maximumRangeKm: 420,
        batteryCapacityKwh: 72,
        connectorType: 'CCS2',
      );

      final map = vehicle.toMap();
      expect(map['maximumRangeKm'], 420);
      expect(map['batteryCapacityKwh'], 72);
      expect(map['connectorType'], 'CCS2');
      expect(map.containsKey('estimatedRange'), isFalse);
    },
  );

  test('keeps the rated range distinct from telemetry estimated range', () {
    final vehicle = Vehicle.fromMap({
      'model': 'EV Smart X1',
      'maximumRangeKm': 283.8888888888889,
    }, id: 'EV001');

    expect(vehicle.maximumRangeKm, closeTo(283.8888888888889, 0.000001));
    expect(vehicle.estimatedRangeKm, vehicle.maximumRangeKm);
  });
}
