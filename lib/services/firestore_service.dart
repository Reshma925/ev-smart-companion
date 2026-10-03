import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

  DocumentReference<Map<String, dynamic>> _chargingCardDocument(
    String uid,
    String vehicleId,
  ) => _userDocument(uid)
      .collection('vehicles')
      .doc(vehicleId)
      .collection('chargingCard')
      .doc('current');

  CollectionReference<Map<String, dynamic>> _chargingTransactions(
    String uid,
    String vehicleId,
  ) => _chargingCardDocument(uid, vehicleId).collection('transactions');
  FirebaseFunctions get _functions => FirebaseFunctions.instance;

  void _requireCurrentUser(String uid) {
    if (uid.isEmpty || FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('You must be signed in to access this charging card.');
    }
  }

  Future<ChargingCard?> getChargingCard(
    String uid, {
    required String vehicleId,
  }) async {
    _requireCurrentUser(uid);
    await _requireConnectedVehicle(uid, vehicleId);
    final snapshot = await _chargingCardDocument(uid, vehicleId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return ChargingCard.fromMap(data, id: snapshot.id);
  }

  Stream<ChargingCard?> watchChargingCard(
    String uid, {
    required String vehicleId,
  }) {
    _requireCurrentUser(uid);
    return _chargingCardDocument(uid, vehicleId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return ChargingCard.fromMap(data, id: snapshot.id);
    });
  }

  Future<Map<String, dynamic>?> getLegacyChargingCardSummary({
    required String uid,
    required String vehicleId,
  }) async {
    _requireCurrentUser(uid);
    await _requireConnectedVehicle(uid, vehicleId);
    final result = await _functions
        .httpsCallable('getLegacyChargingCardSummary')
        .call<Map<String, dynamic>>({'vehicleId': vehicleId});
    final card = result.data['card'];
    if (card == null) return null;
    if (card is! Map) {
      throw StateError('The legacy card service returned an invalid response.');
    }
    return Map<String, dynamic>.from(card);
  }

  Future<bool> migrateLegacyChargingCard({
    required String uid,
    required String vehicleId,
  }) async {
    _requireCurrentUser(uid);
    await _requireConnectedVehicle(uid, vehicleId);
    final result = await _functions
        .httpsCallable('migrateLegacyChargingCard')
        .call<Map<String, dynamic>>({'vehicleId': vehicleId});
    return result.data['migrated'] == true ||
        result.data['alreadyExists'] == true;
  }

  Future<void> setConnectedVehicle({
    required String uid,
    required String vehicleId,
  }) async {
    _requireCurrentUser(uid);
    await _functions.httpsCallable('setConnectedVehicle').call<void>({
      'vehicleId': vehicleId,
    });
  }

  Future<Vehicle> linkVerifiedVehicle({
    required String uid,
    required String registrationNumber,
    required String model,
    required String ownerName,
    required String vin,
  }) async {
    _requireCurrentUser(uid);
    final result = await _functions
        .httpsCallable('linkVerifiedVehicle')
        .call<Map<String, dynamic>>({
          'registrationNumber': registrationNumber,
          'model': model,
          'ownerName': ownerName,
          'vin': vin,
        });
    final data = result.data['vehicle'];
    if (data is! Map) {
      throw StateError(
        'The vehicle linking service returned an invalid response.',
      );
    }
    return Vehicle.fromMap(
      Map<String, dynamic>.from(data),
      id: data['id'] as String? ?? '',
    );
  }

  Future<Vehicle> verifyAndCreateUserProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String registrationNumber,
    required String model,
    required String ownerName,
    required String vin,
  }) async {
    _requireCurrentUser(uid);
    final result = await _functions
        .httpsCallable('verifyAndCreateUserProfile')
        .call<Map<String, dynamic>>({
          'name': name,
          'email': email,
          'phone': phone,
          'registrationNumber': registrationNumber,
          'model': model,
          'ownerName': ownerName,
          'vin': vin,
        });
    final data = result.data['vehicle'];
    if (data is! Map) {
      throw StateError(
        'The vehicle verification service returned an invalid response.',
      );
    }
    return Vehicle.fromMap(
      Map<String, dynamic>.from(data),
      id: data['id'] as String? ?? '',
    );
  }

  Future<Vehicle?> verifyConnectedVehicleDetails({
    required String uid,
    required String registrationNumber,
    required String model,
    required String ownerName,
    required String vin,
  }) async {
    _requireCurrentUser(uid);
    final profile = await getUserProfile(uid);
    final vehicleId = profile?.vehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return null;
    final vehicle = await getVehicleById(vehicleId);
    if (vehicle == null) return null;
    String normalizeText(String value) =>
        value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    String normalizeRegistration(String value) =>
        value.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
    String normalizeVin(String value) =>
        value.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (normalizeRegistration(vehicle.registrationNumber) !=
            normalizeRegistration(registrationNumber) ||
        normalizeText(vehicle.model) != normalizeText(model) ||
        normalizeText(vehicle.ownerName) != normalizeText(ownerName) ||
        normalizeVin(vehicle.vin) != normalizeVin(vin)) {
      return null;
    }
    return vehicle;
  }

  Stream<List<ChargingTransaction>> watchChargingTransactions(
    String uid, {
    required String vehicleId,
  }) {
    _requireCurrentUser(uid);
    return _chargingTransactions(uid, vehicleId).snapshots().map((snapshot) {
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
  }

  Stream<Vehicle?> watchConnectedVehicle(String uid) {
    _requireCurrentUser(uid);
    return watchUserProfile(uid).asyncExpand((profile) {
      final vehicleId = profile?.vehicleId?.trim();
      if (vehicleId == null || vehicleId.isEmpty) {
        return Stream<Vehicle?>.value(null);
      }
      return watchVehicleById(
        vehicleId,
      ).map((vehicle) => vehicle?.isActive == true ? vehicle : null);
    });
  }

  Future<void> _requireConnectedVehicle(String uid, String vehicleId) async {
    final normalizedVehicleId = vehicleId.trim();
    if (normalizedVehicleId.isEmpty) {
      throw ArgumentError.value(vehicleId, 'vehicleId', 'Cannot be empty.');
    }
    final profile = await getUserProfile(uid);
    if (profile?.vehicleId != normalizedVehicleId) {
      throw StateError(
        'This vehicle is not currently connected to your account.',
      );
    }
    final vehicle = await getVehicleRecordById(normalizedVehicleId);
    if (vehicle == null || !vehicle.isActive) {
      throw StateError('The connected vehicle is unavailable or inactive.');
    }
  }

  Future<void> _validateConnectedVehicleInTransaction(
    Transaction transaction, {
    required String uid,
    required String vehicleId,
  }) async {
    final userDocument = _userDocument(uid);
    final vehicleDocument = _firestore.collection('vehicles').doc(vehicleId);
    final userSnapshot = await transaction.get(userDocument);
    final vehicleSnapshot = await transaction.get(vehicleDocument);
    final userData = userSnapshot.data();
    final vehicleData = vehicleSnapshot.data();
    if (!userSnapshot.exists ||
        userData?['uid'] != uid ||
        userData?['vehicleId'] != vehicleId) {
      throw StateError(
        'This vehicle is not currently connected to your account.',
      );
    }
    if (!vehicleSnapshot.exists ||
        vehicleData == null ||
        vehicleData['isActive'] != true) {
      throw StateError('The connected vehicle is unavailable or inactive.');
    }
  }

  Future<ChargingCard> registerChargingCard({
    required String uid,
    required String cardType,
    required String cardNumber,
    required String cardHolderName,
    required String vehicleId,
    DateTime? expiryDate,
    String currency = 'INR',
  }) async {
    _requireCurrentUser(uid);
    final normalizedType = cardType.trim();
    final normalizedNumber = cardNumber.trim();
    final normalizedHolder = cardHolderName.trim();
    final normalizedVehicleId = vehicleId.trim();
    final normalizedCurrency = currency.trim().toUpperCase();
    if (normalizedType.isEmpty ||
        _cardLastFour(normalizedNumber) == null ||
        normalizedHolder.isEmpty ||
        normalizedVehicleId.isEmpty ||
        expiryDate == null ||
        normalizedCurrency.length != 3) {
      throw ArgumentError(
        'Complete all charging card fields and use a three-letter currency code.',
      );
    }
    final cardDocument = _chargingCardDocument(uid, normalizedVehicleId);
    await _firestore.runTransaction((transaction) async {
      await _validateConnectedVehicleInTransaction(
        transaction,
        uid: uid,
        vehicleId: normalizedVehicleId,
      );
      final current = await transaction.get(cardDocument);
      if (current.exists) {
        throw StateError(
          'A charging card is already registered for this vehicle.',
        );
      }
      transaction.set(cardDocument, {
        'cardId': cardDocument.id,
        'cardType': normalizedType,
        'maskedCardNumber': _maskedCardNumber(normalizedNumber),
        'cardHolderName': normalizedHolder,
        'vehicleId': normalizedVehicleId,
        'expiryDate': Timestamp.fromDate(expiryDate),
        'balance': 0.0,
        'currency': normalizedCurrency,
        'status': 'ACTIVE',
        'registeredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    final card = await getChargingCard(uid, vehicleId: normalizedVehicleId);
    if (card == null) {
      throw StateError(
        'Charging card registration succeeded, but the Firestore document could not be reloaded.',
      );
    }
    return card;
  }

  Future<ChargingCard> updateChargingCardDetails({
    required String uid,
    required String cardType,
    String? cardNumber,
    required String cardHolderName,
    required String vehicleId,
    DateTime? expiryDate,
  }) async {
    _requireCurrentUser(uid);
    final normalizedType = cardType.trim();
    final normalizedNumber = cardNumber?.trim() ?? '';
    final normalizedHolder = cardHolderName.trim();
    final normalizedVehicleId = vehicleId.trim();
    if (normalizedType.isEmpty ||
        (normalizedNumber.isNotEmpty &&
            _cardLastFour(normalizedNumber) == null) ||
        normalizedHolder.isEmpty ||
        normalizedVehicleId.isEmpty ||
        expiryDate == null) {
      throw ArgumentError('Complete all charging card fields.');
    }
    final cardDocument = _chargingCardDocument(uid, normalizedVehicleId);
    await _firestore.runTransaction((transaction) async {
      await _validateConnectedVehicleInTransaction(
        transaction,
        uid: uid,
        vehicleId: normalizedVehicleId,
      );
      final snapshot = await transaction.get(cardDocument);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('No charging card is registered for this vehicle.');
      }
      final updates = <String, dynamic>{
        'cardType': normalizedType,
        'cardHolderName': normalizedHolder,
        'vehicleId': normalizedVehicleId,
        'expiryDate': Timestamp.fromDate(expiryDate),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (normalizedNumber.isNotEmpty) {
        updates['maskedCardNumber'] = _maskedCardNumber(normalizedNumber);
        updates['cardNumber'] = FieldValue.delete();
      } else if (data['cardNumber'] is String) {
        final legacyNumber = data['cardNumber'] as String;
        updates['maskedCardNumber'] = _maskedCardNumber(legacyNumber);
        updates['cardNumber'] = FieldValue.delete();
      }
      transaction.update(cardDocument, updates);
    });
    final card = await getChargingCard(uid, vehicleId: normalizedVehicleId);
    if (card == null) {
      throw StateError(
        'Charging card details were saved, but the Firestore document could not be reloaded.',
      );
    }
    return card;
  }

  /// Debits require a trusted backend, which the app does not currently have.
  Future<ChargingCard> debitChargingCardAfterConfirmedSession({
    required String uid,
    required double amount,
    required String stationId,
    required String stationName,
    String? operator,
    required String vehicleId,
    required String description,
  }) async {
    _requireCurrentUser(uid);
    if (!amount.isFinite ||
        amount <= 0 ||
        stationId.trim().isEmpty ||
        stationName.trim().isEmpty ||
        vehicleId.trim().isEmpty ||
        description.trim().isEmpty) {
      throw ArgumentError('A valid confirmed charging session is required.');
    }
    _requireCurrentUser(uid);
    throw StateError(
      'Charging-card debits require a trusted charging-session backend. '
      'No confirmed-session provider is configured in this application.',
    );
  }

  static String? _cardLastFour(String value) {
    final compact = value.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^[A-Za-z0-9]{4,32}$').hasMatch(compact)) return null;
    return compact.substring(compact.length - 4);
  }

  static String _maskedCardNumber(String value) {
    final lastFour = _cardLastFour(value);
    if (lastFour == null) {
      throw ArgumentError.value(value, 'cardNumber', 'Invalid card number.');
    }
    return 'XXXX XXXX XXXX $lastFour';
  }

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
