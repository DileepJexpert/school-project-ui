import 'dio_client.dart';

class QuizApiService {
  static const _base = '/quizzes';

  // Admin/Teacher
  static Future<List<Map<String, dynamic>>> getAllQuizzes() async {
    final response = await DioClient.get(_base);
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> getQuiz(String id) async {
    final response = await DioClient.get('$_base/$id');
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createQuiz(Map<String, dynamic> data) async {
    final response = await DioClient.post(_base, data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateQuiz(String id, Map<String, dynamic> data) async {
    final response = await DioClient.put('$_base/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<void> publishQuiz(String id) async {
    await DioClient.put('$_base/$id/publish');
  }

  static Future<void> deleteQuiz(String id) async {
    await DioClient.delete('$_base/$id');
  }

  static Future<List<Map<String, dynamic>>> getQuizAttempts(String quizId) async {
    final response = await DioClient.get('$_base/$quizId/attempts');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  // Student portal
  static Future<List<Map<String, dynamic>>> getMyQuizzes({String? subject}) async {
    final params = <String, dynamic>{};
    if (subject != null) params['subject'] = subject;
    final response = await DioClient.get('/student-portal/quizzes', queryParams: params.isNotEmpty ? params : null);
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> submitAttempt(String quizId, Map<String, dynamic> data) async {
    final response = await DioClient.post('/student-portal/quizzes/$quizId/attempt', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getMyAttempts() async {
    final response = await DioClient.get('/student-portal/quiz-attempts');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> getMyProgress() async {
    final response = await DioClient.get('/student-portal/quiz-progress');
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> hasAttempted(String quizId) async {
    final response = await DioClient.get('/student-portal/quizzes/$quizId/attempted');
    return response.data as Map<String, dynamic>;
  }
}
