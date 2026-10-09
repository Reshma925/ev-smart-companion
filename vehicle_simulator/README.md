# EV Vehicle Simulator

The Android simulator hosts the existing vehicle BLE GATT service and uses the
shared protocol in `../packages/vehicle_ble_protocol`. Android 12 and later
must grant `BLUETOOTH_ADVERTISE` and `BLUETOOTH_CONNECT`; Bluetooth must also
be enabled.

The local `packages/bluetooth_low_energy_android` override keeps upstream
plugin 6.2.1 but corrects its peripheral capability check. Upstream equated
`BluetoothAdapter.isMultipleAdvertisementSupported` with basic LE advertising
support. The simulator only needs one legacy advertisement, so it now checks
for the BLE system feature and adapter, then lets the Android advertising API
report the actual start result or error. This does not bypass runtime
permissions or alter the GATT protocol.

The local plugin also handles an unchanged adapter name without waiting for a
name-change broadcast that Android may not send, registers callbacks before
issuing asynchronous GATT/advertising calls, and verifies service registration
before advertising. Its logs distinguish the name-setting phase, GATT service
status, advertiser invocation/settings, and Android success/failure callback
(including status codes). Capture them with:

```sh
adb logcat -s VehicleSimulatorBLE:I BluetoothLowEnergy:I flutter:I
```

Build and install the debug APK on a connected Android phone from this
directory:

```sh
flutter pub get
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am force-stop com.evsmartcompanion.vehicle_simulator
adb shell am start -n com.evsmartcompanion.vehicle_simulator/com.evsmartcompanion.vehicle_simulator.MainActivity
```
