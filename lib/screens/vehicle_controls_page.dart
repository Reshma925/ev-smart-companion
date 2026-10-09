import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vehicle_ble_protocol/vehicle_ble_protocol.dart';

import '../app_theme.dart';
import '../models/vehicle.dart';
import '../models/vehicle_controls.dart';
import '../models/vehicle_telemetry.dart';
import '../services/firestore_service.dart';
import '../services/vehicle_ble_client.dart';

class VehicleControlsPage extends StatefulWidget {
  const VehicleControlsPage({
    super.key,
    required this.vehicle,
    this.firestoreService,
  });

  final Vehicle vehicle;
  final FirestoreService? firestoreService;

  @override
  State<VehicleControlsPage> createState() => _VehicleControlsPageState();
}

class _VehicleControlsPageState extends State<VehicleControlsPage> {
  late final FirestoreService _firestore =
      widget.firestoreService ?? FirestoreService();
  late final VehicleBleClient _ble = VehicleBleClient();
  late final Stream<VehicleData?> _telemetry = _firestore.watchVehicleTelemetry(
    widget.vehicle.id,
  );
  late VehicleAlertEngine _alertEngine;

  VehicleControlsPreferences _preferences = const VehicleControlsPreferences();
  bool _preferencesLoading = true;
  bool _preferencesSaving = false;
  String? _preferencesError;
  String? _preferencesSaveError;
  double? _pendingTemperature;
  final Map<VehicleDoor, double> _pendingWindowLevels = {};
  Future<void> _preferenceWriteQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onBleChanged);
    _ble.snapshot.addListener(_onSnapshotChanged);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _preferencesLoading = false;
          _preferencesError = 'Sign in to use vehicle controls.';
        });
      }
      return;
    }
    try {
      final preferences = await _firestore.getVehicleControlsPreferences(
        uid: user.uid,
        vehicleId: widget.vehicle.id,
      );
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _preferencesLoading = false;
      });
      _alertEngine = VehicleAlertEngine(
        activeKeys: preferences.activeAlertKeys,
      );
      await _ble.start(widget.vehicle.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preferencesLoading = false;
        _preferencesError =
            'Could not load vehicle control preferences: $error';
      });
    }
  }

  void _onBleChanged() {
    if (mounted) setState(() {});
  }

  void _onSnapshotChanged() {
    final snapshot = _ble.snapshot.value;
    if (snapshot == null || !mounted) return;
    final newAlerts = _alertEngine.evaluate(snapshot);
    final activeAlertKeys = _alertEngine.activeKeys.toList()..sort();
    final activeAlertsChanged = !setEquals(
      _preferences.activeAlertKeys.toSet(),
      activeAlertKeys.toSet(),
    );
    final ids = _preferences.alertHistory.map((alert) => alert.id).toSet();
    final unseen = newAlerts.where((alert) => !ids.contains(alert.id)).toList();
    if (unseen.isEmpty && !activeAlertsChanged) return;

    setState(() {
      _preferences = _preferences.copyWith(
        activeAlertKeys: activeAlertKeys,
        alertHistory: unseen.isEmpty
            ? _preferences.alertHistory
            : [
                ...unseen.reversed,
                ..._preferences.alertHistory,
              ].take(50).toList(growable: false),
      );
    });
    unawaited(_savePreferences(showError: false));
    if (_preferences.notificationsEnabled) {
      final alert = unseen.where(_isNotificationEnabled).firstOrNull;
      if (alert == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${alert.title}: ${alert.message}'),
            backgroundColor: alert.severity == VehicleAlertSeverity.critical
                ? const Color(0xFFB3261E)
                : null,
          ),
        );
    }
  }

  bool _isNotificationEnabled(VehicleAlert alert) {
    if (alert.kind.startsWith('door_')) {
      return _preferences.safetyAlertsEnabled;
    }
    if (alert.kind.startsWith('battery_')) {
      return _preferences.batteryAlertsEnabled;
    }
    if (alert.kind.startsWith('charging_')) {
      return _preferences.chargingAlertsEnabled;
    }
    return false;
  }

  Future<void> _savePreferences({bool showError = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (showError) _showMessage('Sign in again before saving preferences.');
      return;
    }
    final savedPreferences = _preferences;
    setState(() {
      _preferencesSaving = true;
      _preferencesSaveError = null;
    });
    try {
      final operation = _preferenceWriteQueue
          .catchError((Object _) {})
          .then(
            (_) => _firestore.saveVehicleControlsPreferences(
              uid: user.uid,
              vehicleId: widget.vehicle.id,
              preferences: savedPreferences,
            ),
          );
      _preferenceWriteQueue = operation;
      await operation;
    } catch (error) {
      debugPrint('[Vehicle Controls] Could not save preferences: $error');
      if (!mounted) return;
      setState(
        () => _preferencesSaveError =
            'Preferences could not be saved. Check your connection and retry.',
      );
      if (showError) _showMessage('Could not save controls preferences.');
    } finally {
      if (mounted) setState(() => _preferencesSaving = false);
    }
  }

  void _updatePreferences(VehicleControlsPreferences value) {
    setState(() => _preferences = value);
    unawaited(_savePreferences());
  }

  Future<void> _send(
    String action, {
    VehicleDoor? door,
    bool? enabled,
    int? level,
    double? temperatureC,
  }) async {
    try {
      await _ble.send(
        VehicleControlCommand(
          requestId: DateTime.now().microsecondsSinceEpoch.toString(),
          action: action,
          door: door,
          enabled: enabled,
          level: level,
          temperatureC: temperatureC,
        ),
      );
    } on VehicleSafetyException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('The vehicle command failed: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addPassengerProfile() async {
    if (_preferences.passengerProfiles.length >= 20) {
      _showMessage(
        'A maximum of 20 passenger profiles can be saved per vehicle.',
      );
      return;
    }
    final profile = await showDialog<PassengerProfile>(
      context: context,
      builder: (context) => const _PassengerProfileDialog(),
    );
    if (profile == null) return;
    final selectedProfile = profile.copyWith(lastUsedAt: DateTime.now());
    final profiles = [..._preferences.passengerProfiles, selectedProfile];
    setState(() {
      _preferences = _preferences.copyWith(
        passengerProfiles: profiles,
        selectedProfileId: selectedProfile.id,
      );
    });
    await _savePreferences();
    await _applyProfile(selectedProfile);
  }

  Future<void> _editPassengerProfile(PassengerProfile profile) async {
    final updatedProfile = await showDialog<PassengerProfile>(
      context: context,
      builder: (context) => _PassengerProfileDialog(initialProfile: profile),
    );
    if (updatedProfile == null) return;
    setState(() {
      _preferences = _preferences.copyWith(
        passengerProfiles: [
          for (final item in _preferences.passengerProfiles)
            if (item.id == profile.id) updatedProfile else item,
        ],
      );
    });
    await _savePreferences();
    if (_preferences.selectedProfileId == profile.id) {
      await _applyProfile(updatedProfile);
    }
  }

  Future<void> _selectPassengerProfile(PassengerProfile profile) async {
    final selectedProfile = profile.copyWith(lastUsedAt: DateTime.now());
    setState(() {
      _preferences = _preferences.copyWith(
        passengerProfiles: [
          for (final item in _preferences.passengerProfiles)
            if (item.id == profile.id) selectedProfile else item,
        ],
        selectedProfileId: profile.id,
      );
    });
    await _savePreferences();
    await _applyProfile(selectedProfile);
  }

  Future<void> _applyProfile(PassengerProfile profile) async {
    if (!_ble.isConnected) return;
    await _send('climate', enabled: true);
    await _send(
      'targetTemperature',
      temperatureC: profile.preferredTemperatureC.toDouble(),
    );
    await _send('fanLevel', level: profile.fanLevel);
    await _send('seatHeating', enabled: profile.seatHeating);
  }

  Future<void> _deletePassengerProfile(PassengerProfile profile) async {
    final profiles = _preferences.passengerProfiles
        .where((item) => item.id != profile.id)
        .toList(growable: false);
    setState(() {
      _preferences = _preferences.copyWith(
        passengerProfiles: profiles,
        clearSelectedProfileId: _preferences.selectedProfileId == profile.id,
      );
    });
    await _savePreferences();
  }

  Future<void> _showNotificationSettings() async {
    final result = await showModalBottomSheet<VehicleControlsPreferences>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _NotificationSettingsSheet(preferences: _preferences),
    );
    if (result != null) _updatePreferences(result);
  }

  @override
  void dispose() {
    _ble.removeListener(_onBleChanged);
    _ble.snapshot.removeListener(_onSnapshotChanged);
    _ble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    appBar: AppBar(
      title: const Text('Vehicle controls'),
      backgroundColor: AppTheme.background,
      actions: [
        IconButton(
          tooltip: 'Alert settings',
          onPressed: _showNotificationSettings,
          icon: const Icon(Icons.notifications_active_outlined),
        ),
      ],
    ),
    body: _preferencesLoading
        ? const Center(child: CircularProgressIndicator())
        : _preferencesError != null
        ? _PageError(message: _preferencesError!, onRetry: _initialize)
        : LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 920;
              final content = _buildDashboard(wide);
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: content,
                ),
              );
            },
          ),
  );

  Widget _buildDashboard(bool wide) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 16, wide ? 28 : 16, 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeading(vehicle: widget.vehicle, saving: _preferencesSaving),
        if (_preferencesSaveError != null) ...[
          const SizedBox(height: 8),
          _InlineError(message: _preferencesSaveError!),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _savePreferences(),
              child: const Text('Retry saving'),
            ),
          ),
        ],
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: _ble,
          builder: (context, _) => _BleStatusCard(
            phase: _ble.phase,
            error: _ble.error,
            onRetry: () => _ble.start(widget.vehicle.id),
          ),
        ),
        if (kIsWeb) ...[const SizedBox(height: 8), const _WebBleNotice()],
        const SizedBox(height: 14),
        StreamBuilder<VehicleData?>(
          stream: _telemetry,
          builder: (context, telemetrySnapshot) {
            final telemetry = telemetrySnapshot.data;
            return ValueListenableBuilder<VehicleStateSnapshot?>(
              valueListenable: _ble.snapshot,
              builder: (context, liveSnapshot, _) {
                final state = liveSnapshot?.state;
                final statusPanel = _VehicleStatusPanel(
                  state: state,
                  telemetry: telemetry,
                  telemetryError: telemetrySnapshot.hasError,
                  telemetryLoading:
                      telemetrySnapshot.connectionState ==
                      ConnectionState.waiting,
                );
                final vehiclePanel = _VehicleDoorPanel(
                  state: state,
                  enabled: _ble.isConnected,
                  speedKph: state?.speedKph ?? 0,
                  pendingWindowLevels: _pendingWindowLevels,
                  onDoorOpenChanged: (door, open) =>
                      _send('doorOpen', door: door, enabled: open),
                  onDoorLockChanged: (door, locked) =>
                      _send('doorLock', door: door, enabled: locked),
                  onWindowChanged: (door, level) =>
                      setState(() => _pendingWindowLevels[door] = level),
                  onWindowChangeEnd: (door, level) {
                    setState(() => _pendingWindowLevels.remove(door));
                    unawaited(
                      _send('windowLevel', door: door, level: level.round()),
                    );
                  },
                );
                final quickControls = _VehicleActionsPanel(
                  state: state,
                  enabled: _ble.isConnected,
                  onVehicleOnChanged: (value) =>
                      _send('vehicleOn', enabled: value),
                  onHeadlightsChanged: (value) =>
                      _send('headlights', enabled: value),
                );
                final climatePanel = _ClimatePanel(
                  state: state,
                  enabled: _ble.isConnected,
                  pendingTemperature: _pendingTemperature,
                  onTemperatureChanged: (value) =>
                      setState(() => _pendingTemperature = value),
                  onTemperatureChangeEnd: (value) {
                    setState(() => _pendingTemperature = null);
                    unawaited(_send('targetTemperature', temperatureC: value));
                  },
                  onClimateChanged: (enabled) =>
                      _send('climate', enabled: enabled),
                  onFanChanged: (level) => _send('fanLevel', level: level),
                  onSeatHeatingChanged: (enabled) =>
                      _send('seatHeating', enabled: enabled),
                );
                final chargingPanel = _ChargingPanel(
                  state: state,
                  enabled: _ble.isConnected,
                  onChargingChanged: (connected) =>
                      _send('chargingConnected', enabled: connected),
                  onTargetChanged: (value) =>
                      _send('targetCharge', level: value),
                );

                return Column(
                  children: [
                    statusPanel,
                    const SizedBox(height: 14),
                    quickControls,
                    const SizedBox(height: 14),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: vehiclePanel),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              children: [
                                climatePanel,
                                const SizedBox(height: 14),
                                chargingPanel,
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      vehiclePanel,
                      const SizedBox(height: 14),
                      climatePanel,
                      const SizedBox(height: 14),
                      chargingPanel,
                    ],
                    const SizedBox(height: 14),
                    _PassengerProfilesPanel(
                      preferences: _preferences,
                      enabled: _ble.isConnected,
                      onAdd: _addPassengerProfile,
                      onEdit: _editPassengerProfile,
                      onSelected: _selectPassengerProfile,
                      onDelete: _deletePassengerProfile,
                    ),
                    const SizedBox(height: 14),
                    _AlertsPanel(
                      preferences: _preferences,
                      onSettings: _showNotificationSettings,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    ),
  );
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.vehicle, required this.saving});

  final Vehicle vehicle;
  final bool saving;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vehicle.model.isEmpty ? 'Your vehicle' : vehicle.model,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              vehicle.registrationNumber,
              style: const TextStyle(color: AppTheme.mutedBlue),
            ),
            const SizedBox(height: 4),
            SelectableText(
              'Vehicle ID for simulator: ${vehicle.id}',
              style: const TextStyle(color: AppTheme.mutedBlue, fontSize: 11),
            ),
          ],
        ),
      ),
      if (saving)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
    ],
  );
}

class _BleStatusCard extends StatelessWidget {
  const _BleStatusCard({
    required this.phase,
    required this.error,
    required this.onRetry,
  });

  final VehicleBlePhase phase;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final connected = phase == VehicleBlePhase.connected;
    final message = switch (phase) {
      VehicleBlePhase.unsupported =>
        'Bluetooth vehicle connection requires a physical Android device.',
      VehicleBlePhase.authorizing => 'Requesting Bluetooth permission…',
      VehicleBlePhase.scanning => 'Looking for the EV Vehicle Simulator…',
      VehicleBlePhase.connecting => 'Connecting to the vehicle simulator…',
      VehicleBlePhase.connected => 'Connected · receiving live vehicle state',
      VehicleBlePhase.reconnecting => 'Connection interrupted · reconnecting…',
      VehicleBlePhase.error => error ?? 'Bluetooth connection failed.',
      VehicleBlePhase.stopped => 'Vehicle simulator is not connected.',
    };
    final color = connected ? const Color(0xFF13845A) : AppTheme.mutedBlue;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(
              connected
                  ? Icons.bluetooth_connected_rounded
                  : Icons.bluetooth_searching_rounded,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: error != null ? Colors.red.shade700 : AppTheme.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (phase == VehicleBlePhase.error ||
                phase == VehicleBlePhase.stopped)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _WebBleNotice extends StatelessWidget {
  const _WebBleNotice();

  @override
  Widget build(BuildContext context) => const Text(
    'Live Bluetooth controls are unavailable on Web. Open the app on a physical Android device to connect to a vehicle simulator.',
    style: TextStyle(color: AppTheme.mutedBlue, height: 1.4),
  );
}

class _VehicleStatusPanel extends StatelessWidget {
  const _VehicleStatusPanel({
    required this.state,
    required this.telemetry,
    required this.telemetryError,
    required this.telemetryLoading,
  });

  final VehicleControlState? state;
  final VehicleData? telemetry;
  final bool telemetryError;
  final bool telemetryLoading;

  @override
  Widget build(BuildContext context) {
    final battery = state?.batteryPercent ?? telemetry?.battery;
    final range = state?.rangeKm ?? telemetry?.range;
    final isCharging = state?.chargingConnected ?? telemetry?.isCharging;
    final values = [
      _Metric(
        'Battery',
        battery == null ? '—' : '${battery.round()}%',
        Icons.battery_charging_full_rounded,
      ),
      _Metric(
        'Range',
        range == null ? '—' : '${range.round()} km',
        Icons.route_rounded,
      ),
      _Metric(
        'Speed',
        state == null ? '—' : '${state!.speedKph.round()} km/h',
        Icons.speed_rounded,
      ),
      _Metric(
        'Charging',
        isCharging == null
            ? '—'
            : isCharging
            ? 'Connected'
            : 'Not connected',
        Icons.ev_station_rounded,
      ),
    ];
    return _Panel(
      title: 'Vehicle status',
      subtitle: state == null
          ? telemetryError
                ? 'Cloud telemetry is unavailable'
                : telemetryLoading
                ? 'Loading vehicle telemetry…'
                : 'Cloud telemetry · connect the simulator for live controls'
          : 'Live BLE telemetry from the simulator',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (telemetryError) ...[
            const Text(
              'Could not refresh cloud telemetry. BLE controls remain available if connected.',
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
            const SizedBox(height: 10),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 440 ? 2 : 4;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final metric in values)
                    SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 8) / columns,
                      child: _MetricTile(metric: metric),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F7FA),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(metric.icon, size: 19, color: AppTheme.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.label,
                style: const TextStyle(fontSize: 11, color: AppTheme.mutedBlue),
              ),
              const SizedBox(height: 3),
              Text(
                metric.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VehicleActionsPanel extends StatelessWidget {
  const _VehicleActionsPanel({
    required this.state,
    required this.enabled,
    required this.onVehicleOnChanged,
    required this.onHeadlightsChanged,
  });

  final VehicleControlState? state;
  final bool enabled;
  final ValueChanged<bool> onVehicleOnChanged;
  final ValueChanged<bool> onHeadlightsChanged;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Vehicle',
    subtitle: 'Power and exterior lighting',
    child: Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Vehicle power'),
          subtitle: Text(state?.vehicleOn == true ? 'Ready' : 'Off'),
          value: state?.vehicleOn ?? false,
          onChanged: enabled ? onVehicleOnChanged : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Headlights'),
          value: state?.lightsOn ?? false,
          onChanged: enabled ? onHeadlightsChanged : null,
        ),
      ],
    ),
  );
}

class _VehicleDoorPanel extends StatelessWidget {
  const _VehicleDoorPanel({
    required this.state,
    required this.enabled,
    required this.speedKph,
    required this.pendingWindowLevels,
    required this.onDoorOpenChanged,
    required this.onDoorLockChanged,
    required this.onWindowChanged,
    required this.onWindowChangeEnd,
  });

  final VehicleControlState? state;
  final bool enabled;
  final double speedKph;
  final Map<VehicleDoor, double> pendingWindowLevels;
  final void Function(VehicleDoor door, bool open) onDoorOpenChanged;
  final void Function(VehicleDoor door, bool locked) onDoorLockChanged;
  final void Function(VehicleDoor door, double level) onWindowChanged;
  final void Function(VehicleDoor door, double level) onWindowChangeEnd;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Doors and windows',
    subtitle:
        'Four individually controlled doors · opening is disabled while moving',
    child: Column(
      children: [
        _VehicleDoorDiagram(
          state: state,
          enabled: enabled,
          speedKph: speedKph,
          onDoorChanged: onDoorOpenChanged,
        ),
        const SizedBox(height: 14),
        for (final door in VehicleDoor.values)
          _DoorRow(
            door: door,
            state: state?.doors[door] ?? const VehicleDoorState(),
            windowLevel: state?.windows[door] ?? 0,
            pendingWindowLevel: pendingWindowLevels[door],
            enabled: enabled,
            moving: speedKph > 0,
            onDoorChanged: (open) => onDoorOpenChanged(door, open),
            onLockChanged: (locked) => onDoorLockChanged(door, locked),
            onWindowChanged: (level) => onWindowChanged(door, level),
            onWindowChangeEnd: (level) => onWindowChangeEnd(door, level),
          ),
      ],
    ),
  );
}

class _VehicleDoorDiagram extends StatelessWidget {
  const _VehicleDoorDiagram({
    required this.state,
    required this.enabled,
    required this.speedKph,
    required this.onDoorChanged,
  });

  final VehicleControlState? state;
  final bool enabled;
  final double speedKph;
  final void Function(VehicleDoor door, bool open) onDoorChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final carWidth = (width * 0.30).clamp(104.0, 154.0);
      final doorWidth = ((width - carWidth - 28) / 2).clamp(82.0, 118.0);
      return SizedBox(
        height: 226,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: carWidth,
              height: 196,
              decoration: BoxDecoration(
                color: const Color(0xFF162A40),
                borderRadius: BorderRadius.circular(carWidth / 2),
                border: Border.all(color: const Color(0xFF92A7BA), width: 3),
              ),
            ),
            Positioned(
              top: 54,
              child: Container(
                width: carWidth * 0.64,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFF8EC5E7),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            Positioned(
              bottom: 54,
              child: Container(
                width: carWidth * 0.64,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFF8EC5E7),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            Positioned(
              top: 63,
              left: 4,
              child: _DoorDiagramButton(
                door: VehicleDoor.frontLeft,
                state: state?.doors[VehicleDoor.frontLeft],
                width: doorWidth,
                enabled: enabled,
                canOpen: speedKph <= 0,
                onChanged: onDoorChanged,
              ),
            ),
            Positioned(
              top: 63,
              right: 4,
              child: _DoorDiagramButton(
                door: VehicleDoor.frontRight,
                state: state?.doors[VehicleDoor.frontRight],
                width: doorWidth,
                enabled: enabled,
                canOpen: speedKph <= 0,
                onChanged: onDoorChanged,
              ),
            ),
            Positioned(
              bottom: 51,
              left: 4,
              child: _DoorDiagramButton(
                door: VehicleDoor.rearLeft,
                state: state?.doors[VehicleDoor.rearLeft],
                width: doorWidth,
                enabled: enabled,
                canOpen: speedKph <= 0,
                onChanged: onDoorChanged,
              ),
            ),
            Positioned(
              bottom: 51,
              right: 4,
              child: _DoorDiagramButton(
                door: VehicleDoor.rearRight,
                state: state?.doors[VehicleDoor.rearRight],
                width: doorWidth,
                enabled: enabled,
                canOpen: speedKph <= 0,
                onChanged: onDoorChanged,
              ),
            ),
            if (state == null)
              const Positioned(
                bottom: 4,
                child: Text(
                  'Connect simulator to control doors',
                  style: TextStyle(color: AppTheme.mutedBlue, fontSize: 11),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _DoorDiagramButton extends StatelessWidget {
  const _DoorDiagramButton({
    required this.door,
    required this.state,
    required this.width,
    required this.enabled,
    required this.canOpen,
    required this.onChanged,
  });

  final VehicleDoor door;
  final VehicleDoorState? state;
  final double width;
  final bool enabled;
  final bool canOpen;
  final void Function(VehicleDoor door, bool open) onChanged;

  @override
  Widget build(BuildContext context) {
    final isOpen = state?.open ?? false;
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: enabled && (!isOpen ? canOpen : true)
            ? () => onChanged(door, !isOpen)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          decoration: BoxDecoration(
            color: isOpen
                ? const Color(0xFFFFEBCF)
                : enabled
                ? const Color(0xFFE4F3ED)
                : const Color(0xFFE8EDF1),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isOpen ? Colors.orange : const Color(0xFFB8C9D7),
            ),
          ),
          child: Column(
            children: [
              AnimatedRotation(
                turns: isOpen
                    ? (door == VehicleDoor.frontLeft ||
                              door == VehicleDoor.rearLeft
                          ? -0.08
                          : 0.08)
                    : 0,
                duration: const Duration(milliseconds: 220),
                child: Icon(
                  isOpen ? Icons.door_sliding_outlined : Icons.sensor_door,
                  size: 20,
                  color: isOpen ? Colors.deepOrange : AppTheme.blue,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                switch (door) {
                  VehicleDoor.frontLeft => 'Front L',
                  VehicleDoor.frontRight => 'Front R',
                  VehicleDoor.rearLeft => 'Rear L',
                  VehicleDoor.rearRight => 'Rear R',
                },
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                isOpen ? 'OPEN' : 'CLOSED',
                style: TextStyle(
                  fontSize: 9,
                  color: isOpen ? Colors.deepOrange : AppTheme.mutedBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoorRow extends StatelessWidget {
  const _DoorRow({
    required this.door,
    required this.state,
    required this.windowLevel,
    required this.pendingWindowLevel,
    required this.enabled,
    required this.moving,
    required this.onDoorChanged,
    required this.onLockChanged,
    required this.onWindowChanged,
    required this.onWindowChangeEnd,
  });

  final VehicleDoor door;
  final VehicleDoorState state;
  final int windowLevel;
  final double? pendingWindowLevel;
  final bool enabled;
  final bool moving;
  final ValueChanged<bool> onDoorChanged;
  final ValueChanged<bool> onLockChanged;
  final ValueChanged<double> onWindowChanged;
  final ValueChanged<double> onWindowChangeEnd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                door.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: enabled && (state.open || !moving)
                  ? () => onDoorChanged(!state.open)
                  : null,
              child: Text(state.open ? 'Close' : 'Open'),
            ),
            IconButton(
              tooltip: state.locked ? 'Unlock' : 'Lock',
              onPressed: enabled ? () => onLockChanged(!state.locked) : null,
              icon: Icon(
                state.locked ? Icons.lock_outline : Icons.lock_open_rounded,
              ),
            ),
            Text(
              '${(pendingWindowLevel ?? windowLevel.toDouble()).round()}%',
              style: const TextStyle(color: AppTheme.mutedBlue, fontSize: 12),
            ),
          ],
        ),
        Slider(
          value: (pendingWindowLevel ?? windowLevel.toDouble())
              .clamp(0, 100)
              .toDouble(),
          max: 100,
          divisions: 10,
          label: '${(pendingWindowLevel ?? windowLevel.toDouble()).round()}%',
          onChanged: enabled ? onWindowChanged : null,
          onChangeEnd: enabled ? onWindowChangeEnd : null,
        ),
      ],
    ),
  );
}

class _ClimatePanel extends StatelessWidget {
  const _ClimatePanel({
    required this.state,
    required this.enabled,
    required this.pendingTemperature,
    required this.onTemperatureChanged,
    required this.onTemperatureChangeEnd,
    required this.onClimateChanged,
    required this.onFanChanged,
    required this.onSeatHeatingChanged,
  });

  final VehicleControlState? state;
  final bool enabled;
  final double? pendingTemperature;
  final ValueChanged<double> onTemperatureChanged;
  final ValueChanged<double> onTemperatureChangeEnd;
  final ValueChanged<bool> onClimateChanged;
  final ValueChanged<int> onFanChanged;
  final ValueChanged<bool> onSeatHeatingChanged;

  @override
  Widget build(BuildContext context) {
    final climateOn = state?.climateOn ?? false;
    final temperature = pendingTemperature ?? state?.targetTemperatureC ?? 21;
    final fanLevel = state?.fanLevel ?? 1;
    return _Panel(
      title: 'Climate',
      subtitle: enabled
          ? 'Cabin climate controls'
          : 'Connect the simulator to adjust climate',
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Climate system'),
            value: climateOn,
            onChanged: enabled ? onClimateChanged : null,
          ),
          Row(
            children: [
              const Expanded(child: Text('Target temperature')),
              Text('${temperature.round()} °C'),
            ],
          ),
          Slider(
            value: temperature.clamp(16, 30).toDouble(),
            min: 16,
            max: 30,
            divisions: 14,
            label: '${temperature.round()} °C',
            onChanged: enabled ? onTemperatureChanged : null,
            onChangeEnd: enabled ? onTemperatureChangeEnd : null,
          ),
          Row(
            children: [
              const Expanded(child: Text('Fan speed')),
              DropdownButton<int>(
                value: fanLevel.clamp(0, 5).toInt(),
                items: [
                  for (var level = 0; level <= 5; level++)
                    DropdownMenuItem(value: level, child: Text('$level')),
                ],
                onChanged: enabled && state != null
                    ? (value) {
                        if (value != null) onFanChanged(value);
                      }
                    : null,
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Seat heating'),
            value: state?.seatHeatingEnabled ?? false,
            onChanged: enabled ? onSeatHeatingChanged : null,
          ),
        ],
      ),
    );
  }
}

class _ChargingPanel extends StatelessWidget {
  const _ChargingPanel({
    required this.state,
    required this.enabled,
    required this.onChargingChanged,
    required this.onTargetChanged,
  });

  final VehicleControlState? state;
  final bool enabled;
  final ValueChanged<bool> onChargingChanged;
  final ValueChanged<int> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    final connected = state?.chargingConnected ?? false;
    final target = state?.targetChargePercent ?? 80;
    return _Panel(
      title: 'Charging',
      subtitle: 'Charging state reported by the connected simulator',
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Charger connected'),
            subtitle: Text(
              connected
                  ? '${state?.chargingPowerKw.toStringAsFixed(1) ?? '0.0'} kW'
                  : 'Not charging',
            ),
            value: connected,
            onChanged: enabled ? onChargingChanged : null,
          ),
          Row(
            children: [
              const Expanded(child: Text('Charge target')),
              Text('$target%'),
            ],
          ),
          Slider(
            value: target.toDouble(),
            min: 50,
            max: 100,
            divisions: 10,
            label: '$target%',
            onChanged: enabled && state != null
                ? (value) => onTargetChanged(value.round())
                : null,
          ),
        ],
      ),
    );
  }
}

class _PassengerProfilesPanel extends StatelessWidget {
  const _PassengerProfilesPanel({
    required this.preferences,
    required this.enabled,
    required this.onAdd,
    required this.onEdit,
    required this.onSelected,
    required this.onDelete,
  });

  final VehicleControlsPreferences preferences;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<PassengerProfile> onEdit;
  final ValueChanged<PassengerProfile> onSelected;
  final ValueChanged<PassengerProfile> onDelete;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Passenger profiles',
    subtitle: 'Saved for this vehicle',
    trailing: IconButton(
      tooltip: 'Add passenger profile',
      onPressed: onAdd,
      icon: const Icon(Icons.person_add_alt_1_rounded),
    ),
    child: preferences.passengerProfiles.isEmpty
        ? const Text(
            'Add a profile to save preferred cabin temperature and fan settings.',
            style: TextStyle(color: AppTheme.mutedBlue),
          )
        : Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final profile in preferences.passengerProfiles)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InputChip(
                      label: Text(
                        '${profile.name} · ${profile.role} · ${profile.seatPosition}',
                      ),
                      tooltip: [
                        'Mirrors L(${profile.leftMirrorHorizontal.round()},'
                            '${profile.leftMirrorVertical.round()}) '
                            'R(${profile.rightMirrorHorizontal.round()},'
                            '${profile.rightMirrorVertical.round()})',
                        profile.lastUsedAt == null
                            ? 'Not used yet'
                            : 'Last used ${profile.lastUsedAt!.toLocal()}',
                      ].join(' · '),
                      selected: profile.id == preferences.selectedProfileId,
                      onPressed: enabled ? () => onSelected(profile) : null,
                      onDeleted: () => onDelete(profile),
                      avatar: const Icon(Icons.person_outline, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Edit ${profile.name}',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onEdit(profile),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                  ],
                ),
            ],
          ),
  );
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({required this.preferences, required this.onSettings});

  final VehicleControlsPreferences preferences;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Alerts and history',
    subtitle: 'Safety, battery and charging notifications',
    trailing: TextButton(onPressed: onSettings, child: const Text('Settings')),
    child: preferences.alertHistory.isEmpty
        ? const _EmptyAlerts()
        : Column(
            children: [
              for (final alert in preferences.alertHistory.take(6))
                _AlertTile(alert: alert),
              if (preferences.alertHistory.length > 6)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${preferences.alertHistory.length - 6} earlier alerts saved',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mutedBlue,
                    ),
                  ),
                ),
            ],
          ),
  );
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Icon(Icons.check_circle_outline, color: Color(0xFF168266)),
        SizedBox(width: 10),
        Expanded(child: Text('No vehicle alerts have been recorded.')),
      ],
    ),
  );
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final VehicleAlert alert;

  @override
  Widget build(BuildContext context) {
    final color = switch (alert.severity) {
      VehicleAlertSeverity.critical => const Color(0xFFCC3445),
      VehicleAlertSeverity.warning => const Color(0xFFCC8128),
      VehicleAlertSeverity.info => AppTheme.blue,
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        alert.severity == VehicleAlertSeverity.critical
            ? Icons.error_outline_rounded
            : Icons.warning_amber_rounded,
        color: color,
      ),
      title: Text(alert.title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(alert.message),
      trailing: Text(
        TimeOfDay.fromDateTime(alert.timestamp).format(context),
        style: const TextStyle(fontSize: 11, color: AppTheme.mutedBlue),
      ),
    );
  }
}

class _NotificationSettingsSheet extends StatefulWidget {
  const _NotificationSettingsSheet({required this.preferences});

  final VehicleControlsPreferences preferences;

  @override
  State<_NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends State<_NotificationSettingsSheet> {
  late VehicleControlsPreferences _value = widget.preferences;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Alert settings', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
            title: const Text('In-app notifications'),
            value: _value.notificationsEnabled,
            onChanged: (enabled) => setState(
              () => _value = _value.copyWith(notificationsEnabled: enabled),
            ),
          ),
          SwitchListTile(
            title: const Text('Safety alerts'),
            value: _value.safetyAlertsEnabled,
            onChanged: (enabled) => setState(
              () => _value = _value.copyWith(safetyAlertsEnabled: enabled),
            ),
          ),
          SwitchListTile(
            title: const Text('Battery alerts'),
            value: _value.batteryAlertsEnabled,
            onChanged: (enabled) => setState(
              () => _value = _value.copyWith(batteryAlertsEnabled: enabled),
            ),
          ),
          SwitchListTile(
            title: const Text('Charging alerts'),
            value: _value.chargingAlertsEnabled,
            onChanged: (enabled) => setState(
              () => _value = _value.copyWith(chargingAlertsEnabled: enabled),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _value),
              child: const Text('Save settings'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PassengerProfileDialog extends StatefulWidget {
  const _PassengerProfileDialog({this.initialProfile});

  final PassengerProfile? initialProfile;

  @override
  State<_PassengerProfileDialog> createState() =>
      _PassengerProfileDialogState();
}

class _PassengerProfileDialogState extends State<_PassengerProfileDialog> {
  final TextEditingController _name = TextEditingController();
  double _temperature = 21;
  int _fanLevel = 1;
  bool _seatHeating = false;
  String _role = 'passenger';
  String _seatPosition = 'frontLeft';
  double _leftMirrorHorizontal = 0;
  double _leftMirrorVertical = 0;
  double _rightMirrorHorizontal = 0;
  double _rightMirrorVertical = 0;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    if (profile == null) return;
    _name.text = profile.name;
    _temperature = profile.preferredTemperatureC.toDouble();
    _fanLevel = profile.fanLevel;
    _seatHeating = profile.seatHeating;
    _role = profile.role;
    _seatPosition = profile.seatPosition;
    _leftMirrorHorizontal = profile.leftMirrorHorizontal;
    _leftMirrorVertical = profile.leftMirrorVertical;
    _rightMirrorHorizontal = profile.rightMirrorHorizontal;
    _rightMirrorVertical = profile.rightMirrorVertical;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      PassengerProfile(
        id:
            widget.initialProfile?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        role: _role,
        seatPosition: _seatPosition,
        preferredTemperatureC: _temperature.round(),
        fanLevel: _fanLevel,
        seatHeating: _seatHeating,
        leftMirrorHorizontal: _leftMirrorHorizontal,
        leftMirrorVertical: _leftMirrorVertical,
        rightMirrorHorizontal: _rightMirrorHorizontal,
        rightMirrorVertical: _rightMirrorVertical,
        lastUsedAt: widget.initialProfile?.lastUsedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initialProfile == null ? 'Passenger profile' : 'Edit profile',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(value: 'driver', child: Text('Driver')),
              DropdownMenuItem(value: 'passenger', child: Text('Passenger')),
              DropdownMenuItem(value: 'child', child: Text('Child')),
              DropdownMenuItem(value: 'caregiver', child: Text('Caregiver')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _role = value);
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: _seatPosition,
            decoration: const InputDecoration(labelText: 'Seat position'),
            items: const [
              DropdownMenuItem(value: 'frontLeft', child: Text('Front left')),
              DropdownMenuItem(value: 'frontRight', child: Text('Front right')),
              DropdownMenuItem(value: 'rearLeft', child: Text('Rear left')),
              DropdownMenuItem(value: 'rearRight', child: Text('Rear right')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _seatPosition = value);
            },
          ),
          Row(
            children: [
              const Expanded(child: Text('Preferred temperature')),
              Text('${_temperature.round()} °C'),
            ],
          ),
          Slider(
            value: _temperature,
            min: 16,
            max: 30,
            divisions: 14,
            onChanged: (value) => setState(() => _temperature = value),
          ),
          DropdownButtonFormField<int>(
            initialValue: _fanLevel,
            decoration: const InputDecoration(labelText: 'Fan level'),
            items: [
              for (var level = 0; level <= 5; level++)
                DropdownMenuItem(value: level, child: Text('$level')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _fanLevel = value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Seat heating preference'),
            value: _seatHeating,
            onChanged: (value) => setState(() => _seatHeating = value),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Mirror preferences (saved with this profile)'),
            ),
          ),
          const Text(
            'Seat and mirror preferences are saved to this vehicle profile. '
            'The current simulator applies cabin climate and seat heating.',
            style: TextStyle(fontSize: 12, color: AppTheme.mutedBlue),
          ),
          _mirrorSlider(
            'Left mirror horizontal',
            _leftMirrorHorizontal,
            (value) => setState(() => _leftMirrorHorizontal = value),
          ),
          _mirrorSlider(
            'Left mirror vertical',
            _leftMirrorVertical,
            (value) => setState(() => _leftMirrorVertical = value),
          ),
          _mirrorSlider(
            'Right mirror horizontal',
            _rightMirrorHorizontal,
            (value) => setState(() => _rightMirrorHorizontal = value),
          ),
          _mirrorSlider(
            'Right mirror vertical',
            _rightMirrorVertical,
            (value) => setState(() => _rightMirrorVertical = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _name.text.trim().isEmpty ? null : _save,
        child: Text(
          widget.initialProfile == null ? 'Save profile' : 'Save changes',
        ),
      ),
    ],
  );

  Widget _mirrorSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text(value.round().toString()),
        ],
      ),
      Slider(
        value: value,
        min: -20,
        max: 20,
        divisions: 40,
        onChanged: onChanged,
      ),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppTheme.mutedBlue,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _PageError extends StatelessWidget {
  const _PageError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42, color: Colors.red),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFECEC),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message, style: TextStyle(color: Colors.red.shade800)),
  );
}
