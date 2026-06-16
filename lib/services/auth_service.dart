import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';
import 'dio_client.dart';
import 'token_storage.dart';

/// Manages authentication state: login, logout, token storage, role checks.
/// Tokens live in platform secure storage (TokenStorage); only non-secret
/// data (user profile, tenant id) is kept in SharedPreferences.
class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const _userKey = 'auth_user';

  AuthUser? _currentUser;
  String? _token;
  String? _refreshToken;
  bool _mustChangePassword = false;

  AuthUser? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoggedIn => _currentUser != null && _token != null;
  bool get mustChangePassword => _mustChangePassword;

  // -- Initialization

  /// Load persisted auth state.
  /// Call this once in main() before runApp().
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _token = await TokenStorage.getToken();
    _refreshToken = await TokenStorage.getRefreshToken();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      try {
        _currentUser = AuthUser.fromJson(jsonDecode(userJson));
      } catch (e) {
        debugPrint('[AuthService] Corrupt stored user, clearing session: $e');
        await _clearStorage(prefs);
      }
    }
  }

  // -- Login

  /// Login for school-level users (SCHOOL_ADMIN, TEACHER, etc.).
  /// The current tenant_id in SharedPreferences must be set before calling this.
  Future<AuthResponse> loginTenant(String email, String password) async {
    return _doLogin('/auth/login', email, password);
  }

  /// Login for SUPER_ADMIN users (uses /platform/auth/login, platform_db).
  Future<AuthResponse> loginPlatform(String email, String password) async {
    // Platform login uses a different base URL prefix -- strip /api from baseUrl
    final dio = DioClient.instance;
    final response = await dio.post(
      // Remove /api prefix: platform path is relative to server root
      '${_platformBaseUrl()}/platform/auth/login',
      data: {'email': email, 'password': password},
    );
    return _handleLoginResponse(response);
  }

  Future<AuthResponse> _doLogin(String path, String email, String password) async {
    final response = await DioClient.post(path, data: {
      'email': email,
      'password': password,
    });
    return _handleLoginResponse(response);
  }

  Future<AuthResponse> _handleLoginResponse(Response response) async {
    final data = response.data as Map<String, dynamic>;
    final authResponse = AuthResponse.fromJson(data);

    _token = authResponse.token;
    _refreshToken = authResponse.refreshToken;
    _currentUser = authResponse.user;
    _mustChangePassword = authResponse.mustChangePassword;

    await TokenStorage.saveToken(_token!);
    if (_refreshToken != null) {
      await TokenStorage.saveRefreshToken(_refreshToken!);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));

    // Persist tenant from the response (for future requests)
    if (_currentUser!.tenantId != null) {
      await prefs.setString('tenant_id', _currentUser!.tenantId!);
    }

    return authResponse;
  }

  // -- Force password change

  /// Sets the initial password for users who must change their default password.
  /// The backend does not require the current password for this endpoint.
  Future<void> setInitialPassword(String newPassword) async {
    await DioClient.post('/auth/set-initial-password', data: {
      'newPassword': newPassword,
    });
    _mustChangePassword = false;
  }

  /// Clears the mustChangePassword flag (e.g. after successful password change).
  void clearMustChangePassword() {
    _mustChangePassword = false;
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

      await TokenStorage.saveToken(_token!);
      if (_refreshToken != null) {
        await TokenStorage.saveRefreshToken(_refreshToken!);
      }
      return true;
    } catch (e) {
      debugPrint('[AuthService] Token refresh failed: $e');
      return false;
    }
  }

  // -- Logout

  Future<void> logout() async {
    try {
      await DioClient.post('/auth/logout');
    } catch (e) {
      // Logout is always completed locally even if the server call fails
      debugPrint('[AuthService] Server logout failed (continuing locally): $e');
    }
    _token = null;
    _refreshToken = null;
    _currentUser = null;

    final prefs = await SharedPreferences.getInstance();
    await _clearStorage(prefs);
  }

  Future<void> _clearStorage(SharedPreferences prefs) async {
    await TokenStorage.clear();
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
