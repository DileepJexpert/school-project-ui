import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../services/auth_service.dart';

/// Standalone screen shown when a user's account requires a password change
/// before accessing the application (e.g. auto-created parent accounts with
/// default passwords).
///
/// This screen:
///   - Cannot be dismissed or navigated away from (back button disabled)
///   - Does not show the main app shell/navbar
///   - On success, navigates to the role-appropriate dashboard
class ForcePasswordChangeScreen extends StatefulWidget {
  const ForcePasswordChangeScreen({super.key});

  @override
  State<ForcePasswordChangeScreen> createState() =>
      _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // -- Validation helpers

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a new password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Confirm your new password';
    if (value != _newPasswordCtrl.text) return 'Passwords do not match';
    return null;
  }

  // -- Submit

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.instance.setInitialPassword(_newPasswordCtrl.text);

      if (mounted) {
        final role = AuthService.instance.currentUser?.role;
        final route = AppRouter.dashboardRouteForRole(role);
        Navigator.of(context).pushReplacementNamed(route);
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
    if (raw.contains('400')) return 'Invalid password. Please try a different one.';
    if (raw.contains('401')) return 'Session expired. Please log in again.';
    if (raw.contains('connection') || raw.contains('timeout')) {
      return 'Cannot connect to server. Check your internet.';
    }
    return 'Failed to set password. Please try again.';
  }

  // -- Password strength hint

  Widget _buildPasswordHints() {
    final password = _newPasswordCtrl.text;
    final hasMinLength = password.length >= 6;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hintRow('At least 6 characters', hasMinLength),
        _hintRow('Contains an uppercase letter', hasUppercase),
        _hintRow('Contains a number', hasDigit),
      ],
    );
  }

  Widget _hintRow(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: met ? AppColors.success : AppColors.textLight,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: met ? AppColors.success : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  // -- Build

  @override
  Widget build(BuildContext context) {
    // Prevent back navigation -- user MUST change their password
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildMessage(),
                        const SizedBox(height: 24),
                        _buildNewPasswordField(),
                        const SizedBox(height: 8),
                        _buildPasswordHints(),
                        const SizedBox(height: 16),
                        _buildConfirmPasswordField(),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _buildError(),
                        ],
                        const SizedBox(height: 24),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, size: 32, color: AppColors.gold),
          ),
          const SizedBox(height: 16),
          Text(
            'Set New Password',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ],
      );

  Widget _buildMessage() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.goldPale,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Welcome! For your security, please set a new password before continuing.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildNewPasswordField() => TextFormField(
        controller: _newPasswordCtrl,
        obscureText: !_newPasswordVisible,
        decoration: InputDecoration(
          labelText: 'New Password',
          prefixIcon: const Icon(Icons.lock_outline),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          suffixIcon: IconButton(
            icon: Icon(
              _newPasswordVisible ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () =>
                setState(() => _newPasswordVisible = !_newPasswordVisible),
          ),
        ),
        validator: _validateNewPassword,
        onChanged: (_) => setState(() {}), // rebuild password hints
        textInputAction: TextInputAction.next,
      );

  Widget _buildConfirmPasswordField() => TextFormField(
        controller: _confirmPasswordCtrl,
        obscureText: !_confirmPasswordVisible,
        decoration: InputDecoration(
          labelText: 'Confirm Password',
          prefixIcon: const Icon(Icons.lock_outline),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          suffixIcon: IconButton(
            icon: Icon(
              _confirmPasswordVisible
                  ? Icons.visibility_off
                  : Icons.visibility,
            ),
            onPressed: () => setState(
                () => _confirmPasswordVisible = !_confirmPasswordVisible),
          ),
        ),
        validator: _validateConfirmPassword,
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
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.red[700],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildSubmitButton() => SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Set Password',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
}
