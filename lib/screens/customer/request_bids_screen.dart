import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/bid_model.dart';
import '../../models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../services/ai_insights_service.dart';
import '../../services/avatar_cache.dart';
import '../../widgets/rating_dialog.dart';

const _kBidApiKey = kGroqApiKey;
const _kBidModel  = 'llama-3.3-70b-versatile';

class RequestBidsScreen extends StatefulWidget {
  final String requestId;
  const RequestBidsScreen({super.key, required this.requestId});

  @override
  State<RequestBidsScreen> createState() => _RequestBidsScreenState();
}

class _RequestBidsScreenState extends State<RequestBidsScreen> {
  ServiceRequest? _request;
  bool _loadingReq    = true;
  bool _aiAnalyzing   = false;
  String? _aiRecommendedProvider;
  String? _aiReason;
  // bid_id -> {rank, success_score, reason} — advisory-only per-bid AI
  // scoring, kept separate from the single "recommended provider" summary
  // above so a partial/failed ranking still lets that older feature work.
  Map<String, dynamic> _bidScores = {};
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _init();
    // Start polling immediately — don't wait for _init() to finish
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      final rp = context.read<RequestProvider>();
      final updated = await rp.fetchRequest(widget.requestId);
      if (mounted && updated != null) setState(() => _request = updated);
      if (mounted) await rp.loadBidsForRequest(widget.requestId);
    });
  }

  Future<void> _init() async {
    try {
      final rp = context.read<RequestProvider>();
      final req = await rp.fetchRequest(widget.requestId);
      if (mounted) setState(() { _request = req; _loadingReq = false; });
      await rp.subscribeToBids(widget.requestId);
    } catch (_) {
      if (mounted) setState(() => _loadingReq = false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    context.read<RequestProvider>().unsubscribeFromBids();
    super.dispose();
  }

  Future<void> _acceptBid(Bid bid) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Accept Bid?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Accept ${bid.providerName}\'s offer of Rs ${bid.price}?\n\nAll other bids will be rejected.',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Accept', style: GoogleFonts.inter(color: AppColors.success, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final ok = await context.read<RequestProvider>().acceptBid(
      requestId: widget.requestId,
      bidId: bid.id,
      providerId: bid.providerId,
      customerId: user.id,
    );

    if (ok && mounted) {
      final req = await context.read<RequestProvider>().fetchRequest(widget.requestId);
      setState(() => _request = req);
    }
  }

  Future<void> _refresh() async {
    final rp = context.read<RequestProvider>();
    final req = await rp.fetchRequest(widget.requestId);
    await rp.loadBidsForRequest(widget.requestId);
    if (mounted) setState(() => _request = req);
  }

  Future<void> _fetchBidScores(List<Bid> bids) async {
    try {
      final providerIds = bids.map((b) => b.providerId).toSet().toList();
      // the location is on the users row, rating/jobs on provider_profiles
      final rows = await Supabase.instance.client
          .from('users')
          .select('id, latitude, longitude, provider_profiles(rating, total_jobs, experience)')
          .inFilter('id', providerIds);
      final profileById = <String, Map<String, dynamic>>{};
      for (final r in (rows as List)) {
        final raw = r['provider_profiles'];
        final pp = raw is List ? (raw.isNotEmpty ? raw.first as Map<String, dynamic> : <String, dynamic>{}) : (raw as Map<String, dynamic>? ?? {});
        profileById[r['id'] as String] = {...pp, 'latitude': r['latitude'], 'longitude': r['longitude']};
      }

      final payload = bids.map((b) {
        final p = profileById[b.providerId];
        final distance = AiInsightsService.distanceKm(
          _request?.latitude, _request?.longitude,
          (p?['latitude'] as num?)?.toDouble(), (p?['longitude'] as num?)?.toDouble(),
        );
        return {
          'bid_id': b.id,
          'provider_name': b.providerName,
          'price': b.price,
          'message': b.message,
          'rating': p?['rating'],
          'total_jobs': p?['total_jobs'],
          'experience': p?['experience'],
          'distance_km': distance != null ? (distance * 10).round() / 10 : null,
        };
      }).toList();

      final result = await AiInsightsService.rankAndScoreBidsML(bids: payload);
      if (mounted && result != null) setState(() => _bidScores = result);
    } catch (_) {
      // Advisory only — leave _bidScores empty, bid cards render without badges.
    }
  }

  Future<void> _analyzeBids(List<Bid> bids) async {
    if (_aiAnalyzing) return;
    setState(() {
      _aiAnalyzing = true;
      _aiRecommendedProvider = null;
      _aiReason = null;
    });
    unawaited(_fetchBidScores(bids));

    final bidSummary = bids.asMap().entries.map((e) {
      final b = e.value;
      return '${e.key + 1}. ${b.providerName} — Rs ${b.price}${b.message.isNotEmpty ? ' — "${b.message}"' : ''}';
    }).join('\n');

    try {
      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $_kBidApiKey',
        },
        body: jsonEncode({
          'model': _kBidModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a bid advisor for a home service marketplace in Pakistan. '
                  'Analyze the bids and recommend the best one for the customer. '
                  'Consider price value AND professionalism of the message. '
                  'Respond ONLY with valid JSON — no text outside JSON:\n'
                  '{"recommended_provider": "Exact provider name", "reason": "2 sentences why this bid is best"}',
            },
            {
              'role': 'user',
              'content':
                  'Service: ${_request?.serviceName ?? "Home Service"}\n\nBids:\n$bidSummary',
            },
          ],
          'max_tokens': 150,
          'temperature': 0.3,
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final content =
            jsonDecode(res.body)['choices'][0]['message']['content'] as String;
        final s = content.indexOf('{');
        final e = content.lastIndexOf('}') + 1;
        if (s != -1 && e > s) {
          final data =
              jsonDecode(content.substring(s, e)) as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _aiRecommendedProvider =
                  data['recommended_provider'] as String?;
              _aiReason = data['reason'] as String?;
            });
          }
          return;
        }
      }
      throw Exception('Bad response');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('AI analysis failed. Try again.',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.surface2,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _aiAnalyzing = false);
    }
  }

  Future<void> _deleteRequest(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Request?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('This request and all its bids will be permanently deleted.', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
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
    if (user == null || _request == null) return;
    final ok = await context.read<RequestProvider>().deleteRequest(_request!.id, user.id);
    if (ok && context.mounted) context.go('/customer');
  }

  @override
  Widget build(BuildContext context) {
    final bids = context.watch<RequestProvider>().bidsOnRequest;
    final status = _request?.status ?? 'open';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.go('/customer'),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Live Bids', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      if (_request != null)
                        Text(_request!.serviceName, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  _StatusBadge(status: status),
                  if (status == 'open') ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _deleteRequest(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                      ),
                    ),
                  ],
                ]),
              ),
            ),

            // Loading skeleton
            if (_loadingReq)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                ),
              )
            else ...[

              // Request summary card
              if (_request != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Your Request', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(_request!.description, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.5)),
                        if (_request!.imageUrl != null && _request!.imageUrl!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(imageUrl: _request!.imageUrl!, height: 140, width: double.infinity, fit: BoxFit.cover),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.location_on_rounded, color: AppColors.textDim, size: 14),
                          const SizedBox(width: 4),
                          Text('${_request!.area}, ${_request!.city}', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                        ]),
                      ]),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // Track provider on map (accepted / in_progress)
              if (status == 'accepted' || status == 'in_progress')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: GestureDetector(
                      onTap: () => context.push('/service-request/${widget.requestId}/map'),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1D1035), Color(0xFF0D1B3E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.map_rounded, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Track Provider', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            Text('See provider live location on map', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11)),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success)),
                              const SizedBox(width: 5),
                              Text('LIVE', style: GoogleFonts.inter(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),

              // OTP verify button (when accepted)
              if (status == 'accepted')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha:0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.success.withValues(alpha:0.4)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Provider is on the way!', style: GoogleFonts.inter(color: AppColors.success, fontSize: 14, fontWeight: FontWeight.w700))),
                        ]),
                        const SizedBox(height: 10),
                        Text(
                          'When they arrive at your door, ask them for their ServiceHive OTP. Then tap the button below to verify.',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => context.push('/service-request/${widget.requestId}/otp'),
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha:0.3), blurRadius: 12)],
                            ),
                            child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.key_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text('Verify Provider OTP', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                            ])),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),

              // In Progress banner
              if (status == 'in_progress')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha:0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha:0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.build_circle_rounded, color: AppColors.primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Job is currently in progress...', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  ),
                ),

              // Completed banner
              if (status == 'completed') ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha:0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.success.withValues(alpha:0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Job Completed! Thank you.', style: GoogleFonts.inter(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w700))),
                      ]),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _request!.rating != null
                        ? Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(children: [
                              ...List.generate(5, (i) => Icon(Icons.star_rounded,
                                color: i < _request!.rating!.round() ? const Color(0xFFFBBF24) : AppColors.border, size: 18)),
                              const SizedBox(width: 10),
                              Text(_request!.rating!.toStringAsFixed(1),
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            ]),
                          )
                        : GestureDetector(
                            onTap: () => showDialog(
                              context: context,
                              barrierColor: Colors.black.withValues(alpha: 0.75),
                              builder: (_) => RatingDialog(requestId: _request!.id),
                            ),
                            child: Container(
                              width: double.infinity,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  const Color(0xFFFBBF24).withValues(alpha: 0.18),
                                  const Color(0xFFFBBF24).withValues(alpha: 0.06),
                                ]),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.35)),
                              ),
                              child: Center(
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 18),
                                  const SizedBox(width: 8),
                                  Text('Rate this Service', style: GoogleFonts.inter(color: const Color(0xFFFBBF24), fontWeight: FontWeight.w700, fontSize: 14)),
                                ]),
                              ),
                            ),
                          ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap: () => context.go('/customer'),
                      child: Container(
                        width: double.infinity,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.home_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('Back to Home', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Bids header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(children: [
                    Flexible(child: Text('Bids (${bids.length})', overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
                    if (status == 'open' && bids.isEmpty) ...[
                      const SizedBox(width: 10),
                      const _PulsingDot(),
                      const SizedBox(width: 6),
                      Flexible(child: Text('Waiting...', overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12))),
                    ],
                    const Spacer(),
                    if (bids.length >= 2 && status == 'open')
                      GestureDetector(
                        onTap: () => _analyzeBids(bids),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: _aiAnalyzing
                                ? null
                                : const LinearGradient(
                                    colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)]),
                            color: _aiAnalyzing ? AppColors.surface2 : null,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: _aiAnalyzing
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.auto_awesome,
                                      color: Colors.white, size: 13),
                                  const SizedBox(width: 5),
                                  Text('AI Recommend',
                                      style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ]),
                        ),
                      ),
                  ]),
                ),
              ),

              // AI Recommendation card
              if (_aiRecommendedProvider != null) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1D1035), Color(0xFF0D1B3E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF8B5CF6).withValues(alpha:0.45)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.auto_awesome,
                              color: Color(0xFF8B5CF6), size: 13),
                          const SizedBox(width: 6),
                          Expanded(child: Text('AI RECOMMENDATION',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  color: const Color(0xFF8B5CF6),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4))),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 16),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_aiRecommendedProvider!,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800))),
                        ]),
                        if (_aiReason != null) ...[
                          const SizedBox(height: 6),
                          Text(_aiReason!,
                              maxLines: 3, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  height: 1.5)),
                        ],
                      ]),
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Empty bids state
              if (bids.isEmpty && status == 'open')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.hourglass_empty_rounded, color: AppColors.textDim, size: 44),
                        const SizedBox(height: 14),
                        Text('Waiting for providers to bid...', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('Providers in your area will respond shortly.\nPull down to refresh.', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, height: 1.5), textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BidCard(
                          bid: bids[i],
                          requestId: widget.requestId,
                          canAccept: status == 'open',
                          isAiRecommended: _aiRecommendedProvider != null &&
                              bids[i].providerName == _aiRecommendedProvider,
                          successScore: (_bidScores[bids[i].id]?['success_score'] as num?)?.toInt(),
                          onAccept: () => _acceptBid(bids[i]),
                          onChat: () => context.push(
                            '/service-request/${widget.requestId}/chat/${bids[i].id}',
                            extra: bids[i].providerName,
                          ),
                        ),
                      ),
                      childCount: bids.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Bid Card ─────────────────────────────────────────────────────────────────

class _BidCard extends StatefulWidget {
  final Bid bid;
  final String requestId;
  final bool canAccept;
  final bool isAiRecommended;
  final int? successScore;
  final VoidCallback onAccept;
  final VoidCallback onChat;

  const _BidCard({
    required this.bid,
    required this.requestId,
    required this.canAccept,
    required this.onAccept,
    required this.onChat,
    this.isAiRecommended = false,
    this.successScore,
  });

  @override
  State<_BidCard> createState() => _BidCardState();
}

class _BidCardState extends State<_BidCard> {
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final url = await AvatarCache.getAvatar(widget.bid.providerId);
    if (mounted && url != null) {
      setState(() => _avatarUrl = url);
    }
  }

  Bid get bid => widget.bid;
  String get requestId => widget.requestId;
  bool get canAccept => widget.canAccept;
  bool get isAiRecommended => widget.isAiRecommended;
  int? get successScore => widget.successScore;
  VoidCallback get onAccept => widget.onAccept;
  VoidCallback get onChat => widget.onChat;

  @override
  Widget build(BuildContext context) {
    final isAccepted = bid.status == 'accepted';
    final isRejected = bid.status == 'rejected';

    Color borderColor = AppColors.border;
    Color bgColor = AppColors.surface;
    if (isAccepted) {
      borderColor = AppColors.success.withValues(alpha:0.4);
      bgColor = AppColors.success.withValues(alpha:0.05);
    } else if (isRejected) {
      bgColor = AppColors.surface;
    }

    Color statusColor = AppColors.textDim;
    if (isAccepted) statusColor = AppColors.success;
    if (isRejected) statusColor = AppColors.error;

    return Opacity(
      opacity: isRejected ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GestureDetector(
              onTap: () => context.push('/provider/${bid.providerId}'),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha:0.1),
                    border: Border.all(color: AppColors.primary.withValues(alpha:0.2)),
                    image: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                        ? DecorationImage(image: CachedNetworkImageProvider(_avatarUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                      ? Center(child: Text(
                          bid.providerName.isNotEmpty ? bid.providerName[0].toUpperCase() : '?',
                          style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18),
                        ))
                      : null,
                ),
                const SizedBox(width: 12),
              ]),
            ),
            Expanded(child: GestureDetector(
              onTap: () => context.push('/provider/${bid.providerId}'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(bid.providerName, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (bid.providerPhone.isNotEmpty)
                  Text(bid.providerPhone, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Rs ${bid.price}', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(bid.status.toUpperCase(), style: GoogleFonts.inter(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
              ),
            ]),
          ]),

          if (successScore != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.auto_awesome, color: AppColors.success, size: 13),
                const SizedBox(width: 6),
                Text('$successScore% job success likelihood',
                    style: GoogleFonts.inter(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ],

          if (bid.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
              child: Text(bid.message, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
          ],

          if (!isRejected) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: onChat,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text('Chat', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ])),
                  ),
                ),
              ),
              if (canAccept) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: onAccept,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.success, Color(0xFF059669)]),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha:0.25), blurRadius: 10)],
                      ),
                      child: Center(child: Text('Accept Bid', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                    ),
                  ),
                ),
              ],
            ]),
          ],
        ]),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'open':        color = AppColors.primary;        label = 'OPEN';        break;
      case 'accepted':    color = AppColors.success;        label = 'ACCEPTED';    break;
      case 'in_progress': color = const Color(0xFFF59E0B); label = 'IN PROGRESS'; break;
      case 'completed':   color = AppColors.success;        label = 'DONE';        break;
      default:            color = AppColors.textDim;        label = status.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  late final _anim = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Opacity(
      opacity: _anim.value,
      child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success)),
    ),
  );
}
