import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';
import 'dio_client.dart';

/// Manages authentication state: login, logout, token storage, role checks.
class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _userKey = 'auth_user';

  AuthUser? _currentUser;
  String? _token;
  String? _refreshToken;

  AuthUser? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoggedIn => _currentUser != null && _token != null;

  // -- Initialization

  /// Load persisted auth state from SharedPreferences.
  /// Call this once in main() before runApp().
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      try {
        _currentUser = AuthUser.fromJson(jsonDecode(userJson));
      } catch (_) {
        await _clearStorage(prefs);
      }
    }
  }

  // -- Login

  /// Login for school-level users (SCHOOL_ADMIN, TEACHER, etc.).
  /// The current tenant_id in SharedPreferences must be set before calling this.
  Future<AuthUser> loginTenant(String email, String password) async {
    return _doLogin('/auth/login', email, password);
  }

  /// Login for SUPER_ADMIN users (uses /platform/auth/login, platform_db).
  Future<AuthUser> loginPlatform(String email, String password) async {
    // Platform login uses a different base URL prefix -- strip /api from baseUrl
    final dio = DioClient.instance;
    final response = await dio.post(
      // Remove /api prefix: platform path is relative to server root
      '${_platformBaseUrl()}/platform/auth/login',
      data: {'email': email, 'password': password},
    );
    return _handleLoginResponse(response);
  }

  Future<AuthUser> _doLogin(String path, String email, String password) async {
    final response = await DioClient.post(path, data: {
      'email': email,
      'password': password,
    });
    return _handleLoginResponse(response);
  }

  Future<AuthUser> _handleLoginResponse(Response response) async {
    final data = response.data as Map<String, dynamic>;
    final authResponse = AuthResponse.fromJson(data);

    _token = authResponse.token;
    _refreshToken = authResponse.refreshToken;
    _currentUser = authResponse.user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    if (_refreshToken != null) {
      await prefs.setString(_refreshTokenKey, _refreshToken!);
    }
    await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));

    // Persist tenant from the response (for future requests)
    if (_currentUser!.tenantId != null) {
      await prefs.setString('tenant_id', _currentUser!.tenantId!);
    }

    return _currentUser!;
  }

  // -- Refresh

  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;
    try {
      final response = await DioClient.post('/auth/refresh', data: {
        'refreshToken': _refreshToken,
      });
      final data = response.data as Map<String, dynamic>;
      _token = data['token'] as String;
      _refreshToken = data['refreshToken'] as String?;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
      if (_refreshToken != null) {
        await prefs.setString(_refreshTokenKey, _refreshToken!);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // -- Logout

  Future<void> logout() async {
    try {
      await DioClient.post('/auth/logout');
    } catch (_) {
      // Ignore -- logout is always local
    }
    _token = null;
    _refreshToken = null;
    _currentUser = null;

    final prefs = await SharedPreferences.getInstance();
    await _clearStorage(prefs);
  }

  Future<void> _clearStorage(SharedPreferences prefs) async {
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
  }

  // -- Permission helpers

  bool hasPermission(String permission) {
    if (_currentUser == null) return false;
    final perms = _currentUser!.permissions;
    return perms.contains('*') || perms.contains(permission);
  }

  bool hasRole(String role) => _currentUser?.role == role;

  bool hasAnyRole(List<String> roles) => roles.contains(_currentUser?.role);

  /// Returns true if the current user can see a given admin menu item.
  bool canAccessMenu(String menuLabel) {
    final role = _currentUser?.role;
    if (role == null) return false;
    return switch (role) {
      UserRole.superAdmin || UserRole.schoolAdmin => true,
      UserRole.teacher => const {
          'Overview', 'Students', 'Attendance', 'Timetable', 'Results',
          'Notifications', 'Discipline', 'Chat', 'Homework', 'Video Tutorials'
        }.contains(menuLabel),
      UserRole.accountant => const {
          'Overview', 'Students', 'Fees', 'Expenses', 'Reports',
          'HR & Staff', 'Certificates'
        }.contains(menuLabel),
      UserRole.transportManager => const {
          'Overview', 'Students', 'Transport'
        }.contains(menuLabel),
      UserRole.student || UserRole.parent => const {
          'Overview'
        }.contains(menuLabel),
      _ => false,
    };
  }

  // -- Helpers

  String _platformBaseUrl() {
    // Strip /api suffix from base URL to get the server root
    final base = DioClient.baseUrl;
    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    return base;
  }
}
