import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/charging_card.dart';
import '../models/user_model.dart';
import '../models/vehicle.dart';
import '../models/vehicle_health.dart';
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
    await _requireOwnedVehicle(uid, vehicleId);
    final snapshot = await _chargingCardDocument(uid, vehicleId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return ChargingCard.fromMap(data, id: snapshot.id);
  }

  Stream<ChargingCard?> watchChargingCard(
    String uid, {
    required String vehicleId,
    String? vehicleModel,
    String? vehicleRegistration,
  }) {
    final authenticatedUser = FirebaseAuth.instance.currentUser;
    final cardDocument = _chargingCardDocument(uid, vehicleId);
    debugPrint('[CHARGING CARD READ DEBUG]');
    debugPrint(
      '[CHARGING CARD READ DEBUG] Firebase project ID: '
      '${_firestore.app.options.projectId}',
    );
    debugPrint('[CHARGING CARD READ DEBUG] Firestore database: (default)');
    debugPrint(
      '[CHARGING CARD READ DEBUG] Authenticated UID: '
      '${authenticatedUser?.uid ?? '<none>'}',
    );
    debugPrint(
      '[CHARGING CARD READ DEBUG] Authenticated email: '
      '${authenticatedUser?.email ?? '<none>'}',
    );
    debugPrint('[CHARGING CARD READ DEBUG] Selected vehicle ID: $vehicleId');
    debugPrint(
      '[CHARGING CARD READ DEBUG] Selected vehicle model: '
      '${vehicleModel ?? '<not supplied>'}',
    );
    debugPrint(
      '[CHARGING CARD READ DEBUG] Selected vehicle registration: '
      '${vehicleRegistration ?? '<not supplied>'}',
    );
    debugPrint(
      '[CHARGING CARD READ DEBUG] Exact Firestore document path: '
      '${cardDocument.path}',
    );
    debugPrint(
      '[CHARGING CARD READ DEBUG] Is currentUser null: '
      '${authenticatedUser == null}',
    );
    try {
      _requireCurrentUser(uid);
    } catch (error) {
      debugPrint('[CHARGING CARD READ DEBUG] READ FAILED');
      debugPrint('[CHARGING CARD READ DEBUG] Error: $error');
      rethrow;
    }
    return cardDocument.snapshots().transform(
      StreamTransformer<
        DocumentSnapshot<Map<String, dynamic>>,
        ChargingCard?
      >.fromHandlers(
        handleData: (snapshot, sink) {
          debugPrint(
            '[CHARGING CARD READ DEBUG] Does the card document exist: '
            '${snapshot.exists}',
          );
          debugPrint(
            '[CHARGING CARD READ DEBUG] Snapshot is from cache: '
            '${snapshot.metadata.isFromCache}',
          );
          if (!snapshot.exists) {
            debugPrint(
              '[CHARGING CARD READ DEBUG] Document does not exist at '
              '${cardDocument.path}',
            );
            sink.add(null);
            return;
          }
          final data = snapshot.data();
          if (data == null) {
            final error = StateError(
              'Firestore returned an existing card document without data.',
            );
            debugPrint('[CHARGING CARD READ DEBUG] READ FAILED');
            debugPrint('[CHARGING CARD READ DEBUG] Error: $error');
            sink.addError(error, StackTrace.current);
            return;
          }
          debugPrint('[CHARGING CARD READ DEBUG] Read SUCCESS');
          sink.add(ChargingCard.fromMap(data, id: snapshot.id));
        },
        handleError: (Object error, StackTrace stackTrace, sink) {
          debugPrint('[CHARGING CARD READ DEBUG] READ FAILED');
          if (error is FirebaseException) {
            debugPrint(
              '[CHARGING CARD READ DEBUG] Exact FirebaseException code: ${error.code}',
            );
            debugPrint(
              '[CHARGING CARD READ DEBUG] Exact FirebaseException message: ${error.message}',
            );
          } else {
            debugPrint('[CHARGING CARD READ DEBUG] Error: $error');
          }
          sink.addError(error, stackTrace);
        },
      ),
    );
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
    final normalizedVehicleId = vehicleId.trim();
    if (normalizedVehicleId.isEmpty) {
      throw ArgumentError.value(vehicleId, 'vehicleId', 'Cannot be empty.');
    }
    await _firestore.runTransaction((transaction) async {
      final vehicle = await _validateOwnedVehicleInTransaction(
        transaction,
        uid: uid,
        vehicleId: normalizedVehicleId,
      );
      transaction.update(_userDocument(uid), {
        'vehicleId': normalizedVehicleId,
        'vehicleRegistrationNumber': vehicle.registrationNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });
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

  Stream<List<Vehicle>> watchLinkedVehicles(String uid) {
    _requireCurrentUser(uid);
    final controller = StreamController<List<Vehicle>>();
    final vehicleSubscriptions =
        <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    final vehicles = <String, Vehicle>{};
    var primaryVehicleId = '';
    var membershipVehicleIds = <String>{};

    void emitVehicles() {
      final sorted = vehicles.values.toList()
        ..sort((a, b) {
          final modelOrder = a.model.compareTo(b.model);
          return modelOrder != 0 ? modelOrder : a.id.compareTo(b.id);
        });
      if (!controller.isClosed) controller.add(List.unmodifiable(sorted));
    }

    void refreshVehicleSubscriptions() {
      final linkedIds = <String>{
        if (primaryVehicleId.isNotEmpty) primaryVehicleId,
        ...membershipVehicleIds,
      };
      for (final removedId
          in vehicleSubscriptions.keys
              .where((id) => !linkedIds.contains(id))
              .toList()) {
        vehicleSubscriptions.remove(removedId)?.cancel();
        vehicles.remove(removedId);
      }
      for (final vehicleId in linkedIds) {
        if (vehicleSubscriptions.containsKey(vehicleId)) continue;
        vehicleSubscriptions[vehicleId] = _firestore
            .collection('vehicles')
            .doc(vehicleId)
            .snapshots()
            .listen((snapshot) {
              final data = snapshot.data();
              if (!snapshot.exists || data == null) {
                vehicles.remove(vehicleId);
              } else {
                final vehicle = Vehicle.fromMap(data, id: snapshot.id);
                if (vehicle.isActive) {
                  vehicles[vehicleId] = vehicle;
                } else {
                  vehicles.remove(vehicleId);
                }
              }
              emitVehicles();
            }, onError: controller.addError);
      }
      emitVehicles();
    }

    final profileSubscription = watchUserProfile(uid).listen((profile) {
      primaryVehicleId = profile?.vehicleId?.trim() ?? '';
      refreshVehicleSubscriptions();
    }, onError: controller.addError);
    final membershipSubscription = _userDocument(uid)
        .collection('vehicles')
        .snapshots()
        .listen((memberships) {
          membershipVehicleIds = memberships.docs
              .map((document) => document.id)
              .toSet();
          refreshVehicleSubscriptions();
        }, onError: controller.addError);

    controller.onCancel = () async {
      await profileSubscription.cancel();
      await membershipSubscription.cancel();
      await Future.wait(
        vehicleSubscriptions.values.map(
          (subscription) => subscription.cancel(),
        ),
      );
      vehicleSubscriptions.clear();
    };
    return controller.stream;
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

  Future<void> _requireOwnedVehicle(String uid, String vehicleId) async {
    final normalizedVehicleId = vehicleId.trim();
    if (normalizedVehicleId.isEmpty) {
      throw ArgumentError.value(vehicleId, 'vehicleId', 'Cannot be empty.');
    }
    final profile = await getUserProfile(uid);
    final membership = await _userDocument(
      uid,
    ).collection('vehicles').doc(normalizedVehicleId).get();
    if (profile == null ||
        (profile.vehicleId != normalizedVehicleId && !membership.exists)) {
      throw StateError('This vehicle is not linked to your account.');
    }
    final vehicle = await getVehicleRecordById(normalizedVehicleId);
    if (vehicle == null || !vehicle.isActive) {
      throw StateError('The linked vehicle is unavailable or inactive.');
    }
  }

  Future<Vehicle> _validateOwnedVehicleInTransaction(
    Transaction transaction, {
    required String uid,
    required String vehicleId,
  }) async {
    final userDocument = _userDocument(uid);
    final membershipDocument = userDocument
        .collection('vehicles')
        .doc(vehicleId);
    final vehicleDocument = _firestore.collection('vehicles').doc(vehicleId);
    final userSnapshot = await transaction.get(userDocument);
    final membershipSnapshot = await transaction.get(membershipDocument);
    final vehicleSnapshot = await transaction.get(vehicleDocument);
    final userData = userSnapshot.data();
    final vehicleData = vehicleSnapshot.data();
    final membershipData = membershipSnapshot.data();
    if (!userSnapshot.exists ||
        (userData?['vehicleId'] != vehicleId && !membershipSnapshot.exists)) {
      throw StateError('This vehicle is not linked to your account.');
    }
    if (!vehicleSnapshot.exists ||
        vehicleData == null ||
        vehicleData['isActive'] != true) {
      throw StateError('The linked vehicle is unavailable or inactive.');
    }
    if (userData?['vehicleId'] == vehicleId &&
        userData?['vehicleRegistrationNumber'] is String &&
        userData?['vehicleRegistrationNumber'] !=
            vehicleData['registrationNumber']) {
      throw StateError(
        'The vehicle registration does not match your linked user profile.',
      );
    }
    if (membershipSnapshot.exists &&
        (membershipData?['uid'] != uid ||
            membershipData?['vehicleId'] != vehicleId ||
            (membershipData?['registrationNumber'] is String &&
                membershipData?['registrationNumber'] !=
                    vehicleData['registrationNumber']))) {
      throw StateError(
        'The linked vehicle record does not match this vehicle.',
      );
    }
    return Vehicle.fromMap(vehicleData, id: vehicleSnapshot.id);
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Please sign in before registering a charging card.');
    }
    final authenticatedUid = user.uid;
    if (uid != authenticatedUid) {
      throw StateError('The signed-in user changed before card registration.');
    }
    final normalizedVehicleId = vehicleId.trim();
    final cardDocument = _chargingCardDocument(
      authenticatedUid,
      normalizedVehicleId,
    );
    debugPrint('[CARD PROD DEBUG] Starting Firestore registration');
    debugPrint(
      '[CARD PROD DEBUG] Firebase project ID: '
      '${_firestore.app.options.projectId}',
    );
    debugPrint('[CARD PROD DEBUG] Firestore database: (default)');
    debugPrint(
      '[CARD PROD DEBUG] Firestore emulator routing: not configured '
      '(no useFirestoreEmulator call in lib/)',
    );
    debugPrint('[CARD PROD DEBUG] Authenticated email: ${user.email}');
    debugPrint('[CARD PROD DEBUG] Authenticated UID: $authenticatedUid');
    debugPrint(
      '[CARD PROD DEBUG] FirebaseFirestore.instance is active instance: '
      '${identical(_firestore, FirebaseFirestore.instance)}',
    );
    debugPrint('[CARD PROD DEBUG] Vehicle ID: $normalizedVehicleId');
    debugPrint(
      '[CARD PROD DEBUG] Target path:\n'
      '${cardDocument.path}',
    );
    try {
      _requireCurrentUser(authenticatedUid);
    } on FirebaseException catch (error) {
      _logChargingCardWriteFailure(error);
      rethrow;
    } catch (error) {
      debugPrint('[CHARGING CARD WRITE ERROR] $error');
      rethrow;
    }
    final normalizedType = cardType.trim();
    final normalizedNumber = cardNumber.trim();
    final normalizedHolder = cardHolderName.trim();
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
    late Vehicle verifiedVehicle;
    try {
      debugPrint(
        '[CARD PROD DEBUG] Pre-registration server read path: '
        '${cardDocument.path}',
      );
      final beforeWrite = await cardDocument.get(
        const GetOptions(source: Source.server),
      );
      debugPrint(
        '[CARD PROD DEBUG] Pre-registration server read exists: '
        '${beforeWrite.exists}',
      );
      if (beforeWrite.exists) {
        throw StateError(
          'A charging card is already registered for this vehicle.',
        );
      }
      await _firestore.runTransaction((transaction) async {
        final vehicle = await _validateOwnedVehicleInTransaction(
          transaction,
          uid: authenticatedUid,
          vehicleId: normalizedVehicleId,
        );
        verifiedVehicle = vehicle;
        debugPrint('[CARD PROD DEBUG] Authenticated user exists: true');
        debugPrint('[CARD PROD DEBUG] UID matches requested account: true');
        debugPrint('[CARD PROD DEBUG] Vehicle exists: true');
        debugPrint(
          '[CARD PROD DEBUG] Vehicle belongs to authenticated user: true',
        );
        debugPrint('[CARD PROD DEBUG] Vehicle active: ${vehicle.isActive}');
        debugPrint('[CARD PROD DEBUG] Verified vehicle ID: ${vehicle.id}');
        final current = await transaction.get(cardDocument);
        if (current.exists) {
          throw StateError(
            'A charging card is already registered for this vehicle.',
          );
        }
        debugPrint('[CARD PROD DEBUG] Vehicle model: ${vehicle.model}');
        debugPrint(
          '[CARD PROD DEBUG] Vehicle registration: '
          '${vehicle.registrationNumber}',
        );
        debugPrint('[CARD PROD DEBUG] Creating Firestore card document...');
        transaction.set(cardDocument, {
          'cardId': cardDocument.id,
          'cardType': normalizedType,
          'maskedCardNumber': _maskedCardNumber(normalizedNumber),
          'cardHolderName': normalizedHolder,
          'vehicleId': normalizedVehicleId,
          'vehicleModel': vehicle.model,
          'vehicleRegistrationNumber': vehicle.registrationNumber,
          'vehicleVin': vehicle.vin,
          'expiryDate': Timestamp.fromDate(expiryDate),
          'balance': 0.0,
          'currency': normalizedCurrency,
          'status': 'ACTIVE',
          'registeredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      debugPrint('[CARD PROD DEBUG] WRITE COMPLETED');
      debugPrint(
        '[CARD PROD DEBUG] Written document path: ${cardDocument.path}',
      );
    } catch (error) {
      _logChargingCardWriteFailure(error);
      rethrow;
    }

    try {
      debugPrint('[CARD PROD DEBUG] SERVER READ PATH: ${cardDocument.path}');
      final snapshot = await cardDocument.get(
        const GetOptions(source: Source.server),
      );
      debugPrint('[CARD PROD DEBUG] SERVER READ EXISTS: ${snapshot.exists}');
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        debugPrint(
          '[CARD PROD ERROR] WRITE COMPLETED BUT SERVER READ SAYS DOCUMENT '
          'DOES NOT EXIST.',
        );
        throw StateError(
          'Charging card registration failed: Firestore document was not '
          'created at ${cardDocument.path}.',
        );
      }
      final storedExpiry = data['expiryDate'];
      if (data['cardId'] != 'current' ||
          data['cardType'] != normalizedType ||
          data['maskedCardNumber'] != _maskedCardNumber(normalizedNumber) ||
          data['cardHolderName'] != normalizedHolder ||
          data['vehicleId'] != normalizedVehicleId ||
          data['vehicleModel'] != verifiedVehicle.model ||
          data['vehicleRegistrationNumber'] !=
              verifiedVehicle.registrationNumber ||
          data['vehicleVin'] != verifiedVehicle.vin ||
          storedExpiry is! Timestamp ||
          !storedExpiry.toDate().isAtSameMomentAs(expiryDate) ||
          data['balance'] != 0 ||
          data['currency'] != normalizedCurrency ||
          data['status'] != 'ACTIVE' ||
          data['registeredAt'] is! Timestamp ||
          data['updatedAt'] is! Timestamp ||
          data.containsKey('cardNumber') ||
          data.containsKey('cvv') ||
          data.containsKey('pin') ||
          data.containsKey('paymentPassword')) {
        throw StateError(
          'Firestore read-back returned data that failed card verification.',
        );
      }
      const safeFields = [
        'cardType',
        'maskedCardNumber',
        'cardHolderName',
        'vehicleId',
        'vehicleModel',
        'vehicleRegistrationNumber',
        'vehicleVin',
        'expiryDate',
        'balance',
        'currency',
        'status',
      ];
      final safeData = {
        for (final field in safeFields)
          if (data.containsKey(field)) field: data[field],
      };
      debugPrint('[CARD PROD DEBUG] SERVER DOCUMENT DATA: $safeData');
      return ChargingCard.fromMap(data, id: snapshot.id);
    } catch (error) {
      _logChargingCardWriteFailure(error);
      rethrow;
    }
  }

  void _logChargingCardWriteFailure(Object error) {
    if (error is FirebaseException) {
      debugPrint('[CARD PROD ERROR]');
      debugPrint('[CARD PROD ERROR] Firebase exception code: ${error.code}');
      debugPrint(
        '[CARD PROD ERROR] Firebase exception message: ${error.message}',
      );
      debugPrint('[CARD PROD ERROR] Exception: $error');
    } else {
      debugPrint('[CARD PROD ERROR] Exception: $error');
    }
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
      final vehicle = await _validateOwnedVehicleInTransaction(
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
        'vehicleModel': vehicle.model,
        'vehicleRegistrationNumber': vehicle.registrationNumber,
        'vehicleVin': vehicle.vin,
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
      for (final sensitiveField in const ['cvv', 'pin', 'paymentPassword']) {
        if (data.containsKey(sensitiveField)) {
          updates[sensitiveField] = FieldValue.delete();
        }
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

  /// Debits only a server-confirmed charging session; the client cannot submit
  /// the amount or station details used by the backend.
  Future<ChargingCard> debitChargingCardAfterConfirmedSession({
    required String uid,
    required String sessionId,
  }) async {
    _requireCurrentUser(uid);
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      throw ArgumentError(
        'A confirmed charging-session reference is required.',
      );
    }
    final response = await _functions
        .httpsCallable('debitConfirmedChargingSession')
        .call<Map<String, dynamic>>({'sessionId': normalizedSessionId});
    final vehicleId = response.data['vehicleId'];
    if (vehicleId is! String || vehicleId.isEmpty) {
      throw StateError(
        'The charging-session service did not identify the charged vehicle.',
      );
    }
    final card = await getChargingCard(uid, vehicleId: vehicleId);
    if (card == null) {
      throw StateError(
        'The charging session was processed, but the updated card could not be loaded.',
      );
    }
    return card;
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

  Stream<VehicleData?> watchVehicleTelemetry(String vehicleId) {
    return _firestore
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
  }

  Stream<double?> watchVehicleBatteryPercentage(String vehicleId) {
    return _firestore
        .collection('vehicles')
        .doc(vehicleId)
        .collection('telemetry')
        .doc('live')
        .snapshots()
        .map(
          (snapshot) => _firstFiniteNumber([
            snapshot.data()?['battery'],
            snapshot.data()?['batteryPercentage'],
          ]),
        );
  }

  Stream<List<VehicleMaintenanceRecord>> watchVehicleMaintenanceRecords(
    String vehicleId,
  ) => _firestore
      .collection('vehicles')
      .doc(vehicleId)
      .collection('maintenance')
      .orderBy('serviceDate', descending: true)
      .snapshots()
      .handleError((Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          final projectId = _firestore.app.options.projectId;
          if (error is FirebaseException) {
            debugPrint(
              '[Maintenance Firestore] Read failed '
              'project=$projectId '
              'path=vehicles/$vehicleId/maintenance '
              'code=${error.code} '
              'message=${error.message ?? '(no message)'}',
            );
          } else {
            debugPrint(
              '[Maintenance Firestore] Read failed '
              'project=$projectId '
              'path=vehicles/$vehicleId/maintenance '
              'errorType=${error.runtimeType}',
            );
          }
        }
        Error.throwWithStackTrace(error, stackTrace);
      })
      .map(
        (snapshot) => snapshot.docs
            .map(
              (document) => VehicleMaintenanceRecord.fromMap(
                document.data(),
                id: document.id,
              ),
            )
            .toList(growable: false),
      );

  Future<void> addVehicleMaintenanceRecord({
    required String vehicleId,
    required String serviceType,
    required String category,
    required DateTime serviceDate,
    DateTime? nextServiceDate,
    double? odometerKm,
    double? cost,
    String? serviceCenter,
    String? notes,
  }) async {
    final normalizedVehicleId = vehicleId.trim();
    final normalizedServiceType = serviceType.trim();
    if (normalizedVehicleId.isEmpty || normalizedServiceType.isEmpty) {
      throw ArgumentError('Vehicle and service type are required.');
    }
    if (odometerKm != null && (!odometerKm.isFinite || odometerKm < 0)) {
      throw ArgumentError.value(odometerKm, 'odometerKm');
    }
    if (cost != null && (!cost.isFinite || cost < 0)) {
      throw ArgumentError.value(cost, 'cost');
    }

    await _firestore
        .collection('vehicles')
        .doc(normalizedVehicleId)
        .collection('maintenance')
        .add({
          'vehicleId': normalizedVehicleId,
          'serviceType': normalizedServiceType,
          'category': category,
          'serviceDate': Timestamp.fromDate(serviceDate),
          'nextServiceDate': nextServiceDate == null
              ? null
              : Timestamp.fromDate(nextServiceDate),
          'odometerKm': odometerKm,
          'cost': cost,
          'serviceCenter': serviceCenter?.trim() ?? '',
          'notes': notes?.trim() ?? '',
          'status': 'Completed',
          'source': 'user_entered',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

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
