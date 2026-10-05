// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../models/admission_data.dart';

/// Generates printable Admission Offer Letters and Provisional ID Slips via Blob HTML.
class AdmissionPrintService {
  static final _dateFmt = DateFormat('dd MMMM yyyy');

  static void printOfferLetter({
    required Student student,
    String? reportingDate,
  }) {
    final dobStr = _dateFmt.format(student.dateOfBirth);
    final doaStr = _dateFmt.format(student.dateOfAdmission);
    final todayStr = _dateFmt.format(DateTime.now());
    final refNo = 'SIA/ADM/${student.academicYear.replaceAll('-', '/')}/${student.admissionNumber.isNotEmpty ? student.admissionNumber : 'PROV'}';
    final reportStr = reportingDate ?? 'Within 7 working days';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Admission Offer Letter - ${student.fullName}</title>
  <style>
    @media print {
      body { margin: 0; padding: 20px; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #172033; }
      .no-print { display: none; }
    }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      padding: 36px 44px;
      max-width: 720px;
      margin: auto;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      color: #172033;
      line-height: 1.5;
    }
    .header { text-align: center; border-bottom: 2px solid #17324D; padding-bottom: 12px; margin-bottom: 20px; }
    .school-title { font-size: 24px; font-weight: bold; color: #17324D; margin: 0; text-transform: uppercase; letter-spacing: 0.5px; }
    .school-sub { font-size: 12px; color: #5F6B7A; margin: 4px 0 0 0; }
    .badge {
      display: inline-block;
      background: #17324D;
      color: white;
      padding: 5px 16px;
      border-radius: 14px;
      font-size: 13px;
      font-weight: 700;
      margin-top: 10px;
      letter-spacing: 0.6px;
    }
    .ref-row { display: flex; justify-content: space-between; margin-bottom: 16px; font-size: 12px; color: #5F6B7A; }
    .salutation { font-size: 14px; font-weight: 600; margin-bottom: 10px; }
    .body-p { font-size: 13px; color: #334155; margin-bottom: 14px; text-align: justify; }
    .info-box {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      padding: 12px 16px;
      margin-bottom: 16px;
    }
    .info-table { width: 100%; border-collapse: collapse; }
    .info-table td { padding: 5px 8px; font-size: 13px; }
    .label-cell { color: #5F6B7A; font-weight: 600; width: 30%; }
    .val-cell { color: #172033; font-weight: bold; width: 70%; }
    .checklist { margin: 12px 0; padding-left: 20px; font-size: 12px; color: #475569; }
    .checklist li { margin-bottom: 4px; }
    .footer { display: flex; justify-content: space-between; align-items: flex-end; margin-top: 44px; padding-top: 16px; border-top: 1px solid #e2e8f0; font-size: 11px; color: #64748b; }
    .sign-box { text-align: center; border-top: 1px dashed #94a3b8; width: 180px; padding-top: 6px; font-size: 12px; font-weight: 600; color: #17324D; }
  </style>
</head>
<body>
  <div class="header">
    <h1 class="school-title">${AppStrings.schoolName}</h1>
    <p class="school-sub">${AppStrings.accreditation} • ${AppStrings.address}</p>
    <p class="school-sub">Phone: ${AppStrings.phone} | Email: ${AppStrings.email}</p>
    <div class="badge">PROVISIONAL ADMISSION OFFER LETTER</div>
  </div>

  <div class="ref-row">
    <div><strong>Ref:</strong> $refNo</div>
    <div><strong>Date:</strong> $todayStr</div>
  </div>

  <div class="salutation">
    Dear Parent / Guardian of <u>${student.fullName}</u>,
  </div>

  <p class="body-p">
    We take immense pleasure in informing you that your ward has been granted <strong>Provisional Admission</strong> at
    <strong>${AppStrings.schoolName}</strong> for the Academic Session <strong>${student.academicYear}</strong>.
  </p>

  <div class="info-box">
    <table class="info-table">
      <tr>
        <td class="label-cell">Student Full Name:</td>
        <td class="val-cell">${student.fullName}</td>
      </tr>
      <tr>
        <td class="label-cell">Offered Class & Section:</td>
        <td class="val-cell">${student.classForAdmission}</td>
      </tr>
      <tr>
        <td class="label-cell">Admission / App No:</td>
        <td class="val-cell">${student.admissionNumber.isNotEmpty ? student.admissionNumber : 'PROV-ENROLL'}</td>
      </tr>
      <tr>
        <td class="label-cell">Date of Admission:</td>
        <td class="val-cell">$doaStr</td>
      </tr>
      <tr>
        <td class="label-cell">Date of Birth:</td>
        <td class="val-cell">$dobStr (${student.gender})</td>
      </tr>
      <tr>
        <td class="label-cell">Father's Name:</td>
        <td class="val-cell">${student.parentDetails.fatherName.isNotEmpty ? student.parentDetails.fatherName : '-'}</td>
      </tr>
      <tr>
        <td class="label-cell">Mother's Name:</td>
        <td class="val-cell">${student.parentDetails.motherName.isNotEmpty ? student.parentDetails.motherName : '-'}</td>
      </tr>
      <tr>
        <td class="label-cell">Contact Phone:</td>
        <td class="val-cell">${student.contactDetails.primaryContactNumber}</td>
      </tr>
    </table>
  </div>

  <p class="body-p">
    <strong>Next Steps & Verification Checklist:</strong>
    Please complete the final enrollment formalities by <strong>$reportStr</strong> at the administrative office:
  </p>

  <ul class="checklist">
    <li>Submission of Transfer Certificate (Original) from previous accredited institution.</li>
    <li>Copy of Official Birth Certificate & Student/Parent Aadhaar cards.</li>
    <li>Medical fitness certificate with blood group verification.</li>
    <li>Settlement of Term-1 / Annual Admission fee installment at the accounts desk.</li>
  </ul>

  <p class="body-p" style="margin-top: 14px;">
    We look forward to partnering with your family to nurture academic brilliance, exemplary character, and holistic growth.
  </p>

  <div class="footer">
    <div>
      <em>Generated by SIA Student Information System</em><br>
      Academic Session ${student.academicYear}
    </div>
    <div class="sign-box">
      Authorized Signatory<br>
      Office of Admissions
    </div>
  </div>

  <script>
    window.onload = function() {
      setTimeout(function() { window.print(); }, 250);
    };
  </script>
</body>
</html>
''';

    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }

  static void printIdCard({required Student student}) {
    final dobStr = _dateFmt.format(student.dateOfBirth);
    final bloodStr = student.bloodGroup.isNotEmpty ? student.bloodGroup : 'N/A';
    final rollStr = student.rollNumber != null && student.rollNumber!.isNotEmpty ? student.rollNumber! : '-';
    final admStr = student.admissionNumber.isNotEmpty ? student.admissionNumber : 'PROV';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Student ID Slip - ${student.fullName}</title>
  <style>
    @media print {
      body { margin: 0; padding: 10px; }
      .no-print { display: none; }
    }
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; display: flex; justify-content: center; padding: 20px; }
    .id-card {
      width: 320px;
      border: 2px solid #17324D;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);
    }
    .id-header {
      background: #17324D;
      color: white;
      text-align: center;
      padding: 10px 8px;
    }
    .id-header h2 { margin: 0; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px; }
    .id-header p { margin: 2px 0 0 0; font-size: 9px; opacity: 0.8; }
    .id-body { padding: 14px; background: white; text-align: center; }
    .photo-box {
      width: 72px;
      height: 84px;
      border: 1px dashed #94a3b8;
      border-radius: 6px;
      margin: 0 auto 10px auto;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #94a3b8;
      font-size: 10px;
      background: #f8fafc;
    }
    .student-name { font-size: 15px; font-weight: bold; color: #17324D; margin: 0 0 4px 0; }
    .class-badge {
      display: inline-block;
      background: #EFF6FF;
      color: #2563EB;
      font-size: 11px;
      font-weight: bold;
      padding: 2px 10px;
      border-radius: 10px;
      margin-bottom: 10px;
    }
    .data-table { width: 100%; border-collapse: collapse; font-size: 11px; text-align: left; }
    .data-table td { padding: 3px 4px; }
    .data-label { color: #5F6B7A; font-weight: 600; width: 40%; }
    .data-val { color: #172033; font-weight: bold; width: 60%; }
    .id-footer {
      background: #f1f5f9;
      padding: 6px 12px;
      font-size: 9px;
      color: #64748b;
      display: flex;
      justify-content: space-between;
      border-top: 1px solid #e2e8f0;
    }
  </style>
</head>
<body>
  <div class="id-card">
    <div class="id-header">
      <h2>${AppStrings.schoolShortName} • STUDENT ID</h2>
      <p>${AppStrings.schoolName}</p>
    </div>
    <div class="id-body">
      <div class="photo-box">PHOTO</div>
      <div class="student-name">${student.fullName}</div>
      <div class="class-badge">${student.classForAdmission}</div>
      <table class="data-table">
        <tr>
          <td class="data-label">Admission No:</td>
          <td class="data-val">$admStr</td>
        </tr>
        <tr>
          <td class="data-label">Roll Number:</td>
          <td class="data-val">$rollStr</td>
        </tr>
        <tr>
          <td class="data-label">Date of Birth:</td>
          <td class="data-val">$dobStr</td>
        </tr>
        <tr>
          <td class="data-label">Blood Group:</td>
          <td class="data-val" style="color: #dc2626;">$bloodStr</td>
        </tr>
        <tr>
          <td class="data-label">Parent:</td>
          <td class="data-val">${student.parentDetails.fatherName.isNotEmpty ? student.parentDetails.fatherName : student.parentDetails.motherName}</td>
        </tr>
        <tr>
          <td class="data-label">Emergency Tel:</td>
          <td class="data-val">${student.contactDetails.primaryContactNumber}</td>
        </tr>
      </table>
    </div>
    <div class="id-footer">
      <span>Session: ${student.academicYear}</span>
      <span>Principal's Sign</span>
    </div>
  </div>

  <script>
    window.onload = function() {
      setTimeout(function() { window.print(); }, 250);
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
