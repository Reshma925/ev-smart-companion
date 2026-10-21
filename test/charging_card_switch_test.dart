import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/charging_card.dart';
import 'package:flutter_application_2/models/vehicle.dart';
import 'package:flutter_application_2/services/data_service.dart';
import 'package:flutter_application_2/widgets/charging_card_section.dart';

import 'support/fake_api.dart';

void main() {
  testWidgets('switching the connected vehicle updates its card stream', (
    tester,
  ) async {
    final dataService = _SwitchableDataService();
    addTearDown(dataService.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChargingCardSection(uid: 'user-1', dataService: dataService),
        ),
      ),
    );

    dataService.select(_vehicle('EV001', 'First EV'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second EV\nREG-002 · EV002').last);
    await tester.pumpAndSettle();

    expect(find.text('Second EV\nREG-002 · EV002'), findsOneWidget);
    expect(find.text('XXXX XXXX XXXX 2222'), findsWidgets);
    expect(find.text('XXXX XXXX XXXX 1111'), findsNothing);
  });

  testWidgets('registration lists all vehicles linked to the user', (
    tester,
  ) async {
    final dataService = _SwitchableDataService()..hasCard = false;
    addTearDown(dataService.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChargingCardSection(uid: 'user-1', dataService: dataService),
        ),
      ),
    );

    dataService.select(_vehicle('EV001', 'First EV'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Register Charging Card'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vehicle association'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    expect(find.text('Second EV · REG-002 · EV002'), findsOneWidget);
  });

  testWidgets('registration sends only the last four card digits', (
    tester,
  ) async {
    final dataService = _SwitchableDataService()..hasCard = false;
    addTearDown(dataService.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChargingCardSection(uid: 'user-1', dataService: dataService),
        ),
      ),
    );
    dataService.select(_vehicle('EV001', 'First EV'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Register Charging Card'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Card type'),
      'EV Charging Card',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Card number'),
      '4111 1111 1111 1234',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Card holder name'),
      'Card Holder',
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Register Card'));
    await tester.tap(find.text('Register Card'));
    await tester.pumpAndSettle();

    expect(dataService.registeredCardLastFour, ['1234']);
  });

  testWidgets('charging card section follows the currently connected vehicle', (
    tester,
  ) async {
    final dataService = _SwitchableDataService();
    addTearDown(dataService.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChargingCardSection(uid: 'user-1', dataService: dataService),
        ),
      ),
    );

    dataService.select(_vehicle('EV001', 'First EV'));
    await tester.pumpAndSettle();
    expect(find.text('First EV\nREG-001\nEV001'), findsWidgets);
    expect(find.text('XXXX XXXX XXXX 1111'), findsWidgets);

    dataService.select(_vehicle('EV002', 'Second EV'));
    await tester.pumpAndSettle();
    expect(find.text('Second EV\nREG-002\nEV002'), findsWidgets);
    expect(find.text('XXXX XXXX XXXX 2222'), findsWidgets);
    expect(find.text('XXXX XXXX XXXX 1111'), findsNothing);

    dataService.select(_vehicle('EV001', 'First EV'));
    await tester.pumpAndSettle();
    expect(find.text('First EV\nREG-001\nEV001'), findsWidgets);
    expect(find.text('XXXX XXXX XXXX 1111'), findsWidgets);
    expect(find.text('XXXX XXXX XXXX 2222'), findsNothing);
  });

  testWidgets('hides a card whose stored vehicle details do not match', (
    tester,
  ) async {
    final dataService = _SwitchableDataService()..mismatchCard = true;
    addTearDown(dataService.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChargingCardSection(uid: 'user-1', dataService: dataService),
        ),
      ),
    );

    dataService.select(_vehicle('EV001', 'First EV'));
    await tester.pumpAndSettle();

    expect(
      find.text('Charging card does not match the selected vehicle.'),
      findsOneWidget,
    );
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

class _SwitchableDataService extends DataService {
  // Every method the section uses is overridden, so no request is sent.
  _SwitchableDataService() : super(api: FakeApi().client());

  final _connectedVehicle = StreamController<Vehicle?>.broadcast(sync: true);
  bool hasCard = true;
  bool mismatchCard = false;
  final List<String> registeredCardLastFour = [];

  void select(Vehicle vehicle) => _connectedVehicle.add(vehicle);

  void dispose() => _connectedVehicle.close();

  @override
  Stream<Vehicle?> watchConnectedVehicle(String uid) =>
      _connectedVehicle.stream;

  @override
  Stream<ChargingCard?> watchChargingCard(
    String uid, {
    required String vehicleId,
    String? vehicleModel,
    String? vehicleRegistration,
  }) => Stream.value(
    hasCard
        ? ChargingCard(
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
            vehicleModel: mismatchCard
                ? 'Mismatched vehicle'
                : vehicleId == 'EV001'
                ? 'First EV'
                : 'Second EV',
            vehicleRegistrationNumber: vehicleId == 'EV001'
                ? 'REG-001'
                : 'REG-002',
            vehicleVin: 'VIN-$vehicleId',
          )
        : null,
  );

  @override
  Future<ChargingCard> registerChargingCard({
    required String uid,
    required String cardType,
    required String cardLastFour,
    required String cardHolderName,
    required String vehicleId,
    DateTime? expiryDate,
    String currency = 'INR',
  }) async {
    registeredCardLastFour.add(cardLastFour);
    return ChargingCard(id: 'current', vehicleId: vehicleId);
  }

  @override
  Stream<List<Vehicle>> watchLinkedVehicles(String uid) => Stream.value([
    _vehicle('EV001', 'First EV'),
    _vehicle('EV002', 'Second EV'),
  ]);

  @override
  Future<void> setConnectedVehicle({
    required String uid,
    required String vehicleId,
  }) async {
    select(
      _vehicle(vehicleId, vehicleId == 'EV001' ? 'First EV' : 'Second EV'),
    );
  }

  @override
  Stream<List<ChargingTransaction>> watchChargingTransactions(
    String uid, {
    required String vehicleId,
  }) => Stream.value(const []);
}
