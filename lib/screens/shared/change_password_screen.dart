import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _otpCtrl         = TextEditingController();
  final _newPassCtrl     = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // 'intro' → 'otp' → 'newpass' → 'done'
  String _stage    = 'intro';
  String _otp      = '';
  bool   _loading  = false;
  String _errorMsg = '';

  String get _email => context.read<AuthProvider>().user?.email ?? '';

  @override
  void dispose() {
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _setError(String msg) => setState(() => _errorMsg = msg);
  void _clearError()         => setState(() => _errorMsg = '');

  Future<void> _sendOtp() async {
    _clearError();
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().sendPasswordOtp(_email);
    setState(() => _loading = false);
    if (!mounted) return;
    if (ok) {
      setState(() => _stage = 'otp');
    } else {
      _setError('Could not send OTP. Please try again.');
    }
  }

  void _verifyOtp() {
    if (_otp.length < 6) { _setError('Enter the 6-digit OTP.'); return; }
    setState(() { _stage = 'newpass'; _errorMsg = ''; });
  }

  Future<void> _submit() async {
    final pass    = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();

    if (pass.length < 6) {
      _setError('Password must be at least 6 characters'); return;
    }
    if (pass != confirm) {
      _setError('Passwords do not match'); return;
    }

    _clearError();
    setState(() => _loading = true);
    final error = await context.read<AuthProvider>().changePassword(
      email:       _email,
      otp:         _otp,
      newPassword: pass,
    );
    setState(() => _loading = false);

    if (!mounted) return;
    if (error == null) {
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
        leading: GestureDetector(
          onTap: () {
            if (_stage == 'otp' || _stage == 'newpass') {
              setState(() { _stage = 'intro'; _errorMsg = ''; });
            } else {
              Navigator.pop(context);
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
        ),
        title: Text('Change Password',
            style: GoogleFonts.inter(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case 'otp':     return _buildOtpStep();
      case 'newpass': return _buildNewPassStep();
      case 'done':    return _buildDone();
      default:        return _buildIntroStep();
    }
  }

  // ── Step 1: Confirm & send OTP ──────────────────────────────────────────
  Widget _buildIntroStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_errorMsg.isNotEmpty) _errorBanner(),
      _title('Change Your Password'),
      const SizedBox(height: 8),
      Text(
        'For your security, we\'ll send a 6-digit OTP to your registered email to verify it\'s really you.',
        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.5),
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.mail_outline_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _email,
              style: GoogleFonts.inter(
                  color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 28),
      AppButton(
        label: 'SEND OTP',
        icon: Icons.send_rounded,
        isLoading: _loading,
        onTap: _sendOtp,
      ),
    ],
  );

  // ── Step 2: Enter OTP ───────────────────────────────────────────────────
  Widget _buildOtpStep() {
    final pinBoxSize = ((MediaQuery.of(context).size.width - 24 * 2 - 5 * 8) / 6).clamp(36.0, 50.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMsg.isNotEmpty) _errorBanner(),
        _title('Check Your Email'),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(children: [
            TextSpan(text: 'We sent a 6-digit code to ',
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
            TextSpan(text: _email,
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

  // ── Step 3: New password ────────────────────────────────────────────────
  Widget _buildNewPassStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_errorMsg.isNotEmpty) _errorBanner(),
      _title('Set New Password'),
      const SizedBox(height: 8),
      Text('OTP verified. Choose your new password.',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 28),
      AppInput(
        label: 'New Password',
        hint: 'Min 6 characters',
        controller: _newPassCtrl,
        isPassword: true,
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: AppColors.textDim, size: 18),
      ),
      const SizedBox(height: 14),
      AppInput(
        label: 'Confirm New Password',
        hint: 'Re-enter new password',
        controller: _confirmPassCtrl,
        isPassword: true,
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: AppColors.textDim, size: 18),
      ),
      const SizedBox(height: 28),
      AppButton(
        label: 'UPDATE PASSWORD',
        icon: Icons.check_rounded,
        isLoading: _loading,
        onTap: _submit,
      ),
      const SizedBox(height: 40),
    ],
  );

  Widget _buildDone() {
    return Column(
      children: [
        const SizedBox(height: 60),
        Center(
          child: Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withOpacity(0.1),
              border: Border.all(
                  color: AppColors.success.withOpacity(0.3), width: 2),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.success, size: 46),
          ),
        ),
        const SizedBox(height: 24),
        Text('Password Changed!',
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text('Your password has been updated successfully.',
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 36),
        AppButton(
          label: 'BACK TO PROFILE',
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _errorBanner() => Container(
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
  );

  Widget _title(String text) => Text(text,
    style: GoogleFonts.inter(
        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900));
}
