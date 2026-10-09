# Vehicle BLE demo

The Controls page acts as the BLE central in the main EV Smart Companion app.
The separate `vehicle_simulator/` Android app acts as the BLE peripheral and
GATT server. The simulator sends all demo state over BLE; it does not write to
Firestore. The main app accepts state only when its `vehicleId` matches the
vehicle selected by the signed-in user.

BLE requires two physical Android devices. Android emulators do not provide the
Bluetooth hardware required for this demonstration. Flutter Web continues to
show cloud telemetry but disables BLE controls.

## Run the demo

1. Run `flutter run` from the repository root on the EV Smart Companion Android
   phone and sign in normally.
2. Open Controls and copy the displayed vehicle document ID.
3. From `vehicle_simulator/`, run `flutter run` on a second Android phone or
   tablet. Enter the same vehicle ID and start the simulator.
4. Allow the Bluetooth permissions requested by each app. Leave both apps
   open, with Bluetooth enabled.
5. The central scans for the `EV-Simulator-01` name and the service UUID. A
   scan attempt ends after 12 seconds; reconnect uses five bounded backoff
   delays (2, 4, 8, 16, and 30 seconds). Retry from Controls after the retry
   limit is reached.
6. Use the simulator sliders, switches, or demo scenarios. The Controls
   dashboard reports a connection only after it receives a valid state
   snapshot for the selected vehicle ID.

The simulator scenarios cover parked/driving states, a moving vehicle with an
open or unlocked door, low and critical battery, charging start/completion/
interruption, and an intentional BLE disconnection. Charging state advances
in the simulator and stops at the configured target. Its local event log keeps
the most recent 40 demo events.

Safety alerts identify the affected door and distinguish open doors from
unlocked doors while moving. Active alert conditions are saved with the
signed-in user's per-vehicle controls preferences so navigating away and back
does not repeat the same alert. Alert history is capped at 50 entries.
Passenger profiles are scoped to the selected vehicle and preserve role, seat,
cabin preferences, left/right mirror adjustments, and last-used time. The
current BLE protocol applies cabin temperature, fan, and seat-heating settings;
seat assignment and mirror values are saved as profile preferences and are
not sent as vehicle commands.

## GATT protocol

The service and characteristics are versioned in
`packages/vehicle_ble_protocol/lib/vehicle_ble_protocol.dart`:

| Attribute | UUID | Role |
| --- | --- | --- |
| Vehicle Control service | `8a7e1000-6d8a-4a31-b8d1-1f40cc5a0001` | Advertised primary service |
| State characteristic | `8a7e1001-6d8a-4a31-b8d1-1f40cc5a0001` | Peripheral notifies snapshots |
| Command characteristic | `8a7e1002-6d8a-4a31-b8d1-1f40cc5a0001` | Central writes commands |

Both directions use UTF-8 JSON messages carried in BLE frames. Every frame is
`0xE7, messageId, frameCount, frameIndex, payload...`; the initial frame payload
is at most 16 bytes for the default 20-byte ATT payload. Receivers validate the
frame sequence, cap assembled messages at 4080 bytes, then validate JSON,
version, state ranges, and the exact four-door set.

State notifications have version `1`, type `state`, a vehicle ID, monotonic
sequence number, timestamp, and vehicle state. Commands have version `1`, type
`command`, a request ID, action, and only the fields required for that action.
The simulator validates every received command and rejects unsafe door,
charging, and vehicle-power transitions. The main app repeats those safety
checks before writing commands.

This is a local demonstration protocol, not an authenticated production vehicle
control interface. Do not connect it to a real vehicle or use it for
safety-critical actions.
