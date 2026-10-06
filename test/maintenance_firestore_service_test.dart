import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_application_2/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'writes completed maintenance records with user-entered source data',
    () async {
      final firestore = FakeFirebaseFirestore();
      final service = FirestoreService(firestore: firestore);
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

      final record =
          (await firestore
                  .collection('vehicles')
                  .doc('EV001')
                  .collection('maintenance')
                  .get())
              .docs
              .single
              .data();
      expect(record['vehicleId'], 'EV001');
      expect(record['serviceType'], 'Brake inspection');
      expect(record['category'], 'Brakes');
      expect(record['serviceDate'].toDate(), serviceDate);
      expect(record['nextServiceDate'].toDate(), nextDate);
      expect(record['odometerKm'], 24860);
      expect(record['cost'], 3200);
      expect(record['status'], 'Completed');
      expect(record['source'], 'user_entered');
    },
  );
}
