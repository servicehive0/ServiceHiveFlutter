import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RequestProvider>();
    final completed = rp.myProviderJobs.where((r) => r.status == 'completed').toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final total = completed.fold(0.0, (s, r) => s + (rp.priceForRequest(r.id) ?? 0));
    final thisMonth = completed
        .where((r) => r.createdAt.month == DateTime.now().month && r.createdAt.year == DateTime.now().year)
        .fold(0.0, (s, r) => s + (rp.priceForRequest(r.id) ?? 0));
    final ratedJobs = completed.where((r) => r.rating != null).toList();
    final rating = ratedJobs.isEmpty
        ? 0.0
        : ratedJobs.fold<double>(0, (s, r) => s + r.rating!) / ratedJobs.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: () async {
          final user = context.read<AuthProvider>().user;
          if (user != null) await context.read<RequestProvider>().loadMyProviderJobs(user.id);
        },
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                Text('Earnings', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
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
                  gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF065F46)]),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total Lifetime Earnings', style: GoogleFonts.inter(color: AppColors.success.withValues(alpha: 0.8), fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('Rs ${total.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 20),
                  Row(children: [
                    _EarnStat(label: 'This Month', value: 'Rs ${thisMonth.toInt()}', color: const Color(0xFF34D399)),
                    Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.1), margin: const EdgeInsets.symmetric(horizontal: 20)),
                    _EarnStat(label: 'Jobs Done', value: '${completed.length}', color: const Color(0xFF34D399)),
                    Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.1), margin: const EdgeInsets.symmetric(horizontal: 20)),
                    _EarnStat(label: 'Rating', value: rating > 0 ? '${rating.toStringAsFixed(1)} ★' : '—', color: const Color(0xFFFBBF24)),
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
                      child: _TransactionTile(request: completed[i], price: rp.priceForRequest(completed[i].id) ?? 0),
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

class _EarnStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _EarnStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: GoogleFonts.inter(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
    Text(label, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
  ]);
}

class _TransactionTile extends StatelessWidget {
  final ServiceRequest request;
  final int price;
  const _TransactionTile({required this.request, required this.price});

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
          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.payments_outlined, color: AppColors.success, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(request.serviceName, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(request.customerName, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('+ Rs $price',
            style: GoogleFonts.inter(color: AppColors.success, fontSize: 14, fontWeight: FontWeight.w800)),
          Text('${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year}',
            style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10)),
        ]),
      ]),
    );
  }
}
