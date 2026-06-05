import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<BookingProvider>().customerBookings('me');
    final active = all.where((b) => b.status == BookingStatus.pending || b.status == BookingStatus.accepted || b.status == BookingStatus.inProgress).toList();
    final completed = all.where((b) => b.status == BookingStatus.completed).toList();
    final other = all.where((b) => b.status == BookingStatus.cancelled || b.status == BookingStatus.rejected).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Bookings',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                    unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textDim,
                    tabs: [
                      Tab(text: 'Active (${active.length})'),
                      Tab(text: 'Done (${completed.length})'),
                      Tab(text: 'Other (${other.length})'),
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
                _BookingList(bookings: active, emptyMsg: 'No active bookings'),
                _BookingList(bookings: completed, emptyMsg: 'No completed bookings yet'),
                _BookingList(bookings: other, emptyMsg: 'No cancelled/rejected bookings'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final String emptyMsg;
  const _BookingList({required this.bookings, required this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded, color: AppColors.textDim, size: 48),
            const SizedBox(height: 12),
            Text(emptyMsg, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _BookingCard(booking: bookings[i]),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/booking/${booking.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: booking.status.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(booking.status.icon, color: booking.status.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.serviceType,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(booking.providerName,
                        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: booking.status.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(booking.status.label,
                    style: GoogleFonts.inter(color: booking.status.color, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _Meta(icon: Icons.calendar_today_rounded,
                  text: '${booking.scheduledDate.day}/${booking.scheduledDate.month}/${booking.scheduledDate.year}'),
                const SizedBox(width: 16),
                _Meta(icon: Icons.access_time_rounded, text: booking.timeSlot),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Meta(icon: Icons.currency_rupee_rounded,
                  text: booking.agreedPrice != null
                      ? 'Rs ${booking.agreedPrice!.toInt()} (agreed)'
                      : 'Rs ${booking.offeredPrice?.toInt() ?? 0} (offered)'),
                if (booking.rating != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 13),
                  const SizedBox(width: 3),
                  Text(booking.rating!.toStringAsFixed(1),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
            if (booking.status == BookingStatus.completed && booking.rating == null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.push('/review/${booking.id}'),
                child: Container(
                  width: double.infinity, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text('Rate this service ★',
                      style: GoogleFonts.inter(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: AppColors.textDim, size: 12),
      const SizedBox(width: 4),
      Text(text, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
    ],
  );
}
