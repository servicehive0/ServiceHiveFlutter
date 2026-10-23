import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/provider_model.dart';
import '../../providers/auth_provider.dart';
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
  bool _blocked = false;
  RealtimeChannel? _profileChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _loadBlockState();
  }

  Future<void> _loadBlockState() async {
    final myId = context.read<AuthProvider>().user?.id;
    if (myId == null) return;
    try {
      final blocked = await Supabase.instance.client
          .rpc('is_blocked', params: {'blocker': myId, 'blocked': widget.providerId}) as bool?;
      if (mounted) setState(() => _blocked = blocked == true);
    } catch (e) {
      debugPrint('ProviderProfileScreen _loadBlockState error: $e');
    }
  }

  Future<void> _toggleBlock() async {
    final myId = context.read<AuthProvider>().user?.id;
    if (myId == null) return;
    final name = _provider?.name ?? 'this provider';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_blocked ? 'Unblock $name?' : 'Block $name?',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          _blocked
              ? 'They will be able to send you messages again.'
              : 'They will no longer be able to send you messages.',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_blocked ? 'Unblock' : 'Block',
              style: GoogleFonts.inter(color: _blocked ? AppColors.primary : AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final db = Supabase.instance.client;
      if (_blocked) {
        await db.from('blocked_users').delete().eq('blocker_id', myId).eq('blocked_id', widget.providerId);
      } else {
        await db.from('blocked_users').insert({'blocker_id': myId, 'blocked_id': widget.providerId});
      }
      if (mounted) setState(() => _blocked = !_blocked);
    } catch (e) {
      debugPrint('ProviderProfileScreen _toggleBlock error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not update block status. Try again.', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }


  @override
  void dispose() {
    if (_profileChannel != null) Supabase.instance.client.removeChannel(_profileChannel!);
    super.dispose();
  }

  Future<void> _load() async {
    // Instant paint if this provider is already in the shared cached list
    // (the common case — reached from a screen that already called
    // ProviderListProvider.fetch()); otherwise fall back to a direct
    // fetch by id so a deep link or a cold list cache doesn't dead-end on
    // "Provider not found" the way this screen used to. Either way, a fresh
    // provider_profiles read + realtime subscription follows below so
    // rating/jobs/rate never sit on the stale snapshot the cached list was
    // built from.
    final cached = context.read<ProviderListProvider>().getById(widget.providerId);
    if (cached != null) {
      setState(() { _provider = cached; _loading = false; });
    } else {
      try {
        // RLS blocks a direct .from('users').eq('id', ...) read for another
        // user's row, which is what made this dead-end into "Provider not
        // found" whenever the shared cached list hadn't loaded yet (e.g. a
        // deep link). Route through the same SECURITY DEFINER RPC every
        // other cross-user profile read already uses.
        final db = Supabase.instance.client;
        final rows = await db.rpc('get_public_user_profile', params: {'user_id': widget.providerId}) as List;
        final row = rows.isNotEmpty ? rows.first as Map<String, dynamic> : null;
        if (row == null) {
          if (mounted) setState(() { _loading = false; _notFound = true; });
          return;
        }
        final profile = await db
            .from('provider_profiles')
            .select()
            .eq('id', widget.providerId)
            .maybeSingle();
        final merged = {...row, 'provider_profiles': profile != null ? [profile] : []};
        final model = ProviderListProvider.rowToModel(merged);
        if (mounted) setState(() { _provider = model; _loading = false; });
      } catch (e, st) {
        debugPrint('ProviderProfileScreen direct-fetch error: $e\n$st');
        if (mounted) setState(() { _loading = false; _notFound = true; });
      }
    }
    final url = await AvatarCache.getAvatar(widget.providerId);
    if (mounted && url != null) setState(() => _avatarUrl = url);
    _subscribeToJobUpdates();
  }

  // Keep listening while this screen stays open, so a job completing or a
  // new review lands in real time without needing to back out and reopen
  // the profile.
  void _subscribeToJobUpdates() {
    _profileChannel = Supabase.instance.client
        .channel('provider_profile_jobs_${widget.providerId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'provider_profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.providerId,
          ),
          // the database updates rating / jobs / online, show them at once
          callback: (payload) {
            final row = payload.newRecord;
            if (!mounted || _provider == null) return;
            setState(() {
              _provider!
                ..rating = (row['rating'] as num?)?.toDouble() ?? _provider!.rating
                ..totalJobs = (row['total_jobs'] as num?)?.toInt() ?? _provider!.totalJobs
                ..reviewCount = (row['review_count'] as num?)?.toInt() ?? _provider!.reviewCount
                ..switchedOn = row['is_online'] as bool? ?? _provider!.switchedOn
                ..lastSeenAt = DateTime.tryParse(row['last_seen_at'] as String? ?? '') ?? _provider!.lastSeenAt
                ..refreshOnline();
            });
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
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
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (_) => _toggleBlock(),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'toggle_block',
                        child: Text(_blocked ? 'Unblock' : 'Block',
                          style: GoogleFonts.inter(
                            color: _blocked ? AppColors.primary : AppColors.error,
                            fontWeight: FontWeight.w600,
                          )),
                      ),
                    ],
                  ),
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
                    if (provider.area.isNotEmpty || provider.city.isNotEmpty) ...[
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
                    ],
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
                        color: provider.isOnline ? AppColors.success.withValues(alpha: 0.1) : AppColors.textDim.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: provider.isOnline ? AppColors.success.withValues(alpha: 0.3) : AppColors.textDim.withValues(alpha: 0.3)),
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
                if (provider.showPhone && provider.phone.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DetailRow(icon: Icons.phone_rounded, label: 'Phone', value: provider.phone),
                ],
                if (provider.showEmail && (provider.email?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 10),
                  _DetailRow(icon: Icons.email_rounded, label: 'Email', value: provider.email!),
                ],
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(s, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              )).toList(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
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
