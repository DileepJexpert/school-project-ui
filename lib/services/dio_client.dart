import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'token_storage.dart';

class DioClient {
  static late Dio _dio;

  static const String _defaultProdUrl =
      'https://school-api-staging.todileepmaurya.workers.dev/api';

  // Set at build time via: flutter build web --dart-define=API_BASE_URL=https://your-app.koyeb.app/api
  // Falls back to production worker in release mode, localhost for local debug.
  static const String _buildBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultProdUrl,
  );
  static const String _publicTenantId = String.fromEnvironment(
    'PUBLIC_TENANT_ID', defaultValue: 'default',
  );
  static String _baseUrl = _buildBaseUrl;

  /// Expose the base URL so AuthService can derive the platform URL from it.
  static String get baseUrl => _baseUrl;

  DioClient._();

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('api_base_url');
    if (saved != null) {
      final isLocalhost =
          saved.contains('localhost') || saved.contains('127.0.0.1');
      if (isLocalhost) {
        await prefs.remove('api_base_url');
        _baseUrl = _buildBaseUrl;
      } else {
        try {
          _baseUrl = _validatedBaseUrl(saved);
        } on FormatException {
          await prefs.remove('api_base_url');
          _baseUrl = _buildBaseUrl;
        }
      }
    } else {
      _baseUrl = _buildBaseUrl;
    }
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
          final tenantId = prefs.getString('tenant_id') ?? _publicTenantId;
          options.headers['X-Tenant-ID'] = tenantId;

          // Normalize paths so they always resolve properly under /api without duplicating
          if (_baseUrl.endsWith('/api') || _baseUrl.endsWith('/api/')) {
            if (options.path.startsWith('/api/')) {
              options.path = options.path.substring(4);
            }
          } else {
            if (options.path.startsWith('/') &&
                !options.path.startsWith('/api') &&
                !options.path.startsWith('/platform')) {
              options.path = '/api${options.path}';
            }
          }


          // Never send stale Authorization header on login endpoints
          if (!options.path.endsWith('/auth/login')) {
            final token = await TokenStorage.getToken() ?? prefs.getString('auth_token');
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (error, handler) async {
          // Auto-refresh on 401 Unauthorized
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['retriedAfterRefresh'] != true &&
              !error.requestOptions.path.endsWith('/auth/refresh') &&
              !error.requestOptions.path.endsWith('/auth/login')) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              // Retry the original request with the new token
              final newToken = await TokenStorage.getToken() ?? prefs.getString('auth_token');
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              error.requestOptions.extra['retriedAfterRefresh'] = true;
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

  }

  static String _validatedBaseUrl(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    final url = Uri.tryParse(normalized);
    if (url == null || !url.hasAuthority ||
        (url.scheme != 'http' && url.scheme != 'https') ||
        !url.path.endsWith('/api') || url.hasQuery || url.hasFragment) {
      throw FormatException('Enter a full http(s) URL ending in /api');
    }
    return normalized;
  }

  static Future<void> setBaseUrl(String value) async {
    final url = _validatedBaseUrl(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', url);
    _baseUrl = url;
    _dio.options.baseUrl = url;
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
    } catch (_) {}
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
    print('[DioClient Error] $message');
  }
}
