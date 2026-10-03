import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/charging_card.dart';
import 'package:flutter_application_2/models/vehicle.dart';
import 'package:flutter_application_2/services/firestore_service.dart';
import 'package:flutter_application_2/widgets/charging_card_section.dart';

void main() {
  testWidgets('charging card section follows the currently connected vehicle', (
    tester,
  ) async {
    final firestore = _SwitchableFirestoreService();
    addTearDown(firestore.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChargingCardSection(uid: 'user-1', firestoreService: firestore),
        ),
      ),
    );

    firestore.select(_vehicle('EV001', 'First EV'));
    await tester.pumpAndSettle();
    expect(find.text('First EV\nREG-001\nEV001'), findsWidgets);
    expect(find.text('XXXX XXXX XXXX 1111'), findsWidgets);

    firestore.select(_vehicle('EV002', 'Second EV'));
    await tester.pumpAndSettle();
    expect(find.text('Second EV\nREG-002\nEV002'), findsWidgets);
    expect(find.text('XXXX XXXX XXXX 2222'), findsWidgets);
    expect(find.text('XXXX XXXX XXXX 1111'), findsNothing);
  });
}

Vehicle _vehicle(String id, String model) => Vehicle(
  id: id,
  model: model,
  registrationNumber: 'REG-${id.substring(2)}',
  ownerName: 'Card Holder',
  vin: 'VIN-$id',
  isActive: true,
);

class _SwitchableFirestoreService extends FirestoreService {
  _SwitchableFirestoreService() : super(firestore: FakeFirebaseFirestore());

  final _connectedVehicle = StreamController<Vehicle?>.broadcast(sync: true);

  void select(Vehicle vehicle) => _connectedVehicle.add(vehicle);

  void dispose() => _connectedVehicle.close();

  @override
  Stream<Vehicle?> watchConnectedVehicle(String uid) =>
      _connectedVehicle.stream;

  @override
  Stream<ChargingCard?> watchChargingCard(
    String uid, {
    required String vehicleId,
  }) => Stream.value(
    ChargingCard(
      id: 'current',
      cardType: 'EV Charging Card',
      maskedCardNumber: vehicleId == 'EV001'
          ? 'XXXX XXXX XXXX 1111'
          : 'XXXX XXXX XXXX 2222',
      cardHolderName: 'Card Holder',
      balance: vehicleId == 'EV001' ? 100 : 200,
      currency: 'INR',
      status: 'ACTIVE',
      vehicleId: vehicleId,
    ),
  );

  @override
  Future<Map<String, dynamic>?> getLegacyChargingCardSummary({
    required String uid,
    required String vehicleId,
  }) async => null;

  @override
  Stream<List<ChargingTransaction>> watchChargingTransactions(
    String uid, {
    required String vehicleId,
  }) => Stream.value(const []);
}
