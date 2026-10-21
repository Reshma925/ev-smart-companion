import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/vehicle.dart';
import 'package:flutter_application_2/screens/vehicle_controls_page.dart';
import 'package:flutter_application_2/services/vehicle_ble_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_ble_protocol/vehicle_ble_protocol.dart';

import 'support/fake_api.dart';

void main() {
  const vehicle = Vehicle(
    id: 'controls-test-ev',
    model: 'EV Smart X1',
    registrationNumber: 'TEST-001',
    ownerName: 'Driver',
    vin: 'TEST-VIN',
    isActive: true,
  );

  testWidgets(
    'shows live values from the shared BLE snapshot and placeholders without one',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ble = VehicleBleClient.shared;
      ble.snapshot.value = const VehicleStateSnapshot(
        vehicleId: 'controls-test-ev',
        sequence: 1,
        timestampMillis: 1,
        state: VehicleControlState(
          batteryPercent: 64,
          rangeKm: 224,
          targetTemperatureC: 23,
          targetChargePercent: 90,
        ),
      );
      addTearDown(() => ble.snapshot.value = null);
      final phaseBefore = ble.phase;

      final api = FakeApi()
        ..on(
          'GET /v1/vehicles/controls-test-ev/controls-preferences',
          (_) => {
            'vehicleId': 'controls-test-ev',
            'preferences': {
              'notificationsEnabled': true,
              'safetyAlertsEnabled': true,
              'batteryAlertsEnabled': true,
              'chargingAlertsEnabled': true,
              'passengerProfiles': <Object>[],
              'selectedProfileId': null,
              'alertHistory': <Object>[],
              'activeAlertKeys': <Object>[],
            },
          },
        );

      await tester.pumpWidget(
        MaterialApp(
          home: VehicleControlsPage(
            vehicle: vehicle,
            dataService: api.dataService(),
            currentUid: () => 'alice',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('64%'), findsWidgets);
      expect(find.text('224 km'), findsWidgets);
      expect(find.text('23 °C'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);

      ble.snapshot.value = null;
      await tester.pumpAndSettle();

      expect(find.text('64%'), findsNothing);
      expect(find.text('224 km'), findsNothing);
      // No invented defaults are shown as if they were live.
      expect(find.text('21 °C'), findsNothing);
      expect(find.text('80%'), findsNothing);
      expect(find.text('—'), findsWidgets);

      // Opening the screen never starts or duplicates a BLE connection.
      expect(ble.phase, phaseBefore);
      expect(ble.isConnected, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
