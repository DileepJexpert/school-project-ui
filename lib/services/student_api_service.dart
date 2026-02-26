import '../models/student_model.dart';
import 'dio_client.dart';

class StudentApiService {
  static const _base = '/students';

  static Future<List<StudentModel>> getAllStudents() async {
    final response = await DioClient.get(_base);
    return (response.data as List)
        .map((e) => StudentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<StudentModel> getStudentById(String id) async {
    final response = await DioClient.get('$_base/$id');
    return StudentModel.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<List<StudentModel>> searchStudents(String name) async {
    final response =
        await DioClient.get('$_base/search', queryParams: {'name': name});
    return (response.data as List)
        .map((e) => StudentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
