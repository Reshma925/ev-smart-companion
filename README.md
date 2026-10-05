# flutter_application_2

## Pre-registered development vehicles

Normal app signup only queries `vehicles`; the Flutter client never creates,
updates, or deletes vehicle identity documents. For development, seed these
documents once using the admin-only script in `tools/firestore_seed`. It is
never run by the Flutter app. Alternatively, create the same records manually
in Firebase Console → Firestore Database → Data.

Create `vehicles/EV001`:

| Field | Value |
| --- | --- |
| registrationNumber | `TN01AB1234` |
| model | `EV Smart X1` |
| ownerName | `Registered Vehicle Owner 1` |
| vin | `EVVIN001` |
| bluetoothDeviceId | `EV-SIM-001` |
| bluetoothDeviceName | `EV-Simulator-01` |
| isActive | `true` |
| createdAt | Firestore timestamp |

Create `vehicles/EV002`:

| Field | Value |
| --- | --- |
| registrationNumber | `TN02CD5678` |
| model | `EV Smart X2` |
| ownerName | `Registered Vehicle Owner 2` |
| vin | `EVVIN002` |
| bluetoothDeviceId | `EV-SIM-002` |
| bluetoothDeviceName | `EV-Simulator-02` |
| isActive | `true` |
| createdAt | Firestore timestamp |

### Run the one-time seed script

Install the script's dependencies with `npm --prefix tools/firestore_seed install`.
Authenticate to the target Google Cloud project using Application Default
Credentials (for example, `gcloud auth application-default login`) with an
account allowed to create Firestore documents, then run:

`npm --prefix tools/firestore_seed run seed`

The script targets `smart-ev-learning-companion`, creates only missing records,
refuses to overwrite conflicting documents, and verifies both document IDs and
both registration lookups plus a negative lookup. It needs IAM permission to
write Firestore; Firestore client security rules do not grant Admin SDK writes.
Never put a service-account key in this repository.

Deploy the project rules with `firebase deploy --only firestore:rules --project smart-ev-learning-companion`.
The client rules allow authenticated
vehicle reads, restrict user documents to their UID and mapped vehicle, deny
vehicle identity writes, and scope telemetry to the mapped owner. Keep admin
vehicle provisioning in Firebase Console or a trusted server environment.

The current Bluetooth page is a UI preview, not a BLE implementation. It
displays the selected Firestore vehicle's Bluetooth identifiers; it does not
advertise or connect to a physical or simulated BLE peripheral. Vehicle Health
uses the existing `telemetry/live` document and vehicle maintenance records.
It does not simulate charging or fabricate driving history.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
