# Vehicle BLE demo

The Controls page in the main EV Smart Companion app acts as the BLE central.
For the laptop demonstration, run the main app in Chrome on macOS and run the
separate `vehicle_simulator/` Android app as the BLE peripheral on the Samsung
phone. The simulator sends all demo state over BLE; it does not write to
Firestore. The main app accepts state only when its `vehicleId` matches the
vehicle selected by the signed-in user.

Chrome Web Bluetooth requires a secure context (HTTPS, or localhost), an
enabled Bluetooth adapter, and user permission from Chrome's device chooser.
The user must click **Connect Vehicle** to open that chooser. If the BLE link is
lost after selection, the app retries the selected device with bounded
backoff; after retries are exhausted, click **Reconnect** to retry. Use
**Disconnect** to intentionally stop the link.
The chooser and device permission are managed by Chrome, not Firebase.

## Run the demo

1. Serve the Flutter Web app from `localhost` during development or from an
   HTTPS origin for the demonstration. Build with `flutter build web` before
   deploying it.
2. Open the app in current Google Chrome on the MacBook and sign in normally.
   Open Controls and copy the displayed vehicle document ID.
3. From `vehicle_simulator/`, run the simulator on the Samsung phone. Enter the
   same vehicle ID and start the simulator. Allow Android's nearby-device/
   Bluetooth advertising permissions and leave the simulator open.
4. On the Mac, open Controls and click **Connect Vehicle**. Select the
   `EV-Simulator-01` device in Chrome's chooser and grant access.
5. The dashboard reports a BLE connection only after it receives and validates
   a state snapshot for the selected vehicle ID. Use the simulator controls to
   change state and verify real-time updates; choose **Vehicle disconnected**
   and **Vehicle reconnected** to exercise loss and recovery.

The simulator controls cover battery percentage, speed, four doors and
charging state. Scenarios cover parked/driving states, a moving vehicle with an
open or unlocked door, low and critical battery, charging start/completion/
interruption, and intentional BLE disconnect/reconnect. Charging state
advances in the simulator and stops at the configured target. Its local event
log keeps the most recent 40 demo events.

The browser only accepts live vehicle control state from a valid BLE snapshot;
when BLE is disconnected, any separately available Firestore telemetry remains
cloud telemetry and is not represented as a BLE connection.

Controls preferences are stored at
`users/{uid}/vehicles/{vehicleId}/controls/preferences`. On first access, the
app initializes this document transactionally after verifying the signed-in
owner, vehicle membership, and active vehicle. Firestore rules must be deployed
from the repository before first-use initialization can succeed. A permission
error is shown as an error with retry; the app does not substitute local or
simulated preferences.

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
