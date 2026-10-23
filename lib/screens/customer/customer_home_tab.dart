import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../models/provider_model.dart';
import '../../models/service_request_model.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/provider_list_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/services_provider.dart';

IconData _iconForService(String iconName) {
  switch (iconName) {
    case 'Zap':        return Icons.electric_bolt_rounded;
    case 'Droplet':    return Icons.water_drop_rounded;
    case 'Wind':       return Icons.ac_unit_rounded;
    case 'Paintbrush': return Icons.brush_rounded;
    case 'Sparkles':   return Icons.cleaning_services_rounded;
    case 'Heart':      return Icons.favorite_rounded;
    case 'Hammer':     return Icons.carpenter_rounded;
    case 'Leaf':       return Icons.grass_rounded;
    case 'Shield':     return Icons.security_rounded;
    case 'Scissors':   return Icons.content_cut_rounded;
    case 'Wrench':     return Icons.build_rounded;
    case 'Home':       return Icons.home_repair_service_rounded;
    default:           return Icons.home_repair_service_rounded;
  }
}

Color _colorFromHex(String hex) {
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return AppColors.primary;
  }
}

class CustomerHomeTab extends StatefulWidget {
  const CustomerHomeTab({super.key});

  @override
  State<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

class _CustomerHomeTabState extends State<CustomerHomeTab> {
  Timer? _refreshTimer;
  // Top Providers filter — 'Overall' (no filter), a city name, or 'My Area'
  // (the customer's own profile area). Kept simple: one active chip at a
  // time, matching search_screen.dart's existing filter-chip UX.
  String _topProvidersFilter = 'Overall';

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _silentRefresh());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LocationProvider>().fetch();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;
    final user = context.read<AuthProvider>().user;
    if (user != null) await context.read<RequestProvider>().loadMyRequests(user.id);
  }

  Future<void> _silentRefresh() async {
    if (!mounted) return;
    final user = context.read<AuthProvider>().user;
    if (user != null) await context.read<RequestProvider>().loadMyRequests(user.id, silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final providerListProv = context.watch<ProviderListProvider>();
    final locationProv = context.watch<LocationProvider>();
    final bookings = context.watch<BookingProvider>();
    final servicesProv = context.watch<ServicesProvider>();
    final settings = context.watch<AppSettingsProvider>();
    final myRequests = context.watch<RequestProvider>().myRequests
        .where((r) => r.status != 'completed' && r.status != 'cancelled')
        .toList();
    final unread = context.watch<NotificationsProvider>().unreadCount;
    final active = bookings.customerBookings('me')
        .where((b) => b.status.index <= 2 && b.status.index >= 1)
        .toList();

    // Trigger fetch if not loaded yet
    if (!servicesProv.loaded && !servicesProv.loading) {
      Future.microtask(() => servicesProv.fetch());
    }

    final topProvidersFilterCity = _topProvidersFilter == 'Overall'
        ? null
        : _topProvidersFilter == 'My Area'
            ? null // area filter uses the customer's own area below, not a city
            : _topProvidersFilter;
    final topProvidersFilterArea = _topProvidersFilter == 'My Area' ? user?.area : null;
    final topProviders = providerListProv.topProviders(
      city: topProvidersFilterCity,
      area: topProvidersFilterArea,
    );
    final topProvidersChips = ['Overall', if (user?.area.isNotEmpty == true) 'My Area', ...locationProv.cities];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.14),
                    AppColors.bg.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                      image: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                          ? DecorationImage(image: CachedNetworkImageProvider(user.avatarUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
                        ? Center(
                            child: Text(
                              (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, ${user?.name.split(' ').first ?? 'there'} 👋',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('What service do you need?',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                        ),
                        if (unread > 0)
                          Positioned(
                            right: -2, top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              constraints: const BoxConstraints(minWidth: 18),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: AppColors.bg, width: 2),
                              ),
                              child: Text('$unread',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
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
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(Icons.search_rounded, color: AppColors.primaryLight.withValues(alpha: 0.8), size: 21),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Search services or providers...',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 14)),
                      ),
                      Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune_rounded, color: AppColors.primaryLight, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 22)),

          // Promo carousel — admin-managed slides, auto-sliding
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _PromoCarousel(slides: settings.promoSlides),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Trust stats strip
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(child: _StatItem(icon: Icons.verified_rounded, value: settings.statUsersServed, label: 'Users Served', color: AppColors.primaryLight)),
                    Container(width: 1, height: 32, color: AppColors.border),
                    Expanded(child: _StatItem(icon: Icons.star_rounded, value: settings.statAvgRating, label: 'Avg Rating', color: const Color(0xFFFBBF24))),
                    Container(width: 1, height: 32, color: AppColors.border),
                    Expanded(child: _StatItem(icon: Icons.bolt_rounded, value: settings.statServiceTypes, label: 'Services', color: AppColors.success)),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // Services grid header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Our Services',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                  GestureDetector(
                    onTap: () => context.push('/all-services'),
                    child: Text('See all',
                      style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Services grid - dynamic from DB
          if (servicesProv.loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (servicesProv.services.isEmpty)
            const SliverToBoxAdapter(child: SizedBox.shrink())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final s = servicesProv.services[i];
                    final color = _colorFromHex(s.color);
                    return GestureDetector(
                      onTap: () => context.push('/service-request/create', extra: s.name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.04)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withValues(alpha: 0.16),
                                border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: (s.imgUrl != null && s.imgUrl!.isNotEmpty)
                                  ? Image.network(
                                      s.imgUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(_iconForService(s.icon), color: color, size: 24),
                                    )
                                  : Icon(_iconForService(s.icon), color: color, size: 24),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                s.name,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: servicesProv.services.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 116,
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
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: active.first.status.color.withValues(alpha: 0.12),
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
                            color: active.first.status.color.withValues(alpha: 0.12),
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

          // My Service Requests
          if (myRequests.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('My Requests', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('${myRequests.length}', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ServiceRequestCard(request: myRequests[i]),
                  ),
                  childCount: myRequests.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],

          // Top providers — ranked by rating/jobs (ProviderListProvider.topProviders),
          // not just whoever happens to be online right now, with filter chips for
          // Overall / My Area / a specific city.
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
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: topProvidersChips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final chip = topProvidersChips[i];
                  final active = chip == _topProvidersFilter;
                  return GestureDetector(
                    onTap: () => setState(() => _topProvidersFilter = chip),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.surface2,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: active ? AppColors.primary : AppColors.border),
                      ),
                      child: Center(
                        child: Text(chip,
                          style: GoogleFonts.inter(
                            color: active ? Colors.white : AppColors.textMuted,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverToBoxAdapter(
            child: topProviders.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      height: 100,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text('No providers yet in this filter',
                        style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 13)),
                    ),
                  )
                : SizedBox(
                    height: 180,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: topProviders.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _ProviderCard(provider: topProviders[i]),
                    ),
                  ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
        ),
      ),
    );
  }
}

class _PromoCarousel extends StatefulWidget {
  final List<PromoSlide> slides;
  const _PromoCarousel({required this.slides});

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final _pageCtrl = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(covariant _PromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides.length != widget.slides.length) {
      _page = 0;
      _startAutoSlide();
    }
  }

  // PageView has no true "wrap around" — animating from the last index
  // straight to 0 plays backwards. Instead we render one extra page at the
  // end that's a clone of the first slide, animate forward into it (still
  // one direction), then snap back to the real index 0 with no animation
  // so it looks like a seamless forward-only loop.
  void _startAutoSlide() {
    _timer?.cancel();
    if (widget.slides.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted || !_pageCtrl.hasClients) return;
      final next = _page + 1;
      await _pageCtrl.animateToPage(next,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
      if (!mounted) return;
      if (next == widget.slides.length) {
        _pageCtrl.jumpToPage(0);
        _page = 0;
      } else {
        _page = next;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _handleTap(String route) {
    if (route.startsWith('/customer?tab=')) {
      final tab = route.split('=').last;
      context.push('/customer?tab=$tab');
    } else {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) {
      return Container(
        height: 190,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF3B82F6), Color(0xFF0EA5E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: Icon(Icons.home_repair_service_rounded, color: Colors.white, size: 40),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 214,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.slides.length + 1,
            onPageChanged: (i) {
              if (i == widget.slides.length) return; // clone page mid-loop-snap, ignore
              setState(() => _page = i);
            },
            itemBuilder: (_, i) {
              final slide = widget.slides[i % widget.slides.length];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: GestureDetector(
                  onTap: () => _handleTap(slide.targetRoute),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: slide.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: slide.gradient.last.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -24, top: -34,
                          child: Container(
                            width: 140, height: 140,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)),
                          ),
                        ),
                        Positioned(
                          right: 20, bottom: -50,
                          child: Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.auto_awesome, color: Colors.white, size: 10),
                                      const SizedBox(width: 4),
                                      Text(slide.badge, style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                                    ]),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(slide.title,
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900, height: 1.15),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 5),
                                  Text(slide.subtitle,
                                    style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.82), fontSize: 11, height: 1.35, fontWeight: FontWeight.w500),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 11),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(100),
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3))],
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Text(slide.buttonText, style: GoogleFonts.inter(color: slide.gradient.last, fontSize: 11.5, fontWeight: FontWeight.w800)),
                                      const SizedBox(width: 4),
                                      Icon(Icons.arrow_forward_rounded, color: slide.gradient.last, size: 12),
                                    ]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.5),
                              ),
                              child: Icon(slide.icon, color: Colors.white, size: 23),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.slides.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.slides.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(100),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatItem({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ServiceRequestCard extends StatelessWidget {
  final ServiceRequest request;
  const _ServiceRequestCard({required this.request});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Request?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('This request will be permanently deleted.', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textDim))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    await context.read<RequestProvider>().deleteRequest(request.id, user.id);
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (request.status) {
      case 'open':
        statusColor = AppColors.primary;
        statusLabel = 'Open';
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case 'accepted':
        statusColor = AppColors.success;
        statusLabel = 'Accepted';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'in_progress':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'In Progress';
        statusIcon = Icons.build_circle_rounded;
        break;
      default:
        statusColor = AppColors.textDim;
        statusLabel = request.status;
        statusIcon = Icons.circle_outlined;
    }

    return GestureDetector(
      onTap: () => context.push('/service-request/${request.id}/bids'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(request.serviceName, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(request.description, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(statusLabel, style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 4),
            if (request.status == 'open')
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                ),
              )
            else
              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textDim, size: 11),
          ]),
        ]),
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
                    image: provider.avatarUrl != null
                        ? DecorationImage(image: CachedNetworkImageProvider(provider.avatarUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: provider.avatarUrl == null
                      ? Center(
                          child: Text(provider.name[0],
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        )
                      : null,
                ),
                const Spacer(),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: provider.isOnline ? AppColors.success : AppColors.textDim,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(provider.name,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(provider.serviceType,
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 14),
                const SizedBox(width: 3),
                Text(provider.rating.toStringAsFixed(1),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('Rs ${provider.ratePerHour.toInt()}/hr',
                  style: GoogleFonts.inter(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
