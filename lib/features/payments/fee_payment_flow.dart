import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/payment_gateway_service.dart';
import '../../services/razorpay_web.dart';

/// Drives the full online fee-payment flow for a single installment:
///   create order  ->  Razorpay checkout  ->  verify  ->  result
///
/// Returns `true` only when the payment is verified PAID, so the caller can
/// refresh the fee list. All user feedback (snackbars/dialogs) is handled here.
Future<bool> startFeePayment(
  BuildContext context, {
  required String studentId,
  required String studentName,
  required String className,
  required String installmentId,
  required String installmentName,
  required double amount,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  // 1. Create the order (show a brief loading dialog)
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  Map<String, dynamic> order;
  try {
    order = await PaymentGatewayService.createOrder(
      studentId: studentId,
      installmentId: installmentId,
      installmentLabel: installmentName,
      amount: amount,
      studentName: studentName,
      className: className,
      parentEmail: AuthService.instance.currentUser?.email,
    );
  } catch (e) {
    if (context.mounted) Navigator.of(context).pop(); // close loader
    messenger.showSnackBar(
      SnackBar(content: Text('Could not start payment: $e')),
    );
    return false;
  }

  // Need the Razorpay key id to open checkout
  String? keyId;
  try {
    final config = await PaymentGatewayService.getConfig();
    keyId = config['keyId'] as String?;
  } catch (_) {}

  if (context.mounted) Navigator.of(context).pop(); // close loader

  final razorpayOrderId = order['razorpayOrderId'] as String?;
  if (keyId == null || keyId.isEmpty || razorpayOrderId == null) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Online payment is not set up by your school yet.'),
    ));
    return false;
  }

  // 2. Open Razorpay checkout and wait for a terminal outcome
  final completer = Completer<bool>();

  RazorpayWeb.open(
    keyId: keyId,
    orderId: razorpayOrderId,
    amountPaise: (amount * 100).round(),
    name: '$studentName · Fee Payment',
    description: installmentName,
    email: AuthService.instance.currentUser?.email,
    onSuccess: (paymentId, returnedOrderId, signature) async {
      // 3. Verify on the backend before trusting the result
      try {
        final result = await PaymentGatewayService.verifyPayment(
          razorpayOrderId: returnedOrderId.isNotEmpty ? returnedOrderId : razorpayOrderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: signature,
        );
        final paid = result['status'] == 'PAID';
        messenger.showSnackBar(SnackBar(
          content: Text(paid
              ? 'Payment successful! Receipt updated.'
              : 'Payment could not be verified. If money was deducted, it will be reconciled shortly.'),
          backgroundColor: paid ? Colors.green : Colors.orange,
        ));
        if (!completer.isCompleted) completer.complete(paid);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
        if (!completer.isCompleted) completer.complete(false);
      }
    },
    onError: (message) {
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
      if (!completer.isCompleted) completer.complete(false);
    },
    onDismiss: () {
      messenger.showSnackBar(
        const SnackBar(content: Text('Payment cancelled.')),
      );
      if (!completer.isCompleted) completer.complete(false);
    },
  );

  return completer.future;
}
