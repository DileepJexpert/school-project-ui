import 'package:dio/dio.dart';

import '../models/fee_models.dart';
import 'dio_client.dart';

class FeeApiService {
  static const _profileBase = '/student-fee-profiles';
  static const _feeBase = '/fees';
  static const _structureBase = '/feestructures';
  static const _expenseBase = '/expenses';

  // ── Student Fee Profile ──────────────────────────────────────────────────
  static Future<StudentFeeProfile> getStudentFeeProfile(String studentId) async {
    final response = await DioClient.get('$_profileBase/$studentId');
    return StudentFeeProfile.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<List<StudentFeeProfile>> searchStudents({
    String? name,
    String? className,
    String? rollNumber,
  }) async {
    final params = <String, dynamic>{
      if (name != null && name.isNotEmpty) 'name': name,
      if (className != null && className.isNotEmpty) 'className': className,
      if (rollNumber != null && rollNumber.isNotEmpty) 'rollNumber': rollNumber,
    };
    final response = await DioClient.get('$_feeBase/search', queryParams: params);
    return (response.data as List)
        .map((e) => StudentFeeProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Fee Collection ───────────────────────────────────────────────────────
  static Future<PaymentRecord> collectFee(FeePaymentRequest request) async {
    final response = await DioClient.post('$_feeBase/collect', data: request.toJson());
    return PaymentRecord.fromJson(response.data as Map<String, dynamic>);
  }

  /// Returns all students with outstanding dues (dueFees > 0), sorted highest first.
  static Future<List<StudentFeeProfile>> getOutstandingDues() async {
    final response = await DioClient.get('$_feeBase/dues');
    return (response.data as List)
        .map((e) => StudentFeeProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Fee Structure ────────────────────────────────────────────────────────
  // Backend GET /api/feestructures requires year as a mandatory query param
  static Future<List<FeeStructure>> getFeeStructures({String year = '2025-2026'}) async {
    final response = await DioClient.get(
      _structureBase,
      queryParams: {'year': year},
    );
    return (response.data as List)
        .map((e) => FeeStructure.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Backend POST /api/feestructures expects List<FeeStructure> (array)
  static Future<void> saveFeeStructure(FeeStructure structure) async {
    await DioClient.post(_structureBase, data: [structure.toJson()]);
  }

  // Backend has no individual PUT — re-save via POST list
  static Future<void> updateFeeStructure(String id, FeeStructure structure) async {
    await DioClient.post(_structureBase, data: [structure.toJson()]);
  }

  static Future<void> deleteFeeStructure(String id) async {
    await DioClient.delete('$_structureBase/$id');
  }

  // ── Dashboard Analytics ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDashboardAnalytics() async {
    final response = await DioClient.get('/reports/dashboard-analytics');
    return response.data as Map<String, dynamic>;
  }

  // ── School Summary (Reports Screen) ──────────────────────────────────────
  static Future<SchoolSummary> getSchoolSummary() async {
    final response = await DioClient.get('/reports/school-summary');
    return SchoolSummary.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Fee Reports ──────────────────────────────────────────────────────────
  static Future<FeeReportResponse> getFeeReport({
    String? startDate,
    String? endDate,
    String? className,
    String? paymentMode,
  }) async {
    final params = <String, dynamic>{
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (className != null && className.isNotEmpty) 'className': className,
      if (paymentMode != null && paymentMode.isNotEmpty) 'paymentMode': paymentMode,
    };
    final response = await DioClient.get(
      '/reports/fees/report-summary',
      queryParams: params,
    );
    return FeeReportResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Expenses ─────────────────────────────────────────────────────────────
  /// Returns all expenses.  Pass [from] and [to] (ISO date strings, e.g.
  /// "2024-06-01") to filter by date range for monthly reports.
  static Future<List<Expense>> getExpenses({String? from, String? to}) async {
    final params = <String, dynamic>{
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    };
    final response = await DioClient.get(
      _expenseBase,
      queryParams: params.isNotEmpty ? params : null,
    );
    return (response.data as List)
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> addExpense(Expense expense) async {
    await DioClient.post(_expenseBase, data: expense.toJson());
  }

  static Future<void> deleteExpense(String id) async {
    await DioClient.delete('$_expenseBase/$id');
  }

  // ── Receipt Downloads ───────────────────────────────────────────────────
  static Future<List<int>> downloadReceipt(String feeRecordId) async {
    final r = await DioClient.instance.get(
      '$_feeBase/receipt/$feeRecordId',
      options: Options(responseType: ResponseType.bytes),
    );
    return r.data as List<int>;
  }

  static Future<List<int>> downloadBulkReceipts(String className, String academicYear) async {
    final r = await DioClient.instance.get(
      '$_feeBase/receipts/bulk',
      queryParameters: {'className': className, 'academicYear': academicYear},
      options: Options(responseType: ResponseType.bytes),
    );
    return r.data as List<int>;
  }
}
