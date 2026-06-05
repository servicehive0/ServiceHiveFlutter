import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';

class ActiveJobsScreen extends StatelessWidget {
  const ActiveJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookingProvider>();
    final active = bp.activeProviderJobs;
    final history = bp.providerBookings('me_provider')
        .where((b) => b.status == BookingStatus.completed || b.status == BookingStatus.rejected)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
              child: Text('My Jobs', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ),

          if (active.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text('Active', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: _JobCard(booking: active[i], isActive: true),
                ),
                childCount: active.length,
              ),
            ),
          ],

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
                      child: _JobCard(booking: history[i], isActive: false),
                    ),
                    childCount: history.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final BookingModel booking;
  final bool isActive;
  const _JobCard({required this.booking, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/provider/job/${booking.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isActive ? booking.status.color.withOpacity(0.3) : AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: booking.status.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(booking.status.icon, color: booking.status.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(booking.serviceType, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text(booking.customerName, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: booking.status.color.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                child: Text(booking.status.label, style: GoogleFonts.inter(color: booking.status.color, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              Text('Rs ${(booking.agreedPrice ?? booking.offeredPrice ?? 0).toInt()}',
                style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ]),
          const SizedBox(height: 10),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.location_on_rounded, color: AppColors.textDim, size: 12),
            const SizedBox(width: 4),
            Expanded(child: Text(booking.address, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          if (booking.rating != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              ...List.generate(5, (i) => Icon(Icons.star_rounded,
                color: i < booking.rating! ? const Color(0xFFFBBF24) : AppColors.border, size: 14)),
              const SizedBox(width: 6),
              Text(booking.review ?? '', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ],
        ]),
      ),
    );
  }
}
