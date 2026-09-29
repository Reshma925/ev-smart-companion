import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleData {
  final double battery; // %
  final double range; // km
  final double batteryHealth; // %
  final int healthScore; // 0-100
  final bool isCharging;

  VehicleData(
    this.battery,
    this.range,
    this.batteryHealth,
    this.healthScore,
    this.isCharging,
  );

  // Turns the data saved in Firebase back into VehicleData
  factory VehicleData.fromMap(Map<String, dynamic> m) => VehicleData(
    (m['battery'] as num).toDouble(),
    (m['range'] as num).toDouble(),
    (m['batteryHealth'] as num).toDouble(),
    (m['healthScore'] as num).toInt(),
    m['isCharging'] as bool,
  );
}

class VehicleSimulator {
  VehicleSimulator({required String vehicleId})
    : _doc = FirebaseFirestore.instance
          .collection('vehicles')
          .doc(vehicleId)
          .collection('telemetry')
          .doc('live');

  // Telemetry is separated from the pre-registered vehicle identity document.
  final DocumentReference<Map<String, dynamic>> _doc;
  Timer? _timer;
  double _battery = 80;
  double _batteryHealth = 95;
  bool _isCharging = false;
  static const double _maxRange = 300;

  // Telemetry is sourced exclusively from the mapped vehicle's Firestore path.
  Stream<VehicleData> get stream => _doc
      .snapshots()
      .where((snap) {
        final data = snap.data();
        return data != null &&
            data['battery'] is num &&
            data['range'] is num &&
            data['batteryHealth'] is num &&
            data['healthScore'] is num &&
            data['isCharging'] is bool;
      })
      .map((snap) => VehicleData.fromMap(snap.data()!));

  /// Generates development telemetry for this Firestore vehicle ID.
  /// Vehicle identity is always fetched separately from `vehicles/{vehicleId}`.
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_isCharging) {
        _battery = (_battery + 1).clamp(0, 100).toDouble();
        if (_battery >= 100) _isCharging = false;
      } else {
        _battery = (_battery - 0.5).clamp(0, 100).toDouble();
        if (_battery <= 20) _isCharging = true;
      }

      _batteryHealth = (_batteryHealth - 0.001).clamp(0, 100).toDouble();
      final range = _maxRange * (_battery / 100) * (_batteryHealth / 100);
      final healthScore = (_batteryHealth * 0.7 + _battery * 0.3).round();

      try {
        await _doc.set({
          'battery': double.parse(_battery.toStringAsFixed(1)),
          'range': double.parse(range.toStringAsFixed(1)),
          'batteryHealth': double.parse(_batteryHealth.toStringAsFixed(2)),
          'healthScore': healthScore,
          'isCharging': _isCharging,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (error, stackTrace) {
        // Preview telemetry can fail without changing registered vehicle data.
        developer.log(
          'Failed to write telemetry for vehicle ${_doc.parent.parent?.id}: $error',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
