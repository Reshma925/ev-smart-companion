import 'package:cloud_firestore/cloud_firestore.dart';

class ChargingCard {
  const ChargingCard({
    required this.id,
    this.maskedCardNumber,
    this.cardType,
    this.balance,
    this.status,
    this.linkedVehicleId,
    this.expiryDate,
    this.lastRechargeAmount,
    this.lastRechargeDate,
  });

  final String id;
  final String? maskedCardNumber;
  final String? cardType;
  final double? balance;
  final String? status;
  final String? linkedVehicleId;
  final DateTime? expiryDate;
  final double? lastRechargeAmount;
  final DateTime? lastRechargeDate;

  factory ChargingCard.fromMap(Map<String, dynamic> map, {required String id}) {
    return ChargingCard(
      id: id,
      maskedCardNumber: _string(map['maskedCardNumber']),
      cardType: _string(map['cardType']),
      balance: _number(map['balance']),
      status: _string(map['status']),
      linkedVehicleId: _string(map['linkedVehicleId']),
      expiryDate: _date(map['expiryDate']),
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
    this.type,
    this.stationName,
    this.date,
    this.status,
    this.vehicleId,
  });

  final String id;
  final double? amount;
  final String? type;
  final String? stationName;
  final DateTime? date;
  final String? status;
  final String? vehicleId;

  factory ChargingTransaction.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return ChargingTransaction(
      id: id,
      amount: ChargingCard._number(map['amount']),
      type: ChargingCard._string(map['type']),
      stationName: ChargingCard._string(map['stationName']),
      date: ChargingCard._date(map['date']),
      status: ChargingCard._string(map['status']),
      vehicleId: ChargingCard._string(map['vehicleId']),
    );
  }
}
