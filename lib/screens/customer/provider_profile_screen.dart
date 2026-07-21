import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/provider_model.dart';
import '../../providers/provider_list_provider.dart';
import '../../services/avatar_cache.dart';

class ProviderProfileScreen extends StatefulWidget {
  final String providerId;
  const ProviderProfileScreen({super.key, required this.providerId});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  ProviderModel? _provider;
  String? _avatarUrl;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Instant paint if this provider is already in the shared cached list
    // (the common case — reached from a screen that already called
    // ProviderListProvider.fetch()); otherwise fall back to a direct
    // fetch by id so a deep link or a cold list cache doesn't dead-end on
    // "Provider not found" the way this screen used to.
    final cached = context.read<ProviderListProvider>().getById(widget.providerId);
    if (cached != null) {
      setState(() { _provider = cached; _loading = false; });
    } else {
      try {
        final row = await Supabase.instance.client
            .from('users')
            .select('id, name, phone, city, area, provider_profiles(*)')
            .eq('id', widget.providerId)
            .maybeSingle();
        if (row == null) {
          if (mounted) setState(() { _loading = false; _notFound = true; });
          return;
        }
        final model = ProviderListProvider.rowToModel(row);
        if (mounted) setState(() { _provider = model; _loading = false; });
      } catch (_) {
        if (mounted) setState(() { _loading = false; _notFound = true; });
      }
    }
    final url = await AvatarCache.getAvatar(widget.providerId);
    if (mounted && url != null) setState(() => _avatarUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
      );
    }

    if (_provider == null || _notFound) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Provider not found', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('Go Back', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ]),
        ),
      );
    }

    final provider = _provider!;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // App bar with back
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface2, borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const Spacer(),
                  Text('Provider Profile',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  const SizedBox(width: 44),
                ],
              ),
            ),
          ),

          // Profile header card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                            image: (_avatarUrl != null)
                                ? DecorationImage(image: CachedNetworkImageProvider(_avatarUrl!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: _avatarUrl == null
                              ? Center(
                                  child: Text(provider.name.isNotEmpty ? provider.name[0].toUpperCase() : '?',
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32)),
                                )
                              : null,
                        ),
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: provider.isOnline ? AppColors.success : AppColors.textDim,
                            border: Border.all(color: AppColors.surface, width: 2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(provider.name,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(provider.serviceType,
                      style: GoogleFonts.inter(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppColors.textMuted, size: 14),
                        const SizedBox(width: 3),
                        Flexible(child: Text('${provider.area}, ${provider.city}',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Stats row
                    Row(
                      children: [
                        _StatItem(label: 'Rating', value: provider.rating.toStringAsFixed(1), icon: Icons.star_rounded, color: const Color(0xFFFBBF24)),
                        _vDivider(),
                        _StatItem(label: 'Jobs Done', value: '${provider.totalJobs}', icon: Icons.work_outline_rounded, color: AppColors.primary),
                        _vDivider(),
                        _StatItem(label: 'Reviews', value: '${provider.reviewCount}', icon: Icons.reviews_outlined, color: AppColors.success),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: provider.isOnline ? AppColors.success.withOpacity(0.1) : AppColors.textDim.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: provider.isOnline ? AppColors.success.withOpacity(0.3) : AppColors.textDim.withOpacity(0.3)),
                      ),
                      child: Text(
                        provider.isOnline ? '● Available Now' : '○ Currently Offline',
                        style: GoogleFonts.inter(
                          color: provider.isOnline ? AppColors.success : AppColors.textDim,
                          fontSize: 12, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // About
          _SectionCard(
            title: 'About',
            child: Text(provider.about,
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.6),
              maxLines: 5, overflow: TextOverflow.ellipsis),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Details
          _SectionCard(
            title: 'Details',
            child: Column(
              children: [
                _DetailRow(icon: Icons.access_time_rounded, label: 'Experience', value: provider.experience),
                const SizedBox(height: 10),
                _DetailRow(icon: Icons.phone_rounded, label: 'Phone', value: provider.phone),
                const SizedBox(height: 10),
                _DetailRow(icon: Icons.attach_money_rounded, label: 'Rate', value: 'Rs ${provider.ratePerHour.toInt()} / hour'),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Skills
          _SectionCard(
            title: 'Skills & Expertise',
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: provider.skills.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Text(s, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              )).toList(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // Book Now button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: GestureDetector(
          onTap: () => context.push('/book/${provider.id}'),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Book Now — Rs ${provider.ratePerHour.toInt()}/hr',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 36, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 16));
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        Text(label, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10)),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.primary, size: 16),
      const SizedBox(width: 10),
      Text('$label:', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12)),
      const SizedBox(width: 6),
      Expanded(child: Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    ),
  );
}
