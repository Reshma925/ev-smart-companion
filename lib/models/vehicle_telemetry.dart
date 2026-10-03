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
      battery: _number(map['battery'] ?? map['batteryPercentage']),
      range: _number(map['range']),
      batteryHealth: _number(map['batteryHealth']),
      healthScore: _integer(map['healthScore']),
      isCharging: map['isCharging'] is bool && map['isCharging'] as bool,
      updatedAt: _readDate(map['updatedAt']),
    );
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _integer(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
