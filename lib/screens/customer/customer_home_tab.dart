import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../models/provider_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/provider_list_provider.dart';

class CustomerHomeTab extends StatelessWidget {
  const CustomerHomeTab({super.key});

  static const _services = [
    (name: 'Electrical', icon: Icons.electric_bolt_rounded, color: Color(0xFFFBBF24)),
    (name: 'Plumbing', icon: Icons.plumbing_rounded, color: Color(0xFF3B82F6)),
    (name: 'AC Service', icon: Icons.ac_unit_rounded, color: Color(0xFF06B6D4)),
    (name: 'Painting', icon: Icons.brush_rounded, color: Color(0xFF10B981)),
    (name: 'Cleaning', icon: Icons.cleaning_services_rounded, color: Color(0xFFEC4899)),
    (name: 'Repair', icon: Icons.build_rounded, color: Color(0xFFF97316)),
    (name: 'Carpentry', icon: Icons.carpenter_rounded, color: Color(0xFF8B5CF6)),
    (name: 'Gardening', icon: Icons.grass_rounded, color: Color(0xFF22C55E)),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final providers = context.watch<ProviderListProvider>().providers;
    final bookings = context.watch<BookingProvider>();
    final unread = bookings.unreadNotifCount;
    final active = bookings.customerBookings('me')
        .where((b) => b.status.index <= 2 && b.status.index >= 1)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, ${user?.name.split(' ').first ?? 'there'} 👋',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                        Text('What service do you need?',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Stack(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface2, borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                        ),
                        if (unread > 0)
                          Positioned(
                            right: 8, top: 8,
                            child: Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () => context.push('/search'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      const Icon(Icons.search_rounded, color: AppColors.textDim, size: 20),
                      const SizedBox(width: 10),
                      Text('Search services or providers...',
                        style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Promo banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text('LIMITED OFFER', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(height: 8),
                          Text('Get 20% OFF\non first booking!',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text('Book Now', style: GoogleFonts.inter(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.home_repair_service_rounded, color: Colors.white, size: 72),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // Services
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Our Services',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final s = _services[i];
                  return GestureDetector(
                    onTap: () => context.push('/search', extra: s.name),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: s.color.withOpacity(0.12),
                            ),
                            child: Icon(s.icon, color: s.color, size: 22),
                          ),
                          const SizedBox(height: 8),
                          Text(s.name,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _services.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.9,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // Active booking
          if (active.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('Active Booking',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: () => context.push('/booking/${active.first.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: active.first.status.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(active.first.status.icon, color: active.first.status.color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(active.first.serviceType,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                              Text(active.first.providerName,
                                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: active.first.status.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(active.first.status.label,
                            style: GoogleFonts.inter(color: active.first.status.color, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],

          // Top providers
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Top Providers',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  GestureDetector(
                    onTap: () => context.push('/search'),
                    child: Text('See all',
                      style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: providers.where((p) => p.isOnline).length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final p = providers.where((p) => p.isOnline).toList()[i];
                  return _ProviderCard(provider: p);
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final ProviderModel provider;
  const _ProviderCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/provider/${provider.id}'),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
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
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                  ),
                  child: Center(
                    child: Text(provider.name[0],
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(provider.name,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(provider.serviceType,
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 14),
                const SizedBox(width: 3),
                Text(provider.rating.toStringAsFixed(1),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('Rs ${provider.ratePerHour.toInt()}/hr',
                  style: GoogleFonts.inter(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
