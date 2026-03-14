import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';

/// Login page — supports all roles.
///
/// Flow:
///   1. User enters school code (tenantId), e.g., "springfield"
///   2. School code is validated via GET /platform/schools/{tenantId}/validate
///   3. User enters email + password
///   4. Login via POST /api/auth/login (tenant) or /platform/auth/login (super admin)
///   5. On success, navigate to /admin-dashboard
///
/// The "Platform Admin" toggle skips the school code step and uses /platform/auth/login.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _schoolCodeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isPlatformAdmin = false;
  bool _passwordVisible = false;
  bool _loading = false;
  String? _error;

  // School info from validate endpoint
  String? _schoolName;
  bool _schoolValidated = false;

  @override
  void dispose() {
    _schoolCodeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── School code validation ───────────────────────────────────────────────

  Future<void> _validateSchool() async {
    final code = _schoolCodeCtrl.text.trim().toLowerCase();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _schoolValidated = false;
      _schoolName = null;
    });

    try {
      // Persist tenant_id so DioClient uses it
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tenant_id', code);

      final response = await AuthService.instance
          ._validateSchoolCode(code);

      if (response['valid'] == true) {
        setState(() {
          _schoolValidated = true;
          _schoolName = response['name'] as String? ?? code;
        });
      } else {
        setState(() => _error = 'School code not found or inactive.');
      }
    } catch (e) {
      setState(() => _error = 'Could not reach server. Check your connection.');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Login ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isPlatformAdmin) {
        await AuthService.instance.loginPlatform(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
      } else {
        await AuthService.instance.loginTenant(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRouter.adminDashboard);
      }
    } catch (e) {
      setState(() {
        _error = _friendlyError(e.toString());
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('401') || raw.contains('Invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('403')) return 'Your account has been deactivated.';
    if (raw.contains('connection') || raw.contains('timeout')) {
      return 'Cannot connect to server. Check your internet.';
    }
    return 'Login failed. Please try again.';
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 28),
                      _buildPlatformToggle(),
                      const SizedBox(height: 20),
                      if (!_isPlatformAdmin) ...[
                        _buildSchoolCodeField(),
                        const SizedBox(height: 16),
                      ],
                      _buildEmailField(),
                      const SizedBox(height: 16),
                      _buildPasswordField(),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _buildError(),
                      ],
                      const SizedBox(height: 24),
                      _buildLoginButton(),
                      const SizedBox(height: 12),
                      _buildBackToSite(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Column(children: [
        const Icon(Icons.school, size: 48, color: AppColors.primary),
        const SizedBox(height: 12),
        Text('School Management',
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Sign in to your account',
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.grey[600])),
      ]);

  Widget _buildPlatformToggle() => Row(
        children: [
          Switch(
            value: _isPlatformAdmin,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() {
              _isPlatformAdmin = v;
              _schoolValidated = false;
              _schoolName = null;
              _error = null;
            }),
          ),
          const SizedBox(width: 8),
          Text('Platform Admin login',
              style: GoogleFonts.poppins(fontSize: 13)),
        ],
      );

  Widget _buildSchoolCodeField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _schoolCodeCtrl,
            decoration: InputDecoration(
              labelText: 'School Code',
              hintText: 'e.g. springfield',
              prefixIcon: const Icon(Icons.business),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              suffixIcon: _schoolValidated
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : TextButton(
                      onPressed: _loading ? null : _validateSchool,
                      child: Text('Verify',
                          style: GoogleFonts.poppins(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter your school code' : null,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _validateSchool(),
          ),
          if (_schoolName != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              Text(_schoolName!,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500)),
            ]),
          ],
        ],
      );

  Widget _buildEmailField() => TextFormField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: 'Email',
          prefixIcon: const Icon(Icons.email_outlined),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Enter your email';
          if (!v.contains('@')) return 'Enter a valid email';
          return null;
        },
        textInputAction: TextInputAction.next,
      );

  Widget _buildPasswordField() => TextFormField(
        controller: _passwordCtrl,
        obscureText: !_passwordVisible,
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          suffixIcon: IconButton(
            icon: Icon(_passwordVisible
                ? Icons.visibility_off
                : Icons.visibility),
            onPressed: () =>
                setState(() => _passwordVisible = !_passwordVisible),
          ),
        ),
        validator: (v) =>
            v == null || v.isEmpty ? 'Enter your password' : null,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
      );

  Widget _buildError() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red[50],
          border: Border.all(color: Colors.red[200]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(_error!,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.red[700]))),
        ]),
      );

  Widget _buildLoginButton() => SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text('Sign In',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _buildBackToSite() => TextButton(
        onPressed: () =>
            Navigator.of(context).pushReplacementNamed(AppRouter.home),
        child: Text('← Back to school website',
            style: GoogleFonts.poppins(
                color: Colors.grey[600], fontSize: 13)),
      );
}

// Extension on AuthService to keep login_page self-contained
extension _AuthServiceLoginExt on AuthService {
  Future<Map<String, dynamic>> _validateSchoolCode(String code) async {
    final dio = DioClient.instance;
    // Platform validate endpoint is not tenant-scoped
    final response = await dio.get(
      '${DioClient.baseUrl.replaceAll('/api', '')}/platform/schools/$code/validate',
    );
    return response.data as Map<String, dynamic>;
  }
}
