import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/services/vehicle_ble_client.dart';
import 'package:flutter_application_2/widgets/vehicle_ble_state_view.dart';
import 'package:vehicle_ble_protocol/vehicle_ble_protocol.dart';

void main() {
  test('application BLE client is a single shared instance', () {
    expect(VehicleBleClient.shared, same(VehicleBleClient.shared));
  });

  testWidgets('all consumers update and clear together on disconnect', (
    tester,
  ) async {
    final client = VehicleBleClient.shared;
    addTearDown(() => client.snapshot.value = null);

    Widget consumer() => VehicleBleStateView(
      builder: (context, _, snapshot) => Text(
        snapshot == null ? 'N/A' : '${snapshot.state.batteryPercent.round()}%',
      ),
    );

    client.snapshot.value = const VehicleStateSnapshot(
      vehicleId: 'vehicle-1',
      sequence: 1,
      timestampMillis: 1,
      state: VehicleControlState(batteryPercent: 64, rangeKm: 210),
    );
    await tester.pumpWidget(
      MaterialApp(home: Column(children: [consumer(), consumer()])),
    );
    expect(find.text('64%'), findsNWidgets(2));

    client.snapshot.value = null;
    await tester.pump();
    expect(find.text('N/A'), findsNWidgets(2));
  });
}
