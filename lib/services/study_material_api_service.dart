import 'dio_client.dart';

class StudyMaterialApiService {
  static const _base = '/study-materials';

  static Future<List<Map<String, dynamic>>> getAllMaterials() async {
    final response = await DioClient.get(_base);
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getMaterialsByClass(String className) async {
    final response = await DioClient.get('$_base/class/$className');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getMaterialsByClassAndSubject(String className, String subject) async {
    final response = await DioClient.get('$_base/class/$className/subject/$subject');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createMaterial(Map<String, dynamic> data) async {
    final response = await DioClient.post(_base, data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateMaterial(String id, Map<String, dynamic> data) async {
    final response = await DioClient.put('$_base/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<void> deleteMaterial(String id) async {
    await DioClient.delete('$_base/$id');
  }

  // Student portal
  static Future<List<Map<String, dynamic>>> getMyMaterials({String? subject}) async {
    final params = <String, dynamic>{};
    if (subject != null) params['subject'] = subject;
    final response = await DioClient.get('/student-portal/study-materials', queryParams: params.isNotEmpty ? params : null);
    return (response.data as List).cast<Map<String, dynamic>>();
  }
}
