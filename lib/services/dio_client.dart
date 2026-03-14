import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DioClient {
  static late Dio _dio;

  // Set at build time via: flutter build web --dart-define=API_BASE_URL=https://your-app.koyeb.app/api
  // Falls back to localhost for local development.
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  DioClient._();

  static void initialize() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Multi-tenant interceptor — injects X-Tenant-ID header from SharedPreferences
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final tenantId = prefs.getString('tenant_id') ?? 'default';
          options.headers['X-Tenant-ID'] = tenantId;
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (error, handler) {
          _handleError(error);
          return handler.next(error);
        },
      ),
    );

    // Logging interceptor (remove in production)
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[DIO] $obj'),
    ));
  }

  static Dio get instance => _dio;

  // --- Generic API Methods ---

  static Future<Response> get(String path, {Map<String, dynamic>? queryParams}) async {
    return await _dio.get(path, queryParameters: queryParams);
  }

  static Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  static Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  static Future<Response> delete(String path,
      {Map<String, dynamic>? queryParams}) async {
    return await _dio.delete(path, queryParameters: queryParams);
  }

  static Future<Response> uploadFile(String path, String filePath, String fieldName) async {
    final formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath),
    });
    return await _dio.post(path, data: formData);
  }

  // --- Error Handler ---

  static void _handleError(DioException error) {
    String message;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        message = 'Connection timed out. Please check your internet.';
        break;
      case DioExceptionType.receiveTimeout:
        message = 'Server took too long to respond.';
        break;
      case DioExceptionType.badResponse:
        message = 'Server error: ${error.response?.statusCode}';
        break;
      case DioExceptionType.connectionError:
        message = 'Could not connect to server. Is it running?';
        break;
      default:
        message = 'An unexpected error occurred.';
    }
    print('[DioClient Error] $message');
  }
}
