import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/rating_dialog.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
    // Same on-the-spot polling pattern used on the Home tab — the bidding
    // flow (open → accepted → in_progress → completed) has no dedicated
    // realtime channel yet, so poll quietly instead of making the user
    // pull-to-refresh to see a request they just posted or that just got
    // accepted.
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user != null) await context.read<RequestProvider>().loadMyRequests(user.id);
  }

  Future<void> _silentRefresh() async {
    if (!mounted) return;
    final user = context.read<AuthProvider>().user;
    if (user != null) await context.read<RequestProvider>().loadMyRequests(user.id, silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<RequestProvider>().myRequests;
    final active = all.where((r) => r.status != 'completed').toList();
    final completed = all.where((r) => r.status == 'completed').toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.12),
                    AppColors.bg.withOpacity(0),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('My Bookings',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                          const SizedBox(height: 2),
                          Text('${all.length} total booking${all.length == 1 ? '' : 's'}',
                            style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _load,
                        child: Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.calendar_month_rounded, color: AppColors.primaryLight, size: 19),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TabBar(
                      controller: _tabCtrl,
                      indicator: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      splashBorderRadius: BorderRadius.circular(12),
                      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12.5),
                      unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.5),
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.textDim,
                      tabs: [
                        Tab(text: 'Active (${active.length})'),
                        Tab(text: 'Done (${completed.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _RequestList(requests: active, emptyMsg: 'No active bookings', emptyIcon: Icons.pending_actions_rounded, onRefresh: _load),
                  _RequestList(requests: completed, emptyMsg: 'No completed bookings yet', emptyIcon: Icons.task_alt_rounded, onRefresh: _load),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  final List<ServiceRequest> requests;
  final String emptyMsg;
  final IconData emptyIcon;
  final Future<void> Function() onRefresh;
  const _RequestList({required this.requests, required this.emptyMsg, required this.emptyIcon, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84, height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [AppColors.primary.withOpacity(0.16), AppColors.primary.withOpacity(0.04)],
                        ),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Icon(emptyIcon, color: AppColors.primaryLight, size: 34),
                    ),
                    const SizedBox(height: 20),
                    Text(emptyMsg, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Your bookings will show up here.',
                      style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _RequestCard(request: requests[i]),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ServiceRequest request;
  const _RequestCard({required this.request});

  Color get _statusColor {
    switch (request.status) {
      case 'open': return AppColors.primary;
      case 'accepted':
      case 'confirmed': return AppColors.success;
      case 'in_progress': return AppColors.warning;
      case 'completed': return AppColors.success;
      default: return AppColors.textDim;
    }
  }

  IconData get _statusIcon {
    switch (request.status) {
      case 'open': return Icons.hourglass_empty_rounded;
      case 'accepted':
      case 'confirmed': return Icons.check_circle_outline_rounded;
      case 'in_progress': return Icons.build_circle_rounded;
      case 'completed': return Icons.task_alt_rounded;
      default: return Icons.circle_outlined;
    }
  }

  String get _statusLabel {
    switch (request.status) {
      case 'open': return 'Finding Providers';
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
      onTap: () => context.push('/service-request/${request.id}/bids'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.025),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [statusColor.withOpacity(0.22), statusColor.withOpacity(0.06)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Icon(_statusIcon, color: statusColor, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.serviceName,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(request.description,
                        style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(_statusLabel,
                    style: GoogleFonts.inter(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.w800),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            Row(
              children: [
                _Meta(icon: Icons.location_on_rounded, text: '${request.area}, ${request.city}'),
                const SizedBox(width: 18),
                _Meta(icon: Icons.calendar_today_rounded,
                  text: '${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year}'),
              ],
            ),
            if (request.status == 'completed') ...[
              const SizedBox(height: 14),
              if (request.rating != null)
                Row(children: [
                  ...List.generate(5, (i) => Icon(Icons.star_rounded,
                    color: i < request.rating!.round() ? const Color(0xFFFBBF24) : AppColors.border, size: 16)),
                  const SizedBox(width: 8),
                  Text(request.rating!.toStringAsFixed(1),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ])
              else
                GestureDetector(
                  onTap: () => _openRatingDialog(context),
                  child: Container(
                    width: double.infinity, height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.warning.withOpacity(0.16), AppColors.warning.withOpacity(0.06)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, color: AppColors.warning, size: 15),
                          const SizedBox(width: 6),
                          Text('Rate this service',
                            style: GoogleFonts.inter(color: AppColors.warning, fontSize: 12.5, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _openRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => RatingDialog(requestId: request.id),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        Icon(icon, color: AppColors.textDim, size: 12),
        const SizedBox(width: 4),
        Expanded(child: Text(text, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}
