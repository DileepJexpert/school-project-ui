import 'dio_client.dart';

class LibraryApiService {
  static const _base = '/library';

  // Books
  static Future<List<Map<String, dynamic>>> getAllBooks() async {
    final response = await DioClient.get('$_base/books');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    final response =
        await DioClient.get('$_base/books/search', queryParams: {'q': query});
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> addBook(
      Map<String, dynamic> data) async {
    final response = await DioClient.post('$_base/books', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateBook(
      String id, Map<String, dynamic> data) async {
    final response = await DioClient.put('$_base/books/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<void> deleteBook(String id) async {
    await DioClient.delete('$_base/books/$id');
  }

  // Issues
  static Future<Map<String, dynamic>> issueBook(
      Map<String, dynamic> data) async {
    final response = await DioClient.post('$_base/issues', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> returnBook(String issueId) async {
    final response = await DioClient.put('$_base/issues/$issueId/return');
    return response.data as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getStudentIssues(
      String studentId) async {
    final response =
        await DioClient.get('$_base/issues/student/$studentId');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getOverdueBooks() async {
    final response = await DioClient.get('$_base/issues/overdue');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> getLibraryStats() async {
    final response = await DioClient.get('$_base/stats');
    return response.data as Map<String, dynamic>;
  }

  // Student portal
  static Future<List<Map<String, dynamic>>> getMyBooks() async {
    final response = await DioClient.get('/student-portal/library/my-books');
    return (response.data as List).cast<Map<String, dynamic>>();
  }
}
