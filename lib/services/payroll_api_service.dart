import 'dio_client.dart';

class PayrollApiService {
  static const _base = '/payroll';

  static Future<List<dynamic>> generatePayroll(String month, int year) async {
    final r = await DioClient.post('$_base/generate',
        data: {'month': month, 'year': year});
    return r.data as List;
  }

  static Future<List<dynamic>> getByMonth(String month, int year) async {
    final r = await DioClient.get(_base,
        queryParams: {'month': month, 'year': year.toString()});
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getPayroll(String id) async {
    final r = await DioClient.get('$_base/$id');
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updatePayroll(
      String id, Map<String, dynamic> data) async {
    final r = await DioClient.put('$_base/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<void> processPayroll(String id) async {
    await DioClient.put('$_base/$id/process');
  }

  static Future<void> markAsPaid(String id) async {
    await DioClient.put('$_base/$id/pay');
  }

  static Future<List<dynamic>> getStaffPayroll(String userId) async {
    final r = await DioClient.get('$_base/staff/$userId');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getStats(String month, int year) async {
    final r = await DioClient.get('$_base/stats',
        queryParams: {'month': month, 'year': year.toString()});
    return r.data as Map<String, dynamic>;
  }
}
