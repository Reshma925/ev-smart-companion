import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/vehicle.dart';
import 'package:flutter_application_2/screens/vehicle_health_page.dart';
import 'package:flutter_application_2/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows responsive health sections and opens component details', (
    tester,
  ) async {
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
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('vehicles')
        .doc(vehicle.id)
        .collection('telemetry')
        .doc('live')
        .set({
          'battery': 72,
          'range': 300,
          'batteryHealth': 91,
          'healthScore': 87,
          'isCharging': false,
          'batteryTemperatureC': 32,
          'batteryAgeMonths': 28,
          'chargingCycles': 284,
          'motorHealth': 86,
          'motorTemperatureC': 58,
          'brakeHealth': 89,
          'tirePressureFlPsi': 34,
          'tirePressureFrPsi': 31,
          'tirePressureRlPsi': 34,
          'tirePressureRrPsi': 33,
          'softwareHealth': 95,
          'ecoScore': 87,
          'efficiencyKmPerKwh': 6.3,
          'regenerativeEnergyKwh': 6.8,
          'hardBrakingEvents': 2,
        });
    await firestore
        .collection('vehicles')
        .doc(vehicle.id)
        .collection('maintenance')
        .add({
          'serviceType': 'Brake inspection',
          'serviceDate': DateTime(2026, 9, 12),
          'nextServiceDate': DateTime(2026, 10, 15),
          'status': 'Completed',
        });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: VehicleHealthPage(
          vehicle: vehicle,
          firestoreService: FirestoreService(firestore: firestore),
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
    expect(find.text('Brake inspection'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    final batteryCard = find.text('Battery').first;
    await tester.ensureVisible(batteryCard);
    await tester.tap(batteryCard);
    await tester.pumpAndSettle();
    expect(find.text('Current charge'), findsWidgets);
    expect(find.text('72%'), findsWidgets);
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
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('vehicles')
        .doc(vehicle.id)
        .collection('telemetry')
        .doc('live')
        .set({
          'battery': 50,
          'range': 180,
          'batteryHealth': 91,
          'healthScore': 91,
          'isCharging': false,
        });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: VehicleHealthPage(
          vehicle: vehicle,
          firestoreService: FirestoreService(firestore: firestore),
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
