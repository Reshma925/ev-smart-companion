import 'dart:async';
import 'dart:js_interop';

import 'package:vehicle_ble_protocol/vehicle_ble_protocol.dart';

import 'vehicle_ble_web_adapter_interface.dart';

@JS('VehicleBleBridge.isSupported')
external bool _isSupported();

@JS('VehicleBleBridge.isSecureContext')
external bool _isSecureContext();

@JS('VehicleBleBridge.bluetoothPolicyStatus')
external String _bluetoothPolicyStatus();

@JS('VehicleBleBridge.getAvailabilityStatus')
external JSPromise<JSString> _getAvailabilityStatus();

@JS('VehicleBleBridge.requestDevice')
external JSPromise<JSObject> _requestDevice(String serviceUuid);

@JS('VehicleBleBridge.connect')
external JSPromise<JSObject> _connect(JSObject device);

@JS('VehicleBleBridge.getDeviceName')
external String? _getDeviceName(JSObject device);

@JS('VehicleBleBridge.getService')
external JSPromise<JSObject> _getService(JSObject server, String serviceUuid);

@JS('VehicleBleBridge.getCharacteristic')
external JSPromise<JSObject> _getCharacteristic(
  JSObject service,
  String characteristicUuid,
);

@JS('VehicleBleBridge.startNotifications')
external JSPromise<JSAny?> _startNotifications(JSObject characteristic);

@JS('VehicleBleBridge.addNotificationListener')
external void _addNotificationListener(
  JSObject characteristic,
  int listenerId,
  JSFunction callback,
);

@JS('VehicleBleBridge.removeNotificationListener')
external void _removeNotificationListener(
  JSObject characteristic,
  int listenerId,
);

@JS('VehicleBleBridge.addDisconnectListener')
external void _addDisconnectListener(
  JSObject device,
  int listenerId,
  JSFunction callback,
);

@JS('VehicleBleBridge.removeDisconnectListener')
external void _removeDisconnectListener(JSObject device, int listenerId);

@JS('VehicleBleBridge.write')
external JSPromise<JSAny?> _write(
  JSObject characteristic,
  JSArray<JSNumber> bytes,
);

@JS('VehicleBleBridge.disconnect')
external void _disconnect(JSObject device);

VehicleBleWebAdapter createVehicleBleWebAdapter() =>
    _BrowserVehicleBleAdapter();

class _BrowserVehicleBleAdapter implements VehicleBleWebAdapter {
  JSObject? _device;
  int _listenerId = 0;
  static const _gattOperationTimeout = Duration(seconds: 15);

  @override
  bool get isSupported => _isSupported();

  @override
  bool get isSecureContext => _isSecureContext();

  @override
  String get bluetoothPolicyStatus => _bluetoothPolicyStatus();

  @override
  bool get hasSelectedDevice => _device != null;

  @override
  String? get selectedDeviceName {
    final device = _device;
    return device == null ? null : _getDeviceName(device);
  }

  @override
  Future<String> getAvailabilityStatus() async =>
      (await _getAvailabilityStatus().toDart).toDart;

  @override
  Future<VehicleBleWebConnection> connect({
    required bool requestDevice,
    void Function()? onConnecting,
    void Function(String stage)? onStage,
  }) async {
    if (requestDevice) {
      _device = await _requestDevice(vehicleControlServiceUuid).toDart;
      onStage?.call('DEVICE_SELECTED');
    }
    final device = _device;
    if (device == null) {
      throw StateError('Choose the vehicle from the browser device chooser.');
    }
    onConnecting?.call();
    try {
      onStage?.call('GATT_CONNECT_STARTED');
      final server = await _connect(
        device,
      ).toDart.timeout(_gattOperationTimeout);
      onStage?.call('GATT_CONNECTED');
      onStage?.call('GATT_SERVICE_DISCOVERY_STARTED');
      final service = await _getService(
        server,
        vehicleControlServiceUuid,
      ).toDart.timeout(_gattOperationTimeout);
      onStage?.call('GATT_SERVICE_DISCOVERY_SUCCEEDED');
      onStage?.call('GATT_CHARACTERISTIC_DISCOVERY_STARTED');
      final stateCharacteristic = await _getCharacteristic(
        service,
        vehicleStateCharacteristicUuid,
      ).toDart.timeout(_gattOperationTimeout);
      final commandCharacteristic = await _getCharacteristic(
        service,
        vehicleCommandCharacteristicUuid,
      ).toDart.timeout(_gattOperationTimeout);
      onStage?.call('GATT_CHARACTERISTIC_DISCOVERY_SUCCEEDED');
      return _BrowserVehicleBleConnection(
        device: device,
        stateCharacteristic: stateCharacteristic,
        commandCharacteristic: commandCharacteristic,
        listenerId: _listenerId++,
      );
    } catch (_) {
      _disconnect(device);
      rethrow;
    }
  }
}

class _BrowserVehicleBleConnection implements VehicleBleWebConnection {
  _BrowserVehicleBleConnection({
    required this.device,
    required this.stateCharacteristic,
    required this.commandCharacteristic,
    required this.listenerId,
  }) {
    _notificationCallback = ((JSArray<JSNumber> bytes) {
      _stateNotifications.add(
        bytes.toDart.map((byte) => byte.toDartInt).toList(growable: false),
      );
    }).toJS;
    _disconnectCallback = (() {
      _disconnected.add(null);
    }).toJS;
    _addNotificationListener(
      stateCharacteristic,
      listenerId,
      _notificationCallback,
    );
    _addDisconnectListener(device, listenerId, _disconnectCallback);
  }

  final JSObject device;
  final JSObject stateCharacteristic;
  final JSObject commandCharacteristic;
  final int listenerId;
  final StreamController<List<int>> _stateNotifications =
      StreamController<List<int>>.broadcast();
  final StreamController<void> _disconnected =
      StreamController<void>.broadcast();
  late final JSFunction _notificationCallback;
  late final JSFunction _disconnectCallback;
  bool _closed = false;

  @override
  Stream<List<int>> get stateNotifications => _stateNotifications.stream;

  @override
  Stream<void> get disconnected => _disconnected.stream;

  @override
  Future<void> startStateNotifications() async {
    await _startNotifications(stateCharacteristic).toDart;
  }

  @override
  Future<void> write(List<int> value) async {
    final bytes = value.map((byte) => byte.toJS).toList().toJS;
    await _write(commandCharacteristic, bytes).toDart;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _removeNotificationListener(stateCharacteristic, listenerId);
    _removeDisconnectListener(device, listenerId);
    _disconnect(device);
    await _stateNotifications.close();
    await _disconnected.close();
  }
}
