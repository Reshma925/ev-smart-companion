import 'dart:async';

enum PayPalWebCheckoutStatus { approved, cancelled, failed }

class PayPalWebCheckoutEvent {
  const PayPalWebCheckoutEvent({
    required this.status,
    this.orderId,
    this.message,
  });

  final PayPalWebCheckoutStatus status;
  final String? orderId;
  final String? message;
}

final Stream<PayPalWebCheckoutEvent> paypalWebCheckoutEvents =
    const Stream<PayPalWebCheckoutEvent>.empty();

void initializePayPalWebCheckoutBridge() {}

Future<void> preparePayPalWebCheckout({
  required String clientId,
  required String orderId,
}) async {
  throw UnsupportedError('PayPal Web checkout is only available on Web.');
}

void startPayPalWebCheckout() {
  throw UnsupportedError('PayPal Web checkout is only available on Web.');
}

void finishPayPalWebCheckoutCapture({required bool success}) {
  throw UnsupportedError('PayPal Web checkout is only available on Web.');
}
