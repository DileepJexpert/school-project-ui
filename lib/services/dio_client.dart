import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'token_storage.dart';

class DioClient {
  static late Dio _dio;

  // Set at build time via:
  // flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api
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

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();

          final tenantId = prefs.getString('tenant_id');
          if (tenantId != null && tenantId.isNotEmpty) {
            options.headers['X-Tenant-ID'] = tenantId;
          } else {
            options.headers.remove('X-Tenant-ID');
          }

          final token = await TokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onResponse: (response, handler) => handler.next(response),
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final newToken = await TokenStorage.getToken();
              if (newToken != null && newToken.isNotEmpty) {
                error.requestOptions.headers['Authorization'] =
                    'Bearer $newToken';
              }
              try {
                final response = await _dio.fetch(error.requestOptions);
                return handler.resolve(response);
              } catch (_) {
                // Refresh worked but retry failed. Propagate the original error.
              }
            }
          }
          _handleError(error);
          return handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('[DIO] $obj'),
        ),
      );
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
        if (newRefresh != null) {
          await TokenStorage.saveRefreshToken(newRefresh);
        }
        return true;
      }
    } catch (e) {
      debugPrint('[DioClient] Token refresh failed: $e');
    }
    return false;
  }

  static Dio get instance => _dio;

  static Future<Response> get(String path,
      {Map<String, dynamic>? queryParams}) async {
    return _dio.get(path, queryParameters: queryParams);
  }

  static Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  static Future<Response> put(String path, {dynamic data}) async {
    return _dio.put(path, data: data);
  }

  static Future<Response> delete(String path,
      {Map<String, dynamic>? queryParams}) async {
    return _dio.delete(path, queryParameters: queryParams);
  }

  static void _handleError(DioException error) {
    if (kDebugMode) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          debugPrint('[DioClient Error] Connection timeout');
          break;
        case DioExceptionType.badResponse:
          debugPrint(
            '[DioClient Error] Server error: ${error.response?.statusCode}',
          );
          break;
        case DioExceptionType.cancel:
          debugPrint('[DioClient Error] Request cancelled');
          break;
        default:
          debugPrint('[DioClient Error] ${error.message}');
      }
    }
  }
}
