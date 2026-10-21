import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';

void main() {
  test(
    'writes completed maintenance records with user-entered source data',
    () async {
      final api = FakeApi()
        ..on('POST /v1/vehicles/EV001/maintenance', (_) => {'id': 'r1'});
      final service = api.dataService();
      final serviceDate = DateTime(2026, 10, 6);
      final nextDate = DateTime(2027, 10, 6);

      await service.addVehicleMaintenanceRecord(
        vehicleId: 'EV001',
        serviceType: 'Brake inspection',
        category: 'Brakes',
        serviceDate: serviceDate,
        nextServiceDate: nextDate,
        odometerKm: 24860,
        cost: 3200,
        serviceCenter: 'EV Service Centre',
        notes: 'Inspection completed',
      );

      final request = api.requestsTo('POST /v1/vehicles/EV001/maintenance');
      expect(request, hasLength(1));
      expect(request.single.headers['Authorization'], 'Bearer test-token');
      final record = jsonDecode(request.single.body) as Map<String, dynamic>;
      expect(record['serviceType'], 'Brake inspection');
      expect(record['category'], 'Brakes');
      expect(
        DateTime.parse(record['serviceDate'] as String).toLocal(),
        serviceDate,
      );
      expect(
        DateTime.parse(record['nextServiceDate'] as String).toLocal(),
        nextDate,
      );
      expect(record['odometerKm'], 24860);
      expect(record['cost'], 3200);
      // Status and source are set by the server, not by the client.
      expect(record.containsKey('status'), isFalse);
      expect(record.containsKey('source'), isFalse);
    },
  );
}
