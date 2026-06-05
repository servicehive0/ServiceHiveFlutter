import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class CustomerDashboard extends StatelessWidget {
  const CustomerDashboard({super.key});

  static const _services = [
    {'icon': Icons.electrical_services_outlined, 'label': 'Electrician', 'color': 0xFFF59E0B},
    {'icon': Icons.plumbing_outlined, 'label': 'Plumber', 'color': 0xFF3B82F6},
    {'icon': Icons.cleaning_services_outlined, 'label': 'Cleaning', 'color': 0xFF10B981},
    {'icon': Icons.ac_unit_outlined, 'label': 'AC Repair', 'color': 0xFF6366F1},
    {'icon': Icons.handyman_outlined, 'label': 'Carpenter', 'color': 0xFFF97316},
    {'icon': Icons.format_paint_outlined, 'label': 'Painter', 'color': 0xFFEC4899},
    {'icon': Icons.security_outlined, 'label': 'Security', 'color': 0xFF14B8A6},
    {'icon': Icons.pest_control_outlined, 'label': 'Pest Control', 'color': 0xFF8B5CF6},
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(top: -80, right: -80,
            child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.08)))),

          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Good Morning,', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                                Text(
                                  user?.name ?? 'Customer',
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () async {
                                await auth.logout();
                                if (context.mounted) context.go('/auth');
                              },
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(Icons.logout_rounded, color: AppColors.textMuted, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Search bar
                        Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded, color: AppColors.textDim, size: 20),
                              const SizedBox(width: 10),
                              Text('Search for a service...', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 14)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Get 20% OFF', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 4),
                                    Text('On your first booking!', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(100)),
                                      child: Text('Book Now', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.shield_rounded, color: Colors.white30, size: 70),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        Text('Services', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // Services grid
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _ServiceTile(
                        icon: _services[i]['icon'] as IconData,
                        label: _services[i]['label'] as String,
                        color: Color(_services[i]['color'] as int),
                      ),
                      childCount: _services.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 28)),

                // Recent bookings header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent Bookings', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        Text('See All', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Empty bookings state
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface2),
                            child: const Icon(Icons.calendar_today_outlined, color: AppColors.textDim, size: 24),
                          ),
                          const SizedBox(height: 12),
                          Text('No bookings yet', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Book your first service today!', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),

      // Bottom nav
      bottomNavigationBar: _BottomNav(),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ServiceTile({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatefulWidget {
  @override
  State<_BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<_BottomNav> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', active: _index == 0, onTap: () => setState(() => _index = 0)),
              _NavItem(icon: Icons.search_outlined, activeIcon: Icons.search_rounded, label: 'Search', active: _index == 1, onTap: () => setState(() => _index = 1)),
              _NavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, label: 'Bookings', active: _index == 2, onTap: () => setState(() => _index = 2)),
              _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile', active: _index == 3, onTap: () => setState(() => _index = 3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? activeIcon : icon, color: active ? AppColors.primary : AppColors.textDim, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              color: active ? AppColors.primary : AppColors.textDim,
              fontSize: 10,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
