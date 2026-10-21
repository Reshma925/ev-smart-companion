import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/charging_card.dart';

void main() {
  test('parses charging-card values supplied by the backend', () {
    final card = ChargingCard.fromMap({
      'cardLastFour': '4821',
      'cardType': 'EV Smart Card',
      'cardHolderName': 'Maheswara',
      'balance': 1250,
      'currency': 'INR',
      'status': 'ACTIVE',
      'vehicleId': 'EV001',
      'expiryDate': DateTime(2028, 12).toUtc().toIso8601String(),
      'registeredAt': DateTime(2026, 10, 2).toUtc().toIso8601String(),
      'lastRechargeAmount': 500,
      'lastRechargeDate': DateTime(2026, 10, 2).toUtc().toIso8601String(),
    }, id: 'current');

    expect(card.id, 'current');
    expect(card.displayCardNumber, 'XXXX XXXX XXXX 4821');
    expect(card.cardHolderName, 'Maheswara');
    expect(card.balance, 1250);
    expect(card.currency, 'INR');
    expect(card.linkedVehicleId, 'EV001');
    expect(card.expiryDate, DateTime(2028, 12));
    expect(card.registeredAt, DateTime(2026, 10, 2));
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
      'type': 'debit',
      'balanceBefore': 500,
      'balanceAfter': 80,
      'stationId': 'osm-node-1',
      'operator': 'Operator',
      'cardId': 'current',
      'sessionReferenceId': 'session-42',
      'timestamp': DateTime(2026, 10, 2).toUtc().toIso8601String(),
      'status': 'completed',
    }, id: 'transaction-1');

    expect(transaction.id, 'transaction-1');
    expect(transaction.amount, 420);
    expect(transaction.balanceBefore, 500);
    expect(transaction.balanceAfter, 80);
    expect(transaction.stationId, 'osm-node-1');
    expect(transaction.operator, 'Operator');
    expect(transaction.cardId, 'current');
    expect(transaction.sessionReferenceId, 'session-42');
    expect(transaction.stationName, isNull);
    expect(transaction.vehicleId, isNull);
  });

  test('parses PayPal recharge provider and safe transaction identifiers', () {
    final transaction = ChargingTransaction.fromMap({
      'amount': 100,
      'currency': 'INR',
      'type': 'credit',
      'description': 'PayPal recharge',
      'provider': 'paypal',
      'paymentProvider': 'PayPal Sandbox',
      'paypalOrderId': 'SANDBOXORDER123',
      'paypalCaptureId': 'SANDBOXCATURE123',
      'paypalAmount': 1.2,
      'paypalCurrency': 'USD',
      'conversionType': 'demo_fixed_rate',
      'demoExchangeRate': 0.012,
      'status': 'completed',
    }, id: 'paypal-transaction-1');

    expect(transaction.paymentProvider, 'PayPal Sandbox');
    expect(transaction.paypalOrderId, 'SANDBOXORDER123');
    expect(transaction.paypalCaptureId, 'SANDBOXCATURE123');
    expect(transaction.amount, 100);
    expect(transaction.currency, 'INR');
    expect(transaction.paypalAmount, 1.2);
    expect(transaction.paypalCurrency, 'USD');
    expect(transaction.conversionType, 'demo_fixed_rate');
    expect(transaction.demoExchangeRate, 0.012);
    expect(transaction.status, 'completed');
  });

  test('masks the last four while preserving legacy masked values', () {
    final newCard = ChargingCard.fromMap({
      'cardLastFour': '1234',
    }, id: 'current');
    final legacyCard = ChargingCard.fromMap({
      'maskedCardNumber': '•••• 4821',
    }, id: 'current');

    expect(newCard.displayCardNumber, 'XXXX XXXX XXXX 1234');
    expect(legacyCard.displayCardNumber, '•••• 4821');
  });

  test(
    'reads already-masked vehicle-scoped card data without a raw number',
    () {
      final card = ChargingCard.fromMap({
        'cardId': 'current',
        'cardType': 'EV Charging Card',
        'maskedCardNumber': 'XXXX XXXX XXXX 4321',
        'cardHolderName': 'Test Holder',
        'vehicleId': 'EV002',
        'balance': 0,
        'currency': 'INR',
        'status': 'ACTIVE',
      }, id: 'current');

      expect(card.displayCardNumber, 'XXXX XXXX XXXX 4321');
      expect(card.vehicleId, 'EV002');
    },
  );
}
