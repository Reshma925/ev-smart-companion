import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_ble_protocol/vehicle_ble_protocol.dart';

import 'package:flutter_application_2/models/vehicle_controls.dart';

void main() {
  group('VehicleAlertEngine', () {
    test('deduplicates an active alert and rearms after recovery', () {
      final engine = VehicleAlertEngine();
      VehicleStateSnapshot snapshot(int sequence, double battery) =>
          VehicleStateSnapshot(
            vehicleId: 'ev-1',
            sequence: sequence,
            timestampMillis: sequence * 1000,
            state: VehicleControlState(batteryPercent: battery),
          );

      expect(engine.evaluate(snapshot(1, 8)), hasLength(1));
      expect(engine.evaluate(snapshot(2, 7)), isEmpty);
      expect(engine.evaluate(snapshot(3, 25)), isEmpty);
      expect(engine.evaluate(snapshot(4, 8)), hasLength(1));
    });

    test('raises a critical alert when a door is open while moving', () {
      const state = VehicleControlState(
        speedKph: 12,
        doors: {
          VehicleDoor.frontLeft: VehicleDoorState(open: true, locked: false),
          VehicleDoor.frontRight: VehicleDoorState(),
          VehicleDoor.rearLeft: VehicleDoorState(),
          VehicleDoor.rearRight: VehicleDoorState(),
        },
      );
      const snapshot = VehicleStateSnapshot(
        vehicleId: 'ev-1',
        sequence: 1,
        timestampMillis: 1000,
        state: state,
      );

      final alerts = VehicleAlertEngine().evaluate(snapshot);

      expect(alerts.single.kind, 'door_open_moving_frontLeft');
      expect(alerts.single.title, 'Front left door open while moving');
      expect(alerts.single.severity, VehicleAlertSeverity.critical);
    });

    test('identifies an unlocked door while moving', () {
      const snapshot = VehicleStateSnapshot(
        vehicleId: 'ev-1',
        sequence: 1,
        timestampMillis: 1000,
        state: VehicleControlState(
          speedKph: 12,
          doors: {
            VehicleDoor.frontLeft: VehicleDoorState(),
            VehicleDoor.frontRight: VehicleDoorState(),
            VehicleDoor.rearLeft: VehicleDoorState(),
            VehicleDoor.rearRight: VehicleDoorState(locked: false),
          },
        ),
      );

      final alerts = VehicleAlertEngine().evaluate(snapshot);

      expect(alerts.single.kind, 'door_unlocked_moving_rearRight');
      expect(alerts.single.title, 'Rear right door unlocked while moving');
      expect(alerts.single.severity, VehicleAlertSeverity.warning);
    });

    test('reports charging start and interruption once per transition', () {
      final engine = VehicleAlertEngine();
      VehicleStateSnapshot snapshot(int sequence, VehicleControlState state) =>
          VehicleStateSnapshot(
            vehicleId: 'ev-1',
            sequence: sequence,
            timestampMillis: sequence * 1000,
            state: state,
          );

      expect(
        engine
            .evaluate(
              snapshot(
                1,
                const VehicleControlState(
                  chargingConnected: true,
                  chargingPowerKw: 7.2,
                ),
              ),
            )
            .single
            .kind,
        'charging_active',
      );
      final stopped = const VehicleControlState(chargingInterrupted: true);
      expect(
        engine.evaluate(snapshot(2, stopped)).single.kind,
        'charging_interrupted',
      );
      expect(engine.evaluate(snapshot(3, stopped)), isEmpty);
    });
  });

  test('passenger preferences and alert history round-trip', () {
    final preferences = VehicleControlsPreferences(
      notificationsEnabled: false,
      passengerProfiles: [
        PassengerProfile(
          id: 'profile-1',
          name: 'Sam',
          role: 'driver',
          seatPosition: 'frontLeft',
          preferredTemperatureC: 22,
          fanLevel: 2,
          seatHeating: true,
          leftMirrorHorizontal: -4,
          leftMirrorVertical: 3,
          rightMirrorHorizontal: 5,
          rightMirrorVertical: -2,
          lastUsedAt: DateTime.utc(2025, 1, 2, 3, 4),
        ),
      ],
      selectedProfileId: 'profile-1',
      activeAlertKeys: ['battery_low', 'charging_active'],
    );

    final decoded = VehicleControlsPreferences.fromMap(preferences.toMap());

    expect(decoded.notificationsEnabled, isFalse);
    expect(decoded.passengerProfiles.single.name, 'Sam');
    expect(decoded.passengerProfiles.single.seatHeating, isTrue);
    expect(decoded.passengerProfiles.single.role, 'driver');
    expect(decoded.passengerProfiles.single.seatPosition, 'frontLeft');
    expect(decoded.passengerProfiles.single.leftMirrorHorizontal, -4);
    expect(
      decoded.passengerProfiles.single.lastUsedAt?.toUtc(),
      DateTime.utc(2025, 1, 2, 3, 4),
    );
    expect(decoded.selectedProfileId, 'profile-1');
    expect(decoded.activeAlertKeys, ['battery_low', 'charging_active']);
  });
}
