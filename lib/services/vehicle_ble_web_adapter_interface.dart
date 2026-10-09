import 'dart:async';

abstract interface class VehicleBleWebAdapter {
  bool get isSupported;
  bool get hasSelectedDevice;
  String? get selectedDeviceName;

  Future<VehicleBleWebConnection> connect({
    required bool requestDevice,
    void Function()? onConnecting,
  });
}

abstract interface class VehicleBleWebConnection {
  Stream<List<int>> get stateNotifications;
  Stream<void> get disconnected;

  Future<void> startStateNotifications();
  Future<void> write(List<int> value);
  Future<void> close();
}
