import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/provider_list_provider.dart';

class ProviderHomeTab extends StatelessWidget {
  const ProviderHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final prov = context.watch<ProviderListProvider>();
    final bp = context.watch<BookingProvider>();
    final pending = bp.pendingProviderBookings;
    final active = bp.activeProviderJobs;
    final unread = bp.unreadNotifCount;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Provider Dashboard', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                      Text(auth.user?.name.split(' ').first ?? 'Provider',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Stack(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                        child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                      ),
                      if (unread > 0)
                        Positioned(right: 8, top: 8,
                          child: Container(width: 8, height: 8,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error))),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // Online toggle card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: () => prov.toggleMyOnline(),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: prov.isOnline
                        ? const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF065F46)])
                        : null,
                    color: prov.isOnline ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: prov.isOnline ? AppColors.success.withOpacity(0.4) : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (prov.isOnline ? AppColors.success : AppColors.textDim).withOpacity(0.15),
                        ),
                        child: Icon(
                          prov.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                          color: prov.isOnline ? AppColors.success : AppColors.textDim,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(prov.isOnline ? 'You are Online' : 'You are Offline',
                            style: GoogleFonts.inter(
                              color: prov.isOnline ? AppColors.success : AppColors.textMuted,
                              fontSize: 16, fontWeight: FontWeight.w800)),
                          Text(prov.isOnline ? 'Customers can book you now' : 'Tap to go online & accept jobs',
                            style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11)),
                        ]),
                      ),
                      Switch.adaptive(
                        value: prov.isOnline,
                        onChanged: (_) => prov.toggleMyOnline(),
                        activeColor: AppColors.success,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Expanded(child: _StatCard(label: 'Total Jobs', value: '${bp.completedProviderJobs}', icon: Icons.work_outline_rounded, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'Earnings', value: 'Rs ${(bp.totalProviderEarnings / 1000).toStringAsFixed(1)}k', icon: Icons.payments_outlined, color: AppColors.success)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'Rating', value: bp.providerRating > 0 ? bp.providerRating.toStringAsFixed(1) : '—', icon: Icons.star_outline_rounded, color: const Color(0xFFFBBF24))),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Pending requests
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('New Requests', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  if (pending.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                      child: Text('${pending.length} new', style: GoogleFonts.inter(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          if (pending.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _EmptyCard(icon: Icons.inbox_rounded, message: 'No new requests right now'),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: _RequestTile(booking: pending[i]),
                ),
                childCount: pending.length > 2 ? 2 : pending.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Active jobs
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Active Jobs', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          if (active.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _EmptyCard(icon: Icons.work_outline_rounded, message: 'No active jobs'),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: _JobTile(booking: active[i]),
                ),
                childCount: active.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 8),
      Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      Text(label, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Center(child: Column(children: [
      Icon(icon, color: AppColors.textDim, size: 28),
      const SizedBox(height: 8),
      Text(message, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
    ])),
  );
}

class _RequestTile extends StatelessWidget {
  final BookingModel booking;
  const _RequestTile({required this.booking});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/provider/request/${booking.id}'),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.notification_important_rounded, color: AppColors.warning, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(booking.customerName, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(booking.serviceType, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Rs ${booking.offeredPrice?.toInt()}', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
          const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textDim, size: 12),
        ]),
      ]),
    ),
  );
}

class _JobTile extends StatelessWidget {
  final BookingModel booking;
  const _JobTile({required this.booking});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/provider/job/${booking.id}'),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: booking.status.color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: booking.status.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(booking.status.icon, color: booking.status.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(booking.customerName, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(booking.serviceType, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: booking.status.color.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
          child: Text(booking.status.label, style: GoogleFonts.inter(color: booking.status.color, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ]),
    ),
  );
}
