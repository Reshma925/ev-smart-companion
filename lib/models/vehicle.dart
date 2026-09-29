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
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String model;
  final String registrationNumber;
  final String ownerName;
  final String vin;
  final String bluetoothDeviceId;
  final String bluetoothDeviceName;
  final bool isActive;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
    'model': model,
    'registrationNumber': registrationNumber,
    'ownerName': ownerName,
    'vin': vin,
    'bluetoothDeviceId': bluetoothDeviceId,
    'bluetoothDeviceName': bluetoothDeviceName,
    'isActive': isActive,
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
        createdAt: _dateTimeFrom(map['createdAt']),
      );

  static DateTime? _dateTimeFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
