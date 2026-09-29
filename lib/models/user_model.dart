import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.vehicleId,
    this.vehicleRegistrationNumber = '',
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? vehicleId;
  final String vehicleRegistrationNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? map['mobile'] as String? ?? '',
      vehicleId: map['vehicleId'] as String?,
      vehicleRegistrationNumber:
          map['vehicleRegistrationNumber'] as String? ?? '',
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
