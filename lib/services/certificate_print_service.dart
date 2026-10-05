// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:intl/intl.dart';

/// Handles browser-native printable School Certificates (TC, Bonafide, Character, Study).
class CertificatePrintService {
  static void printCertificate({
    required Map<String, dynamic> certificate,
    String schoolName = 'Springdale Public School',
    String schoolAffiliation = 'Affiliated to CBSE, New Delhi (Affiliation No: 1930245)',
    String schoolAddress = 'Sector 4, Dwarka, New Delhi - 110075 | Tel: +91 11 2808 0000',
  }) {
    final certType = (certificate['certificateType'] as String? ?? 'BONAFIDE').toUpperCase();
    final studentName = certificate['studentName'] as String? ?? 'Student Name';
    final serialNumber = certificate['serialNumber'] as String? ?? 'CERT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final admissionNo = certificate['admissionNumber'] as String? ?? (certificate['studentId'] as String? ?? '').substring(0, 8);
    final className = certificate['className'] as String? ?? 'Class 10-A';
    final academicYear = certificate['academicYear'] as String? ?? '2024-2025';
    final fatherName = certificate['fatherName'] as String? ?? 'Parent / Guardian';
    final reason = certificate['reason'] as String? ?? '';
    final dateStr = DateFormat('dd MMMM yyyy').format(DateTime.now());

    String title;
    String certificateBody;

    switch (certType) {
      case 'TRANSFER':
        title = 'TRANSFER CERTIFICATE';
        certificateBody = '''
        <p style="font-size: 14px; line-height: 1.8; margin-top: 24px;">
          This is to certify that <strong>$studentName</strong>, Son/Daughter of <strong>$fatherName</strong>,
          holding Admission / Scholar No. <strong>$admissionNo</strong>, was admitted to this institution in
          <strong>$className</strong> and has been on the rolls up to <strong>$dateStr</strong>.
        </p>
        <table style="width: 100%; border-collapse: collapse; margin-top: 18px; font-size: 13px;">
          <tr><td style="padding: 6px 0; width: 45%; color: #475569;">1. Class in which student last studied:</td><td style="font-weight: bold; color: #17324D;">$className</td></tr>
          <tr><td style="padding: 6px 0; color: #475569;">2. Academic Year:</td><td style="font-weight: bold; color: #17324D;">$academicYear</td></tr>
          <tr><td style="padding: 6px 0; color: #475569;">3. School / Board Examination last taken:</td><td style="font-weight: bold; color: #17324D;">Passed & Promoted</td></tr>
          <tr><td style="padding: 6px 0; color: #475569;">4. Whether school dues have been cleared:</td><td style="font-weight: bold; color: #059669;">Yes, All Dues Cleared</td></tr>
          <tr><td style="padding: 6px 0; color: #475569;">5. Reason for leaving the school:</td><td style="font-weight: bold; color: #17324D;">${reason.isNotEmpty ? reason : 'Parent Request / Relocation'}</td></tr>
          <tr><td style="padding: 6px 0; color: #475569;">6. General Conduct and Behavior:</td><td style="font-weight: bold; color: #17324D;">Good & Exemplary</td></tr>
        </table>
        ''';
        break;

      case 'CHARACTER':
        title = 'CHARACTER & CONDUCT CERTIFICATE';
        certificateBody = '''
        <p style="font-size: 15px; line-height: 2.0; margin-top: 32px; text-align: justify;">
          This is to certify that <strong>$studentName</strong>, Son/Daughter of <strong>$fatherName</strong>,
          bearing Admission No. <strong>$admissionNo</strong>, has been a student of this school in
          <strong>$className</strong> during the academic session <strong>$academicYear</strong>.
        </p>
        <p style="font-size: 15px; line-height: 2.0; margin-top: 16px; text-align: justify;">
          During their tenure at the institution, they have demonstrated exemplary conduct, moral integrity,
          and obedience. They have actively engaged in curricular and co-curricular endeavors and bear a
          <strong>commendable moral character</strong>.
        </p>
        <p style="font-size: 14px; line-height: 1.8; margin-top: 16px;">
          ${reason.isNotEmpty ? 'Issued on request for: <em>$reason</em>.' : 'We wish them all success in their future endeavors.'}
        </p>
        ''';
        break;

      case 'STUDY':
        title = 'STUDY & MEDIUM OF INSTRUCTION CERTIFICATE';
        certificateBody = '''
        <p style="font-size: 15px; line-height: 2.0; margin-top: 32px; text-align: justify;">
          This is to certify that <strong>$studentName</strong>, Son/Daughter of <strong>$fatherName</strong>,
          Admission No. <strong>$admissionNo</strong>, is a student of this institution studying in
          <strong>$className</strong> during the academic year <strong>$academicYear</strong>.
        </p>
        <p style="font-size: 15px; line-height: 2.0; margin-top: 16px; text-align: justify;">
          The medium of instruction and examination in this school is <strong>ENGLISH</strong> for all
          scholastic subjects. The curriculum follows the standard syllabi prescribed by the
          Central Board of Secondary Education (CBSE), New Delhi.
        </p>
        <p style="font-size: 14px; line-height: 1.8; margin-top: 16px;">
          ${reason.isNotEmpty ? 'Issued for: <em>$reason</em>.' : ''}
        </p>
        ''';
        break;

      case 'BONAFIDE':
      default:
        title = 'BONAFIDE CERTIFICATE';
        certificateBody = '''
        <p style="font-size: 15px; line-height: 2.0; margin-top: 36px; text-align: justify;">
          This is to certify that <strong>$studentName</strong>, Son/Daughter of <strong>$fatherName</strong>,
          bearing Admission No. <strong>$admissionNo</strong>, is a <strong>bonafide student</strong> of this school
          studying in <strong>$className</strong> for the Academic Session <strong>$academicYear</strong>.
        </p>
        <p style="font-size: 15px; line-height: 2.0; margin-top: 16px; text-align: justify;">
          As per the institutional records, their date of birth and residential credentials are on official file.
          Their attendance and behavior have been regular and satisfactory.
        </p>
        <p style="font-size: 14px; line-height: 1.8; margin-top: 16px;">
          ${reason.isNotEmpty ? 'This certificate is issued on specific request for: <strong>$reason</strong>.' : 'This certificate is issued upon request for official verification.'}
        </p>
        ''';
        break;
    }

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>$title - $studentName</title>
  <style>
    @media print {
      body { margin: 0; padding: 20px; font-family: 'Times New Roman', Times, serif; color: #172033; }
      .no-print { display: none; }
      @page { size: A4 portrait; margin: 15mm; }
    }
    body { font-family: 'Times New Roman', Times, serif; padding: 40px; max-width: 740px; margin: auto; border: 3px double #17324D; background: #fff; }
    .school-header { text-align: center; border-bottom: 2px solid #17324D; padding-bottom: 12px; margin-bottom: 16px; }
    .school-name { font-size: 26px; font-weight: bold; color: #17324D; text-transform: uppercase; letter-spacing: 1px; margin: 0; font-family: 'Georgia', serif; }
    .school-sub { font-size: 12px; color: #475569; margin: 3px 0; font-family: sans-serif; }
    .cert-badge { display: inline-block; border-bottom: 2px solid #17324D; padding-bottom: 4px; font-size: 17px; font-weight: bold; letter-spacing: 1.5px; text-transform: uppercase; margin-top: 14px; color: #17324D; font-family: 'Georgia', serif; }
    .meta-row { display: flex; justify-content: space-between; font-size: 13px; font-family: sans-serif; color: #475569; margin-top: 16px; border-bottom: 1px dashed #cbd5e1; padding-bottom: 8px; }
    .content-area { font-family: 'Georgia', serif; color: #1e293b; min-height: 220px; }
    .seal-box { width: 90px; height: 90px; border: 2px dashed #94a3b8; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 10px; color: #64748b; text-align: center; text-transform: uppercase; }
    .signatures { display: flex; justify-content: space-between; align-items: flex-end; margin-top: 80px; padding: 0 10px; font-family: sans-serif; }
    .sig-line { text-align: center; border-top: 1px solid #334155; width: 170px; padding-top: 6px; font-size: 12px; font-weight: 600; color: #17324D; }
  </style>
</head>
<body>
  <div class="school-header">
    <div class="school-name">$schoolName</div>
    <div class="school-sub">$schoolAffiliation</div>
    <div class="school-sub">$schoolAddress</div>
    <div class="cert-badge">$title</div>
  </div>

  <div class="meta-row">
    <div><strong>Certificate No:</strong> $serialNumber</div>
    <div><strong>Date of Issue:</strong> $dateStr</div>
  </div>

  <div class="content-area">
    $certificateBody
  </div>

  <div class="signatures">
    <div class="sig-line">Prepared & Verified By</div>
    <div class="seal-box">School Seal</div>
    <div class="sig-line">Principal / Headmaster</div>
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
