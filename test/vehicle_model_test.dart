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
}
