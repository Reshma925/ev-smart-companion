import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleData {
  const VehicleData({
    required this.battery,
    required this.range,
    required this.batteryHealth,
    required this.healthScore,
    required this.isCharging,
    this.updatedAt,
  });

  final double battery;
  final double range;
  final double batteryHealth;
  final int healthScore;
  final bool isCharging;
  final DateTime? updatedAt;

  factory VehicleData.fromMap(Map<String, dynamic> map) {
    return VehicleData(
      battery: (map['battery'] as num?)?.toDouble() ?? 0,
      range: (map['range'] as num?)?.toDouble() ?? 0,
      batteryHealth: (map['batteryHealth'] as num?)?.toDouble() ?? 0,
      healthScore: (map['healthScore'] as num?)?.toInt() ?? 0,
      isCharging: map['isCharging'] as bool? ?? false,
      updatedAt: _readDate(map['updatedAt']),
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class VehicleSimulator {
  VehicleSimulator({required String vehicleId})
      : _doc = FirebaseFirestore.instance
            .collection('vehicles')
            .doc(vehicleId)
            .collection('telemetry')
            .doc('live');

  final DocumentReference<Map<String, dynamic>> _doc;
  Timer? _timer;
  double _battery = 80;
  double _batteryHealth = 95;
  bool _isCharging = false;
  static const double _maxRange = 300;

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
