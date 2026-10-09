import 'dart:async';
import 'dart:convert';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';
import 'package:vehicle_ble_protocol/vehicle_ble_protocol.dart';

import 'vehicle_ble_web_adapter_interface.dart';
import 'vehicle_ble_web_adapter_stub.dart'
    if (dart.library.js_interop) 'vehicle_ble_web_adapter_web.dart'
    as web_adapter;

enum VehicleBlePhase {
  unsupported,
  authorizing,
  scanning,
  selectingDevice,
  connecting,
  connected,
  reconnecting,
  error,
  stopped,
}

class VehicleBleClient extends ChangeNotifier {
  VehicleBleClient({this.webAdapter});

  final VehicleBleWebAdapter? webAdapter;
  CentralManager? _manager;
  Peripheral? _peripheral;
  GATTCharacteristic? _stateCharacteristic;
  GATTCharacteristic? _commandCharacteristic;
  final BleFrameAssembler _stateAssembler = BleFrameAssembler();
  final ValueNotifier<VehicleStateSnapshot?> snapshot =
      ValueNotifier<VehicleStateSnapshot?>(null);
  StreamSubscription<DiscoveredEventArgs>? _discoveredSubscription;
  StreamSubscription<PeripheralConnectionStateChangedEventArgs>?
  _connectionSubscription;
  StreamSubscription<GATTCharacteristicNotifiedEventArgs>?
  _notificationSubscription;
  Timer? _reconnectTimer;
  Timer? _scanTimeoutTimer;
  String _vehicleId = '';
  String? _error;
  VehicleBlePhase _phase = VehicleBlePhase.stopped;
  int _lastSequence = -1;
  DateTime? _lastDataUpdate;
  String? _selectedDeviceName;
  int _messageId = 0;
  bool _disposed = false;
  bool _discoveryRunning = false;
  bool _connecting = false;
  bool _manualDisconnect = false;
  int _reconnectAttempts = 0;
  Completer<void>? _firstStatePacket;
  Future<void> _writeQueue = Future<void>.value();
  VehicleBleWebAdapter? _resolvedWebAdapter;
  VehicleBleWebConnection? _webConnection;
  StreamSubscription<List<int>>? _webStateSubscription;
  StreamSubscription<void>? _webDisconnectSubscription;
  static const _reconnectDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];
  static const _operationTimeout = Duration(seconds: 15);
  static const _scanTimeout = Duration(seconds: 12);

  VehicleBlePhase get phase => _phase;
  String? get error => _error;
  DateTime? get lastDataUpdate => _lastDataUpdate;
  String? get selectedDeviceName => _isWebMode
      ? _resolvedWebAdapter?.selectedDeviceName
      : _selectedDeviceName;
  bool get isConnected =>
      _phase == VehicleBlePhase.connected && snapshot.value != null;

  bool get _isWebMode => kIsWeb || webAdapter != null;

  bool get isSupported {
    if (_isWebMode) {
      _resolvedWebAdapter ??=
          webAdapter ?? web_adapter.createVehicleBleWebAdapter();
      return _resolvedWebAdapter!.isSupported;
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Future<void> start(String vehicleId) async {
    _vehicleId = vehicleId.trim();
    if (_vehicleId.isEmpty) {
      throw ArgumentError.value(vehicleId, 'vehicleId', 'Cannot be empty.');
    }
    if (!isSupported) {
      _setPhase(
        VehicleBlePhase.unsupported,
        _isWebMode
            ? 'Web Bluetooth is not available in this browser. Use current Chrome on HTTPS or localhost.'
            : 'Bluetooth vehicle connection requires a physical Android device.',
      );
      return;
    }

    _reconnectTimer?.cancel();
    _scanTimeoutTimer?.cancel();
    _reconnectAttempts = 0;
    _manualDisconnect = false;
    await _startAttempt();
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _scanTimeoutTimer?.cancel();
    if (_isWebMode) {
      final connection = _webConnection;
      _webConnection = null;
      await _cancelWebSubscriptions();
      if (connection != null) await connection.close();
    } else {
      await _stopDiscovery();
      final peripheral = _peripheral;
      if (peripheral != null) {
        try {
          await _manager?.disconnect(peripheral);
        } catch (error) {
          debugPrint('[Vehicle BLE] User-requested disconnect failed: $error');
          _onBleError(error, StackTrace.current);
          return;
        }
        _peripheral = null;
        _stateCharacteristic = null;
        _commandCharacteristic = null;
      }
    }
    snapshot.value = null;
    _firstStatePacket = null;
    _setPhase(VehicleBlePhase.stopped, null);
  }

  Future<void> _startAttempt() async {
    if (_disposed) return;
    if (_isWebMode) {
      await _startWebAttempt();
      return;
    }
    _manager ??= CentralManager();
    _discoveredSubscription ??= _manager!.discovered.listen(
      _onDiscovered,
      onError: _onBleError,
    );
    _connectionSubscription ??= _manager!.connectionStateChanged.listen(
      _onConnectionChanged,
      onError: _onBleError,
    );
    _notificationSubscription ??= _manager!.characteristicNotified.listen(
      _onNotification,
      onError: _onBleError,
    );

    _setPhase(VehicleBlePhase.authorizing, null);
    try {
      final authorized = await _manager!.authorize();
      if (!authorized) {
        _setPhase(
          VehicleBlePhase.error,
          'Bluetooth permission is required to connect to the vehicle simulator.',
        );
        return;
      }
      if (_manager!.state != BluetoothLowEnergyState.poweredOn) {
        _setPhase(
          VehicleBlePhase.error,
          'Turn on Bluetooth to connect to the vehicle simulator.',
        );
        return;
      }
      await _discover();
    } catch (error) {
      _onBleError(error, StackTrace.current);
    }
  }

  Future<void> _startWebAttempt() async {
    final adapter = _resolvedWebAdapter!;
    if (_disposed || _connecting) return;
    _connecting = true;
    _setPhase(
      adapter.hasSelectedDevice
          ? VehicleBlePhase.connecting
          : VehicleBlePhase.selectingDevice,
      null,
    );
    try {
      final connection = await adapter
          .connect(
            requestDevice: !adapter.hasSelectedDevice,
            onConnecting: () => _setPhase(VehicleBlePhase.connecting, null),
          );
      _webConnection = connection;
      _firstStatePacket = Completer<void>();
      _lastSequence = -1;
      _stateAssembler.reset();
      _webStateSubscription = connection.stateNotifications.listen(
        _onStateBytes,
        onError: _onBleError,
      );
      _webDisconnectSubscription = connection.disconnected.listen(
        (_) => _onWebDisconnected(connection),
        onError: _onBleError,
      );
      await connection.startStateNotifications().timeout(_operationTimeout);
      await _firstStatePacket!.future.timeout(_operationTimeout);
      _reconnectAttempts = 0;
    } on TimeoutException catch (error) {
      final connection = _webConnection;
      _webConnection = null;
      await _cancelWebSubscriptions();
      if (connection != null) await connection.close();
      _firstStatePacket = null;
      _setPhase(
        VehicleBlePhase.error,
        'Bluetooth connection timed out. Check that the simulator is advertising and try again.',
      );
      debugPrint('[Vehicle BLE Web] Connection timed out: $error');
      if (adapter.hasSelectedDevice) _scheduleReconnect();
    } catch (error) {
      final connection = _webConnection;
      _webConnection = null;
      await _cancelWebSubscriptions();
      if (connection != null) await connection.close();
      _firstStatePacket = null;
      _setPhase(VehicleBlePhase.error, _webErrorMessage(error));
      debugPrint('[Vehicle BLE Web] Connection failed: $error');
      if (adapter.hasSelectedDevice) _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  String _webErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('NotFoundError') ||
        message.contains('cancelled') ||
        message.contains('canceled')) {
      return 'No vehicle selected. Choose Connect Vehicle to open the Chrome device chooser.';
    }
    if (message.contains('SecurityError') ||
        message.contains('NotAllowedError')) {
      return 'Chrome blocked Bluetooth access. Use HTTPS or localhost and allow the selected device.';
    }
    if (message.contains('NetworkError')) {
      return 'Could not connect to the vehicle. Keep the simulator advertising and retry.';
    }
    if (message.contains('NotFound')) {
      return 'The selected device is missing the EV vehicle service or required characteristics.';
    }
    return 'Could not connect to the vehicle over Web Bluetooth: $message';
  }

  void _onWebDisconnected(VehicleBleWebConnection connection) {
    if (_webConnection != connection) return;
    _webConnection = null;
    unawaited(_cancelWebSubscriptions());
    unawaited(connection.close());
    if (_disposed) return;
    snapshot.value = null;
    _firstStatePacket = null;
    if (_manualDisconnect) {
      _setPhase(VehicleBlePhase.stopped, null);
      return;
    }
    _setPhase(VehicleBlePhase.reconnecting, null);
    _scheduleReconnect();
  }

  Future<void> _cancelWebSubscriptions() async {
    await _webStateSubscription?.cancel();
    _webStateSubscription = null;
    await _webDisconnectSubscription?.cancel();
    _webDisconnectSubscription = null;
  }

  Future<void> _discover() async {
    if (_disposed || _manager == null || _discoveryRunning || _connecting) {
      return;
    }
    _setPhase(VehicleBlePhase.scanning, null);
    try {
      _discoveryRunning = true;
      await _manager!.startDiscovery(
        serviceUUIDs: [UUID.fromString(vehicleControlServiceUuid)],
      );
      _scanTimeoutTimer?.cancel();
      _scanTimeoutTimer = Timer(_scanTimeout, () {
        if (_disposed || !_discoveryRunning || _connecting) return;
        unawaited(_stopDiscovery());
        _setPhase(
          VehicleBlePhase.reconnecting,
          'No EV-Simulator-01 found. Retrying with a limited backoff.',
        );
        _scheduleReconnect();
      });
    } catch (error) {
      await _stopDiscovery();
      _onBleError(error, StackTrace.current);
      _scheduleReconnect();
    }
  }

  void _onDiscovered(DiscoveredEventArgs event) {
    if (_disposed || _connecting || _peripheral != null) return;
    final serviceFound = event.advertisement.serviceUUIDs.any(
      (uuid) =>
          uuid.toString().toLowerCase() ==
          vehicleControlServiceUuid.toLowerCase(),
    );
    if (!serviceFound ||
        event.advertisement.name != vehicleSimulatorAdvertisedName) {
      return;
    }
    _selectedDeviceName = event.advertisement.name;
    _scanTimeoutTimer?.cancel();
    unawaited(_stopDiscovery());
    unawaited(_connect(event.peripheral));
  }

  Future<void> _connect(Peripheral peripheral) async {
    final manager = _manager;
    if (manager == null || _connecting || _disposed) return;
    _connecting = true;
    _peripheral = peripheral;
    _setPhase(VehicleBlePhase.connecting, null);
    try {
      await _stopDiscovery();
      await manager.connect(peripheral).timeout(_operationTimeout);
      try {
        await manager
            .requestMTU(peripheral, mtu: 247)
            .timeout(_operationTimeout);
      } catch (error) {
        debugPrint('[Vehicle BLE] Continuing with default MTU: $error');
      }
      final services = await manager
          .discoverGATT(peripheral)
          .timeout(_operationTimeout);
      final service = services
          .where(
            (candidate) =>
                candidate.uuid.toString().toLowerCase() ==
                vehicleControlServiceUuid.toLowerCase(),
          )
          .firstOrNull;
      if (service == null) {
        throw StateError('The simulator does not expose the vehicle service.');
      }
      _stateCharacteristic = service.characteristics
          .where(
            (characteristic) =>
                characteristic.uuid.toString().toLowerCase() ==
                vehicleStateCharacteristicUuid.toLowerCase(),
          )
          .firstOrNull;
      _commandCharacteristic = service.characteristics
          .where(
            (characteristic) =>
                characteristic.uuid.toString().toLowerCase() ==
                vehicleCommandCharacteristicUuid.toLowerCase(),
          )
          .firstOrNull;
      if (_stateCharacteristic == null || _commandCharacteristic == null) {
        throw StateError(
          'The simulator is missing a required BLE characteristic.',
        );
      }
      _firstStatePacket = Completer<void>();
      await manager
          .setCharacteristicNotifyState(
            peripheral,
            _stateCharacteristic!,
            state: true,
          )
          .timeout(_operationTimeout);
      _lastSequence = -1;
      _stateAssembler.reset();
      await _firstStatePacket!.future.timeout(_operationTimeout);
      _reconnectAttempts = 0;
    } catch (error) {
      _firstStatePacket = null;
      await _disconnectPeripheral(peripheral);
      _connecting = false;
      _setPhase(
        VehicleBlePhase.error,
        'Could not connect to the vehicle simulator. Check that it is advertising and retry.',
      );
      debugPrint('[Vehicle BLE] Connection failed: $error');
      _scheduleReconnect();
    }
  }

  void _onConnectionChanged(PeripheralConnectionStateChangedEventArgs event) {
    if (_peripheral != event.peripheral) return;
    if (event.state == ConnectionState.disconnected) {
      _peripheral = null;
      _stateCharacteristic = null;
      _commandCharacteristic = null;
      _connecting = false;
      if (!_disposed) {
        snapshot.value = null;
        if (_manualDisconnect) {
          _setPhase(VehicleBlePhase.stopped, null);
          return;
        }
        _setPhase(VehicleBlePhase.reconnecting, null);
        _scheduleReconnect();
      }
    }
  }

  void _onNotification(GATTCharacteristicNotifiedEventArgs event) {
    if (event.peripheral != _peripheral ||
        event.characteristic.uuid.toString().toLowerCase() !=
            vehicleStateCharacteristicUuid.toLowerCase()) {
      return;
    }
    _onStateBytes(event.value);
  }

  void _onStateBytes(List<int> value) {
    try {
      final bytes = _stateAssembler.add(value);
      if (bytes == null) return;
      final decoded = VehicleStateSnapshot.decode(utf8.decode(bytes));
      if (decoded.vehicleId != _vehicleId) {
        _setPhase(
          VehicleBlePhase.error,
          'The connected simulator is configured for a different vehicle.',
        );
        return;
      }
      if (decoded.sequence <= _lastSequence) return;
      _lastSequence = decoded.sequence;
      _lastDataUpdate = DateTime.now();
      snapshot.value = decoded;
      _setPhase(VehicleBlePhase.connected, null);
      if (!(_firstStatePacket?.isCompleted ?? true)) {
        _firstStatePacket!.complete();
      }
    } catch (error) {
      debugPrint('[Vehicle BLE] Ignored invalid state packet: $error');
    }
  }

  Future<void> send(VehicleControlCommand command) async {
    if (_isWebMode) {
      await _sendWeb(command);
      return;
    }
    final manager = _manager;
    final peripheral = _peripheral;
    final characteristic = _commandCharacteristic;
    final current = snapshot.value;
    if (!isConnected ||
        manager == null ||
        peripheral == null ||
        characteristic == null ||
        current == null) {
      throw StateError(
        'Connect to the vehicle simulator before sending controls.',
      );
    }
    applyVehicleCommand(current.state, command);

    final bytes = Uint8List.fromList(utf8.encode(command.encode()));
    final operation = _writeQueue.then((_) async {
      final maximumLength = await manager.getMaximumWriteLength(
        peripheral,
        type: GATTCharacteristicWriteType.withResponse,
      );
      final frames = BleFrameCodec.fragment(
        bytes,
        maximumFrameLength: maximumLength,
        messageId: _messageId++ & 0xff,
      );
      for (final frame in frames) {
        await manager.writeCharacteristic(
          peripheral,
          characteristic,
          value: frame,
          type: GATTCharacteristicWriteType.withResponse,
        );
      }
    });
    _writeQueue = operation.catchError((Object error) {
      _setPhase(
        VehicleBlePhase.error,
        'The vehicle command could not be sent.',
      );
      Error.throwWithStackTrace(error, StackTrace.current);
    });
    await operation;
  }

  Future<void> _sendWeb(VehicleControlCommand command) async {
    final connection = _webConnection;
    final current = snapshot.value;
    if (!isConnected || connection == null || current == null) {
      throw StateError(
        'Connect to the vehicle simulator before sending controls.',
      );
    }
    applyVehicleCommand(current.state, command);
    final bytes = Uint8List.fromList(utf8.encode(command.encode()));
    final operation = _writeQueue.then((_) async {
      final frames = BleFrameCodec.fragment(
        bytes,
        maximumFrameLength: bleDefaultFrameLength,
        messageId: _messageId++ & 0xff,
      );
      for (final frame in frames) {
        await connection.write(frame);
      }
    });
    _writeQueue = operation.catchError((Object error) {
      _setPhase(
        VehicleBlePhase.error,
        'The vehicle command could not be sent.',
      );
      Error.throwWithStackTrace(error, StackTrace.current);
    });
    await operation;
  }

  void _scheduleReconnect() {
    if (_disposed || _vehicleId.isEmpty) return;
    _reconnectTimer?.cancel();
    if (_reconnectAttempts >= _reconnectDelays.length) {
      _setPhase(
        VehicleBlePhase.error,
        'Could not connect after ${_reconnectDelays.length} attempts. Check the simulator and retry.',
      );
      return;
    }
    final delay = _reconnectDelays[_reconnectAttempts++];
    _reconnectTimer = Timer(delay, () {
      if (!_disposed) unawaited(_startAttempt());
    });
  }

  Future<void> _stopDiscovery() async {
    _scanTimeoutTimer?.cancel();
    if (!_discoveryRunning || _manager == null) return;
    _discoveryRunning = false;
    try {
      await _manager!.stopDiscovery();
    } catch (error) {
      debugPrint('[Vehicle BLE] Discovery cleanup failed: $error');
    }
  }

  Future<void> _disconnectPeripheral(Peripheral peripheral) async {
    try {
      await _manager?.disconnect(peripheral);
    } catch (error) {
      debugPrint('[Vehicle BLE] Disconnect cleanup failed: $error');
    }
    if (_peripheral == peripheral) _peripheral = null;
    _stateCharacteristic = null;
    _commandCharacteristic = null;
    if (!_disposed) snapshot.value = null;
  }

  void _onBleError(Object error, StackTrace stackTrace) {
    debugPrint('[Vehicle BLE] Bluetooth operation failed: $error');
    if (!_disposed) {
      _setPhase(
        VehicleBlePhase.error,
        'Bluetooth operation failed. Check Bluetooth permissions and try again.',
      );
    }
  }

  void _setPhase(VehicleBlePhase phase, String? error) {
    if (_disposed) return;
    _phase = phase;
    _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _scanTimeoutTimer?.cancel();
    _discoveredSubscription?.cancel();
    _connectionSubscription?.cancel();
    _notificationSubscription?.cancel();
    unawaited(_cancelWebSubscriptions());
    final peripheral = _peripheral;
    if (peripheral != null) unawaited(_disconnectPeripheral(peripheral));
    final webConnection = _webConnection;
    _webConnection = null;
    if (webConnection != null) unawaited(webConnection.close());
    if (_discoveryRunning) unawaited(_manager?.stopDiscovery());
    snapshot.dispose();
    super.dispose();
  }
}
