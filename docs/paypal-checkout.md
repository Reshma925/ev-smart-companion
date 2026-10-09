# PayPal checkout by platform

PayPal order creation and capture remain authenticated Firebase callable
operations. The backend validates the INR recharge, calculates the fixed
DEMO-only INR-to-USD Sandbox amount, verifies PayPal's completed capture, and
credits the INR amount once. The browser receives only the public PayPal client
ID; no PayPal secret or OAuth token is sent to Flutter.

## Web

Flutter Web uses PayPal's official JavaScript SDK v6 Sandbox core and one-time
payment session. The PayPal checkout opens in the SDK-supported popup, leaving
the recharge screen in place. Its approval callback invokes the existing
`capturePayPalRechargeOrder` callable; only a successful backend capture marks
the recharge successful. The app does not embed PayPal login in a WebView.

## Android and iOS

Native Android/iOS currently retain the clearly labeled external PayPal
approval URL fallback. Native PayPal SDK checkout return handling is pending
until the project has a real HTTPS domain configured and verified for Android
App Links and iOS Universal Links. No placeholder domain or deep-link
association is configured.

## Official SDK references

- [PayPal JavaScript SDK v6 reference](https://developer.paypal.com/sdk/js/reference/)
- [PayPal Android Mobile SDK overview](https://developer.paypal.com/sdk/android/overview)
- [PayPal iOS Mobile SDK overview](https://developer.paypal.com/sdk/ios/overview)
