// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Handles browser-native printable Salary Slips / Payslips via Blob HTML.
class PayslipPrintService {
  static void printPayslip({
    required Map<String, dynamic> salary,
    required int month,
    required int year,
    String schoolName = 'Springdale Public School',
    String schoolAffiliation = 'Affiliated to CBSE, New Delhi (Affiliation No: 1930245)',
    String schoolAddress = 'Sector 4, Dwarka, New Delhi - 110075 | Tel: +91 11 2808 0000',
  }) {
    final staffName = salary['staffName'] as String? ?? 'Staff Member';
    final department = salary['department'] as String? ?? 'General';
    final designation = salary['designation'] as String? ?? 'Teacher / Staff';
    final employeeId = salary['staffId'] as String? ?? (salary['id'] as String? ?? '').substring(0, 8);
    final status = salary['status'] as String? ?? 'GENERATED';

    final basicPay = (salary['basicPay'] as num?)?.toDouble() ?? 0;
    final hra = (salary['hra'] as num?)?.toDouble() ?? 0;
    final da = (salary['da'] as num?)?.toDouble() ?? 0;
    final ta = (salary['ta'] as num?)?.toDouble() ?? 0;
    final otherAllowances = (salary['otherAllowances'] as num?)?.toDouble() ?? 0;
    final grossSalary = (salary['grossSalary'] as num?)?.toDouble() ?? 0;

    final pf = (salary['pf'] as num?)?.toDouble() ?? 0;
    final tax = (salary['tax'] as num?)?.toDouble() ?? 0;
    final otherDeductions = (salary['otherDeductions'] as num?)?.toDouble() ?? 0;
    final totalDeductions = (salary['totalDeductions'] as num?)?.toDouble() ?? 0;
    final netSalary = (salary['netSalary'] as num?)?.toDouble() ?? 0;

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthName = (month >= 1 && month <= 12) ? monthNames[month - 1] : 'Month';
    final isPaid = status.toUpperCase() == 'PAID';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Payslip - $staffName - $monthName $year</title>
  <style>
    @media print {
      body { margin: 0; padding: 12px; font-family: 'Segoe UI', Arial, sans-serif; color: #172033; }
      .no-print { display: none; }
      @page { size: A4 portrait; margin: 12mm; }
    }
    body { font-family: 'Segoe UI', Arial, sans-serif; padding: 24px; max-width: 760px; margin: auto; border: 2px solid #17324D; border-radius: 6px; }
    .school-header { text-align: center; border-bottom: 2px solid #17324D; padding-bottom: 10px; margin-bottom: 12px; }
    .school-name { font-size: 22px; font-weight: bold; color: #17324D; text-transform: uppercase; margin: 0; letter-spacing: 0.5px; }
    .school-meta { font-size: 11px; color: #475569; margin: 2px 0; }
    .payslip-title { display: inline-block; background: #17324D; color: white; padding: 4px 18px; border-radius: 12px; font-size: 13px; font-weight: bold; margin-top: 6px; letter-spacing: 0.5px; text-transform: uppercase; }
    .meta-table { width: 100%; border-collapse: collapse; margin-bottom: 14px; font-size: 12px; }
    .meta-table td { padding: 5px 8px; }
    .label { color: #64748b; font-weight: 600; width: 22%; }
    .val { color: #0f172a; font-weight: bold; width: 28%; }
    .salary-table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 12px; }
    .salary-table th { background: #17324D; color: white; padding: 8px 10px; font-size: 11px; text-transform: uppercase; }
    .salary-table td { border: 1px solid #cbd5e1; padding: 6px 10px; }
    .net-box { display: flex; justify-content: space-between; align-items: center; background: #f0fdf4; border: 2px solid #059669; border-radius: 6px; padding: 12px 18px; margin-top: 14px; }
    .net-title { font-size: 13px; font-weight: 600; color: #065f46; text-transform: uppercase; }
    .net-amt { font-size: 22px; font-weight: bold; color: #059669; }
    .signatures { display: flex; justify-content: space-between; margin-top: 48px; padding: 0 12px; }
    .sig-block { text-align: center; border-top: 1px solid #334155; width: 160px; padding-top: 6px; font-size: 11px; color: #334155; font-weight: 600; }
    .status-stamp { display: inline-block; padding: 3px 10px; border-radius: 4px; font-size: 11px; font-weight: bold; }
    .paid { background: #dcfce7; color: #166534; border: 1px solid #86efac; }
    .pending { background: #fef3c7; color: #92400e; border: 1px solid #fde68a; }
  </style>
</head>
<body>
  <div class="school-header">
    <div class="school-name">$schoolName</div>
    <div class="school-meta">$schoolAffiliation</div>
    <div class="school-meta">$schoolAddress</div>
    <div class="payslip-title">Salary Slip · $monthName $year</div>
  </div>

  <table class="meta-table">
    <tr>
      <td class="label">Staff Name:</td>
      <td class="val">$staffName</td>
      <td class="label">Employee ID:</td>
      <td class="val">$employeeId</td>
    </tr>
    <tr>
      <td class="label">Designation:</td>
      <td class="val">$designation</td>
      <td class="label">Department:</td>
      <td class="val">$department</td>
    </tr>
    <tr>
      <td class="label">Pay Period:</td>
      <td class="val">$monthName $year</td>
      <td class="label">Payout Status:</td>
      <td class="val"><span class="status-stamp ${isPaid ? 'paid' : 'pending'}">${isPaid ? 'DISBURSED / PAID' : 'GENERATED / PENDING'}</span></td>
    </tr>
  </table>

  <table class="salary-table">
    <thead>
      <tr>
        <th style="width: 50%;">Earnings & Allowances</th>
        <th style="width: 50%;">Deductions</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td style="vertical-align: top; padding: 0;">
          <table style="width: 100%; border-collapse: collapse;">
            <tr><td style="border: none; border-bottom: 1px solid #f1f5f9; padding: 6px 10px;">Basic Pay</td><td style="border: none; border-bottom: 1px solid #f1f5f9; text-align: right; font-weight: bold; padding: 6px 10px;">₹ ${basicPay.toStringAsFixed(2)}</td></tr>
            <tr><td style="border: none; border-bottom: 1px solid #f1f5f9; padding: 6px 10px;">House Rent Allowance (HRA)</td><td style="border: none; border-bottom: 1px solid #f1f5f9; text-align: right; font-weight: bold; padding: 6px 10px;">₹ ${hra.toStringAsFixed(2)}</td></tr>
            <tr><td style="border: none; border-bottom: 1px solid #f1f5f9; padding: 6px 10px;">Dearness Allowance (DA)</td><td style="border: none; border-bottom: 1px solid #f1f5f9; text-align: right; font-weight: bold; padding: 6px 10px;">₹ ${da.toStringAsFixed(2)}</td></tr>
            <tr><td style="border: none; border-bottom: 1px solid #f1f5f9; padding: 6px 10px;">Transport Allowance (TA)</td><td style="border: none; border-bottom: 1px solid #f1f5f9; text-align: right; font-weight: bold; padding: 6px 10px;">₹ ${ta.toStringAsFixed(2)}</td></tr>
            ${otherAllowances > 0 ? '<tr><td style="border: none; border-bottom: 1px solid #f1f5f9; padding: 6px 10px;">Other Allowances</td><td style="border: none; border-bottom: 1px solid #f1f5f9; text-align: right; font-weight: bold; padding: 6px 10px;">₹ ${otherAllowances.toStringAsFixed(2)}</td></tr>' : ''}
            <tr style="background: #f8fafc;"><td style="border: none; padding: 8px 10px; font-weight: bold; color: #17324D;">Gross Salary</td><td style="border: none; text-align: right; font-weight: bold; color: #17324D; padding: 8px 10px;">₹ ${grossSalary.toStringAsFixed(2)}</td></tr>
          </table>
        </td>
        <td style="vertical-align: top; padding: 0;">
          <table style="width: 100%; border-collapse: collapse;">
            <tr><td style="border: none; border-bottom: 1px solid #f1f5f9; padding: 6px 10px;">Provident Fund (PF)</td><td style="border: none; border-bottom: 1px solid #f1f5f9; text-align: right; font-weight: bold; padding: 6px 10px;">₹ ${pf.toStringAsFixed(2)}</td></tr>
            <tr><td style="border: none; border-bottom: 1px solid #f1f5f9; padding: 6px 10px;">Income Tax / TDS</td><td style="border: none; border-bottom: 1px solid #f1f5f9; text-align: right; font-weight: bold; padding: 6px 10px;">₹ ${tax.toStringAsFixed(2)}</td></tr>
            ${otherDeductions > 0 ? '<tr><td style="border: none; border-bottom: 1px solid #f1f5f9; padding: 6px 10px;">Other Deductions</td><td style="border: none; border-bottom: 1px solid #f1f5f9; text-align: right; font-weight: bold; padding: 6px 10px;">₹ ${otherDeductions.toStringAsFixed(2)}</td></tr>' : ''}
            <tr style="background: #f8fafc;"><td style="border: none; padding: 8px 10px; font-weight: bold; color: #dc2626;">Total Deductions</td><td style="border: none; text-align: right; font-weight: bold; color: #dc2626; padding: 8px 10px;">₹ ${totalDeductions.toStringAsFixed(2)}</td></tr>
          </table>
        </td>
      </tr>
    </tbody>
  </table>

  <div class="net-box">
    <div>
      <div class="net-title">Net Take-Home Pay</div>
      <div style="font-size: 11px; color: #4b5563; margin-top: 2px;">(Gross Salary - Total Deductions)</div>
    </div>
    <div class="net-amt">₹ ${netSalary.toStringAsFixed(2)}</div>
  </div>

  <div class="signatures">
    <div class="sig-block">Employee Signature</div>
    <div class="sig-block">Accountant / Cashier</div>
    <div class="sig-block">Principal / Authority</div>
  </div>

  <script>
    window.onload = function() {
      window.print();
    };
  </script>
</body>
</html>
''';

    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }
}
