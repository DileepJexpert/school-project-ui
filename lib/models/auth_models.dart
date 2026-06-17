/// Role constants — must match the Java UserRole enum exactly.
///
/// To add a new role:
///   1. Add the constant here
///   2. Update AuthService.menuAccessFor() and permissionDefaults
///   3. Update AdminDashboardPage menu visibility logic
class UserRole {
  static const superAdmin = 'SUPER_ADMIN';
  static const schoolAdmin = 'SCHOOL_ADMIN';
  static const teacher = 'TEACHER';
  static const accountant = 'ACCOUNTANT';
  static const transportManager = 'TRANSPORT_MANAGER';
  static const student = 'STUDENT';
  static const parent = 'PARENT';

  /// Display name for each role
  static String displayName(String role) {
    return switch (role) {
      superAdmin => 'Super Admin',
      schoolAdmin => 'School Admin',
      teacher => 'Teacher',
      accountant => 'Accountant',
      transportManager => 'Transport Manager',
      student => 'Student',
      parent => 'Parent',
      _ => role,
    };
  }

  /// Human-readable short description of what each role can do
  static String description(String role) {
    return switch (role) {
      superAdmin => 'Full platform access — manages all schools',
      schoolAdmin => 'Full access within the school',
      teacher => 'Attendance, results, timetable',
      accountant => 'Fees, expenses, financial reports',
      transportManager => 'Buses, routes, transport assignments',
      student => 'View own records',
      parent => "View child's records",
      _ => '',
    };
  }
}

/// Authenticated user details returned after login
class AuthUser {
  final String userId;
  final String email;
  final String fullName;
  final String role;
  final String? tenantId;
  final String? linkedEntityId;
  final List<String> permissions;

  const AuthUser({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    this.tenantId,
    this.linkedEntityId,
    this.permissions = const [],
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        userId: json['userId'] as String,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
        role: json['role'] as String,
        tenantId: json['tenantId'] as String?,
        linkedEntityId: json['linkedEntityId'] as String?,
        permissions: (json['permissions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'fullName': fullName,
        'role': role,
        'tenantId': tenantId,
        'linkedEntityId': linkedEntityId,
        'permissions': permissions,
      };

  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isSchoolAdmin => role == UserRole.schoolAdmin;
  bool get isTeacher => role == UserRole.teacher;
  bool get isAccountant => role == UserRole.accountant;
  bool get isTransportManager => role == UserRole.transportManager;
  bool get isStudent => role == UserRole.student;
  bool get isParent => role == UserRole.parent;

  /// True if the user has management-level access (can access admin dashboard)
  bool get hasAdminAccess => [
        UserRole.superAdmin,
        UserRole.schoolAdmin,
        UserRole.teacher,
        UserRole.accountant,
        UserRole.transportManager,
      ].contains(role);
}

/// Full response from POST /api/auth/login or /platform/auth/login
class AuthResponse {
  final String token;
  final String? refreshToken;
  final AuthUser user;
  final int expiresIn;
  final bool mustChangePassword;

  const AuthResponse({
    required this.token,
    this.refreshToken,
    required this.user,
    required this.expiresIn,
    this.mustChangePassword = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['token'] as String,
        refreshToken: json['refreshToken'] as String?,
        user: AuthUser.fromJson(json),
        expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 86400,
        mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      );
}
