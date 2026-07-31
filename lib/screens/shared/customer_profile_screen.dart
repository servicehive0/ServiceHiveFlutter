import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../services/avatar_cache.dart';

class CustomerProfileScreen extends StatefulWidget {
  final String customerId;
  const CustomerProfileScreen({super.key, required this.customerId});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  String? _name;
  String? _phone;
  String? _email;
  String? _city;
  String? _area;
  String? _avatarUrl;
  int _requestsPosted = 0;
  int _jobsCompleted = 0;
  bool _loading = true;
  bool _notFound = false;
  bool _showPhone = true;
  bool _showEmail = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = Supabase.instance.client;
    try {
      // RLS only allows a user to read their own `users` row directly — this
      // RPC (SECURITY DEFINER, same pattern as get_public_avatar/is_blocked)
      // is what actually lets a provider view a customer's basic profile.
      final rows = await db.rpc('get_public_user_profile', params: {'user_id': widget.customerId}) as List;
      final row = rows.isNotEmpty ? rows.first as Map<String, dynamic> : null;
      if (row == null) {
        if (mounted) setState(() { _loading = false; _notFound = true; });
        return;
      }

      final posted = await db
          .from('service_requests')
          .count(CountOption.exact)
          .eq('customer_id', widget.customerId);
      final completed = await db
          .from('service_requests')
          .count(CountOption.exact)
          .eq('customer_id', widget.customerId)
          .eq('status', 'completed');

      if (mounted) {
        setState(() {
          _name = row['name'] as String?;
          _phone = row['phone'] as String?;
          _email = row['email'] as String?;
          _city = row['city'] as String?;
          _area = row['area'] as String?;
          _showPhone = row['show_phone'] as bool? ?? true;
          _showEmail = row['show_email'] as bool? ?? true;
          _requestsPosted = posted;
          _jobsCompleted = completed;
          _loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('CustomerProfileScreen load error: $e\n$st');
      if (mounted) setState(() { _loading = false; _notFound = true; });
    }
    final url = await AvatarCache.getAvatar(widget.customerId);
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

    if (_notFound || _name == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Customer not found', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
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

    final name = _name!;

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
                    Text('Customer Profile',
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
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32)),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(name,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                        ),
                        child: Text('Customer',
                          style: GoogleFonts.inter(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                      if ((_area?.isNotEmpty ?? false) || (_city?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppColors.textMuted, size: 14),
                            const SizedBox(width: 3),
                            Flexible(child: Text([_area, _city].where((s) => s?.isNotEmpty ?? false).join(', '),
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12))),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Stats row
                      Row(
                        children: [
                          _StatItem(label: 'Requests Posted', value: '$_requestsPosted', icon: Icons.assignment_outlined, color: AppColors.primary),
                          Container(width: 1, height: 36, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 16)),
                          _StatItem(label: 'Jobs Completed', value: '$_jobsCompleted', icon: Icons.check_circle_outline_rounded, color: AppColors.success),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            if ((_showPhone && (_phone?.isNotEmpty ?? false)) || (_showEmail && (_email?.isNotEmpty ?? false)))
              _SectionCard(
                title: 'Contact',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showPhone && (_phone?.isNotEmpty ?? false))
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, color: AppColors.primary, size: 16),
                          const SizedBox(width: 10),
                          Text('Phone:', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_phone!, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    if (_showPhone && (_phone?.isNotEmpty ?? false) && _showEmail && (_email?.isNotEmpty ?? false))
                      const SizedBox(height: 10),
                    if (_showEmail && (_email?.isNotEmpty ?? false))
                      Row(
                        children: [
                          const Icon(Icons.email_rounded, color: AppColors.primary, size: 16),
                          const SizedBox(width: 10),
                          Text('Email:', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_email!, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                  ],
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
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
        Text(label, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10), textAlign: TextAlign.center),
      ],
    ),
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
