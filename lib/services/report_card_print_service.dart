// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../models/result_models.dart';

/// Service generating official CBSE-compliant Report Cards / Marksheets
/// with browser-native printing and PDF export via Blob HTML.
class ReportCardPrintService {
  static void printReportCard({
    required StudentReportCard card,
    String schoolName = 'Springdale Public School',
    String schoolAffiliation = 'Affiliated to CBSE, New Delhi (Affiliation No: 1930245)',
    String schoolAddress = 'Sector 4, Dwarka, New Delhi - 110075 | Tel: +91 11 2808 0000',
  }) {
    final examTypes = <String>{};
    for (final s in card.subjects) {
      examTypes.addAll(s.examResults.keys);
    }
    final sortedExams = examTypes.toList()..sort();

    final examHeadersHtml = sortedExams.map((et) {
      final label = et.replaceAll('_', ' ');
      return '<th style="text-align: center; border: 1px solid #cbd5e1; padding: 6px 8px; font-size: 11px;">$label</th>';
    }).join('');

    final subjectRowsHtml = card.subjects.map((sub) {
      final examMarksHtml = sortedExams.map((et) {
        final res = sub.examResults[et];
        if (res == null) return '<td style="text-align: center; border: 1px solid #cbd5e1; padding: 6px 8px;">—</td>';
        return '<td style="text-align: center; border: 1px solid #cbd5e1; padding: 6px 8px; font-size: 12px;">'
            '${res.marksObtained.toStringAsFixed(0)}/${res.maxMarks.toStringAsFixed(0)} '
            '<span style="font-weight: bold; color: #1e3a8a;">(${res.grade})</span></td>';
      }).join('');

      final isPass = sub.weightedPercentage >= 33;
      final passColor = isPass ? '#059669' : '#dc2626';

      return '''
      <tr>
        <td style="border: 1px solid #cbd5e1; padding: 6px 10px; font-weight: 600; font-size: 12px;">${sub.subject}</td>
        $examMarksHtml
        <td style="text-align: center; border: 1px solid #cbd5e1; padding: 6px 8px; font-weight: bold; color: $passColor; font-size: 12px;">
          ${sub.weightedPercentage.toStringAsFixed(1)}%
        </td>
        <td style="text-align: center; border: 1px solid #cbd5e1; padding: 6px 8px; font-weight: bold; font-size: 12px; color: #17324D;">
          ${sub.predictedGrade}
        </td>
      </tr>
      ''';
    }).join('');

    // Co-scholastic sections
    String coscholasticHtml = '';
    if (card.coscholasticTerm1 != null || card.coscholasticTerm2 != null) {
      final term1Rows = card.coscholasticTerm1?.areas.map((a) =>
        '<tr><td style="border: 1px solid #cbd5e1; padding: 4px 8px; font-size: 11px;">${a.name}</td>'
        '<td style="text-align: center; border: 1px solid #cbd5e1; padding: 4px 8px; font-weight: bold; font-size: 11px;">${a.grade}</td></tr>'
      ).join('') ?? '';

      final term2Rows = card.coscholasticTerm2?.areas.map((a) =>
        '<tr><td style="border: 1px solid #cbd5e1; padding: 4px 8px; font-size: 11px;">${a.name}</td>'
        '<td style="text-align: center; border: 1px solid #cbd5e1; padding: 4px 8px; font-weight: bold; font-size: 11px;">${a.grade}</td></tr>'
      ).join('') ?? '';

      coscholasticHtml = '''
      <div style="margin-top: 14px;">
        <h4 style="margin: 0 0 6px 0; color: #17324D; font-size: 13px; text-transform: uppercase;">Co-Scholastic & Life Skills Evaluation</h4>
        <div style="display: flex; gap: 16px;">
          ${term1Rows.isNotEmpty ? '''
          <div style="flex: 1;">
            <table style="width: 100%; border-collapse: collapse; margin-top: 4px;">
              <tr style="background: #f1f5f9;"><th colspan="2" style="border: 1px solid #cbd5e1; padding: 4px; font-size: 11px; text-align: left;">Term 1 Assessment</th></tr>
              $term1Rows
            </table>
          </div>''' : ''}
          ${term2Rows.isNotEmpty ? '''
          <div style="flex: 1;">
            <table style="width: 100%; border-collapse: collapse; margin-top: 4px;">
              <tr style="background: #f1f5f9;"><th colspan="2" style="border: 1px solid #cbd5e1; padding: 4px; font-size: 11px; text-align: left;">Term 2 Assessment</th></tr>
              $term2Rows
            </table>
          </div>''' : ''}
        </div>
      </div>
      ''';
    }

    final remarks = card.overallGrade.startsWith('A')
        ? 'Outstanding academic performance and exemplary conduct.'
        : card.overallGrade.startsWith('B')
            ? 'Very good performance with consistent effort across subjects.'
            : card.overallGrade.startsWith('C')
                ? 'Satisfactory performance. Regular practice recommended in weaker subjects.'
                : 'Needs academic support and focused improvement.';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>CBSE Report Card - ${card.studentName}</title>
  <style>
    @media print {
      body { margin: 0; padding: 12px; font-family: 'Segoe UI', Arial, sans-serif; color: #172033; }
      .no-print { display: none; }
      @page { size: A4 portrait; margin: 10mm; }
    }
    body { font-family: 'Segoe UI', Arial, sans-serif; padding: 24px; max-width: 800px; margin: auto; border: 2px solid #17324D; border-radius: 6px; }
    .school-header { text-align: center; border-bottom: 2px solid #17324D; padding-bottom: 10px; margin-bottom: 12px; }
    .school-name { font-size: 22px; font-weight: bold; color: #17324D; text-transform: uppercase; margin: 0; letter-spacing: 0.5px; }
    .school-meta { font-size: 11px; color: #475569; margin: 2px 0; }
    .report-title { display: inline-block; background: #17324D; color: white; padding: 4px 18px; border-radius: 12px; font-size: 13px; font-weight: bold; margin-top: 6px; letter-spacing: 0.5px; }
    .student-info-table { width: 100%; border-collapse: collapse; margin-bottom: 12px; font-size: 12px; }
    .student-info-table td { padding: 4px 8px; }
    .label { color: #64748b; font-weight: 600; width: 20%; }
    .val { color: #0f172a; font-weight: bold; width: 30%; }
    .marks-table { width: 100%; border-collapse: collapse; margin-top: 8px; }
    .marks-table th { background: #17324D; color: white; padding: 6px 8px; font-size: 11px; text-transform: uppercase; }
    .summary-strip { display: flex; justify-content: space-between; background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 6px; padding: 10px 16px; margin-top: 14px; }
    .summary-item { text-align: center; }
    .summary-item .title { font-size: 11px; color: #64748b; font-weight: 600; }
    .summary-item .score { font-size: 18px; font-weight: bold; color: #17324D; }
    .signatures { display: flex; justify-content: space-between; margin-top: 40px; padding: 0 10px; }
    .sig-block { text-align: center; border-top: 1px solid #334155; width: 160px; padding-top: 6px; font-size: 12px; color: #334155; font-weight: 600; }
  </style>
</head>
<body>
  <div class="school-header">
    <div class="school-name">$schoolName</div>
    <div class="school-meta">$schoolAffiliation</div>
    <div class="school-meta">$schoolAddress</div>
    <div class="report-title">ANNUAL PROGRESS REPORT CARD · ${card.academicYear}</div>
  </div>

  <table class="student-info-table">
    <tr>
      <td class="label">Student Name:</td>
      <td class="val">${card.studentName}</td>
      <td class="label">Roll Number:</td>
      <td class="val">${card.rollNumber ?? '—'}</td>
    </tr>
    <tr>
      <td class="label">Class & Section:</td>
      <td class="val">${card.className}</td>
      <td class="label">Student ID:</td>
      <td class="val">${card.studentId}</td>
    </tr>
    <tr>
      <td class="label">Academic Year:</td>
      <td class="val">${card.academicYear}</td>
      <td class="label">Class Rank:</td>
      <td class="val">#${card.classRank}</td>
    </tr>
  </table>

  <h4 style="margin: 8px 0 4px 0; color: #17324D; font-size: 13px; text-transform: uppercase;">Part 1: Scholastic Performance</h4>
  <table class="marks-table">
    <thead>
      <tr>
        <th style="text-align: left; border: 1px solid #cbd5e1; padding: 6px 10px;">Subject</th>
        $examHeadersHtml
        <th style="border: 1px solid #cbd5e1; padding: 6px 8px;">Cumulative %</th>
        <th style="border: 1px solid #cbd5e1; padding: 6px 8px;">Grade</th>
      </tr>
    </thead>
    <tbody>
      $subjectRowsHtml
    </tbody>
  </table>

  <div class="summary-strip">
    <div class="summary-item">
      <div class="title">Cumulative Aggregate</div>
      <div class="score">${card.cumulativePercentage.toStringAsFixed(1)}%</div>
    </div>
    <div class="summary-item">
      <div class="title">Overall Grade</div>
      <div class="score" style="color: #059669;">${card.overallGrade}</div>
    </div>
    <div class="summary-item">
      <div class="title">Grade Point Average</div>
      <div class="score">${card.overallGradePoint.toStringAsFixed(2)}</div>
    </div>
    <div class="summary-item">
      <div class="title">Result Status</div>
      <div class="score" style="color: ${card.overallGrade != 'E' && card.overallGrade != 'F' ? '#059669' : '#dc2626'};">
        ${card.overallGrade != 'E' && card.overallGrade != 'F' ? 'PASSED & PROMOTED' : 'DETENTION / RE-TEST'}
      </div>
    </div>
  </div>

  $coscholasticHtml

  <div style="margin-top: 14px; border: 1px dashed #cbd5e1; border-radius: 6px; padding: 8px 12px; font-size: 12px; background: #fafafa;">
    <strong>Class Teacher's Remarks:</strong> $remarks
  </div>

  <div class="signatures">
    <div class="sig-block">Class Teacher</div>
    <div class="sig-block">Exam In-Charge</div>
    <div class="sig-block">Principal / Headmaster</div>
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
