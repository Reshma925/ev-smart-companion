import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_ble_protocol/vehicle_ble_protocol.dart';

void main() {
  test('simulator command codec accepts only valid vehicle commands', () {
    final command = VehicleControlCommand.decode(
      const VehicleControlCommand(
        requestId: 'demo-1',
        action: 'speed',
        level: 24,
      ).encode(),
    );

    expect(command.action, 'speed');
    expect(
      applyVehicleCommand(const VehicleControlState(), command).speedKph,
      24,
    );
  });
}
