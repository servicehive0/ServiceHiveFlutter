import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';

class RatingHistoryScreen extends StatelessWidget {
  const RatingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RequestProvider>();
    final rated = rp.myProviderJobs.where((r) => r.rating != null).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final avgRating = rated.isEmpty
        ? 0.0
        : rated.fold(0.0, (s, r) => s + r.rating!) / rated.length;

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
                Text('Ratings', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
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
                  gradient: const LinearGradient(colors: [Color(0xFF78350F), Color(0xFF92400E)]),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Overall Rating', style: GoogleFonts.inter(color: const Color(0xFFFCD34D), fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(avgRating > 0 ? avgRating.toStringAsFixed(1) : '—',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 26),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('(${rated.length} ${rated.length == 1 ? 'review' : 'reviews'})',
                        style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ]),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Job Reviews', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          rated.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                      child: Center(child: Column(children: [
                        const Icon(Icons.star_outline_rounded, color: AppColors.textDim, size: 32),
                        const SizedBox(height: 10),
                        Text('No ratings yet', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                      ])),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                      child: _RatingTile(request: rated[i]),
                    ),
                    childCount: rated.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
        ),
      ),
    );
  }
}

class _RatingTile extends StatelessWidget {
  final ServiceRequest request;
  const _RatingTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final rating = request.rating ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(request.serviceName, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(request.customerName, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Row(children: [
            ...List.generate(5, (i) => Icon(
              i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
              color: const Color(0xFFFBBF24), size: 16,
            )),
          ]),
        ]),
        if ((request.review ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('"${request.review}"',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic), maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }
}
