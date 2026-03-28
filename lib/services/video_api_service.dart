import 'package:dio/dio.dart';
import 'dio_client.dart';

class VideoApiService {
  static const _base = '/videos';

  /// Get all videos (admin/teacher). Optional className and subject filters.
  static Future<List<dynamic>> getAllVideos(
      {String? className, String? subject}) async {
    final params = <String, dynamic>{};
    if (className != null && className.isNotEmpty) {
      params['className'] = className;
    }
    if (subject != null && subject.isNotEmpty) {
      params['subject'] = subject;
    }
    final response = await DioClient.get(
      _base,
      queryParams: params.isNotEmpty ? params : null,
    );
    return response.data as List<dynamic>;
  }

  /// Get videos for the logged-in student
  static Future<List<dynamic>> getMyVideos() async {
    final response = await DioClient.get('/student-portal/videos');
    return response.data as List<dynamic>;
  }

  /// Upload a video (multipart form)
  static Future<Map<String, dynamic>> uploadVideo({
    required List<int> fileBytes,
    required String fileName,
    required String title,
    required String subject,
    required String className,
    String? description,
    String? chapter,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      'title': title,
      'subject': subject,
      'className': className,
      if (description != null) 'description': description,
      if (chapter != null) 'chapter': chapter,
    });
    final response = await DioClient.instance.post(
      '$_base',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Delete a video
  static Future<void> deleteVideo(String id) async {
    await DioClient.delete('$_base/$id');
  }

  /// Get stream URL for a video
  static String getStreamUrl(String videoId) {
    return '${DioClient.baseUrl}/videos/$videoId/stream';
  }
}
