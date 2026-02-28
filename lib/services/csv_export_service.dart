// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:intl/intl.dart';

import '../models/admission_data.dart';
import '../models/student_model.dart';

/// Builds CSV strings and triggers browser file-downloads via dart:html.
class CsvExportService {
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  // ── Students screen (StudentModel — simplified list) ──────────────────────

  static void exportStudents(List<StudentModel> students) {
    final buf = StringBuffer();
    buf.writeln(
        'Name,Admission No,Class,Academic Year,Roll No,Gender,Blood Group,Status');
    for (final s in students) {
      buf.writeln([
        _q(s.fullName),
        _q(s.admissionNumber ?? ''),
        _q(s.classForAdmission ?? ''),
        _q(s.academicYear ?? ''),
        _q(s.rollNumber ?? ''),
        _q(s.gender ?? ''),
        _q(s.bloodGroup ?? ''),
        _q(s.status),
      ].join(','));
    }
    _download(buf.toString(), 'students_${_today()}.csv');
  }

  // ── Admissions screen (Student — full model) ──────────────────────────────

  static void exportAdmissions(List<Student> students) {
    final buf = StringBuffer();
    buf.writeln([
      'Admission No', 'Name', 'Class', 'Academic Year',
      'Date of Admission', 'Date of Birth', 'Gender', 'Blood Group',
      'Father Name', 'Father Mobile', 'Mother Name', 'Mother Mobile',
      'Contact No', 'Status',
    ].join(','));
    for (final s in students) {
      buf.writeln([
        _q(s.admissionNumber),
        _q(s.fullName),
        _q(s.classForAdmission),
        _q(s.academicYear),
        _q(_dateFmt.format(s.dateOfAdmission)),
        _q(_dateFmt.format(s.dateOfBirth)),
        _q(s.gender),
        _q(s.bloodGroup),
        _q(s.parentDetails.fatherName),
        _q(s.parentDetails.fatherMobile),
        _q(s.parentDetails.motherName),
        _q(s.parentDetails.motherMobile),
        _q(s.contactDetails.primaryContactNumber),
        _q(s.status),
      ].join(','));
    }
    _download(buf.toString(), 'admissions_${_today()}.csv');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// RFC-4180 quoting: wrap in double-quotes if value contains comma/quote/newline.
  static String _q(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  static void _download(String content, String filename) {
    final blob = html.Blob([content], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
