// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../models/timetable_model.dart';

/// Handles browser-native printable Class Timetables and Schedule Matrices.
class TimetablePrintService {
  static void printClassTimetable({
    required String className,
    required String academicYear,
    required List<TimetableModel> schedule,
    String schoolName = 'Springdale Public School',
  }) {
    const days = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY'
    ];

    final Map<String, TimetableModel> dayMap = {
      for (final s in schedule) s.dayOfWeek.toUpperCase(): s,
    };

    // Calculate maximum periods across any day
    int maxPeriods = 8;
    for (final s in schedule) {
      if (s.periods.length > maxPeriods) {
        maxPeriods = s.periods.length;
      }
    }

    final headersHtml = List.generate(maxPeriods, (i) {
      return '<th style="border: 1px solid #cbd5e1; padding: 6px; text-align: center; font-size: 11px;">Period ${i + 1}</th>';
    }).join('');

    final rowsHtml = days.map((day) {
      final entry = dayMap[day];
      final cellsHtml = List.generate(maxPeriods, (i) {
        if (entry == null || i >= entry.periods.length) {
          return '<td style="border: 1px solid #cbd5e1; padding: 6px; text-align: center; color: #94a3b8; font-size: 11px;">—</td>';
        }
        final p = entry.periods[i];
        return '''
        <td style="border: 1px solid #cbd5e1; padding: 6px; font-size: 11px; text-align: center; vertical-align: top;">
          <div style="font-weight: bold; color: #17324D;">${p.subject}</div>
          <div style="color: #64748b; font-size: 10px;">${p.teacherName}</div>
          <div style="color: #059669; font-size: 9px; margin-top: 2px;">${p.startTime} - ${p.endTime}</div>
        </td>
        ''';
      }).join('');

      return '''
      <tr>
        <td style="border: 1px solid #cbd5e1; padding: 8px 10px; font-weight: bold; background: #f8fafc; font-size: 11px; color: #17324D;">
          $day
        </td>
        $cellsHtml
      </tr>
      ''';
    }).join('');

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Class Timetable - $className</title>
  <style>
    @media print {
      body { margin: 0; padding: 12px; font-family: 'Segoe UI', Arial, sans-serif; }
      .no-print { display: none; }
      @page { size: A4 landscape; margin: 10mm; }
    }
    body { font-family: 'Segoe UI', Arial, sans-serif; padding: 20px; color: #172033; background: white; }
    .header { text-align: center; border-bottom: 2px solid #17324D; padding-bottom: 8px; margin-bottom: 12px; }
    .school-name { font-size: 20px; font-weight: bold; color: #17324D; text-transform: uppercase; margin: 0; }
    .sub { font-size: 12px; color: #475569; margin-top: 2px; }
    .badge { display: inline-block; background: #17324D; color: white; padding: 4px 14px; border-radius: 12px; font-size: 12px; font-weight: bold; margin-top: 6px; }
    .matrix-table { width: 100%; border-collapse: collapse; margin-top: 12px; table-layout: fixed; }
    .matrix-table th { background: #17324D; color: white; text-transform: uppercase; font-size: 11px; }
    .footer { display: flex; justify-content: space-between; margin-top: 36px; padding: 0 10px; font-size: 11px; font-weight: bold; color: #334155; }
    .sig-line { width: 150px; text-align: center; border-top: 1px solid #334155; padding-top: 4px; }
  </style>
</head>
<body>
  <div class="header">
    <div class="school-name">$schoolName</div>
    <div class="sub">Official Academic Schedule Matrix · Academic Year $academicYear</div>
    <div class="badge">CLASS SCHEDULE: $className</div>
  </div>

  <table class="matrix-table">
    <thead>
      <tr>
        <th style="border: 1px solid #cbd5e1; padding: 6px; width: 100px;">Day</th>
        $headersHtml
      </tr>
    </thead>
    <tbody>
      $rowsHtml
    </tbody>
  </table>

  <div class="footer">
    <div class="sig-line">Class Teacher</div>
    <div class="sig-line">Time Table Coordinator</div>
    <div class="sig-line">Principal / Vice-Principal</div>
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
