import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_ble_protocol/vehicle_ble_protocol.dart';

import 'package:flutter_application_2/services/vehicle_ble_client.dart';
import 'package:flutter_application_2/services/vehicle_ble_web_adapter_interface.dart';

void main() {
  group('Web Bluetooth vehicle bridge', () {
    test(
      'selects a device, validates live state and frames commands',
      () async {
        final adapter = _FakeWebAdapter();
        final client = VehicleBleClient(webAdapter: adapter);
        addTearDown(client.dispose);

        await client.start('vehicle-1');

        expect(adapter.requestDeviceArguments, [true]);
        expect(client.isConnected, isTrue);
        expect(client.selectedDeviceName, 'EV-Simulator-01');
        expect(client.lastDataUpdate, isNotNull);
        expect(client.snapshot.value?.state.batteryPercent, 75);

        adapter.connections.single.emitSnapshot(
          VehicleStateSnapshot(
            vehicleId: 'vehicle-1',
            sequence: 2,
            timestampMillis: 200,
            state: const VehicleControlState(
              batteryPercent: 43,
              speedKph: 28,
              doors: {
                VehicleDoor.frontLeft: VehicleDoorState(
                  open: true,
                  locked: false,
                ),
                VehicleDoor.frontRight: VehicleDoorState(),
                VehicleDoor.rearLeft: VehicleDoorState(),
                VehicleDoor.rearRight: VehicleDoorState(),
              },
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(client.snapshot.value?.state.batteryPercent, 43);
        expect(client.snapshot.value?.state.speedKph, 28);
        expect(
          client.snapshot.value?.state.doors[VehicleDoor.frontLeft]?.open,
          isTrue,
        );
        expect(client.lastDataUpdate, isNotNull);

        await client.send(
          const VehicleControlCommand(
            requestId: 'web-1',
            action: 'speed',
            level: 12,
          ),
        );
        final assembler = BleFrameAssembler();
        Uint8List? commandBytes;
        for (final frame in adapter.connections.single.writes) {
          commandBytes = assembler.add(frame) ?? commandBytes;
        }
        expect(
          VehicleControlCommand.decode(utf8.decode(commandBytes!)).level,
          12,
        );
      },
    );

    test(
      'reports chooser and connection failures without fake connected state',
      () async {
        final adapter = _FakeWebAdapter()
          ..connectError = StateError('Bluetooth access denied');
        final client = VehicleBleClient(webAdapter: adapter);
        addTearDown(client.dispose);

        await client.start('vehicle-1');

        expect(client.phase, VehicleBlePhase.error);
        expect(client.error, contains('Bluetooth access denied'));
        expect(client.isConnected, isFalse);
        expect(client.snapshot.value, isNull);
      },
    );

    test('drops stale and wrong-vehicle snapshots', () async {
      final adapter = _FakeWebAdapter();
      final client = VehicleBleClient(webAdapter: adapter);
      addTearDown(client.dispose);
      await client.start('vehicle-1');

      adapter.connections.single.emitSnapshot(
        _snapshot(vehicleId: 'vehicle-1', sequence: 4, battery: 51),
      );
      adapter.connections.single.emitSnapshot(
        _snapshot(vehicleId: 'vehicle-1', sequence: 3, battery: 22),
      );
      await Future<void>.delayed(Duration.zero);
      expect(client.snapshot.value?.state.batteryPercent, 51);

      adapter.connections.single.emitSnapshot(
        _snapshot(vehicleId: 'different-vehicle', sequence: 5, battery: 10),
      );
      await Future<void>.delayed(Duration.zero);
      expect(client.phase, VehicleBlePhase.error);
      expect(client.error, contains('different vehicle'));
      expect(client.snapshot.value?.state.batteryPercent, 51);
    });

    test('reconnects the previously selected device after link loss', () async {
      final adapter = _FakeWebAdapter();
      final client = VehicleBleClient(webAdapter: adapter);
      addTearDown(client.dispose);
      await client.start('vehicle-1');

      adapter.connections.single.loseConnection();
      await Future<void>.delayed(const Duration(milliseconds: 2200));

      expect(adapter.requestDeviceArguments, [true, false]);
      expect(adapter.connections, hasLength(2));
      expect(client.isConnected, isTrue);
    });

    test('manual disconnect stops automatic reconnects', () async {
      final adapter = _FakeWebAdapter();
      final client = VehicleBleClient(webAdapter: adapter);
      addTearDown(client.dispose);
      await client.start('vehicle-1');

      await client.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 2200));

      expect(client.phase, VehicleBlePhase.stopped);
      expect(client.isConnected, isFalse);
      expect(adapter.requestDeviceArguments, [true]);
      expect(adapter.connections, hasLength(1));
    });
  });
}

VehicleStateSnapshot _snapshot({
  required String vehicleId,
  required int sequence,
  required double battery,
}) => VehicleStateSnapshot(
  vehicleId: vehicleId,
  sequence: sequence,
  timestampMillis: sequence + 100,
  state: VehicleControlState(batteryPercent: battery, rangeKm: battery * 3.5),
);

class _FakeWebAdapter implements VehicleBleWebAdapter {
  final List<_FakeWebConnection> connections = [];
  final List<bool> requestDeviceArguments = [];
  Object? connectError;
  bool _hasSelectedDevice = false;

  @override
  bool get isSupported => true;

  @override
  bool get hasSelectedDevice => _hasSelectedDevice;

  @override
  String? get selectedDeviceName =>
      _hasSelectedDevice ? 'EV-Simulator-01' : null;

  @override
  Future<VehicleBleWebConnection> connect({
    required bool requestDevice,
    void Function()? onConnecting,
  }) async {
    requestDeviceArguments.add(requestDevice);
    if (requestDevice) _hasSelectedDevice = true;
    onConnecting?.call();
    final error = connectError;
    if (error != null) throw error;
    final connection = _FakeWebConnection();
    connections.add(connection);
    return connection;
  }
}

class _FakeWebConnection implements VehicleBleWebConnection {
  final StreamController<List<int>> _notifications =
      StreamController<List<int>>.broadcast();
  final StreamController<void> _disconnects =
      StreamController<void>.broadcast();
  final List<List<int>> writes = [];
  int _messageId = 0;

  @override
  Stream<List<int>> get stateNotifications => _notifications.stream;

  @override
  Stream<void> get disconnected => _disconnects.stream;

  @override
  Future<void> startStateNotifications() async {
    emitSnapshot(_snapshot(vehicleId: 'vehicle-1', sequence: 0, battery: 75));
  }

  void emitSnapshot(VehicleStateSnapshot snapshot) {
    final bytes = utf8.encode(snapshot.encode());
    for (final frame in BleFrameCodec.fragment(
      bytes,
      messageId: _messageId++,
    )) {
      _notifications.add(frame);
    }
  }

  void loseConnection() => _disconnects.add(null);

  @override
  Future<void> write(List<int> value) async => writes.add(value);

  @override
  Future<void> close() async {
    await _notifications.close();
    await _disconnects.close();
  }
}
