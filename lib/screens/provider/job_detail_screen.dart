import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';

class JobDetailScreen extends StatelessWidget {
  final String bookingId;
  const JobDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>().getById(bookingId);
    if (booking == null) {
      return Scaffold(backgroundColor: AppColors.bg,
        body: Center(child: Text('Job not found', style: GoogleFonts.inter(color: Colors.white))));
    }

    final steps = [
      (label: 'Request Sent', done: true),
      (label: 'Accepted', done: booking.status != BookingStatus.pending && booking.status != BookingStatus.rejected),
      (label: 'In Progress', done: booking.status == BookingStatus.inProgress || booking.status == BookingStatus.completed),
      (label: 'Completed', done: booking.status == BookingStatus.completed),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Text('Job Detail', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),

          // Status progress
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Job Progress', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Row(children: List.generate(steps.length, (i) {
                    final s = steps[i];
                    return Expanded(
                      child: Row(children: [
                        Column(children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: s.done ? AppColors.primary : AppColors.surface3,
                              border: Border.all(color: s.done ? AppColors.primary : AppColors.border, width: 2),
                            ),
                            child: s.done ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 60,
                            child: Text(s.label,
                              style: GoogleFonts.inter(color: s.done ? Colors.white : AppColors.textDim, fontSize: 9, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center),
                          ),
                        ]),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: steps[i + 1].done ? AppColors.primary : AppColors.border,
                              margin: const EdgeInsets.only(bottom: 22),
                            ),
                          ),
                      ]),
                    );
                  })),
                ]),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // Customer info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Customer', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1)),
                      child: Center(child: Text(booking.customerName[0],
                        style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(booking.customerName, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(booking.customerPhone, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/chat/${booking.id}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
                        child: Row(children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 14),
                          const SizedBox(width: 6),
                          Text('Chat', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Job info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Row('Service', booking.serviceType),
                  _Row('Date', '${booking.scheduledDate.day}/${booking.scheduledDate.month}/${booking.scheduledDate.year}'),
                  _Row('Time', booking.timeSlot),
                  _Row('Address', booking.address),
                  _Row('Payment', 'Rs ${(booking.agreedPrice ?? booking.offeredPrice ?? 0).toInt()}', valueColor: AppColors.success),
                ]),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Problem Description', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Text(booking.description, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.6)),
                ]),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      bottomNavigationBar: _buildActions(context, booking),
    );
  }

  Widget _buildActions(BuildContext context, BookingModel booking) {
    final bp = context.read<BookingProvider>();

    if (booking.status == BookingStatus.accepted) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
        child: GestureDetector(
          onTap: () => bp.startJob(booking.id),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 15)],
            ),
            child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text('Start Job', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ])),
          ),
        ),
      );
    }

    if (booking.status == BookingStatus.inProgress) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
        child: GestureDetector(
          onTap: () => bp.completeJob(booking.id),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.success, Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.3), blurRadius: 15)],
            ),
            child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text('Mark as Completed', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ])),
          ),
        ),
      );
    }

    if (booking.status == BookingStatus.completed) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
          const SizedBox(width: 8),
          Text('Job Completed — Rs ${(booking.agreedPrice ?? booking.offeredPrice ?? 0).toInt()} earned',
            style: GoogleFonts.inter(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      );
    }

    return const SizedBox.shrink();
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _Row(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      SizedBox(width: 80, child: Text(label, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12))),
      Expanded(child: Text(value, style: GoogleFonts.inter(color: valueColor ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );
}
