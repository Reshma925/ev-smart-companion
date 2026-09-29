import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../models/vehicle.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDocument(String uid) =>
      _firestore.collection('users').doc(uid);

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

  Future<Vehicle?> getCurrentUserVehicle(String uid) async {
    final profile = await getUserProfile(uid);
    final vehicleId = profile?.vehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return null;
    return getVehicleById(vehicleId);
  }
}
