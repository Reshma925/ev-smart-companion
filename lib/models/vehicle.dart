import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  const Vehicle({
    this.id = '',
    required this.model,
    required this.registrationNumber,
    required this.ownerName,
    required this.vin,
    this.bluetoothDeviceId = '',
    this.bluetoothDeviceName = '',
    this.isActive = false,
    this.batteryCapacityKwh,
    this.batteryPercentage,
    double? maximumRangeKm,
    double? estimatedRangeKm,
    this.health,
    this.connectorType = '',
    this.createdAt,
  }) : maximumRangeKm = maximumRangeKm ?? estimatedRangeKm;

  final String id;
  final String model;
  final String registrationNumber;
  final String ownerName;
  final String vin;
  final String bluetoothDeviceId;
  final String bluetoothDeviceName;
  final bool isActive;
  final double? batteryCapacityKwh;
  final double? batteryPercentage;
  final double? maximumRangeKm;
  final double? health;
  final String connectorType;
  final DateTime? createdAt;

  double? get estimatedRangeKm => maximumRangeKm;
  double? get estimatedRange => maximumRangeKm;

  Map<String, dynamic> toMap() => {
    'model': model,
    'registrationNumber': registrationNumber,
    'ownerName': ownerName,
    'vin': vin,
    'bluetoothDeviceId': bluetoothDeviceId,
    'bluetoothDeviceName': bluetoothDeviceName,
    'isActive': isActive,
    if (batteryCapacityKwh != null) 'batteryCapacityKwh': batteryCapacityKwh,
    if (batteryPercentage != null) 'batteryPercentage': batteryPercentage,
    if (maximumRangeKm != null) 'maximumRangeKm': maximumRangeKm,
    if (health != null) 'health': health,
    'connectorType': connectorType,
  };

  factory Vehicle.fromMap(Map<String, dynamic> map, {String id = ''}) =>
      Vehicle(
        id: id,
        model: map['model'] as String? ?? '',
        registrationNumber: map['registrationNumber'] as String? ?? '',
        ownerName: map['ownerName'] as String? ?? '',
        vin: map['vin'] as String? ?? '',
        bluetoothDeviceId: map['bluetoothDeviceId'] as String? ?? '',
        bluetoothDeviceName: map['bluetoothDeviceName'] as String? ?? '',
        isActive: map['isActive'] as bool? ?? false,
        batteryCapacityKwh: _asDouble(
          map['batteryCapacityKwh'] ?? map['batteryCapacity'],
        ),
        batteryPercentage: _firstDouble([
          map['batteryPercentage'],
          map['battery'],
        ]),
        maximumRangeKm: _firstDouble([
          map['maximumRangeKm'],
          map['maxRangeKm'],
          map['estimatedRangeKm'],
          map['estimatedRange'],
          map['range'],
        ]),
        health: _asDouble(map['health'] ?? map['batteryHealth']),
        connectorType: (map['connectorType'] as String?) ?? '',
        createdAt: _dateTimeFrom(map['createdAt']),
      );

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static double? _firstDouble(Iterable<Object?> values) {
    for (final value in values) {
      final parsed = _asDouble(value);
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return null;
  }

  static DateTime? _dateTimeFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
