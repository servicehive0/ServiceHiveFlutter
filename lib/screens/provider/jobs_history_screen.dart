import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';

class JobsHistoryScreen extends StatelessWidget {
  const JobsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookingProvider>();
    final completed = bp.providerBookings('me_provider')
        .where((b) => b.status == BookingStatus.completed)
        .toList()
      ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: () async {
          final user = context.read<AuthProvider>().user;
          if (user != null) await context.read<BookingProvider>().load(user.id, user.role);
        },
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 56, 24, 20),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 4),
                Text('Jobs Done', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),

          // Total card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)]),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total Jobs Completed', style: GoogleFonts.inter(color: AppColors.primaryLight, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('${completed.length}',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('All Completed Jobs', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          completed.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                      child: Center(child: Column(children: [
                        const Icon(Icons.work_outline_rounded, color: AppColors.textDim, size: 32),
                        const SizedBox(height: 10),
                        Text('No completed jobs yet', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                      ])),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                      child: _JobTile(booking: completed[i]),
                    ),
                    childCount: completed.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
        ),
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  final BookingModel booking;
  const _JobTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(booking.serviceType, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(booking.customerName, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Rs ${(booking.agreedPrice ?? booking.offeredPrice ?? 0).toInt()}',
            style: GoogleFonts.inter(color: AppColors.success, fontSize: 14, fontWeight: FontWeight.w800)),
          Text('${booking.scheduledDate.day}/${booking.scheduledDate.month}/${booking.scheduledDate.year}',
            style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10)),
        ]),
      ]),
    );
  }
}
