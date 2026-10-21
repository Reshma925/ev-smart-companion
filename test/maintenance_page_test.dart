import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/vehicle.dart';
import 'package:flutter_application_2/screens/maintenance.dart';
import 'package:flutter_application_2/services/vehicle_ble_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';

void main() {
  testWidgets(
    'shows the empty maintenance state from the backend without invented data',
    (tester) async {
      const vehicle = Vehicle(
        id: 'maintenance-test-ev',
        model: 'EV Smart X1',
        registrationNumber: 'TEST-001',
        ownerName: 'Driver',
        vin: 'TEST-VIN',
      );
      VehicleBleClient.shared.snapshot.value = null;
      addTearDown(() => VehicleBleClient.shared.snapshot.value = null);
      final api = FakeApi()
        ..on(
          'GET /v1/vehicles/${vehicle.id}',
          (_) => {'id': vehicle.id, ...vehicle.toMap(), 'isActive': true},
        )
        ..on(
          'GET /v1/vehicles/${vehicle.id}/maintenance',
          (_) => {'records': <Object>[]},
        );

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenancePage(
            vehicle: vehicle,
            dataService: api.dataService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EV Smart X1'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Battery: N/A'),
        400,
        scrollable: scrollable,
      );
      expect(find.text('Battery: N/A'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('No due dates recorded'),
        400,
        scrollable: scrollable,
      );
      expect(find.text('No due dates recorded'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('No maintenance costs recorded yet.'),
        400,
        scrollable: scrollable,
      );
      expect(find.text('No maintenance costs recorded yet.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('No service history yet'),
        400,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text('No service history yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
