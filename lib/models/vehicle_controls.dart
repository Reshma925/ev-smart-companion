import 'package:vehicle_ble_protocol/vehicle_ble_protocol.dart';

enum VehicleAlertSeverity { critical, warning, info }

class VehicleAlert {
  const VehicleAlert({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
  });

  final String id;
  final String kind;
  final String title;
  final String message;
  final VehicleAlertSeverity severity;
  final DateTime timestamp;

  Map<String, Object> toMap() => {
    'id': id,
    'kind': kind,
    'title': title,
    'message': message,
    'severity': severity.name,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };

  factory VehicleAlert.fromMap(Map<String, dynamic> map) {
    final timestamp = DateTime.tryParse(map['timestamp'] as String? ?? '');
    final severity = VehicleAlertSeverity.values
        .where((value) => value.name == map['severity'])
        .firstOrNull;
    if (map['id'] is! String ||
        map['kind'] is! String ||
        map['title'] is! String ||
        map['message'] is! String ||
        timestamp == null ||
        severity == null) {
      throw const FormatException('Invalid vehicle alert record.');
    }
    return VehicleAlert(
      id: map['id'] as String,
      kind: map['kind'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      severity: severity,
      timestamp: timestamp.toLocal(),
    );
  }
}

class PassengerProfile {
  const PassengerProfile({
    required this.id,
    required this.name,
    this.role = 'passenger',
    this.seatPosition = 'frontLeft',
    this.preferredTemperatureC = 21,
    this.fanLevel = 1,
    this.seatHeating = false,
    this.leftMirrorHorizontal = 0,
    this.leftMirrorVertical = 0,
    this.rightMirrorHorizontal = 0,
    this.rightMirrorVertical = 0,
    this.lastUsedAt,
  });

  final String id;
  final String name;
  final String role;
  final String seatPosition;
  final int preferredTemperatureC;
  final int fanLevel;
  final bool seatHeating;
  final double leftMirrorHorizontal;
  final double leftMirrorVertical;
  final double rightMirrorHorizontal;
  final double rightMirrorVertical;
  final DateTime? lastUsedAt;

  Map<String, Object> toMap() => {
    'id': id,
    'name': name,
    'role': role,
    'seatPosition': seatPosition,
    'preferredTemperatureC': preferredTemperatureC,
    'fanLevel': fanLevel,
    'seatHeating': seatHeating,
    'leftMirrorHorizontal': leftMirrorHorizontal,
    'leftMirrorVertical': leftMirrorVertical,
    'rightMirrorHorizontal': rightMirrorHorizontal,
    'rightMirrorVertical': rightMirrorVertical,
    'lastUsedAt': lastUsedAt?.toUtc().toIso8601String() ?? '',
  };

  factory PassengerProfile.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final name = map['name'];
    final temperature = map['preferredTemperatureC'];
    final fan = map['fanLevel'];
    final seatHeating = map['seatHeating'];
    final role = map['role'] ?? 'passenger';
    final seatPosition = map['seatPosition'] ?? 'frontLeft';
    final lastUsedAtValue = map['lastUsedAt'];
    final lastUsedAt = lastUsedAtValue == null || lastUsedAtValue == ''
        ? null
        : lastUsedAtValue is String
        ? DateTime.tryParse(lastUsedAtValue)
        : null;
    final leftMirrorHorizontal = _numberOrDefault(
      map,
      'leftMirrorHorizontal',
      0,
    );
    final leftMirrorVertical = _numberOrDefault(map, 'leftMirrorVertical', 0);
    final rightMirrorHorizontal = _numberOrDefault(
      map,
      'rightMirrorHorizontal',
      0,
    );
    final rightMirrorVertical = _numberOrDefault(
      map,
      'rightMirrorVertical',
      0,
    );
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        temperature is! int ||
        temperature < 16 ||
        temperature > 30 ||
        fan is! int ||
        fan < 0 ||
        fan > 5 ||
        seatHeating is! bool ||
        role is! String ||
        !const {'driver', 'passenger', 'child', 'caregiver'}.contains(role) ||
        seatPosition is! String ||
        !const {'frontLeft', 'frontRight', 'rearLeft', 'rearRight'}.contains(
          seatPosition,
        ) ||
        leftMirrorHorizontal < -20 ||
        leftMirrorHorizontal > 20 ||
        leftMirrorVertical < -20 ||
        leftMirrorVertical > 20 ||
        rightMirrorHorizontal < -20 ||
        rightMirrorHorizontal > 20 ||
        rightMirrorVertical < -20 ||
        rightMirrorVertical > 20 ||
        (lastUsedAtValue != null &&
            lastUsedAtValue != '' &&
            lastUsedAt == null)) {
      throw const FormatException('Invalid passenger profile.');
    }
    return PassengerProfile(
      id: id,
      name: name.trim(),
      role: role,
      seatPosition: seatPosition,
      preferredTemperatureC: temperature,
      fanLevel: fan,
      seatHeating: seatHeating,
      leftMirrorHorizontal: leftMirrorHorizontal,
      leftMirrorVertical: leftMirrorVertical,
      rightMirrorHorizontal: rightMirrorHorizontal,
      rightMirrorVertical: rightMirrorVertical,
      lastUsedAt: lastUsedAt?.toLocal(),
    );
  }

  PassengerProfile copyWith({DateTime? lastUsedAt}) => PassengerProfile(
    id: id,
    name: name,
    role: role,
    seatPosition: seatPosition,
    preferredTemperatureC: preferredTemperatureC,
    fanLevel: fanLevel,
    seatHeating: seatHeating,
    leftMirrorHorizontal: leftMirrorHorizontal,
    leftMirrorVertical: leftMirrorVertical,
    rightMirrorHorizontal: rightMirrorHorizontal,
    rightMirrorVertical: rightMirrorVertical,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
  );

  static double _numberOrDefault(
    Map<String, dynamic> map,
    String key,
    double fallback,
  ) {
    final value = map[key];
    if (value == null) return fallback;
    if (value is! num) {
      throw FormatException('Invalid passenger profile $key.');
    }
    return value.toDouble();
  }
}

class VehicleControlsPreferences {
  const VehicleControlsPreferences({
    this.notificationsEnabled = true,
    this.safetyAlertsEnabled = true,
    this.batteryAlertsEnabled = true,
    this.chargingAlertsEnabled = true,
    this.passengerProfiles = const [],
    this.selectedProfileId,
    this.alertHistory = const [],
    this.activeAlertKeys = const [],
  });

  final bool notificationsEnabled;
  final bool safetyAlertsEnabled;
  final bool batteryAlertsEnabled;
  final bool chargingAlertsEnabled;
  final List<PassengerProfile> passengerProfiles;
  final String? selectedProfileId;
  final List<VehicleAlert> alertHistory;
  final List<String> activeAlertKeys;

  Map<String, Object?> toMap() => {
    'notificationsEnabled': notificationsEnabled,
    'safetyAlertsEnabled': safetyAlertsEnabled,
    'batteryAlertsEnabled': batteryAlertsEnabled,
    'chargingAlertsEnabled': chargingAlertsEnabled,
    'passengerProfiles': passengerProfiles
        .map((profile) => profile.toMap())
        .toList(growable: false),
    'selectedProfileId': selectedProfileId,
    'alertHistory': alertHistory
        .take(50)
        .map((alert) => alert.toMap())
        .toList(growable: false),
    'activeAlertKeys': activeAlertKeys.toList(growable: false),
  };

  factory VehicleControlsPreferences.fromMap(Object? value) {
    if (value is! Map) return const VehicleControlsPreferences();
    final map = value.map<String, dynamic>((key, value) {
      if (key is! String) throw const FormatException('Invalid controls settings.');
      return MapEntry(key, value);
    });
    List<T> readList<T>(
      Object? value,
      T Function(Map<String, dynamic>) decode,
    ) {
      if (value == null) return const [];
      if (value is! List) throw const FormatException('Invalid controls list.');
      return value
          .map((item) {
            if (item is! Map) {
              throw const FormatException('Invalid controls list item.');
            }
            return decode(item.map<String, dynamic>((key, value) {
              if (key is! String) {
                throw const FormatException('Invalid controls map key.');
              }
              return MapEntry(key, value);
            }));
          })
          .toList(growable: false);
    }

    final profiles = readList(
      map['passengerProfiles'],
      PassengerProfile.fromMap,
    );
    final alerts = readList(map['alertHistory'], VehicleAlert.fromMap);
    final activeAlertKeysValue = map['activeAlertKeys'];
    if (activeAlertKeysValue != null &&
        (activeAlertKeysValue is! List ||
            activeAlertKeysValue.any((value) => value is! String))) {
      throw const FormatException('Invalid active alert keys.');
    }
    final selectedProfileId = map['selectedProfileId'];
    return VehicleControlsPreferences(
      notificationsEnabled: _boolOrDefault(map, 'notificationsEnabled', true),
      safetyAlertsEnabled: _boolOrDefault(map, 'safetyAlertsEnabled', true),
      batteryAlertsEnabled: _boolOrDefault(map, 'batteryAlertsEnabled', true),
      chargingAlertsEnabled: _boolOrDefault(
        map,
        'chargingAlertsEnabled',
        true,
      ),
      passengerProfiles: profiles,
      selectedProfileId: selectedProfileId is String ? selectedProfileId : null,
      alertHistory: alerts.take(50).toList(growable: false),
      activeAlertKeys: activeAlertKeysValue == null
          ? const []
          : (activeAlertKeysValue as List).cast<String>().take(32).toList(),
    );
  }

  VehicleControlsPreferences copyWith({
    bool? notificationsEnabled,
    bool? safetyAlertsEnabled,
    bool? batteryAlertsEnabled,
    bool? chargingAlertsEnabled,
    List<PassengerProfile>? passengerProfiles,
    String? selectedProfileId,
    bool clearSelectedProfileId = false,
    List<VehicleAlert>? alertHistory,
    List<String>? activeAlertKeys,
  }) => VehicleControlsPreferences(
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    safetyAlertsEnabled: safetyAlertsEnabled ?? this.safetyAlertsEnabled,
    batteryAlertsEnabled: batteryAlertsEnabled ?? this.batteryAlertsEnabled,
    chargingAlertsEnabled: chargingAlertsEnabled ?? this.chargingAlertsEnabled,
    passengerProfiles: passengerProfiles ?? this.passengerProfiles,
    selectedProfileId: clearSelectedProfileId
        ? null
        : selectedProfileId ?? this.selectedProfileId,
    alertHistory: alertHistory ?? this.alertHistory,
    activeAlertKeys: activeAlertKeys ?? this.activeAlertKeys,
  );

  static bool _boolOrDefault(
    Map<String, dynamic> map,
    String key,
    bool defaultValue,
  ) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is! bool) throw FormatException('Invalid $key controls setting.');
    return value;
  }
}

class VehicleAlertEngine {
  VehicleAlertEngine({Iterable<String> activeKeys = const []})
    : _active = activeKeys.toSet();

  Set<String> _active;

  Set<String> get activeKeys => Set.unmodifiable(_active);

  List<VehicleAlert> evaluate(VehicleStateSnapshot snapshot) {
    final state = snapshot.state;
    final current = <String, ({String title, String message, VehicleAlertSeverity severity})>{};

    for (final door in VehicleDoor.values) {
      final doorState = state.doors[door] ?? const VehicleDoorState();
      if (state.speedKph > 0 && doorState.open) {
        current['door_open_moving_${door.wireName}'] = (
          title: '${door.label} door open while moving',
          message: 'Stop safely and close the ${door.label.toLowerCase()} door.',
          severity: VehicleAlertSeverity.critical,
        );
      } else if (state.speedKph > 0 && !doorState.locked) {
        current['door_unlocked_moving_${door.wireName}'] = (
          title: '${door.label} door unlocked while moving',
          message: 'Stop safely and secure the ${door.label.toLowerCase()} door.',
          severity: VehicleAlertSeverity.warning,
        );
      } else if (state.speedKph == 0 && doorState.open) {
        current['door_open_parked_${door.wireName}'] = (
          title: '${door.label} door is open',
          message: 'Check the ${door.label.toLowerCase()} door before leaving.',
          severity: VehicleAlertSeverity.warning,
        );
      } else if (state.speedKph == 0 && !doorState.locked) {
        current['door_unlocked_parked_${door.wireName}'] = (
          title: '${door.label} door unlocked',
          message: 'Secure the ${door.label.toLowerCase()} door before leaving.',
          severity: VehicleAlertSeverity.warning,
        );
      }
    }
    if (state.batteryPercent < 10) {
      current['battery_critical'] = (
        title: 'Battery critically low',
        message: 'Battery is below 10%. Plan a charge soon.',
        severity: VehicleAlertSeverity.critical,
      );
    } else if (state.batteryPercent < 20) {
      current['battery_low'] = (
        title: 'Battery running low',
        message: 'Battery is below 20%. Consider charging.',
        severity: VehicleAlertSeverity.warning,
      );
    }
    if (state.chargingConnected && state.chargingPowerKw <= 0) {
      current['charging_paused'] = (
        title: 'Charging paused',
        message: 'The charger is connected but no charging power is reported.',
        severity: VehicleAlertSeverity.warning,
      );
    }
    if (state.chargingConnected && state.chargingPowerKw > 0) {
      current['charging_active'] = (
        title: 'Charging started',
        message: 'The vehicle is charging.',
        severity: VehicleAlertSeverity.info,
      );
    }

    final created = <VehicleAlert>[];
    for (final entry in current.entries) {
      if (_active.contains(entry.key)) continue;
      created.add(
        VehicleAlert(
          id: '${snapshot.vehicleId}_${entry.key}_${snapshot.sequence}',
          kind: entry.key,
          title: entry.value.title,
          message: entry.value.message,
          severity: entry.value.severity,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            snapshot.timestampMillis,
          ),
        ),
      );
    }
    if (_active.contains('charging_active') &&
        !current.containsKey('charging_active')) {
      final interrupted = state.chargingInterrupted;
      final completed = state.batteryPercent >= state.targetChargePercent;
      final kind = interrupted
          ? 'charging_interrupted'
          : completed
          ? 'charging_completed'
          : 'charging_stopped';
      created.add(
        VehicleAlert(
          id: '${snapshot.vehicleId}_${kind}_${snapshot.sequence}',
          kind: kind,
          title: interrupted
              ? 'Charging interrupted'
              : completed
              ? 'Charging complete'
              : 'Charging stopped',
          message: interrupted
              ? 'Charging stopped unexpectedly before reaching the target.'
              : completed
              ? 'The vehicle reached its charge target.'
              : 'Charging was stopped before reaching the charge target.',
          severity: interrupted
              ? VehicleAlertSeverity.warning
              : VehicleAlertSeverity.info,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            snapshot.timestampMillis,
          ),
        ),
      );
    }
    _active = current.keys.toSet();
    return created;
  }
}
