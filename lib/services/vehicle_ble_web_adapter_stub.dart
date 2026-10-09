import 'vehicle_ble_web_adapter_interface.dart';

VehicleBleWebAdapter createVehicleBleWebAdapter() =>
    const _UnsupportedVehicleBleWebAdapter();

class _UnsupportedVehicleBleWebAdapter implements VehicleBleWebAdapter {
  const _UnsupportedVehicleBleWebAdapter();

  @override
  bool get isSupported => false;

  @override
  bool get hasSelectedDevice => false;

  @override
  String? get selectedDeviceName => null;

  @override
  Future<VehicleBleWebConnection> connect({
    required bool requestDevice,
    void Function()? onConnecting,
  }) {
    throw UnsupportedError('Web Bluetooth is only available in a browser.');
  }
}
