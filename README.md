# flutter_application_2

## Pre-registered development vehicles

Sign-up only links an existing vehicle; the app never creates vehicle records.
The demo vehicles `EV001` (`TN01AB1234`, `EV Smart X1`, `Registered Vehicle
Owner 1`, VIN `EVVIN001`, BLE `EV-Simulator-01`) and `EV002` (`TN02CD5678`,
`EV Smart X2`, `Registered Vehicle Owner 2`, VIN `EVVIN002`, BLE
`EV-Simulator-02`) are stored in MongoDB by the backend seed script:
`cd backend; npm run seed` (safe to re-run). Accounts, passwords and data are
also stored by the backend; see `backend/README.md`.

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
