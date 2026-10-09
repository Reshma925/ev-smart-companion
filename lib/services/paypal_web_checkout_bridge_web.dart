import 'dart:async';
import 'dart:js_interop';

import 'paypal_web_checkout_bridge_stub.dart';

export 'paypal_web_checkout_bridge_stub.dart'
    show PayPalWebCheckoutEvent, PayPalWebCheckoutStatus;

@JS('window.evPaypalCheckout.prepare')
external JSPromise<JSAny?> _preparePayPalCheckout(
  JSString clientId,
  JSString orderId,
);

@JS('window.evPaypalCheckout.start')
external void _startPayPalCheckout();

@JS('window.evPaypalCheckout.finishCapture')
external void _finishPayPalCheckoutCapture(JSBoolean success);

@JS('window.evPaypalCheckout.setEventCallback')
external void _setPayPalCheckoutEventCallback(JSFunction callback);

final StreamController<PayPalWebCheckoutEvent> _events =
    StreamController<PayPalWebCheckoutEvent>.broadcast();
bool _initialized = false;
JSFunction? _eventCallback;

Stream<PayPalWebCheckoutEvent> get paypalWebCheckoutEvents => _events.stream;

void initializePayPalWebCheckoutBridge() {
  if (_initialized) return;
  _initialized = true;
  _eventCallback = ((JSAny? rawEvent) {
    final event = rawEvent?.dartify();
    if (event is! Map) return;
    switch (event['status']) {
      case 'approved':
        _events.add(
          PayPalWebCheckoutEvent(
            status: PayPalWebCheckoutStatus.approved,
            orderId: event['orderId']?.toString(),
          ),
        );
      case 'cancelled':
        _events.add(
          const PayPalWebCheckoutEvent(
            status: PayPalWebCheckoutStatus.cancelled,
          ),
        );
      case 'failed':
        _events.add(
          PayPalWebCheckoutEvent(
            status: PayPalWebCheckoutStatus.failed,
            message: event['message']?.toString(),
          ),
        );
    }
  }).toJS;
  _setPayPalCheckoutEventCallback(_eventCallback!);
}

Future<void> preparePayPalWebCheckout({
  required String clientId,
  required String orderId,
}) async {
  await _preparePayPalCheckout(clientId.toJS, orderId.toJS).toDart;
}

void startPayPalWebCheckout() {
  _startPayPalCheckout();
}

void finishPayPalWebCheckoutCapture({required bool success}) {
  _finishPayPalCheckoutCapture(success.toJS);
}
