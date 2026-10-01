import 'dart:js' as js;

/// Thin wrapper around Razorpay Checkout.js (web).
/// The script is loaded in web/index.html.
class RazorpayWeb {
  RazorpayWeb._();

  /// Returns true if checkout.js has loaded.
  static bool get isAvailable => js.context.hasProperty('Razorpay');

  /// Opens the Razorpay checkout modal.
  ///
  /// [amountPaise] must be the amount in paise (rupees * 100).
  /// Exactly one of the callbacks fires for each checkout attempt.
  static void open({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String name,
    required String description,
    String? email,
    String? contact,
    required void Function(String paymentId, String orderId, String signature)
        onSuccess,
    required void Function(String message) onError,
    required void Function() onDismiss,
  }) {
    if (!isAvailable) {
      onError('Payment library failed to load. Check your connection and retry.');
      return;
    }

    // Plain Dart map with allowInterop callbacks — jsify converts nested maps
    // to JS objects and passes the JS functions straight through.
    final options = js.JsObject.jsify({
      'key': keyId,
      'order_id': orderId,
      'amount': amountPaise,
      'currency': 'INR',
      'name': name,
      'description': description,
      'prefill': {
        if (email != null && email.isNotEmpty) 'email': email,
        if (contact != null && contact.isNotEmpty) 'contact': contact,
      },
      'theme': {'color': '#1A2A4F'},
      'handler': js.allowInterop((response) {
        onSuccess(
          response['razorpay_payment_id']?.toString() ?? '',
          response['razorpay_order_id']?.toString() ?? '',
          response['razorpay_signature']?.toString() ?? '',
        );
      }),
      'modal': {
        'ondismiss': js.allowInterop(() => onDismiss()),
      },
    });

    try {
      final rzp = js.JsObject(js.context['Razorpay'], [options]);
      rzp.callMethod('on', [
        'payment.failed',
        js.allowInterop((response) {
          String msg = 'Payment failed. Please try again.';
          try {
            final err = response['error'];
            if (err != null && err['description'] != null) {
              msg = err['description'].toString();
            }
          } catch (_) {}
          onError(msg);
        })
      ]);
      rzp.callMethod('open');
    } catch (e) {
      onError('Could not start payment: $e');
    }
  }
}
