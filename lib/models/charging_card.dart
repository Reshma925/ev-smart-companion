import 'package:cloud_firestore/cloud_firestore.dart';

class ChargingCard {
  const ChargingCard({
    required this.id,
    this.cardNumber,
    this.maskedCardNumber,
    this.cardType,
    this.cardHolderName,
    this.cardLastFour,
    this.balance,
    this.currency,
    this.status,
    this.vehicleId,
    this.vehicleModel,
    this.vehicleRegistrationNumber,
    this.vehicleVin,
    this.expiryDate,
    this.registeredAt,
    this.lastRechargeAmount,
    this.lastRechargeDate,
  });

  final String id;
  final String? cardNumber;
  final String? maskedCardNumber;
  final String? cardType;
  final String? cardHolderName;
  final String? cardLastFour;
  final double? balance;
  final String? currency;
  final String? status;
  final String? vehicleId;
  final String? vehicleModel;
  final String? vehicleRegistrationNumber;
  final String? vehicleVin;
  final DateTime? expiryDate;
  final DateTime? registeredAt;
  final double? lastRechargeAmount;
  final DateTime? lastRechargeDate;

  String? get displayCardNumber {
    final masked = maskedCardNumber;
    if (masked != null) return masked;
    final number = cardNumber;
    final lastFour = cardLastFour;
    if (number == null) {
      return lastFour == null ? null : 'XXXX XXXX XXXX $lastFour';
    }
    final compact = number.replaceAll(RegExp(r'[\s-]'), '');
    final visibleSuffix = compact.length <= 4
        ? compact
        : compact.substring(compact.length - 4);
    return 'XXXX XXXX XXXX $visibleSuffix';
  }

  String? get linkedVehicleId => vehicleId;

  factory ChargingCard.fromMap(Map<String, dynamic> map, {required String id}) {
    return ChargingCard(
      id: id,
      cardNumber: _string(map['cardNumber']),
      maskedCardNumber: _string(map['maskedCardNumber']),
      cardType: _string(map['cardType']),
      cardHolderName: _string(map['cardHolderName']),
      cardLastFour: _string(map['cardLastFour']),
      balance: _number(map['balance']),
      currency: _string(map['currency']),
      status: _string(map['status']),
      vehicleId: _string(map['vehicleId'] ?? map['linkedVehicleId']),
      vehicleModel: _string(map['vehicleModel']),
      vehicleRegistrationNumber: _string(map['vehicleRegistrationNumber']),
      vehicleVin: _string(map['vehicleVin']),
      expiryDate: _date(map['expiryDate']),
      registeredAt: _date(map['registeredAt'] ?? map['createdAt']),
      lastRechargeAmount: _number(map['lastRechargeAmount']),
      lastRechargeDate: _date(map['lastRechargeDate']),
    );
  }

  static String? _string(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static double? _number(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      return parsed != null && parsed.isFinite ? parsed : null;
    }
    return null;
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class ChargingTransaction {
  const ChargingTransaction({
    required this.id,
    this.amount,
    this.balanceBefore,
    this.balanceAfter,
    this.type,
    this.stationId,
    this.stationName,
    this.operator,
    this.vehicleId,
    this.date,
    this.status,
    this.description,
    this.currency,
    this.cardId,
    this.sessionReferenceId,
    this.paymentProvider,
    this.paymentMethod,
    this.paypalOrderId,
    this.paypalCaptureId,
    this.paypalAmount,
    this.paypalCurrency,
    this.conversionType,
    this.demoExchangeRate,
    this.mockPaymentDetails,
  });

  final String id;
  final double? amount;
  final double? balanceBefore;
  final double? balanceAfter;
  final String? type;
  final String? stationId;
  final String? stationName;
  final String? operator;
  final String? vehicleId;
  final DateTime? date;
  final String? status;
  final String? description;
  final String? currency;
  final String? cardId;
  final String? sessionReferenceId;
  final String? paymentProvider;
  final String? paymentMethod;
  final String? paypalOrderId;
  final String? paypalCaptureId;
  final double? paypalAmount;
  final String? paypalCurrency;
  final String? conversionType;
  final double? demoExchangeRate;
  final Map<String, String>? mockPaymentDetails;

  factory ChargingTransaction.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    final rawPaymentDetails = map['mockPaymentDetails'];
    final paymentDetails = rawPaymentDetails is Map
        ? rawPaymentDetails.map(
            (key, value) => MapEntry(
              key.toString(),
              value == null ? '' : value.toString(),
            ),
          )
        : <String, String>{};

    return ChargingTransaction(
      id: id,
      amount: ChargingCard._number(map['amount']),
      balanceBefore: ChargingCard._number(map['balanceBefore']),
      balanceAfter: ChargingCard._number(map['balanceAfter']),
      type: ChargingCard._string(map['type']),
      stationId: ChargingCard._string(map['stationId']),
      stationName: ChargingCard._string(map['stationName']),
      operator: ChargingCard._string(map['operator']),
      vehicleId: ChargingCard._string(map['vehicleId']),
      date: ChargingCard._date(map['timestamp'] ?? map['date']),
      status: ChargingCard._string(map['status']),
      description: ChargingCard._string(map['description']),
      currency: ChargingCard._string(map['currency']),
      cardId: ChargingCard._string(map['cardId']),
      sessionReferenceId: ChargingCard._string(
        map['sessionReferenceId'] ?? map['chargingSessionId'],
      ),
      paymentProvider: ChargingCard._string(
        map['paymentProvider'] ?? map['provider'],
      ),
      paymentMethod: ChargingCard._string(map['paymentMethod']),
      paypalOrderId: ChargingCard._string(map['paypalOrderId']),
      paypalCaptureId: ChargingCard._string(map['paypalCaptureId']),
      paypalAmount: ChargingCard._number(map['paypalAmount']),
      paypalCurrency: ChargingCard._string(map['paypalCurrency']),
      conversionType: ChargingCard._string(map['conversionType']),
      demoExchangeRate: ChargingCard._number(map['demoExchangeRate']),
      mockPaymentDetails: paymentDetails,
    );
  }
}

class InsufficientChargingCardBalanceException implements Exception {
  const InsufficientChargingCardBalanceException();

  @override
  String toString() => 'Insufficient charging card balance.';
}
