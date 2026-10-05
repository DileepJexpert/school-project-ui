// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Handles browser-native printable receipt generation via Blob HTML.
class ReceiptPrintService {
  static void printFeeReceipt({
    required String schoolName,
    required String receiptNumber,
    required String studentName,
    required String className,
    required String rollNumber,
    required String admissionNumber,
    required String paymentDate,
    required String paymentMode,
    required double amountPaid,
    required double discount,
    required List<String> installments,
    String? remarks,
  }) {
    final installmentsHtml = installments.isEmpty
        ? '<tr><td>Tuition & School Fees</td><td style="text-align: right; color: #059669; font-weight: bold;">PAID</td></tr>'
        : installments
            .map((item) =>
                '<tr><td>$item</td><td style="text-align: right; color: #059669; font-weight: bold;">PAID</td></tr>')
            .join('');

    final discountHtml = discount > 0
        ? '<div style="font-size: 12px; color: #f59e0b; margin-bottom: 4px;">Discount Applied: ₹${discount.toStringAsFixed(2)}</div>'
        : '';

    final remarksHtml = remarks != null && remarks.isNotEmpty
        ? '<p style="font-size: 12px; color: #5F6B7A; margin-bottom: 20px;"><strong>Remarks:</strong> $remarks</p>'
        : '';

    final rollStr = rollNumber.isEmpty ? '-' : rollNumber;
    final admStr = admissionNumber.isEmpty ? '-' : admissionNumber;
    final paidStr = amountPaid.toStringAsFixed(2);

    final printContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Fee Receipt - $receiptNumber</title>
  <style>
    @media print {
      body { margin: 0; padding: 20px; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #172033; }
      .no-print { display: none; }
    }
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 30px; max-width: 650px; margin: auto; border: 1px solid #e2e8f0; border-radius: 8px; }
    .header { text-align: center; border-bottom: 2px solid #17324D; padding-bottom: 12px; margin-bottom: 16px; }
    .school-title { font-size: 22px; font-weight: bold; color: #17324D; margin: 0; text-transform: uppercase; letter-spacing: 0.5px; }
    .school-sub { font-size: 12px; color: #5F6B7A; margin: 4px 0 0 0; }
    .badge { display: inline-block; background: #059669; color: white; padding: 4px 14px; border-radius: 12px; font-size: 12px; font-weight: bold; margin-top: 8px; letter-spacing: 0.5px; }
    .meta-table, .items-table { width: 100%; border-collapse: collapse; margin-bottom: 16px; }
    .meta-table td { padding: 6px 8px; font-size: 13px; }
    .meta-label { color: #5F6B7A; font-weight: 600; width: 25%; }
    .meta-val { color: #172033; font-weight: bold; width: 25%; }
    .items-table th { background: #17324D; color: white; text-align: left; padding: 8px 10px; font-size: 12px; text-transform: uppercase; }
    .items-table td { border-bottom: 1px solid #e2e8f0; padding: 8px 10px; font-size: 13px; }
    .total-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 12px 16px; text-align: right; margin-bottom: 20px; }
    .total-val { font-size: 22px; font-weight: bold; color: #059669; }
    .footer { display: flex; justify-content: space-between; align-items: flex-end; margin-top: 36px; padding-top: 16px; font-size: 11px; color: #5F6B7A; border-top: 1px solid #f1f5f9; }
    .sign-box { text-align: center; border-top: 1px dashed #94a3b8; width: 160px; padding-top: 6px; font-size: 12px; font-weight: 600; color: #17324D; }
  </style>
</head>
<body>
  <div class="header">
    <h1 class="school-title">$schoolName</h1>
    <p class="school-sub">Affiliated to CBSE • Excellence in Education</p>
    <div class="badge">FEE PAYMENT RECEIPT</div>
  </div>
  <table class="meta-table">
    <tr>
      <td class="meta-label">Receipt No:</td>
      <td class="meta-val">$receiptNumber</td>
      <td class="meta-label">Payment Date:</td>
      <td class="meta-val">$paymentDate</td>
    </tr>
    <tr>
      <td class="meta-label">Student Name:</td>
      <td class="meta-val">$studentName</td>
      <td class="meta-label">Class:</td>
      <td class="meta-val">$className</td>
    </tr>
    <tr>
      <td class="meta-label">Roll Number:</td>
      <td class="meta-val">$rollStr</td>
      <td class="meta-label">Admission No:</td>
      <td class="meta-val">$admStr</td>
    </tr>
    <tr>
      <td class="meta-label">Payment Mode:</td>
      <td class="meta-val">$paymentMode</td>
      <td class="meta-label">Status:</td>
      <td class="meta-val" style="color: #059669;">SUCCESS</td>
    </tr>
  </table>
  <table class="items-table">
    <thead>
      <tr>
        <th>Fee Head / Installment Description</th>
        <th style="text-align: right;">Status</th>
      </tr>
    </thead>
    <tbody>
      $installmentsHtml
    </tbody>
  </table>
  <div class="total-box">
    $discountHtml
    <div style="font-size: 12px; color: #5F6B7A; text-transform: uppercase;">Total Amount Paid</div>
    <div class="total-val">₹$paidStr</div>
  </div>
  $remarksHtml
  <div class="footer">
    <div>Generated on $paymentDate<br>Official Computer-Generated Receipt</div>
    <div class="sign-box">Authorized Signatory</div>
  </div>
  <script>
    window.onload = function() {
      setTimeout(function() { window.print(); }, 200);
    };
  </script>
</body>
</html>
''';

    final blob = html.Blob([printContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    // Allow window to load before revoking
    Future.delayed(const Duration(seconds: 10), () {
      html.Url.revokeObjectUrl(url);
    });
  }
}
