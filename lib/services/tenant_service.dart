import 'package:shared_preferences/shared_preferences.dart';

/// Manages the current school's tenant identity in local storage.
///
/// The tenant ID is set once when the admin logs in (or enters their school code).
/// Every API request then reads it from here and sends it as the X-Tenant-ID header.
class TenantService {
  static const String _tenantIdKey = 'tenant_id';
  static const String _tenantNameKey = 'tenant_name';

  /// Persists the tenant ID and school name to local storage.
  static Future<void> setTenant(String tenantId, {String? schoolName}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tenantIdKey, tenantId.toLowerCase().trim());
    if (schoolName != null) {
      await prefs.setString(_tenantNameKey, schoolName);
    }
  }

  /// Returns the stored tenant ID, or 'default' if none is set.
  static Future<String> getTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tenantIdKey) ?? 'default';
  }

  /// Returns the stored school name, or empty string if none is set.
  static Future<String> getSchoolName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tenantNameKey) ?? '';
  }

  /// Clears tenant info (e.g., on logout).
  static Future<void> clearTenant() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tenantIdKey);
    await prefs.remove(_tenantNameKey);
  }

  /// Whether a tenant has been configured.
  static Future<bool> hasTenant() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_tenantIdKey);
    return id != null && id.isNotEmpty && id != 'default';
  }
}
