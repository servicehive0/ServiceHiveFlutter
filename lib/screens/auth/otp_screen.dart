import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/error_banner.dart';

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  String _otp = '';
  late AnimationController _iconCtrl;
  late Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _iconScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut),
    );
    _iconCtrl.forward();
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter the 6-digit code', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(_otp);
    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.status == AuthStatus.loading;

    final defaultPinTheme = PinTheme(
      width: 52,
      height: 58,
      textStyle: GoogleFonts.inter(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w900),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary, width: 2),
      color: AppColors.primary.withOpacity(0.05),
      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 12)],
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
      color: AppColors.primary.withOpacity(0.08),
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(top: -80, left: -80, child: Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.12)))),
          Positioned(bottom: -80, right: -80, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF6366F1).withOpacity(0.08)))),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 32),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.go('/auth'),
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, 20))],
                    ),
                    child: Column(
                      children: [
                        // Animated shield icon
                        ScaleTransition(
                          scale: _iconScale,
                          child: Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.1),
                              border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
                              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 20, spreadRadius: 5)],
                            ),
                            child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 38),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Verify Identity',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the 6-digit code sent to',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.email,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        if (auth.errorMessage != null) ErrorBanner(message: auth.errorMessage!),

                        Pinput(
                          length: 6,
                          defaultPinTheme: defaultPinTheme,
                          focusedPinTheme: focusedPinTheme,
                          submittedPinTheme: submittedPinTheme,
                          onChanged: (v) => setState(() => _otp = v),
                          onCompleted: (_) => _verify(),
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.center,
                        ),
                        const SizedBox(height: 32),

                        AppButton(
                          label: 'VERIFY & COMPLETE',
                          icon: Icons.arrow_forward_rounded,
                          isLoading: isLoading,
                          onTap: _verify,
                        ),
                        const SizedBox(height: 20),

                        GestureDetector(
                          onTap: () async {
                            final auth = context.read<AuthProvider>();
                            final ok = await auth.resendOtp(widget.email);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(ok ? 'OTP resent to your email' : 'Failed to resend OTP',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                backgroundColor: ok ? AppColors.success : AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ));
                            }
                          },
                          child: RichText(
                            text: TextSpan(children: [
                              TextSpan(text: "Didn't receive code? ", style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                              TextSpan(text: 'Resend OTP', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => context.go('/auth'),
                          child: Text(
                            'Change Email Address?',
                            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final VoidCallback onDone;

  const _SuccessDialog({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withOpacity(0.1),
                border: Border.all(color: AppColors.success.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 20),
            Text('Registration Successful!',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Your account has been created. Please login to continue.',
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onDone,
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15)],
                ),
                child: Center(
                  child: Text('GO TO LOGIN', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
