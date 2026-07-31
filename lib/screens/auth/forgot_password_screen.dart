import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl   = TextEditingController();
  final _otpCtrl     = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // 'email' → 'otp' → 'newpass' → 'done'
  String _stage    = 'email';
  String _otp      = '';
  bool   _loading  = false;
  String _errorMsg = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _setError(String msg) => setState(() => _errorMsg = msg);
  void _clearError()         => setState(() => _errorMsg = '');

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      _setError('Enter a valid email address.'); return;
    }
    _clearError();
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().sendPasswordOtp(email);
    setState(() => _loading = false);
    if (!mounted) return;
    if (ok) {
      setState(() => _stage = 'otp');
    } else {
      _setError('Could not send OTP. Check the email and try again.');
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length < 6) { _setError('Enter the 6-digit OTP.'); return; }
    setState(() { _stage = 'newpass'; _errorMsg = ''; });
  }

  Future<void> _resetPassword() async {
    final pass    = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (pass.length < 6) { _setError('Password must be at least 6 characters.'); return; }
    if (pass != confirm)  { _setError('Passwords do not match.'); return; }
    _clearError();
    setState(() => _loading = true);
    final error = await context.read<AuthProvider>().changePassword(
      email:       _emailCtrl.text.trim().toLowerCase(),
      otp:         _otp,
      newPassword: pass,
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (error == null) {
      // Sign out so user starts a fresh login with the new password
      await context.read<AuthProvider>().logout();
      setState(() => _stage = 'done');
    } else {
      _setError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: _stage != 'done'
            ? GestureDetector(
                onTap: () {
                  if (_stage == 'otp' || _stage == 'newpass') {
                    setState(() { _stage = 'email'; _errorMsg = ''; });
                  } else {
                    context.pop();
                  }
                },
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                ),
              )
            : const SizedBox.shrink(),
        title: Text(
          _stage == 'done' ? 'Password Reset' : 'Forgot Password',
          style: GoogleFonts.inter(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _stage == 'done' ? _buildDone() : _buildForm(),
      ),
    );
  }

  // ── Step 1: Enter email ─────────────────────────────────────────────────────
  Widget _buildEmailStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title('Reset Your Password'),
      const SizedBox(height: 8),
      Text('Enter your registered email. We\'ll send a 6-digit OTP to reset your password.',
        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.5)),
      const SizedBox(height: 28),
      AppInput(
        label: 'Email Address',
        hint: 'you@example.com',
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.textDim, size: 18),
      ),
      const SizedBox(height: 24),
      AppButton(label: 'SEND OTP', icon: Icons.send_rounded, isLoading: _loading, onTap: _sendOtp),
    ],
  );

  // ── Step 2: Enter OTP ───────────────────────────────────────────────────────
  Widget _buildOtpStep() {
    // Screen has 24px padding on each side — 6 fixed 50px boxes overflowed on
    // narrower phones; size them to whatever width is actually available instead.
    final pinBoxSize = ((MediaQuery.of(context).size.width - 24 * 2 - 5 * 8) / 6).clamp(36.0, 50.0);
    return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title('Check Your Email'),
      const SizedBox(height: 8),
      RichText(
        text: TextSpan(children: [
          TextSpan(text: 'We sent a 6-digit code to ',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
          TextSpan(text: _emailCtrl.text.trim(),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: 28),
      Center(
        child: Pinput(
          length: 6,
          controller: _otpCtrl,
          onChanged: (v) => setState(() => _otp = v),
          onCompleted: (_) => _verifyOtp(),
          defaultPinTheme: PinTheme(
            width: pinBoxSize, height: pinBoxSize * 56 / 50,
            textStyle: GoogleFonts.inter(
                color: AppColors.primary, fontSize: pinBoxSize * 22 / 50, fontWeight: FontWeight.w900),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
          ),
          focusedPinTheme: PinTheme(
            width: pinBoxSize, height: pinBoxSize * 56 / 50,
            textStyle: GoogleFonts.inter(
                color: AppColors.primary, fontSize: pinBoxSize * 22 / 50, fontWeight: FontWeight.w900),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 10)],
            ),
          ),
          submittedPinTheme: PinTheme(
            width: pinBoxSize, height: pinBoxSize * 56 / 50,
            textStyle: GoogleFonts.inter(
                color: AppColors.primary, fontSize: pinBoxSize * 22 / 50, fontWeight: FontWeight.w900),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
            ),
          ),
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        ),
      ),
      const SizedBox(height: 28),
      AppButton(
        label: 'VERIFY OTP',
        icon: Icons.verified_outlined,
        isLoading: false,
        onTap: _verifyOtp,
      ),
      const SizedBox(height: 16),
      Center(
        child: GestureDetector(
          onTap: _loading ? null : _sendOtp,
          child: RichText(
            text: TextSpan(children: [
              TextSpan(text: "Didn't receive? ",
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
              TextSpan(text: 'Resend OTP',
                style: GoogleFonts.inter(
                    color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    ],
  );
  }

  // ── Step 3: New password ────────────────────────────────────────────────────
  Widget _buildNewPassStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title('Set New Password'),
      const SizedBox(height: 8),
      Text('OTP verified. Choose a strong new password.',
        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 28),
      AppInput(
        label: 'New Password',
        hint: 'Min 6 characters',
        controller: _passCtrl,
        isPassword: true,
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textDim, size: 18),
      ),
      const SizedBox(height: 14),
      AppInput(
        label: 'Confirm Password',
        hint: 'Repeat new password',
        controller: _confirmCtrl,
        isPassword: true,
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textDim, size: 18),
      ),
      const SizedBox(height: 24),
      AppButton(
        label: 'RESET PASSWORD',
        icon: Icons.check_rounded,
        isLoading: _loading,
        onTap: _resetPassword,
      ),
    ],
  );

  // ── Success ─────────────────────────────────────────────────────────────────
  Widget _buildDone() => Column(
    children: [
      const SizedBox(height: 60),
      Center(
        child: Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withOpacity(0.1),
            border: Border.all(color: AppColors.success.withOpacity(0.3), width: 2),
          ),
          child: const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.success, size: 46),
        ),
      ),
      const SizedBox(height: 24),
      Text('Password Reset!',
        style: GoogleFonts.inter(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      Text('Your password has been updated.\nPlease log in with your new password.',
        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        textAlign: TextAlign.center),
      const SizedBox(height: 36),
      AppButton(
        label: 'GO TO LOGIN',
        icon: Icons.login_rounded,
        onTap: () => context.go('/auth'),
      ),
    ],
  );

  // ── Shared ──────────────────────────────────────────────────────────────────
  Widget _buildForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_errorMsg.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withOpacity(0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
            const SizedBox(width: 10),
            Expanded(child: Text(_errorMsg,
              style: GoogleFonts.inter(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
        ),
      ],
      if (_stage == 'email')   _buildEmailStep(),
      if (_stage == 'otp')     _buildOtpStep(),
      if (_stage == 'newpass') _buildNewPassStep(),
    ],
  );

  Widget _title(String text) => Text(text,
    style: GoogleFonts.inter(
        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900));
}
