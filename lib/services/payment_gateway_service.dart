import 'dio_client.dart';

class PaymentGatewayService {
  static const _base = '/payment-gateway';

  /// Whether the school has enabled online payments, plus the Razorpay key id.
  /// Returns: { enabled: bool, keyId: String? }
  static Future<Map<String, dynamic>> getConfig() async {
    final response = await DioClient.get('$_base/config');
    return response.data as Map<String, dynamic>;
  }

  /// Create a Razorpay payment order for a single installment.
  static Future<Map<String, dynamic>> createOrder({
    required String studentId,
    required String installmentId,
    required String installmentLabel,
    required double amount,
    String? studentName,
    String? className,
    String? parentEmail,
    String? parentPhone,
  }) async {
    final response = await DioClient.post('$_base/create-order', data: {
      'studentId': studentId,
      'installmentId': installmentId,
      'installmentLabel': installmentLabel,
      'amount': amount,
      if (studentName != null) 'studentName': studentName,
      if (className != null) 'className': className,
      if (parentEmail != null) 'parentEmail': parentEmail,
      if (parentPhone != null) 'parentPhone': parentPhone,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Verify payment after the Razorpay checkout completes.
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

  /// Get payment order status by Razorpay order id.
  static Future<Map<String, dynamic>> getOrderStatus(String orderId) async {
    final response = await DioClient.get('$_base/status/$orderId');
    return response.data as Map<String, dynamic>;
  }
}
