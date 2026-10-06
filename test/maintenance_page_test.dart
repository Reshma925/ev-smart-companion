import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/vehicle.dart';
import 'package:flutter_application_2/screens/maintenance.dart';
import 'package:flutter_application_2/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows Firebase-backed empty maintenance state without invented data',
    (tester) async {
      const vehicle = Vehicle(
        id: 'maintenance-test-ev',
        model: 'EV Smart X1',
        registrationNumber: 'TEST-001',
        ownerName: 'Driver',
        vin: 'TEST-VIN',
      );
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('vehicles').doc(vehicle.id).set({
        ...vehicle.toMap(),
        'isActive': true,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenancePage(
            vehicle: vehicle,
            firestoreService: FirestoreService(firestore: firestore),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EV Smart X1'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('No due dates recorded'), 400);
      expect(find.text('No due dates recorded'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('No maintenance costs recorded yet.'),
        400,
      );
      expect(find.text('No maintenance costs recorded yet.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('No service history yet'),
        400,
      );
      await tester.pumpAndSettle();
      expect(find.text('No service history yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
