import 'package:url_launcher/url_launcher.dart';

/// Service to generate and launch pre-filled WhatsApp messages for fee receipts, reminders, and attendance alerts.
class WhatsAppShareService {
  WhatsAppShareService._();

  /// Formats and launches WhatsApp with a clean fee receipt summary.
  static Future<bool> shareFeeReceipt({
    required String schoolName,
    required String receiptNumber,
    required String studentName,
    required String className,
    String? rollNumber,
    required String paymentDate,
    required String paymentMode,
    required double amountPaid,
    double discount = 0.0,
    required List<String> installments,
    String? parentPhone,
    String? remarks,
  }) async {
    final rollStr = (rollNumber != null && rollNumber.isNotEmpty)
        ? ' (Roll: $rollNumber)'
        : '';
    final instStr =
        installments.isEmpty ? 'General Tuition Fees' : installments.join(', ');
    final discountStr =
        discount > 0 ? '\n🎁 *Discount:* ₹${discount.toStringAsFixed(0)}' : '';
    final remarksStr = (remarks != null && remarks.trim().isNotEmpty)
        ? '\n📌 *Remarks:* ${remarks.trim()}'
        : '';

    final message = '''
🏫 *$schoolName*
🧾 *FEE PAYMENT RECEIPT*
━━━━━━━━━━━━━━━━━━━━
📄 *Receipt No:* $receiptNumber
📅 *Date:* $paymentDate
👤 *Student:* $studentName
🎓 *Class:* $className$rollStr
💰 *Amount Paid:* ₹${amountPaid.toStringAsFixed(0)}
💳 *Payment Mode:* $paymentMode
📋 *Installments:* $instStr$discountStr$remarksStr
━━━━━━━━━━━━━━━━━━━━
✅ *Status:* Paid & Recorded
Thank you! For any queries, please contact the school office.
'''.trim();

    return shareMessage(phone: parentPhone, message: message);
  }

  /// Formats and launches WhatsApp with an outstanding fee dues reminder.
  static Future<bool> shareFeeDueReminder({
    required String schoolName,
    required String studentName,
    required String className,
    String? rollNumber,
    required double dueAmount,
    required List<String> pendingInstallments,
    String? parentPhone,
  }) async {
    final rollStr = (rollNumber != null && rollNumber.isNotEmpty)
        ? ' (Roll: $rollNumber)'
        : '';
    final pendingStr = pendingInstallments.isEmpty
        ? 'Upcoming Installment'
        : pendingInstallments.join(', ');

    final message = '''
🏫 *$schoolName*
🔔 *FEE PAYMENT REMINDER*
━━━━━━━━━━━━━━━━━━━━
👤 *Student:* $studentName
🎓 *Class:* $className$rollStr
⚠️ *Outstanding Dues:* ₹${dueAmount.toStringAsFixed(0)}
📋 *Pending Installments:* $pendingStr
━━━━━━━━━━━━━━━━━━━━
Kindly arrange the payment at your earliest convenience. If already paid, please ignore this reminder.
Thank you!
'''.trim();

    return shareMessage(phone: parentPhone, message: message);
  }

  /// Formats and launches WhatsApp with a student attendance absence notice.
  static Future<bool> shareAttendanceAbsentAlert({
    required String schoolName,
    required String studentName,
    required String className,
    String? rollNumber,
    required String date,
    String? parentPhone,
  }) async {
    final rollStr = (rollNumber != null && rollNumber.isNotEmpty)
        ? ' (Roll: $rollNumber)'
        : '';

    final message = '''
🏫 *$schoolName*
⚠️ *DAILY ATTENDANCE NOTICE*
━━━━━━━━━━━━━━━━━━━━
Dear Parent,
This is to inform you that *$studentName*$rollStr of *Class $className* has been marked *ABSENT* on *$date*.

If your ward was absent due to illness or pre-approved leave, please notify the school office.
━━━━━━━━━━━━━━━━━━━━
Thank you,
*Administration Office*
'''.trim();

    return shareMessage(phone: parentPhone, message: message);
  }

  /// Launches WhatsApp with an optional prefilled phone number and message.
  static Future<bool> shareMessage({
    String? phone,
    required String message,
  }) async {
    String cleanPhone = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.startsWith('+')) {
      cleanPhone = cleanPhone.substring(1);
    }
    // If standard 10-digit Indian number without country code, prepend 91
    if (cleanPhone.length == 10 && !cleanPhone.startsWith('91')) {
      cleanPhone = '91$cleanPhone';
    }

    final encodedMsg = Uri.encodeComponent(message);
    final urlStr = cleanPhone.isNotEmpty
        ? 'https://wa.me/$cleanPhone?text=$encodedMsg'
        : 'https://wa.me/?text=$encodedMsg';

    final uri = Uri.parse(urlStr);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
