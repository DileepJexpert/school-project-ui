import 'dio_client.dart';

class CertificateApiService {
  static const _base = '/certificates';

  static Future<Map<String, dynamic>> generateCertificate(
      Map<String, dynamic> data) async {
    final response = await DioClient.post('$_base/generate', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getStudentCertificates(
      String studentId) async {
    final response = await DioClient.get('$_base/student/$studentId');
    return response.data as List<dynamic>;
  }

  static Future<List<dynamic>> getByType(String type) async {
    final response = await DioClient.get('$_base/type/$type');
    return response.data as List<dynamic>;
  }

  static Future<List<dynamic>> getAllCertificates() async {
    final response = await DioClient.get(_base);
    return response.data as List<dynamic>;
  }
}
