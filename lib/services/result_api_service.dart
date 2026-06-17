import 'package:dio/dio.dart';

import '../models/result_models.dart';
import '../models/student_model.dart';
import 'dio_client.dart';

class ResultApiService {
  static const _base = '/results';

  // ── Students by class (for marks entry grid) ──────────────────────────

  static Future<List<StudentModel>> getStudentsByClass(
      String className, String academicYear) async {
    final resp = await DioClient.get('/students', queryParams: {
      'className': className,
      'academicYear': academicYear,
    });
    return (resp.data as List)
        .map((e) => StudentModel.fromJson(e as Map<String, dynamic>))
        .where((s) => s.status == 'ACTIVE')
        .toList()
      ..sort((a, b) {
        final ra = int.tryParse(a.rollNumber ?? '') ?? 999;
        final rb = int.tryParse(b.rollNumber ?? '') ?? 999;
        return ra.compareTo(rb);
      });
  }

  // ── Bulk marks entry ──────────────────────────────────────────────────

  static Future<List<StudentResult>> bulkSubmitResults({
    required String className,
    required String examType,
    required String academicYear,
    required String subject,
    required double maxMarks,
    required String enteredBy,
    required List<Map<String, dynamic>> entries,
  }) async {
    final resp = await DioClient.post('$_base/bulk', data: {
      'className': className,
      'examType': examType,
      'academicYear': academicYear,
      'subject': subject,
      'maxMarks': maxMarks,
      'enteredBy': enteredBy,
      'entries': entries,
    });
    return (resp.data as List)
        .map((e) => StudentResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Class result sheet ────────────────────────────────────────────────

  static Future<List<StudentResult>> getClassResultSheet(
      String className, String examType, String year) async {
    final resp = await DioClient.get(
      '$_base/class/$className/exam/$examType',
      queryParams: {'year': year},
    );
    return (resp.data as List)
        .map((e) => StudentResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Student report card ───────────────────────────────────────────────

  static Future<StudentReportCard> getStudentReportCard(
      String studentId, String year) async {
    final resp = await DioClient.get(
      '$_base/student/$studentId/report',
      queryParams: {'year': year},
    );
    return StudentReportCard.fromJson(resp.data as Map<String, dynamic>);
  }

  // ── All results for a student ─────────────────────────────────────────

  static Future<List<StudentResult>> getStudentResults(
      String studentId, String year) async {
    final resp = await DioClient.get(
      '$_base/student/$studentId',
      queryParams: {'year': year},
    );
    return (resp.data as List)
        .map((e) => StudentResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Class analytics ───────────────────────────────────────────────────

  static Future<ClassAnalytics> getClassAnalytics(
      String className, String year,
      {String? examType}) async {
    final resp = await DioClient.get(
      '$_base/class/$className/analytics',
      queryParams: {
        'year': year,
        if (examType != null) 'examType': examType,
      },
    );
    return ClassAnalytics.fromJson(resp.data as Map<String, dynamic>);
  }

  // ── Publish results ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> publishResults(
      String className, String examType, String year) async {
    final r = await DioClient.instance.put(
      '$_base/publish',
      queryParameters: {
        'className': className,
        'examType': examType,
        'year': year,
      },
    );
    return r.data as Map<String, dynamic>;
  }

  // ── Update / delete ───────────────────────────────────────────────────

  static Future<StudentResult> updateResult(
      String id, Map<String, dynamic> data) async {
    final resp = await DioClient.put('$_base/$id', data: data);
    return StudentResult.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<void> deleteResult(String id) async {
    await DioClient.delete('$_base/$id');
  }

  // ── Exam config ───────────────────────────────────────────────────────

  static Future<List<ExamConfig>> getExamConfigs(String year) async {
    final resp = await DioClient.get('$_base/exam-config',
        queryParams: {'year': year});
    return (resp.data as List)
        .map((e) => ExamConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<ExamConfig> saveExamConfig(ExamConfig config) async {
    final resp =
        await DioClient.post('$_base/exam-config', data: config.toJson());
    return ExamConfig.fromJson(resp.data as Map<String, dynamic>);
  }

  // ── Co-scholastic ─────────────────────────────────────────────────────

  static Future<List<CoscholasticAssessment>> getCoscholastic(
      String studentId, String year) async {
    final resp = await DioClient.get(
      '$_base/coscholastic/student/$studentId',
      queryParams: {'year': year},
    );
    return (resp.data as List)
        .map((e) =>
            CoscholasticAssessment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<CoscholasticAssessment> saveCoscholastic(
      Map<String, dynamic> data) async {
    final resp =
        await DioClient.post('$_base/coscholastic', data: data);
    return CoscholasticAssessment.fromJson(
        resp.data as Map<String, dynamic>);
  }

  // ── Report card PDF ───────────────────────────────────────────────────

  static Future<List<int>> downloadReportCardPdf(
      String studentId, String year) async {
    // baseUrl already ends in /api, so pass the path without an /api prefix.
    final resp = await DioClient.instance.get(
      '$_base/student/$studentId/report/pdf',
      queryParameters: {'year': year},
      options: Options(responseType: ResponseType.bytes),
    );
    return resp.data as List<int>;
  }
}
