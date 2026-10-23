import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';

class BookingDetailScreen extends StatelessWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>().getById(bookingId);
    if (booking == null) {
      return Scaffold(backgroundColor: AppColors.bg,
        body: Center(child: Text('Booking not found', style: GoogleFonts.inter(color: Colors.white))));
    }
    final isCustomer = booking.customerId == 'me';

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
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('Booking Detail', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),

          // Status hero
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: booking.status.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: booking.status.color.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: booking.status.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(booking.status.icon, color: booking.status.color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(booking.status.label,
                          style: GoogleFonts.inter(color: booking.status.color, fontSize: 16, fontWeight: FontWeight.w800),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(booking.serviceType,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('#${booking.id}',
                          style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Info cards
          _InfoCard(title: isCustomer ? 'Provider' : 'Customer', children: [
            _InfoRow('Name', isCustomer ? booking.providerName : booking.customerName),
            _InfoRow('Phone', isCustomer ? booking.providerPhone : booking.customerPhone),
          ]),

          _InfoCard(title: 'Booking Info', children: [
            _InfoRow('Service', booking.serviceType),
            _InfoRow('Date', '${booking.scheduledDate.day}/${booking.scheduledDate.month}/${booking.scheduledDate.year}'),
            _InfoRow('Time', booking.timeSlot),
            _InfoRow('Address', booking.address),
            _InfoRow('City', booking.city),
          ]),

          _InfoCard(title: 'Pricing', children: [
            _InfoRow('Offered Price', 'Rs ${booking.offeredPrice?.toInt() ?? 0}'),
            if (booking.agreedPrice != null)
              _InfoRow('Agreed Price', 'Rs ${booking.agreedPrice!.toInt()}', highlight: true),
          ]),

          _InfoCard(title: 'Description', children: [
            Text(booking.description, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.6), maxLines: 3, overflow: TextOverflow.ellipsis),
          ]),

          if (booking.rating != null)
            _InfoCard(title: 'Your Review', children: [
              Row(children: [
                ...List.generate(5, (i) => Icon(Icons.star_rounded,
                  color: i < booking.rating! ? const Color(0xFFFBBF24) : AppColors.border, size: 18)),
                const SizedBox(width: 8),
                Text(booking.rating!.toStringAsFixed(1),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              if (booking.review != null) ...[
                const SizedBox(height: 8),
                Text(booking.review!, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.5)),
              ],
            ]),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
        ),
      ),

      // Bottom actions
      bottomNavigationBar: _buildActions(context, booking, isCustomer),
    );
  }

  Widget _buildActions(BuildContext context, BookingModel booking, bool isCustomer) {
    final bp = context.read<BookingProvider>();

    if (isCustomer) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                // a job from a request uses the same chat as the bid, so both people see it
                onTap: () => context.push(booking.requestId != null && booking.acceptedBidId != null
                    ? '/service-request/${booking.requestId}/chat/${booking.acceptedBidId}'
                    : '/chat/${booking.id}'),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.surface2, borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('Chat', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
            if (booking.status == BookingStatus.pending || booking.status == BookingStatus.accepted) ...[
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    showDialog(context: context, builder: (_) => _ConfirmDialog(
                      title: 'Cancel Booking',
                      body: 'Are you sure you want to cancel this booking?',
                      confirmLabel: 'Cancel Booking',
                      confirmColor: AppColors.error,
                      onConfirm: () { bp.cancelBooking(booking.id); context.pop(); },
                    ));
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Center(child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w700))),
                  ),
                ),
              ),
            ],
            if (booking.status == BookingStatus.completed && booking.rating == null) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () => context.push('/review/${booking.id}'),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.warning, Color(0xFFD97706)]),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Center(child: Text('Rate Service ★', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800))),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Provider view (shouldn't reach here normally, but handle)
    return const SizedBox.shrink();
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
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
            Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool highlight;
  const _InfoRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 90, child: Text(label, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12))),
        Expanded(
          child: Text(value, style: GoogleFonts.inter(
            color: highlight ? AppColors.success : Colors.white,
            fontSize: 12, fontWeight: FontWeight.w600,
          )),
        ),
      ],
    ),
  );
}

class _ConfirmDialog extends StatelessWidget {
  final String title, body, confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;
  const _ConfirmDialog({required this.title, required this.body, required this.confirmLabel, required this.confirmColor, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(body, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.border)),
                    child: Center(child: Text('Back', style: GoogleFonts.inter(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(color: confirmColor, borderRadius: BorderRadius.circular(100)),
                    child: Center(child: Text(confirmLabel, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
