import 'vehicle_ble_web_adapter_interface.dart';

VehicleBleWebAdapter createVehicleBleWebAdapter() =>
    const _UnsupportedVehicleBleWebAdapter();

class _UnsupportedVehicleBleWebAdapter implements VehicleBleWebAdapter {
  const _UnsupportedVehicleBleWebAdapter();

  @override
  bool get isSupported => false;

  @override
  bool get isSecureContext => false;

  @override
  String get bluetoothPolicyStatus => 'unknown';

  @override
  bool get hasSelectedDevice => false;

  @override
  String? get selectedDeviceName => null;

  @override
  Future<String> getAvailabilityStatus() async => 'unsupported';

  @override
  Future<VehicleBleWebConnection> connect({
    required bool requestDevice,
    void Function()? onConnecting,
    void Function(String stage)? onStage,
  }) {
    throw UnsupportedError('Web Bluetooth is only available in a browser.');
  }
}
