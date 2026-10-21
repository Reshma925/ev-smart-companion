import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/vehicle.dart';
import 'package:flutter_application_2/screens/vehicle_health_page.dart';
import 'package:flutter_application_2/services/vehicle_ble_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_ble_protocol/vehicle_ble_protocol.dart';

import 'support/fake_api.dart';

void main() {
  testWidgets('shows responsive health sections and opens component details', (
    tester,
  ) async {
    final ble = VehicleBleClient.shared;
    ble.snapshot.value = const VehicleStateSnapshot(
      vehicleId: 'health-page-test-ev',
      sequence: 1,
      timestampMillis: 1,
      state: VehicleControlState(batteryPercent: 42, rangeKm: 141),
    );
    addTearDown(() => ble.snapshot.value = null);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const vehicle = Vehicle(
      id: 'health-page-test-ev',
      model: 'EV Smart X1',
      registrationNumber: 'TEST',
      ownerName: 'Driver',
      vin: 'TEST-VIN',
      batteryCapacityKwh: 60,
    );
    // The backend has no telemetry endpoint: live values come only from BLE.
    final api = FakeApi()
      ..on(
        'GET /v1/vehicles/${vehicle.id}/maintenance',
        (_) => {
          'records': [
            {
              'id': 'r1',
              'serviceType': 'Brake inspection',
              'serviceDate': DateTime(2026, 9, 12).toUtc().toIso8601String(),
              'nextServiceDate': DateTime(
                2026,
                10,
                15,
              ).toUtc().toIso8601String(),
              'status': 'Completed',
            },
          ],
        },
      );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: VehicleHealthPage(
          vehicle: vehicle,
          dataService: api.dataService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VEHICLE HEALTH SCORE'), findsOneWidget);
    expect(find.text('Component health'), findsOneWidget);
    expect(
      find.textContaining('Battery health history is not available yet.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('No trip efficiency data available yet.'),
      findsOneWidget,
    );
    expect(find.text('Charging simulator'), findsNothing);
    expect(find.text('Predictive maintenance'), findsNothing);
    expect(find.text('Brake inspection'), findsOneWidget);
    expect(find.text('42%'), findsWidgets);
    expect(find.text('72%'), findsNothing);
    expect(find.text('87'), findsNothing);
    expect(tester.takeException(), isNull);

    final batteryCard = find.text('Battery').last;
    await tester.ensureVisible(batteryCard);
    await tester.tap(batteryCard);
    await tester.pumpAndSettle();
    expect(find.text('Current charge'), findsWidgets);
    expect(find.text('42%'), findsWidgets);
    expect(find.text('72%'), findsNothing);
    expect(find.text('Charging cycles'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders data unavailable states without fake sensor values', (
    tester,
  ) async {
    const vehicle = Vehicle(
      id: 'health-empty-test-ev',
      model: 'EV Smart',
      registrationNumber: 'TEST',
      ownerName: 'Driver',
      vin: 'TEST-VIN',
    );
    final api = FakeApi()
      ..on(
        'GET /v1/vehicles/${vehicle.id}/maintenance',
        (_) => {'records': <Object>[]},
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: VehicleHealthPage(
          vehicle: vehicle,
          dataService: api.dataService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not reported'), findsWidgets);
    expect(find.text('No service records yet.'), findsOneWidget);
    expect(
      find.textContaining('No trip efficiency data available yet.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
