import 'dio_client.dart';

class PaymentGatewayService {
  static const _base = '/payment-gateway';

  /// Create a Razorpay payment order
  static Future<Map<String, dynamic>> createOrder({
    required String studentId,
    required String installmentId,
    required double amount,
    String currency = 'INR',
  }) async {
    final response = await DioClient.post('$_base/create-order', data: {
      'studentId': studentId,
      'installmentId': installmentId,
      'amount': amount,
      'currency': currency,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Verify payment after Razorpay checkout
  static Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await DioClient.post('$_base/verify', data: {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Get payment order status
  static Future<Map<String, dynamic>> getOrderStatus(String orderId) async {
    final response = await DioClient.get('$_base/status/$orderId');
    return response.data as Map<String, dynamic>;
  }
}
