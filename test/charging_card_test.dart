import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/charging_card.dart';

void main() {
  test('parses charging-card values supplied by Firestore', () {
    final card = ChargingCard.fromMap({
      'maskedCardNumber': '•••• 4821',
      'cardType': 'EV Smart Card',
      'balance': 1250,
      'status': 'Active',
      'linkedVehicleId': 'EV001',
      'expiryDate': Timestamp.fromDate(DateTime(2028, 12)),
      'lastRechargeAmount': 500,
      'lastRechargeDate': Timestamp.fromDate(DateTime(2026, 10, 2)),
    }, id: 'current');

    expect(card.id, 'current');
    expect(card.maskedCardNumber, '•••• 4821');
    expect(card.balance, 1250);
    expect(card.linkedVehicleId, 'EV001');
    expect(card.expiryDate, DateTime(2028, 12));
  });

  test('keeps missing or malformed charging-card values unavailable', () {
    final card = ChargingCard.fromMap({
      'balance': 'unknown',
      'lastRechargeAmount': double.infinity,
    }, id: 'current');

    expect(card.balance, isNull);
    expect(card.maskedCardNumber, isNull);
    expect(card.lastRechargeAmount, isNull);
  });

  test('parses transaction data without defaulting absent fields', () {
    final transaction = ChargingTransaction.fromMap({
      'amount': 420,
      'type': 'recharge',
      'date': Timestamp.fromDate(DateTime(2026, 10, 2)),
      'status': 'completed',
    }, id: 'transaction-1');

    expect(transaction.id, 'transaction-1');
    expect(transaction.amount, 420);
    expect(transaction.stationName, isNull);
    expect(transaction.vehicleId, isNull);
  });
}
