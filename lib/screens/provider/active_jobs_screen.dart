import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../services/ai_insights_service.dart';

class ActiveJobsScreen extends StatefulWidget {
  const ActiveJobsScreen({super.key});

  @override
  State<ActiveJobsScreen> createState() => _ActiveJobsScreenState();
}

class _ActiveJobsScreenState extends State<ActiveJobsScreen> {
  Timer? _refreshTimer;
  // job_id -> {risk, reason} — advisory only, computed after the active job
  // list renders so a slow/failed Groq call never delays the real screen.
  Map<String, dynamic> _riskById = {};
  String? _riskFetchedForIds;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user != null) await context.read<RequestProvider>().loadMyProviderJobs(user.id);
  }

  Future<void> _silentRefresh() async {
    if (!mounted) return;
    final user = context.read<AuthProvider>().user;
    if (user != null) await context.read<RequestProvider>().loadMyProviderJobs(user.id, silent: true);
  }

  Future<void> _fetchRisk(List<ServiceRequest> active) async {
    final key = active.map((r) => r.id).join(',');
    if (key == _riskFetchedForIds || active.isEmpty) return;
    _riskFetchedForIds = key;
    final result = await AiInsightsService.assessCancellationRiskML(active.map((r) => {
      'job_id': r.id,
      'hours_since_accepted': DateTime.now().difference(r.createdAt).inMinutes / 60.0,
      'otp_verified': r.otpVerified,
    }).toList());
    if (mounted && result != null) setState(() => _riskById = result);
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<RequestProvider>().myProviderJobs;
    final active = all.where((r) => r.status != 'completed').toList();
    final history = all.where((r) => r.status == 'completed').toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRisk(active));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                child: Text('My Jobs', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text('Active', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
            if (active.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: Center(child: Column(children: [
                      const Icon(Icons.pending_actions_rounded, color: AppColors.textDim, size: 32),
                      const SizedBox(height: 10),
                      Text('No active jobs right now', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                    ])),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: _JobCard(request: active[i], isActive: true, risk: _riskById[active[i].id]),
                  ),
                  childCount: active.length,
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Text('History', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),

            history.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                        child: Center(child: Column(children: [
                          const Icon(Icons.history_rounded, color: AppColors.textDim, size: 32),
                          const SizedBox(height: 10),
                          Text('No completed jobs yet', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                        ])),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: _JobCard(request: history[i], isActive: false),
                      ),
                      childCount: history.length,
                    ),
                  ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final ServiceRequest request;
  final bool isActive;
  final Map<String, dynamic>? risk;
  const _JobCard({required this.request, required this.isActive, this.risk});

  Color get _statusColor {
    switch (request.status) {
      case 'accepted':
      case 'confirmed': return AppColors.success;
      case 'in_progress': return AppColors.warning;
      case 'completed': return AppColors.success;
      default: return AppColors.primary;
    }
  }

  IconData get _statusIcon {
    switch (request.status) {
      case 'accepted':
      case 'confirmed': return Icons.check_circle_outline_rounded;
      case 'in_progress': return Icons.build_circle_rounded;
      case 'completed': return Icons.task_alt_rounded;
      default: return Icons.circle_outlined;
    }
  }

  String get _statusLabel {
    switch (request.status) {
      case 'accepted': return 'Accepted';
      case 'confirmed': return 'Confirmed';
      case 'in_progress': return 'In Progress';
      case 'completed': return 'Completed';
      default: return request.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;
    return GestureDetector(
      onTap: () => context.push('/provider/service-job/${request.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isActive ? statusColor.withValues(alpha: 0.3) : AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(_statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(request.serviceName, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(request.customerName, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(100)),
              child: Text(_statusLabel, style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.location_on_rounded, color: AppColors.textDim, size: 12),
            const SizedBox(width: 4),
            Expanded(child: Text('${request.area}, ${request.city}', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          if (isActive && risk != null && risk!['risk'] != 'low') ...[
            const SizedBox(height: 10),
            Builder(builder: (_) {
              final isHigh = risk!['risk'] == 'high';
              final color = isHigh ? AppColors.error : AppColors.warning;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: color, size: 14),
                  const SizedBox(width: 6),
                  Text('${isHigh ? "High" : "Medium"} cancellation risk',
                      style: GoogleFonts.inter(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ]),
              );
            }),
          ],
          if (request.rating != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              ...List.generate(5, (i) => Icon(Icons.star_rounded,
                color: i < request.rating!.round() ? const Color(0xFFFBBF24) : AppColors.border, size: 14)),
              const SizedBox(width: 6),
              Text(request.rating!.toStringAsFixed(1),
                style: GoogleFonts.inter(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
              if (request.review != null && request.review!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(child: Text('"${request.review}"',
                  style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11, fontStyle: FontStyle.italic),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ]),
          ],
        ]),
      ),
    );
  }
}
