import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  late AnimationController _iconCtrl;
  late Animation<double> _iconScale;

  Timer? _pollTimer;
  RealtimeChannel? _userChannel;
  bool _approved = false;
  bool _rejected = false;
  String? _rejectionReason;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _iconCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _iconScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut),
    );
    _iconCtrl.forward();

    // Realtime gives an instant update when admin approves/rejects; the 5s
    // poll stays as a fallback in case Realtime isn't enabled for `users`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToOwnRow();
      _startPolling();
    });
  }

  void _subscribeToOwnRow() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    _userChannel = Supabase.instance.client
        .channel('own_user_${session.user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: session.user.id,
          ),
          callback: (_) => _checkApproval(),
        )
        .subscribe();
  }

  void _startPolling() {
    _checkApproval(); // immediate first check
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkApproval());
  }

  Future<void> _checkApproval() async {
    if (_approved || _rejected) return;

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final row = await Supabase.instance.client
          .from('users')
          .select('is_verified, rejection_reason')
          .eq('id', session.user.id)
          .single();

      if (row['is_verified'] == true && mounted && !_approved) {
        _pollTimer?.cancel();
        _userChannel?.unsubscribe();
        _pulseCtrl.stop();
        setState(() => _approved = true);
        return;
      }

      final reason = row['rejection_reason'] as String?;
      if (mounted && reason != _rejectionReason) {
        setState(() => _rejectionReason = reason);
      }
    } on PostgrestException catch (e) {
      // Rejection deletes the account outright (see admin panel) so the same
      // email can register again — PGRST116 means .single() found no row,
      // i.e. this account no longer exists. Stop polling and show a plain
      // "rejected" screen with a manual way back to registration, instead of
      // auto-navigating (which raced with this same callback and crashed).
      if (e.code == 'PGRST116' && mounted && !_rejected) {
        _pollTimer?.cancel();
        _userChannel?.unsubscribe();
        _pulseCtrl.stop();
        // The users row (and its rejection_reason) is already gone by now,
        // so fetch the reason from the rejected_applications log instead —
        // the account's auth session/JWT (and the email baked into it)
        // still works even though the row it pointed to was deleted.
        final email = Supabase.instance.client.auth.currentSession?.user.email;
        if (email != null) {
          try {
            final reason = await Supabase.instance.client
                .rpc('get_latest_rejection_reason', params: {'lookup_email': email});
            if (mounted) _rejectionReason = reason as String?;
          } catch (_) {
            // Non-fatal — show the rejected screen without a reason rather
            // than getting stuck.
          }
        }
        if (mounted) setState(() => _rejected = true);
      }
    } catch (_) {
      // Network error — will retry on next tick
    }
  }

  Future<void> _backToRegister() async {
    await context.read<AuthProvider>().logout();
    if (mounted) context.go('/auth', extra: 'workerRegister');
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _userChannel?.unsubscribe();
    _pulseCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(top: -100, left: -100,
            child: Container(width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.07)))),
          Positioned(bottom: -80, right: -80,
            child: Container(width: 250, height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.06)))),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _rejected
                          ? _RejectedBody(reason: _rejectionReason, onBackToRegister: _backToRegister)
                          : _approved
                              ? const _ApprovedBody()
                              : _PendingBody(
                                  iconCtrl: _iconCtrl,
                                  iconScale: _iconScale,
                                  pulse: _pulse,
                                ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pending UI ────────────────────────────────────────────────────────────────

class _PendingBody extends StatelessWidget {
  final AnimationController iconCtrl;
  final Animation<double> iconScale;
  final Animation<double> pulse;

  const _PendingBody({
    required this.iconCtrl,
    required this.iconScale,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('pending'),
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: iconScale,
          child: ScaleTransition(
            scale: pulse,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25), width: 2),
                boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), blurRadius: 30, spreadRadius: 5)],
              ),
              child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFF59E0B), size: 48),
            ),
          ),
        ),
        const SizedBox(height: 32),

        Text('Verification Pending',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'Your provider account registration is complete.\nAn admin will review your details and verify your account shortly.',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14, height: 1.6),
          textAlign: TextAlign.center),

        const SizedBox(height: 36),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(children: [
            _StatusRow(icon: Icons.check_circle_rounded, color: AppColors.success, label: 'Email OTP Verified'),
            SizedBox(height: 12),
            _StatusRow(icon: Icons.check_circle_rounded, color: AppColors.success, label: 'Registration Complete'),
            SizedBox(height: 12),
            _StatusRow(icon: Icons.radio_button_unchecked_rounded, color: Color(0xFFF59E0B),
              label: 'Waiting for Admin Approval', isWaiting: true),
          ]),
        ),
        const SizedBox(height: 24),

        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success)),
          const SizedBox(width: 8),
          Text('Checking automatically every 5 seconds...',
            style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11)),
        ]),
        const SizedBox(height: 20),

        GestureDetector(
          onTap: () async {
            await context.read<AuthProvider>().logout();
            if (context.mounted) context.go('/auth');
          },
          child: Text('Logout',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13,
              decoration: TextDecoration.underline, decorationColor: AppColors.textMuted)),
        ),
      ],
    );
  }
}

// ── Rejected UI ───────────────────────────────────────────────────────────────
// Own dedicated body (not a variant of _PendingBody) since the account is
// already gone at this point — there's nothing left to poll or wait on, just
// the reason and a way back to a fresh registration form.

class _RejectedBody extends StatelessWidget {
  final String? reason;
  final Future<void> Function() onBackToRegister;

  const _RejectedBody({required this.reason, required this.onBackToRegister});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('rejected'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error.withValues(alpha: 0.1),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.25), width: 2),
            boxShadow: [BoxShadow(color: AppColors.error.withValues(alpha: 0.15), blurRadius: 30, spreadRadius: 5)],
          ),
          child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
        ),
        const SizedBox(height: 32),

        Text('Application Rejected',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'An admin reviewed your application and found an issue.',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14, height: 1.6),
          textAlign: TextAlign.center),

        if (reason != null && reason!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('REASON', style: GoogleFonts.inter(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(reason!, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, height: 1.5)),
            ]),
          ),
        ],

        const SizedBox(height: 32),

        GestureDetector(
          onTap: onBackToRegister,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 20)],
            ),
            child: Center(
              child: Text('BACK TO REGISTER',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Approved UI ───────────────────────────────────────────────────────────────

class _ApprovedBody extends StatelessWidget {
  const _ApprovedBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('approved'),
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.35), width: 2),
              boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.25), blurRadius: 40, spreadRadius: 8)],
            ),
            child: const Icon(Icons.verified_rounded, color: AppColors.success, size: 52),
          ),
        ),
        const SizedBox(height: 28),

        Text('Account Approved!',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('Congratulations! Admin has verified your provider account.',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14, height: 1.6),
          textAlign: TextAlign.center),
        const SizedBox(height: 36),

        // Manual step (not auto-redirect) so the provider consciously logs
        // in fresh rather than being silently dropped into the dashboard.
        GestureDetector(
          onTap: () async {
            // Must go through AuthProvider.logout() so its internal _status
            // resets — a raw Supabase signOut leaves _status stuck on
            // pendingApproval and the router redirect bounces back here.
            await context.read<AuthProvider>().logout();
            if (context.mounted) context.go('/auth');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 20)],
            ),
            child: Center(
              child: Text('BACK TO LOGIN',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Status Row ────────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isWaiting;

  const _StatusRow({required this.icon, required this.color, required this.label, this.isWaiting = false});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      isWaiting
          ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: color, strokeWidth: 2))
          : Icon(icon, color: color, size: 22),
      const SizedBox(width: 12),
      Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    ]);
  }
}
