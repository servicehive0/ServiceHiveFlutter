import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pending = context.watch<BookingProvider>().pendingProviderBookings;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
            child: Row(
              children: [
                Expanded(child: Text('New Requests', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))),
                if (pending.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.error.withOpacity(0.3))),
                    child: Text('${pending.length} pending', style: GoogleFonts.inter(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: pending.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.inbox_rounded, color: AppColors.textDim, size: 52),
                      const SizedBox(height: 14),
                      Text('No pending requests', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text('Go online to start receiving requests', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12)),
                    ]),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    itemCount: pending.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _RequestCard(booking: pending[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final BookingModel booking;
  const _RequestCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/provider/request/${booking.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Center(child: Text(booking.customerName[0],
                style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(booking.customerName, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text(booking.city, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Rs ${booking.offeredPrice?.toInt()}', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w800)),
              Text('offered', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10)),
            ]),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
            child: Text(booking.description, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _Meta(icon: Icons.calendar_today_rounded, text: '${booking.scheduledDate.day}/${booking.scheduledDate.month}/${booking.scheduledDate.year}'),
            const SizedBox(width: 14),
            _Meta(icon: Icons.access_time_rounded, text: booking.timeSlot),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  context.read<BookingProvider>().rejectBooking(booking.id);
                },
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.error.withOpacity(0.3))),
                  child: Center(child: Text('Reject', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 13))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => context.push('/provider/request/${booking.id}'),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Center(child: Text('View & Accept', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: AppColors.textDim, size: 12),
    const SizedBox(width: 4),
    Text(text, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
  ]);
}
