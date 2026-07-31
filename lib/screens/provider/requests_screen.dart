import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/provider_list_provider.dart';
import '../../providers/request_provider.dart';
import '../../services/avatar_cache.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  String? _serviceType;
  bool _loadingProfile = true;
  String? _profileError;
  List<ServiceRequest> _activeJobs = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initProvider();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    context.read<RequestProvider>().unsubscribeFromAvailableRequests();
    super.dispose();
  }

  Future<void> _initProvider() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      setState(() { _loadingProfile = false; _profileError = 'Not logged in'; });
      return;
    }

    if (user.city.isEmpty || user.area.isEmpty) {
      setState(() { _loadingProfile = false; _profileError = 'City/area not set in profile'; });
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('provider_profiles')
          .select('service_type')
          .eq('id', user.id)
          .maybeSingle();
      _serviceType = data?['service_type'] as String?;
      if (_serviceType != null && _serviceType!.isEmpty) _serviceType = null;
    } catch (_) {
      _serviceType = null;
    }

    if (!mounted) return;
    setState(() => _loadingProfile = false);

    final rp = context.read<RequestProvider>();
    final jobs = await rp.fetchProviderActiveJobs(user.id);
    if (mounted) setState(() => _activeJobs = jobs);

    await rp.loadAvailableRequests(
      city: user.city,
      area: user.area,
      serviceType: _serviceType,
    );
    await rp.subscribeToAvailableRequests(
      city: user.city,
      area: user.area,
      serviceType: _serviceType,
    );

    // Polling every 10 seconds as backup to Realtime
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      final u = context.read<AuthProvider>().user;
      if (u == null) return;
      final updatedJobs = await rp.fetchProviderActiveJobs(u.id);
      if (mounted) setState(() => _activeJobs = updatedJobs);
      await rp.loadAvailableRequests(
        city: u.city,
        area: u.area,
        serviceType: _serviceType,
        silent: true,
      );
    });
  }

  Future<void> _refresh() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || _serviceType == null) return;
    final rp = context.read<RequestProvider>();
    final jobs = await rp.fetchProviderActiveJobs(user.id);
    if (mounted) setState(() => _activeJobs = jobs);
    await rp.loadAvailableRequests(
      city: user.city,
      area: user.area,
      serviceType: _serviceType!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RequestProvider>();
    final requests = rp.availableRequests;
    final user = context.watch<AuthProvider>().user;
    final isOnline = context.watch<ProviderListProvider>().isOnline;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('New Requests', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text('${user?.area ?? ''}, ${user?.city ?? ''}', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
              ]),
            ),
            if (!_loadingProfile && isOnline && requests.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.primary.withValues(alpha:0.3)),
                ),
                child: Text('${requests.length} open', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),

        // Service type chip
        if (_serviceType != null && isOnline)
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha:0.08),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.success.withValues(alpha:0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success)),
                  const SizedBox(width: 7),
                  Text(_serviceType!, style: GoogleFonts.inter(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 8),
              Text('requests only', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12)),
            ]),
          ),

        // Body
        Expanded(
          child: _loadingProfile
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
              : !isOnline
                  ? _OfflineState()
                  : _profileError != null
                  ? _ErrorState(message: _profileError!)
                  : _serviceType == null
                  ? _ErrorState(message: 'Set your specialization in your profile to start receiving matching requests.')
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                        children: [
                          // Active jobs section
                          if (_activeJobs.isNotEmpty) ...[
                            Text('Your Active Jobs', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            ..._activeJobs.map((job) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ActiveJobCard(job: job),
                            )),
                            const SizedBox(height: 16),
                            const Divider(color: AppColors.border),
                            const SizedBox(height: 12),
                          ],

                          // Available requests section
                          if (requests.isEmpty)
                            _EmptyState(serviceType: _serviceType ?? '')
                          else ...[
                            if (_activeJobs.isNotEmpty)
                              Text('New Requests', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                            if (_activeJobs.isNotEmpty) const SizedBox(height: 10),
                            ...requests.map((req) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _RequestCard(request: req),
                            )),
                          ],
                        ],
                      ),
                    ),
        ),
      ]),
    );
  }
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
          color: color.withValues(alpha:0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha:0.35)),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha:0.12)),
            child: Icon(isInProgress ? Icons.build_circle_rounded : Icons.check_circle_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(job.serviceName, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(job.customerName, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(100)),
              child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textDim, size: 12),
          ]),
        ]),
      ),
    );
  }
}

// ── Request Card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatefulWidget {
  final ServiceRequest request;
  const _RequestCard({required this.request});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  String? _customerAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadCustomerAvatar();
  }

  Future<void> _loadCustomerAvatar() async {
    final url = await AvatarCache.getAvatar(widget.request.customerId);
    if (mounted && url != null) {
      setState(() => _customerAvatarUrl = url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return GestureDetector(
      onTap: () => context.push('/provider/service-request/${request.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row
          Row(children: [
            GestureDetector(
              onTap: () => context.push('/customer/${request.customerId}'),
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha:0.08),
                  border: Border.all(color: AppColors.primary.withValues(alpha:0.2)),
                  image: (_customerAvatarUrl != null)
                      ? DecorationImage(image: CachedNetworkImageProvider(_customerAvatarUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: _customerAvatarUrl == null
                    ? Center(child: Text(
                        request.customerName.isNotEmpty ? request.customerName[0].toUpperCase() : '?',
                        style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18),
                      ))
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(request.customerName, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(children: [
                const Icon(Icons.location_on_rounded, color: AppColors.textDim, size: 12),
                const SizedBox(width: 3),
                Flexible(child: Text('${request.area}, ${request.city}', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha:0.08),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.primary.withValues(alpha:0.2)),
                ),
                child: Text(request.serviceName, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 4),
              Text(_timeAgo(request.createdAt), style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10)),
            ]),
          ]),

          const SizedBox(height: 12),

          // Description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
            child: Text(
              request.description,
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          if (request.imageUrl != null && request.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(imageUrl: request.imageUrl!, height: 130, width: double.infinity, fit: BoxFit.cover),
            ),
          ],

          const SizedBox(height: 12),

          // CTA button
          Container(
            width: double.infinity,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha:0.25), blurRadius: 10)],
            ),
            child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.gavel_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('View & Bid', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ])),
          ),
        ]),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Offline state ─────────────────────────────────────────────────────────────

class _OfflineState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 70, height: 70,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.textDim.withValues(alpha: 0.1)),
        child: const Icon(Icons.wifi_off_rounded, color: AppColors.textDim, size: 34),
      ),
      const SizedBox(height: 16),
      Text('You are Offline', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Go online to start receiving\nservice requests.', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
    ]),
  );
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String serviceType;
  const _EmptyState({required this.serviceType});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.inbox_rounded, color: AppColors.textDim, size: 52),
      const SizedBox(height: 14),
      Text('No requests right now', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('Customers in your area will post\n$serviceType requests here.', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, height: 1.5), textAlign: TextAlign.center),
    ]),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 44),
        const SizedBox(height: 14),
        Text('Profile Incomplete', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(message, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, height: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Please update your profile to see requests.', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, height: 1.5), textAlign: TextAlign.center),
      ]),
    ),
  );
}
