import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookingProvider>();
    final completed = bp.providerBookings('me_provider')
        .where((b) => b.status == BookingStatus.completed)
        .toList();
    final total = bp.totalProviderEarnings;
    final thisMonth = completed.where((b) => b.scheduledDate.month == DateTime.now().month).fold(0.0, (s, b) => s + (b.agreedPrice ?? b.offeredPrice ?? 0));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
              child: Text('Earnings', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ),

          // Total card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF065F46)]),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total Lifetime Earnings', style: GoogleFonts.inter(color: AppColors.success.withOpacity(0.8), fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('Rs ${total.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 20),
                  Row(children: [
                    _EarnStat(label: 'This Month', value: 'Rs ${thisMonth.toInt()}', color: const Color(0xFF34D399)),
                    Container(width: 1, height: 32, color: Colors.white.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 20)),
                    _EarnStat(label: 'Jobs Done', value: '${completed.length}', color: const Color(0xFF34D399)),
                    Container(width: 1, height: 32, color: Colors.white.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 20)),
                    _EarnStat(label: 'Rating', value: bp.providerRating > 0 ? '${bp.providerRating.toStringAsFixed(1)} ★' : '—', color: const Color(0xFFFBBF24)),
                  ]),
                ]),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Transaction History', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
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
                        const Icon(Icons.receipt_long_rounded, color: AppColors.textDim, size: 32),
                        const SizedBox(height: 10),
                        Text('No transactions yet', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                      ])),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                      child: _TransactionTile(booking: completed[i]),
                    ),
                    childCount: completed.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _EarnStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _EarnStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: GoogleFonts.inter(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
    Text(label, style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 10)),
  ]);
}

class _TransactionTile extends StatelessWidget {
  final BookingModel booking;
  const _TransactionTile({required this.booking});

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
          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.payments_outlined, color: AppColors.success, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(booking.serviceType, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(booking.customerName, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('+ Rs ${(booking.agreedPrice ?? booking.offeredPrice ?? 0).toInt()}',
            style: GoogleFonts.inter(color: AppColors.success, fontSize: 14, fontWeight: FontWeight.w800)),
          Text('${booking.scheduledDate.day}/${booking.scheduledDate.month}/${booking.scheduledDate.year}',
            style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10)),
        ]),
      ]),
    );
  }
}
