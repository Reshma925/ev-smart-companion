import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/vehicle.dart';
import 'package:flutter_application_2/screens/auth_gate.dart';
import 'package:flutter_application_2/screens/bluetooth_scanning_page.dart';
import 'package:flutter_application_2/services/vehicle_ble_client.dart';
import 'package:flutter_application_2/services/vehicle_ble_web_adapter_interface.dart';

void main() {
  testWidgets('does not report a device found before a real BLE connection', (
    tester,
  ) async {
    const vehicle = Vehicle(
      id: 'vehicle-1',
      model: 'EV Model',
      registrationNumber: 'TEST-001',
      ownerName: 'Test Owner',
      vin: 'TESTVIN',
    );
    await tester.pumpWidget(
      const MaterialApp(home: BluetoothScanningPage(vehicle: vehicle)),
    );

    expect(find.text('Vehicle profile ready'), findsOneWidget);
    expect(
      find.text('Ready to connect to the vehicle simulator.'),
      findsOneWidget,
    );
    expect(find.text('Simulator entry found'), findsNothing);
    expect(find.text('Connected ✓'), findsNothing);
    expect(find.text('Connect Vehicle'), findsOneWidget);
  });

  testWidgets('Connect Vehicle invokes the real device chooser flow', (
    tester,
  ) async {
    const vehicle = Vehicle(
      id: 'vehicle-1',
      model: 'EV Model',
      registrationNumber: 'TEST-001',
      ownerName: 'Test Owner',
      vin: 'TESTVIN',
    );
    final adapter = _ChooserAdapter();
    final client = VehicleBleClient(
      webAdapter: adapter,
      authenticationCheck: () => true,
    );
    addTearDown(client.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: BluetoothScanningPage(vehicle: vehicle, bleClient: client),
      ),
    );
    await tester.pumpAndSettle();

    expect(adapter.requestDeviceArguments, isEmpty);
    expect(client.phase, VehicleBlePhase.stopped);
    expect(client.isSupported, isTrue);
    final connectButtonFinder = find.ancestor(
      of: find.text('Connect Vehicle'),
      matching: find.byType(FilledButton),
    );
    final connectButton = tester.widget<FilledButton>(connectButtonFinder);
    expect(connectButton.onPressed, isNotNull);
    await tester.ensureVisible(connectButtonFinder);
    await tester.tap(connectButtonFinder);
    await tester.pumpAndSettle();

    expect(adapter.requestDeviceArguments, [true]);
    expect(find.textContaining('Bluetooth chooser cancelled'), findsOneWidget);
  });

  testWidgets(
    'authenticated gate renders the BLE screen without build errors',
    (tester) async {
      const vehicle = Vehicle(
        id: 'vehicle-1',
        model: 'EV Model',
        registrationNumber: 'TEST-001',
        ownerName: 'Test Owner',
        vin: 'TESTVIN',
      );
      final authChanges = StreamController<User?>.broadcast();
      addTearDown(authChanges.close);
      final client = VehicleBleClient(
        webAdapter: _ChooserAdapter(),
        authenticationCheck: () => true,
      );
      addTearDown(client.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: authChanges.stream,
            authenticatedDestinationBuilder: (_) async =>
                BluetoothScanningPage(vehicle: vehicle, bleClient: client),
          ),
        ),
      );
      authChanges.add(_TestUser());
      await tester.pumpAndSettle();

      expect(find.text('Vehicle connection'), findsOneWidget);
      expect(find.text('Connect Vehicle'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _TestUser implements User {
  @override
  String get uid => 'authenticated-test-user';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChooserAdapter implements VehicleBleWebAdapter {
  final List<bool> requestDeviceArguments = [];

  @override
  bool get isSupported => true;

  @override
  bool get isSecureContext => true;

  @override
  String get bluetoothPolicyStatus => 'allowed';

  @override
  bool get hasSelectedDevice => false;

  @override
  String? get selectedDeviceName => null;

  @override
  Future<String> getAvailabilityStatus() async => 'available';

  @override
  Future<VehicleBleWebConnection> connect({
    required bool requestDevice,
    void Function()? onConnecting,
    void Function(String stage)? onStage,
  }) async {
    requestDeviceArguments.add(requestDevice);
    throw StateError('Bluetooth chooser cancelled');
  }
}
