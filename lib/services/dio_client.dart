import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'token_storage.dart';

class DioClient {
  static late Dio _dio;

  // Set at build time via: flutter build web --dart-define=API_BASE_URL=https://your-app.koyeb.app/api
  // Falls back to localhost for local development.
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  /// Expose the base URL so AuthService can derive the platform URL from it.
  static String get baseUrl => _baseUrl;

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

    // Auth + tenant interceptor — injects X-Tenant-ID and Bearer token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();

          // Tenant header (always set)
          final tenantId = prefs.getString('tenant_id') ?? 'default';
          options.headers['X-Tenant-ID'] = tenantId;

          // Bearer token (when logged in) — from secure storage
          final token = await TokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (error, handler) async {
          // Auto-refresh on 401 Unauthorized
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              // Retry the original request with the new token
              final newToken = await TokenStorage.getToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              try {
                final response = await _dio.fetch(error.requestOptions);
                return handler.resolve(response);
              } catch (e) {
                // Refresh worked but retry failed — propagate original error
              }
            }
          }
          _handleError(error);
          return handler.next(error);
        },
      ),
    );

    // Logging interceptor — DEBUG BUILDS ONLY.
    // Request/response bodies contain passwords and bearer tokens;
    // they must never be logged in production.
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[DIO] $obj'),
      ));
    }
  }

  static Future<bool> _tryRefreshToken() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await Dio().post(
        '$_baseUrl/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      final token = response.data['token'] as String?;
      final newRefresh = response.data['refreshToken'] as String?;
      if (token != null) {
        await TokenStorage.saveToken(token);
        if (newRefresh != null) await TokenStorage.saveRefreshToken(newRefresh);
        return true;
      }
    } catch (e) {
      debugPrint('[DioClient] Token refresh failed: $e');
    }
    return false;
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
    debugPrint('[DioClient Error] $message');
  }
}
