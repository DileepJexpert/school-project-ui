import 'dio_client.dart';

class StaffApiService {
  // ── Staff CRUD ──
  static const _staff = '/staff';

  static Future<Map<String, dynamic>> getStaffDashboard() async {
    final response = await DioClient.get('$_staff/dashboard');
    return response.data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getAllStaff() async {
    final response = await DioClient.get(_staff);
    return response.data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getStaffById(String id) async {
    final response = await DioClient.get('$_staff/$id');
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createStaff(
      Map<String, dynamic> data) async {
    final response = await DioClient.post(_staff, data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateStaff(
      String id, Map<String, dynamic> data) async {
    final response = await DioClient.put('$_staff/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<void> deleteStaff(String id) async {
    await DioClient.delete('$_staff/$id');
  }

  // ── Leave Management ──
  static const _leave = '/leave';

  static Future<List<dynamic>> getLeaves({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final response = await DioClient.get(
      _leave,
      queryParams: params.isNotEmpty ? params : null,
    );
    return response.data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> applyLeave(
      Map<String, dynamic> data) async {
    final response = await DioClient.post('$_leave/apply', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> approveLeave(
      String id, String action) async {
    final response = await DioClient.put(
      '$_leave/$id/approve',
      data: {'action': action},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Salary ──
  static const _salary = '/salary';

  static Future<List<dynamic>> getSalaries(
      {required int month, required int year}) async {
    final response = await DioClient.get(
      _salary,
      queryParams: {'month': month, 'year': year},
    );
    return response.data as List<dynamic>;
  }

  static Future<List<dynamic>> generateSalaries(
      {required int month, required int year}) async {
    final response = await DioClient.post(
      '$_salary/generate',
      data: {'month': month, 'year': year},
    );
    return response.data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> markSalaryPaid(String id) async {
    final response = await DioClient.put('$_salary/$id/pay');
    return response.data as Map<String, dynamic>;
  }

  // ── Staff Attendance ──
  static const _staffAttendance = '/staff-attendance';

  static Future<List<dynamic>> getStaffAttendanceByDate(String date) async {
    final response = await DioClient.get(
      '$_staffAttendance/date',
      queryParams: {'date': date},
    );
    return response.data as List<dynamic>;
  }

  static Future<void> markStaffAttendance(
      List<Map<String, dynamic>> records) async {
    await DioClient.post('$_staffAttendance/mark', data: records);
  }
}
