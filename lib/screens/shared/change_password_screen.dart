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
  final _newPassCtrl     = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _otpCtrl         = TextEditingController();

  // 3 stages: 'initial' → 'otp_sent' → 'done'
  String _stage       = 'initial';
  String  _otp        = '';
  bool   _sending     = false;
  bool   _submitting  = false;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  String get _email => context.read<AuthProvider>().user?.email ?? '';

  Future<void> _sendOtp() async {
    setState(() => _sending = true);
    final ok = await context.read<AuthProvider>().sendPasswordOtp(_email);
    setState(() => _sending = false);

    if (!mounted) return;
    if (ok) {
      setState(() => _stage = 'otp_sent');
      _snack('OTP sent to $_email');
    } else {
      _snack('Failed to send OTP. Try again.', error: true);
    }
  }

  Future<void> _submit() async {
    final pass    = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();

    if (_otp.length < 6) {
      _snack('Enter the 6-digit OTP', error: true); return;
    }
    if (pass.length < 6) {
      _snack('Password must be at least 6 characters', error: true); return;
    }
    if (pass != confirm) {
      _snack('Passwords do not match', error: true); return;
    }

    setState(() => _submitting = true);
    final error = await context.read<AuthProvider>().changePassword(
      email:       _email,
      otp:         _otp,
      newPassword: pass,
    );
    setState(() => _submitting = false);

    if (!mounted) return;
    if (error == null) {
      setState(() => _stage = 'done');
    } else {
      _snack(error, error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
        ),
        title: Text('Change Password',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _stage == 'done' ? _buildDone() : _buildForm(),
      ),
    );
  }

  // ── Success screen ───────────────────────────────────────────────
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
              border: Border.all(color: AppColors.success.withOpacity(0.3), width: 2),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.success, size: 46),
          ),
        ),
        const SizedBox(height: 24),
        Text('Password Changed!',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text('Your password has been updated successfully.',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
          textAlign: TextAlign.center),
        const SizedBox(height: 36),
        AppButton(
          label: 'DONE',
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }

  // ── Main form ────────────────────────────────────────────────────
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'An OTP will be sent to $_email to verify your identity.',
                style: GoogleFonts.inter(color: AppColors.primary, fontSize: 13),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 28),

        // Step 1: New passwords
        _sectionLabel('New Password'),
        const SizedBox(height: 12),
        AppInput(
          label: 'New Password',
          hint: 'Min 6 characters',
          controller: _newPassCtrl,
          isPassword: true,
          enabled: _stage == 'initial',
          prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: AppColors.textDim, size: 18),
        ),
        const SizedBox(height: 14),
        AppInput(
          label: 'Confirm New Password',
          hint: 'Re-enter new password',
          controller: _confirmPassCtrl,
          isPassword: true,
          enabled: _stage == 'initial',
          prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: AppColors.textDim, size: 18),
        ),
        const SizedBox(height: 24),

        // Stage: initial — show send OTP button
        if (_stage == 'initial') ...[
          AppButton(
            label: 'SEND OTP TO EMAIL',
            icon: Icons.send_rounded,
            isLoading: _sending,
            onTap: () {
              if (_newPassCtrl.text.trim().length < 6) {
                _snack('Enter new password first (min 6 chars)', error: true);
                return;
              }
              if (_newPassCtrl.text != _confirmPassCtrl.text) {
                _snack('Passwords do not match', error: true);
                return;
              }
              _sendOtp();
            },
          ),
        ],

        // Stage: otp_sent — show OTP input + submit
        if (_stage == 'otp_sent') ...[
          _sectionLabel('Enter OTP'),
          const SizedBox(height: 6),
          Text('Code sent to $_email',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 16),

          // OTP boxes (Pinput)
          Center(
            child: Pinput(
              length: 6,
              controller: _otpCtrl,
              onChanged: (v) => setState(() => _otp = v),
              onCompleted: (_) => _submit(),
              defaultPinTheme: PinTheme(
                width: 50, height: 56,
                textStyle: GoogleFonts.inter(
                  color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w900),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
              ),
              focusedPinTheme: PinTheme(
                width: 50, height: 56,
                textStyle: GoogleFonts.inter(
                  color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w900),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary, width: 2),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 10)
                  ],
                ),
              ),
              submittedPinTheme: PinTheme(
                width: 50, height: 56,
                textStyle: GoogleFonts.inter(
                  color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w900),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.5), width: 1.5),
                ),
              ),
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            ),
          ),
          const SizedBox(height: 28),

          AppButton(
            label: 'VERIFY & CHANGE PASSWORD',
            icon: Icons.check_rounded,
            isLoading: _submitting,
            onTap: _submit,
          ),
          const SizedBox(height: 16),

          // Resend OTP
          Center(
            child: GestureDetector(
              onTap: _sending ? null : _sendOtp,
              child: RichText(
                text: TextSpan(children: [
                  TextSpan(text: "Didn't receive code? ",
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                  TextSpan(text: 'Resend OTP',
                    style: GoogleFonts.inter(
                      color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _sectionLabel(String t) => Text(
    t.toUpperCase(),
    style: GoogleFonts.inter(
      color: AppColors.textMuted, fontSize: 11,
      fontWeight: FontWeight.w800, letterSpacing: 1),
  );
}
