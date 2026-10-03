import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.vehicleId,
    this.vehicleRegistrationNumber = '',
    this.profileImageUrl = '',
    this.city = '',
    this.dateOfBirth,
    this.preferredDrivingMode = '',
    this.preferredChargingMode = '',
    this.notificationPreference = '',
    this.distanceUnit = 'km',
    this.notificationsEnabled = true,
    this.locationEnabled = false,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? vehicleId;
  final String vehicleRegistrationNumber;
  final String profileImageUrl;
  final String city;
  final DateTime? dateOfBirth;
  final String preferredDrivingMode;
  final String preferredChargingMode;
  final String notificationPreference;
  final String distanceUnit;
  final bool notificationsEnabled;
  final bool locationEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final preferences = map['preferences'] is Map
        ? map['preferences'] as Map
        : <String, dynamic>{};
    final distanceUnit =
        (preferences['distanceUnit'] as String? ??
                map['distanceUnit'] as String? ??
                map['unitSystem'] as String? ??
                'km')
            .trim();
    final notificationsEnabled =
        preferences['notificationsEnabled'] as bool? ??
        map['notificationsEnabled'] as bool? ??
        (map['notificationPreference'] as String? ?? '').toLowerCase() != 'off';
    final locationEnabled =
        preferences['locationEnabled'] as bool? ??
        map['locationEnabled'] as bool? ??
        false;

    return UserModel(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? map['mobile'] as String? ?? '',
      vehicleId: map['vehicleId'] as String?,
      vehicleRegistrationNumber:
          map['vehicleRegistrationNumber'] as String? ?? '',
      profileImageUrl: map['profileImageUrl'] as String? ?? '',
      city: map['city'] as String? ?? '',
      dateOfBirth: _dateTimeFrom(map['dateOfBirth'] ?? map['dob']),
      preferredDrivingMode: map['preferredDrivingMode'] as String? ?? '',
      preferredChargingMode: map['preferredChargingMode'] as String? ?? '',
      notificationPreference:
          map['notificationPreference'] as String? ??
          preferences['notificationPreference'] as String? ??
          'All alerts',
      distanceUnit: distanceUnit.isEmpty ? 'km' : distanceUnit,
      notificationsEnabled: notificationsEnabled,
      locationEnabled: locationEnabled,
      createdAt: _dateTimeFrom(map['createdAt']),
      updatedAt: _dateTimeFrom(map['updatedAt']),
    );
  }

  static DateTime? _dateTimeFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Transient signup data kept in memory only until vehicle onboarding finishes.
class PendingSignup {
  const PendingSignup({
    required this.name,
    required this.email,
    required this.mobile,
    this.password,
  });

  final String name;
  final String email;
  final String mobile;
  final String? password;
}
