import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String requestId;
  const OtpVerifyScreen({super.key, required this.requestId});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) {
      setState(() => _error = 'Please enter the 6-digit OTP');
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() { _loading = true; _error = null; });

    final ok = await context.read<RequestProvider>().verifyOtp(
      requestId: widget.requestId,
      enteredOtp: otp,
      customerId: user.id,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      setState(() => _success = true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.pop();
    } else {
      setState(() => _error = 'Invalid OTP. Please ask the provider to show their code again.');
      _otpCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 6 boxes + 5 gaps must fit inside the available width on any
              // screen size — fixed 56px boxes overflowed on narrower phones.
              const gap = 8.0;
              final boxSize = ((constraints.maxWidth - gap * 5) / 6).clamp(40.0, 56.0);

              final pinTheme = PinTheme(
                width: boxSize,
                height: boxSize * 64 / 56,
                textStyle: TextStyle(color: Colors.white, fontSize: boxSize * 24 / 56, fontWeight: FontWeight.w800),
                decoration: const BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  border: Border.fromBorderSide(BorderSide(color: AppColors.border, width: 1.5)),
                ),
              );

              final focusPinTheme = pinTheme.copyWith(
                decoration: pinTheme.decoration!.copyWith(
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
              );

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      // Back button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => context.pop(),
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
                      ),

                      const SizedBox(height: 40),

                      if (_success) ...[
                        // Success state
                        Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success.withValues(alpha: 0.1),
                            border: Border.all(color: AppColors.success, width: 2),
                          ),
                          child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 50),
                        ),
                        const SizedBox(height: 24),
                        Text('Identity Verified!', style: GoogleFonts.inter(color: AppColors.success, fontSize: 24, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        Text('The job has officially started.\nLet the provider in!', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14, height: 1.6), textAlign: TextAlign.center),
                      ] else ...[
                        // OTP input state
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 4)],
                          ),
                          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 38),
                        ),
                        const SizedBox(height: 28),
                        Text('Verify Provider', style: GoogleFonts.inter(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        Text(
                          'Ask the provider for their ServiceHive OTP.\nEnter it below to confirm they are from ServiceHive.',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14, height: 1.6),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),

                        Pinput(
                          controller: _otpCtrl,
                          length: 6,
                          defaultPinTheme: pinTheme,
                          focusedPinTheme: focusPinTheme,
                          errorPinTheme: pinTheme.copyWith(
                            decoration: pinTheme.decoration!.copyWith(
                              border: Border.all(color: AppColors.error, width: 2),
                            ),
                          ),
                          separatorBuilder: (_) => const SizedBox(width: gap),
                          onCompleted: (_) => _verify(),
                          keyboardType: TextInputType.number,
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 12, height: 1.4))),
                            ]),
                          ),
                        ],

                        const SizedBox(height: 32),

                        GestureDetector(
                          onTap: _loading ? null : _verify,
                          child: Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: _loading
                                  ? null
                                  : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                              color: _loading ? AppColors.surface2 : null,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: _loading
                                  ? []
                                  : [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 15)],
                            ),
                            child: Center(
                              child: _loading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                                      const SizedBox(width: 10),
                                      Text('Verify & Start Job', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                    ]),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
