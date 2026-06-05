import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class ProviderDashboard extends StatelessWidget {
  const ProviderDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(top: -80, right: -80,
            child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.success.withOpacity(0.08)))),

          SafeArea(
            child: CustomScrollView(
              slivers: [
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
                                Text('Provider Dashboard', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                                Text(
                                  user?.name ?? 'Provider',
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success)),
                                      const SizedBox(width: 6),
                                      Text('Online', style: GoogleFonts.inter(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () async {
                                    await auth.logout();
                                    if (context.mounted) context.go('/auth');
                                  },
                                  child: Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                                    child: const Icon(Icons.logout_rounded, color: AppColors.textMuted, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Stats row
                        Row(
                          children: [
                            Expanded(child: _StatCard(label: 'Total Jobs', value: '0', icon: Icons.work_outline_rounded, color: AppColors.primary)),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard(label: 'Earnings', value: 'Rs 0', icon: Icons.payments_outlined, color: AppColors.success)),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard(label: 'Rating', value: '—', icon: Icons.star_outline_rounded, color: AppColors.warning)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Active request banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('New Requests', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                                    child: Text('0 pending', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 52, height: 52,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface2),
                                      child: const Icon(Icons.notifications_none_rounded, color: AppColors.textDim, size: 24),
                                    ),
                                    const SizedBox(height: 10),
                                    Text('No new requests', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                                    Text('You\'ll be notified when customers book', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text('Job History', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.history_rounded, color: AppColors.textDim, size: 32),
                                const SizedBox(height: 10),
                                Text('No completed jobs yet', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
