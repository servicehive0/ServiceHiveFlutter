import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import 'ai_chat_screen.dart';
import 'ai_service_finder_screen.dart';
import 'ai_price_estimator_screen.dart';
import 'ai_scheduling_screen.dart';
import 'ai_provider_match_screen.dart';

class AiAssistantScreen extends StatelessWidget {
  const AiAssistantScreen({super.key});

  static const _features = [
    _AiFeature(
      icon: Icons.chat_bubble_rounded,
      color: Color(0xFF8B5CF6),
      title: 'AI Chat Assistant',
      desc: 'Describe any home problem — get instant advice, identify who to call, and what to do right now.',
      tag: 'LIVE',
      isLive: true,
    ),
    _AiFeature(
      icon: Icons.auto_fix_high_rounded,
      color: Color(0xFF3B82F6),
      title: 'Smart Service Finder',
      desc: 'Describe your problem — AI detects which service you need and posts the request for you.',
      tag: 'LIVE',
      isLive: true,
    ),
    _AiFeature(
      icon: Icons.price_check_rounded,
      color: Color(0xFF10B981),
      title: 'Price Estimator',
      desc: 'Describe the job — AI estimates a realistic price range in PKR.',
      tag: 'LIVE',
      isLive: true,
    ),
    _AiFeature(
      icon: Icons.schedule_rounded,
      color: Color(0xFFF59E0B),
      title: 'Smart Scheduling',
      desc: 'AI picks the best time slot, duration, and preparation tips for your job.',
      tag: 'LIVE',
      isLive: true,
    ),
    _AiFeature(
      icon: Icons.verified_user_rounded,
      color: Color(0xFFEC4899),
      title: 'Provider Match',
      desc: 'AI tells you exactly what skills and experience to look for in a provider.',
      tag: 'LIVE',
      isLive: true,
    ),
  ];

  void _onFeatureTap(BuildContext ctx, int index) {
    switch (index) {
      case 0:
        Navigator.push(ctx, MaterialPageRoute(builder: (_) => const AiChatScreen()));
      case 1:
        Navigator.push(ctx, MaterialPageRoute(builder: (_) => const AiServiceFinderScreen()));
      case 2:
        Navigator.push(ctx, MaterialPageRoute(builder: (_) => const AiPriceEstimatorScreen()));
      case 3:
        Navigator.push(ctx, MaterialPageRoute(builder: (_) => const AiSchedulingScreen()));
      case 4:
        Navigator.push(ctx, MaterialPageRoute(builder: (_) => const AiProviderMatchScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)]),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 12),
                        const SizedBox(width: 5),
                        Text(
                          'POWERED BY SERVICEHIVE AI',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ServiceHive AI',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your intelligent home service assistant.\nSmarter bookings, better matches, instant answers.',
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Hero chat card ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: () => _onFeatureTap(context, 0),
                child: Container(
                  height: 210,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D1035), Color(0xFF0D1B3E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                        width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 170, height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            width: 40,
                          ),
                        ),
                      ),
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.18),
                            width: 18,
                          ),
                        ),
                      ),
                      Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.55),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 30),
                      ),
                      Positioned(
                        top: 18, right: 18,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.success),
                              ),
                              const SizedBox(width: 5),
                              Text('LIVE',
                                  style: GoogleFonts.inter(
                                      color: AppColors.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 18,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                            ),
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text('Start Chatting',
                                  style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Section title ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'AI Features',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // ── Feature cards ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FeatureCard(
                    feature: _features[i],
                    onTap: _features[i].isLive
                        ? () => _onFeatureTap(context, i)
                        : null,
                  ),
                ),
                childCount: _features.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Data ───────────────────────────────────────────────────────────────────────

class _AiFeature {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final String tag;
  final bool isLive;
  const _AiFeature({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.tag,
    this.isLive = false,
  });
}

// ── Feature card ───────────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final _AiFeature feature;
  final VoidCallback? onTap;
  const _FeatureCard({required this.feature, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: feature.isLive
              ? feature.color.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: feature.isLive
                ? feature.color.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: feature.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(feature.icon, color: feature.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          feature.title,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: feature.isLive
                              ? AppColors.success.withValues(alpha: 0.12)
                              : feature.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          feature.tag,
                          style: GoogleFonts.inter(
                            color: feature.isLive
                                ? AppColors.success
                                : feature.color,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature.desc,
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (feature.isLive) ...[
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: feature.color.withValues(alpha: 0.7), size: 14),
            ],
          ],
        ),
      ),
    );
  }
}
