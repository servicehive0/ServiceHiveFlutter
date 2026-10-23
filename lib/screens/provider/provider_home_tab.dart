import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/provider_list_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/live_location_required_sheet.dart';
import 'earnings_screen.dart';
import 'jobs_history_screen.dart';
import 'rating_history_screen.dart';

class ProviderHomeTab extends StatefulWidget {
  final VoidCallback? onGoToRequests;
  const ProviderHomeTab({super.key, this.onGoToRequests});

  @override
  State<ProviderHomeTab> createState() => _ProviderHomeTabState();
}

class _ProviderHomeTabState extends State<ProviderHomeTab> {
  Map<String, dynamic>? _profile;
  List<ServiceRequest> _activeJobs = [];
  bool _initDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) { setState(() => _initDone = true); return; }
    final requests = context.read<RequestProvider>();

    try {
      final profileData = await Supabase.instance.client
          .from('provider_profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      final jobs = await requests.fetchProviderActiveJobs(user.id);
      if (mounted) await requests.loadMyProviderJobs(user.id, silent: true);

      if (mounted) setState(() { _profile = profileData; _activeJobs = jobs; _initDone = true; });
    } catch (_) {
      if (mounted) setState(() => _initDone = true);
    }
  }

  Future<void> _refresh() async {
    setState(() => _initDone = false);
    await _init();
  }

  // Going online promises customers a provider who can actually be found —
  // that only works if live location is on. Only gate the ON direction; a
  // provider can always go back offline freely.
  Future<void> _toggleOnline() async {
    final auth = context.read<AuthProvider>();
    final prov = context.read<ProviderListProvider>();
    final userId = auth.user?.id ?? '';

    if (!prov.isOnline && !auth.liveLocationEnabled) {
      final enabled = await requireLiveLocation(context, reason: 'before you can go online');
      if (!enabled || !mounted) return;
    }
    prov.toggleMyOnline(userId);
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final prov   = context.watch<ProviderListProvider>();
    final myJobs = context.watch<RequestProvider>().myProviderJobs;
    final bp     = context.watch<BookingProvider>();
    final user   = auth.user;

    // Rating/jobs-done are computed live from completed service_requests —
    // provider_profiles.rating/total_jobs are legacy columns from the old
    // bookings flow and are never updated by the new bidding system.
    final completedJobs = myJobs.where((r) => r.status == 'completed').toList();
    final ratedJobs = completedJobs.where((r) => r.rating != null).toList();
    final rating = ratedJobs.isEmpty
        ? 0.0
        : ratedJobs.fold<double>(0, (sum, r) => sum + r.rating!) / ratedJobs.length;
    final totalJobs = completedJobs.length;
    final totalEarned = bp.totalProviderEarnings;
    final svcType  = _profile?['service_type'] as String? ?? '—';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.16),
                      AppColors.bg.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Row(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 54, height: 54,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: prov.isOnline
                              ? [AppColors.success, const Color(0xFF34D399)]
                              : [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.bg,
                          image: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                              ? DecorationImage(image: CachedNetworkImageProvider(user.avatarUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
                            ? Center(
                                child: Text(
                                  (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19),
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      right: -1, bottom: -1,
                      child: Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: prov.isOnline ? AppColors.success : AppColors.textDim,
                          border: Border.all(color: AppColors.bg, width: 2.5),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Provider Dashboard',
                      style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                    const SizedBox(height: 3),
                    Text(user?.name.split(' ').first ?? 'Provider',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                    if (svcType != '—') ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: Text(svcType,
                          style: GoogleFonts.inter(color: AppColors.primaryLight, fontSize: 10.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ])),
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                      ),
                      if (context.watch<NotificationsProvider>().unreadCount > 0)
                        Positioned(
                          right: -2, top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.bg, width: 2)),
                            constraints: const BoxConstraints(minWidth: 18),
                            child: Text('${context.watch<NotificationsProvider>().unreadCount}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),

            // ── Online / Offline Toggle ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _OnlineToggleCard(isOnline: prov.isOnline, onTap: _toggleOnline),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Stats ────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  Expanded(child: _StatCard(
                    label: 'Rating',
                    value: rating > 0 ? rating.toStringAsFixed(1) : '—',
                    icon: Icons.star_rounded,
                    color: const Color(0xFFFBBF24),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RatingHistoryScreen())),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    label: 'Jobs Done',
                    value: '$totalJobs',
                    icon: Icons.work_rounded,
                    color: AppColors.primaryLight,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobsHistoryScreen())),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    label: 'Total Earned',
                    value: totalEarned > 0 ? 'Rs ${totalEarned.toInt()}' : '—',
                    icon: Icons.payments_rounded,
                    color: AppColors.success,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen())),
                  )),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Go to Requests banner ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: () => widget.onGoToRequests?.call(),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(children: [
                        Positioned(
                          right: -24, top: -34,
                          child: Container(
                            width: 120, height: 120,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
                          ),
                        ),
                        Positioned(
                          right: 14, bottom: -30,
                          child: Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
                          ),
                        ),
                        Row(children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.5),
                            ),
                            child: const Icon(Icons.inbox_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('New Service Requests',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('Tap to view & bid on customer requests',
                              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5, fontWeight: FontWeight.w500)),
                          ])),
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 26)),

            // ── Active Jobs ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Active Jobs',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                    if (_activeJobs.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                        ),
                        child: Text('${_activeJobs.length} active',
                          style: GoogleFonts.inter(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            if (!_initDone)
              const SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )),
              )
            else if (_activeJobs.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _EmptyCard(icon: Icons.work_outline_rounded, message: 'No active jobs yet'),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: _ActiveJobCard(job: _activeJobs[i]),
                  ),
                  childCount: _activeJobs.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// ── Online / Offline Toggle Card ────────────────────────────────────────────

class _OnlineToggleCard extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onTap;
  const _OnlineToggleCard({required this.isOnline, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = isOnline ? AppColors.success : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: isOnline
              ? const LinearGradient(
                  colors: [Color(0xFF0B3B2E), Color(0xFF0A2E28)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                )
              : null,
          color: isOnline ? null : Colors.white.withValues(alpha: 0.035),
          border: Border.all(
            color: isOnline ? AppColors.success.withValues(alpha: 0.4) : AppColors.border,
            width: isOnline ? 1.4 : 1,
          ),
          boxShadow: isOnline
              ? [BoxShadow(color: AppColors.success.withValues(alpha: 0.22), blurRadius: 28, offset: const Offset(0, 10))]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(children: [
            if (isOnline)
              Positioned(
                right: -30, top: -30,
                child: Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.success.withValues(alpha: 0.10)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                // Pulsing status icon
                _PulseIcon(active: isOnline, color: accent),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        isOnline ? 'You\'re Online' : 'You\'re Offline',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOnline) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text('LIVE', style: GoogleFonts.inter(color: const Color(0xFF6EE7B7), fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    isOnline
                        ? 'Customers can find & request you now'
                        : 'Go online to start receiving requests',
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
                  ),
                ])),
                const SizedBox(width: 8),
                _StatusSwitch(value: isOnline, onChanged: (_) => onTap()),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PulseIcon extends StatefulWidget {
  final bool active;
  final Color color;
  const _PulseIcon({required this.active, required this.color});

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52, height: 52,
      child: Stack(alignment: Alignment.center, children: [
        if (widget.active)
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = _ctrl.value;
              return Container(
                width: 52 * (0.7 + t * 0.5),
                height: 52 * (0.7 + t * 0.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: (1 - t) * 0.25),
                ),
              );
            },
          ),
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: widget.active
                  ? [AppColors.success, const Color(0xFF059669)]
                  : [AppColors.surface3, AppColors.surface2],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            border: Border.all(color: widget.active ? AppColors.success.withValues(alpha: 0.5) : AppColors.border),
          ),
          child: Icon(
            widget.active ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: widget.active ? Colors.white : AppColors.textDim,
            size: 21,
          ),
        ),
      ]),
    );
  }
}

// Custom pill switch — larger touch target and a smoother sliding thumb than
// the default platform Switch, to match the redesigned card around it.
class _StatusSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _StatusSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 52, height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          gradient: value
              ? const LinearGradient(colors: [AppColors.success, Color(0xFF059669)])
              : null,
          color: value ? null : Colors.white.withValues(alpha: 0.12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2))],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.02)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.18),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(height: 11),
        Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
        const SizedBox(height: 1),
        Text(label, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ── Empty Card ────────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Center(child: Column(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.04)),
        child: Icon(icon, color: AppColors.textDim, size: 24),
      ),
      const SizedBox(height: 12),
      Text(message, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w500)),
    ])),
  );
}

// ── Active Job Card ───────────────────────────────────────────────────────────

class _ActiveJobCard extends StatelessWidget {
  final ServiceRequest job;
  const _ActiveJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final isInProgress = job.status == 'in_progress';
    final color = isInProgress ? const Color(0xFFF59E0B) : AppColors.success;
    final label = isInProgress ? 'IN PROGRESS' : 'ACCEPTED';

    return GestureDetector(
      onTap: () => context.push('/provider/service-job/${job.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.02)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.1)],
              ),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(
              isInProgress ? Icons.build_circle_rounded : Icons.check_circle_rounded,
              color: color, size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(job.serviceName,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${job.customerName} • ${job.area}',
              style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11.5, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(label,
                style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textDim, size: 12),
          ]),
        ]),
      ),
    );
  }
}
