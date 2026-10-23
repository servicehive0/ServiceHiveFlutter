import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/service_request_model.dart';
import '../../providers/request_provider.dart';
import '../../services/avatar_cache.dart';
import '../shared/active_job_map_screen.dart';

class ProviderJobScreen extends StatefulWidget {
  final String requestId;
  const ProviderJobScreen({super.key, required this.requestId});

  @override
  State<ProviderJobScreen> createState() => _ProviderJobScreenState();
}

class _ProviderJobScreenState extends State<ProviderJobScreen> {
  ServiceRequest? _request;
  bool _loading = true;
  String? _otpCode;
  bool _completing = false;
  String? _customerAvatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rp = context.read<RequestProvider>();
    final req = await rp.fetchRequest(widget.requestId);
    final otp = (req != null && req.status == 'accepted' && !req.otpVerified)
        ? await rp.fetchJobOtp(widget.requestId)
        : null;
    if (mounted) setState(() { _request = req; _otpCode = otp; _loading = false; });
    if (req != null) _loadCustomerAvatar(req.customerId);
  }

  Future<void> _loadCustomerAvatar(String customerId) async {
    try {
      final url = await AvatarCache.getAvatar(customerId);
      if (mounted && url != null) {
        setState(() => _customerAvatarUrl = url);
      }
    } catch (_) {}
  }

  void _openMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveJobMapScreen(
          requestId: widget.requestId,
          isProvider: true,
        ),
      ),
    );
  }

  Future<void> _markComplete() async {
    if (_request?.otpVerified != true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ask the customer to verify your OTP first', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Mark Job Complete?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Confirm that you have finished the job.', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Complete', style: GoogleFonts.inter(color: AppColors.success, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _completing = true);
    await context.read<RequestProvider>().markJobComplete(widget.requestId);
    if (mounted) {
      setState(() => _completing = false);
      await _load();
    }
  }

  Widget _buildContent() {
    final req = _request!;
    final isCompleted  = req.status == 'completed';
    final isInProgress = req.status == 'in_progress';
    final isAccepted   = req.status == 'accepted';

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
            child: Row(children: [
              GestureDetector(
                // Once the job is done, popping would land back on whatever
                // pushed this screen (often the bid-editing page) — go to
                // the dashboard instead so this doesn't reappear mid-flow.
                onTap: () => isCompleted ? context.go('/provider-dashboard') : context.pop(),
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
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Active Job', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(req.serviceName, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.success.withValues(alpha: 0.1)
                      : isInProgress
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isCompleted
                        ? AppColors.success.withValues(alpha: 0.3)
                        : isInProgress
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                            : AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isCompleted ? 'DONE' : isInProgress ? 'IN PROGRESS' : 'ACCEPTED',
                  style: GoogleFonts.inter(
                    color: isCompleted
                        ? AppColors.success
                        : isInProgress
                            ? const Color(0xFFF59E0B)
                            : AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ]),
          ),
        ),

        // OTP card (shown to provider)
        if (!isCompleted && (isAccepted || isInProgress) && _otpCode != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D1035), Color(0xFF0D1B3E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5)),
                  boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.15), blurRadius: 20)],
                ),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.shield_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('ServiceHive Verification OTP', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 16),
                  Text('Show this to the customer', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12)),
                  const SizedBox(height: 10),
                  // Card has 24px screen padding + 20px internal padding on
                  // each side, so available width for the digit boxes is
                  // narrower than the full screen — fixed 44px boxes + 10px
                  // margins overflowed on smaller phones; size dynamically.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final digits = _otpCode!.split('');
                      const hMargin = 5.0;
                      final boxSize = ((constraints.maxWidth - hMargin * 2 * digits.length) / digits.length)
                          .clamp(32.0, 44.0);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: digits.map((c) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: hMargin),
                          width: boxSize, height: boxSize * 56 / 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                          ),
                          child: Center(child: Text(c, style: GoogleFonts.inter(color: Colors.white, fontSize: boxSize * 24 / 44, fontWeight: FontWeight.w900))),
                        )).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _otpCode!));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('OTP copied!', style: GoogleFonts.inter(color: Colors.white)),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ));
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.copy_rounded, color: AppColors.textDim, size: 14),
                      const SizedBox(width: 6),
                      Text('Copy OTP', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Customer info
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Customer', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(children: [
                  GestureDetector(
                    onTap: () => context.push('/customer/${req.customerId}'),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        image: (_customerAvatarUrl != null)
                            ? DecorationImage(image: CachedNetworkImageProvider(_customerAvatarUrl!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _customerAvatarUrl == null
                          ? Center(child: Text(
                              req.customerName.isNotEmpty ? req.customerName[0].toUpperCase() : '?',
                              style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18),
                            ))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(req.customerName, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(req.customerPhone, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                  ])),
                ]),
              ]),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Job details
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Job Details', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _Row('Service', req.serviceName),
                _Row('Area', '${req.area}, ${req.city}'),
                _Row('Address', req.address),
                const SizedBox(height: 6),
                Text('Problem', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(req.description, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.5)),
              ]),
            ),
          ),
        ),

        if (isCompleted) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
                  const SizedBox(width: 10),
                  Text('Job Completed!', style: GoogleFonts.inter(color: AppColors.success, fontSize: 15, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
      ),
    );
  }

  bool get _otpVerified => _request?.otpVerified == true;

  Widget get _bottomBar {
    if (_request?.status == 'completed') {
      // Previously this returned nothing at all — the provider was left
      // stranded on a static "Job Completed!" screen with no way forward,
      // and the back button just returned to the bid screen instead of
      // taking them anywhere useful.
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: GestureDetector(
          // Always go() to the dashboard rather than pop() — popping would
          // land back on whatever pushed this screen (often the bid-editing
          // page), which makes no sense to see again once the job is done.
          onTap: () => context.go('/provider-dashboard'),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 15)],
            ),
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Back to Jobs', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Live map button
        GestureDetector(
          onTap: _openMap,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.map_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Text('Live Map & Navigation', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
            ])),
          ),
        ),
        const SizedBox(height: 10),
        // Mark complete button — disabled until the customer verifies the
        // provider's OTP (otpVerified), matching the DB-side guard in
        // RequestProvider.markJobComplete which no-ops without it.
        GestureDetector(
          onTap: _completing ? null : _markComplete,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: (_completing || !_otpVerified) ? null : const LinearGradient(colors: [AppColors.success, Color(0xFF059669)]),
              color: (_completing || !_otpVerified) ? AppColors.surface2 : null,
              borderRadius: BorderRadius.circular(100),
              boxShadow: (_completing || !_otpVerified) ? [] : [BoxShadow(color: AppColors.success.withValues(alpha: 0.3), blurRadius: 15)],
            ),
            child: Center(
              child: _completing
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_otpVerified ? Icons.check_circle_rounded : Icons.lock_rounded, color: _otpVerified ? Colors.white : AppColors.textDim, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        _otpVerified ? 'Mark Job Complete' : 'Verify OTP to Complete',
                        style: GoogleFonts.inter(color: _otpVerified ? Colors.white : AppColors.textDim, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ]),
            ),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = _request?.status == 'completed';
    return PopScope(
      // Once the job is done, the system/gesture back button shouldn't pop
      // into whatever pushed this screen (often the bid-editing page) —
      // send the provider to the dashboard instead, matching the in-app
      // back arrow and "Back to Jobs" button.
      canPop: !isCompleted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isCompleted) context.go('/provider-dashboard');
      },
      child: Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : _request == null
              ? Center(child: Text('Job not found', style: GoogleFonts.inter(color: Colors.white)))
              : _buildContent(),
      // _bottomBar itself already branches on completed vs in-progress and
      // returns the right content either way — this used to also gate on
      // status != 'completed' here, which hid the "Back to Jobs" button
      // _bottomBar builds for the completed case, leaving the provider
      // stranded with no way forward after finishing a job.
      bottomNavigationBar: (!_loading && _request != null) ? _bottomBar : null,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 70, child: Text(label, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12))),
      Expanded(child: Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );
}
