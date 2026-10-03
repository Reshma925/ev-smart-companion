import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/charging_card.dart';
import '../models/user_model.dart';
import '../models/vehicle.dart';
import '../models/vehicle_telemetry.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDocument(String uid) =>
      _firestore.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _chargingCardDocument(String uid) =>
      _userDocument(uid).collection('chargingCard').doc('current');

  Stream<ChargingCard?> watchChargingCard(String uid) =>
      _chargingCardDocument(uid).snapshots().map((snapshot) {
        final data = snapshot.data();
        if (!snapshot.exists || data == null) return null;
        return ChargingCard.fromMap(data, id: snapshot.id);
      });

  Stream<List<ChargingTransaction>> watchChargingTransactions(String uid) =>
      _chargingCardDocument(uid).collection('transactions').snapshots().map((
        snapshot,
      ) {
        final transactions = snapshot.docs
            .map(
              (document) =>
                  ChargingTransaction.fromMap(document.data(), id: document.id),
            )
            .toList();
        transactions.sort((a, b) {
          if (a.date == null) return b.date == null ? 0 : 1;
          if (b.date == null) return -1;
          return b.date!.compareTo(a.date!);
        });
        return List.unmodifiable(transactions);
      });

  Future<Vehicle?> verifyVehicleDetails({
    required String registrationNumber,
    required String model,
    required String ownerName,
    required String vin,
  }) async {
    final normalizedRegistration = _normalizeRegistration(registrationNumber);
    if (normalizedRegistration.isEmpty) return null;

    final result = await _firestore
        .collection('vehicles')
        .where('registrationNumber', isEqualTo: normalizedRegistration)
        .where('isActive', isEqualTo: true)
        .limit(2)
        .get();

    if (result.docs.isEmpty) return null;
    if (result.docs.length > 1) {
      throw StateError(
        'Multiple active vehicles use this registration number. Contact support.',
      );
    }

    final document = result.docs.single;
    final vehicle = Vehicle.fromMap(document.data(), id: document.id);
    final fieldsMatch =
        _normalizeRegistration(vehicle.registrationNumber) ==
            normalizedRegistration &&
        _normalizeText(vehicle.model) == _normalizeText(model) &&
        _normalizeText(vehicle.ownerName) == _normalizeText(ownerName) &&
        _normalizeVin(vehicle.vin) == _normalizeVin(vin) &&
        vehicle.isActive;

    return fieldsMatch ? vehicle : null;
  }

  static String _normalizeRegistration(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();

  static String _normalizeVin(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();

  static String _normalizeText(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  Future<UserModel?> getUserProfile(String uid) async {
    final snapshot = await _userDocument(uid).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    final profile = UserModel.fromMap(snapshot.data()!);
    if (profile.uid != uid) {
      throw StateError(
        'The Firestore user document UID does not match its path.',
      );
    }
    return profile;
  }

  Stream<UserModel?> watchUserProfile(String uid) =>
      _userDocument(uid).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        final profile = UserModel.fromMap(snapshot.data()!);
        if (profile.uid != uid) {
          throw StateError(
            'The Firestore user document UID does not match its path.',
          );
        }
        return profile;
      });

  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? phone,
    String? city,
    DateTime? dateOfBirth,
    String? profileImageUrl,
    String? preferredDrivingMode,
    String? preferredChargingMode,
    String? notificationPreference,
    String? distanceUnit,
    bool? notificationsEnabled,
    bool? locationEnabled,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) {
      final normalizedName = name.trim();
      if (normalizedName.isEmpty) {
        throw ArgumentError('Name cannot be empty.');
      }
      updates['name'] = normalizedName;
    }

    if (phone != null) {
      updates['phone'] = phone.trim();
    }

    if (city != null) {
      updates['city'] = city.trim();
    }

    if (dateOfBirth != null) {
      updates['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
    }

    if (profileImageUrl != null) {
      updates['profileImageUrl'] = profileImageUrl.trim();
    }

    if (preferredDrivingMode != null) {
      updates['preferredDrivingMode'] = preferredDrivingMode.trim();
    }

    if (preferredChargingMode != null) {
      updates['preferredChargingMode'] = preferredChargingMode.trim();
    }

    if (notificationPreference != null) {
      updates['notificationPreference'] = notificationPreference.trim();
      updates['preferences.notificationPreference'] = notificationPreference
          .trim();
    }

    if (distanceUnit != null) {
      updates['distanceUnit'] = distanceUnit.trim();
      updates['preferences.distanceUnit'] = distanceUnit.trim();
    }

    if (notificationsEnabled != null) {
      updates['notificationsEnabled'] = notificationsEnabled;
      updates['preferences.notificationsEnabled'] = notificationsEnabled;
    }

    if (locationEnabled != null) {
      updates['locationEnabled'] = locationEnabled;
      updates['preferences.locationEnabled'] = locationEnabled;
    }

    await _userDocument(uid).update(updates);
  }

  Future<void> updateProfileImageUrl({
    required String uid,
    required String url,
  }) async {
    await _userDocument(uid).update({
      'profileImageUrl': url.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required Vehicle vehicle,
  }) async {
    final doc = _userDocument(uid);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(doc);
      if (existing.exists) {
        throw StateError('A user profile already exists for this account.');
      }
      transaction.set(doc, {
        'uid': uid,
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'vehicleId': vehicle.id,
        'vehicleRegistrationNumber': vehicle.registrationNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<Vehicle?> getVehicleById(String vehicleId) async {
    final snapshot = await _firestore
        .collection('vehicles')
        .doc(vehicleId)
        .get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    final vehicle = Vehicle.fromMap(snapshot.data()!, id: snapshot.id);
    return vehicle.isActive ? vehicle : null;
  }

  Future<Vehicle?> getVehicleRecordById(String vehicleId) async {
    final snapshot = await _firestore
        .collection('vehicles')
        .doc(vehicleId)
        .get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return Vehicle.fromMap(snapshot.data()!, id: snapshot.id);
  }

  Future<Vehicle> updateVehicleConfiguration({
    required String vehicleId,
    required double maximumRangeKm,
    required double? batteryCapacityKwh,
    required String connectorType,
  }) async {
    if (vehicleId.trim().isEmpty) {
      throw ArgumentError.value(vehicleId, 'vehicleId', 'Cannot be empty.');
    }
    if (!maximumRangeKm.isFinite || maximumRangeKm <= 0) {
      throw ArgumentError.value(
        maximumRangeKm,
        'maximumRangeKm',
        'Must be a positive finite value.',
      );
    }
    if (batteryCapacityKwh != null &&
        (!batteryCapacityKwh.isFinite || batteryCapacityKwh <= 0)) {
      throw ArgumentError.value(
        batteryCapacityKwh,
        'batteryCapacityKwh',
        'Must be a positive finite value when provided.',
      );
    }

    final updates = <String, dynamic>{
      'maximumRangeKm': maximumRangeKm,
      'connectorType': connectorType.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (batteryCapacityKwh != null) {
      updates['batteryCapacityKwh'] = batteryCapacityKwh;
    }
    await _firestore.collection('vehicles').doc(vehicleId).update(updates);

    final updatedVehicle = await getVehicleRecordById(vehicleId);
    if (updatedVehicle == null) {
      throw StateError(
        'Vehicle configuration saved, but the updated Firestore vehicle could not be reloaded.',
      );
    }
    return updatedVehicle;
  }

  Stream<Vehicle?> watchVehicleById(String vehicleId) => _firestore
      .collection('vehicles')
      .doc(vehicleId)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return Vehicle.fromMap(snapshot.data()!, id: snapshot.id);
      });

  Stream<VehicleData?> watchVehicleTelemetry(String vehicleId) => _firestore
      .collection('vehicles')
      .doc(vehicleId)
      .collection('telemetry')
      .doc('live')
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data();
        if (data == null ||
            (data['battery'] ?? data['batteryPercentage']) is! num ||
            data['range'] is! num ||
            data['batteryHealth'] is! num ||
            data['healthScore'] is! num ||
            data['isCharging'] is! bool) {
          return null;
        }
        return VehicleData.fromMap(data);
      });

  Stream<double?> watchVehicleBatteryPercentage(String vehicleId) => _firestore
      .collection('vehicles')
      .doc(vehicleId)
      .collection('telemetry')
      .doc('live')
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data();
        return _firstFiniteNumber([
          data?['battery'],
          data?['batteryPercentage'],
        ]);
      });

  Future<double?> getVehicleBatteryPercentage(String vehicleId) async {
    final snapshot = await _firestore
        .collection('vehicles')
        .doc(vehicleId)
        .collection('telemetry')
        .doc('live')
        .get();
    final data = snapshot.data();
    return _firstFiniteNumber([data?['battery'], data?['batteryPercentage']]);
  }

  static double? _firstFiniteNumber(Iterable<Object?> values) {
    for (final value in values) {
      final number = switch (value) {
        num() => value.toDouble(),
        String() => double.tryParse(value.trim()),
        _ => null,
      };
      if (number != null && number.isFinite) return number;
    }
    return null;
  }

  Future<Vehicle?> getCurrentUserVehicle(String uid) async {
    final profile = await getUserProfile(uid);
    final vehicleId = profile?.vehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return null;
    return getVehicleById(vehicleId);
  }
}
