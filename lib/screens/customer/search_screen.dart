import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/provider_model.dart';
import '../../providers/provider_list_provider.dart';
import '../../providers/services_provider.dart';
import '../../services/ai_insights_service.dart';

class SearchScreen extends StatefulWidget {
  final String? initialService;
  const SearchScreen({super.key, this.initialService});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';
  String? _selectedService;
  // ML-predicted rating (Service-Hive-ML/train_rating.py — a real trained
  // regression model, not an LLM) for providers with no real rating yet.
  Map<String, dynamic> _predictedRatings = {};
  bool _predictedForCurrentList = false;

  @override
  void initState() {
    super.initState();
    _selectedService = widget.initialService;
  }

  Future<void> _fetchPredictedRatings(List<ProviderModel> providers) async {
    final unrated = providers.where((p) => p.rating <= 0).toList();
    if (unrated.isEmpty) return;
    final payload = unrated.map((p) => {
      'provider_id': p.id,
      'total_jobs': p.totalJobs,
      'experience_years': double.tryParse(p.experience.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
    }).toList();
    final result = await AiInsightsService.predictProviderRatingML(payload);
    if (mounted && result != null) setState(() => _predictedRatings = result);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProviderListProvider>();
    final servicesProv = context.watch<ServicesProvider>();

    if (!servicesProv.loaded && !servicesProv.loading) {
      Future.microtask(() => servicesProv.fetch());
    }

    final filters = ['All', ...servicesProv.services.map((s) => s.name)];

    List<ProviderModel> results = _query.isNotEmpty
        ? prov.search(_query)
        : (_selectedService != null && _selectedService != 'All')
            ? prov.byService(_selectedService!)
            : prov.providers;

    if (!_predictedForCurrentList && prov.providers.isNotEmpty) {
      _predictedForCurrentList = true;
      Future.microtask(() => _fetchPredictedRatings(prov.providers));
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Find Providers',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                // Search input
                Container(
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
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search by name, skill...',
                            hintStyle: GoogleFonts.inter(color: AppColors.textDim, fontSize: 14),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () { _ctrl.clear(); setState(() => _query = ''); },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Icon(Icons.close_rounded, color: AppColors.textDim, size: 18),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Dynamic filter chips
                SizedBox(
                  height: 34,
                  child: servicesProv.loading
                      ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: filters.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final f = filters[i];
                            final active = (f == 'All' && (_selectedService == null || _selectedService == 'All'))
                                || f == _selectedService;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedService = f == 'All' ? null : f),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: active ? AppColors.primary : AppColors.surface2,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: active ? AppColors.primary : AppColors.border),
                                ),
                                child: Center(
                                  child: Text(f,
                                    style: GoogleFonts.inter(
                                      color: active ? Colors.white : AppColors.textMuted,
                                      fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded, color: AppColors.textDim, size: 48),
                        const SizedBox(height: 12),
                        Text('No providers found', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _ProviderTile(
                      provider: results[i],
                      predictedRating: _predictedRatings[results[i].id] as num?,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final ProviderModel provider;
  final num? predictedRating;
  const _ProviderTile({required this.provider, this.predictedRating});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/provider/${provider.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                  ),
                  child: Center(
                    child: Text(provider.name[0],
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                  ),
                ),
                if (provider.isOnline)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.success,
                        border: Border.all(color: AppColors.bg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider.name,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(provider.serviceType,
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (provider.rating > 0) ...[
                        const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 12),
                        const SizedBox(width: 3),
                        Text(provider.rating.toStringAsFixed(1),
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ] else if (predictedRating != null) ...[
                        const Icon(Icons.star_outline_rounded, color: AppColors.textDim, size: 12),
                        const SizedBox(width: 3),
                        Text('~${predictedRating!.toStringAsFixed(1)}',
                          style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 2),
                        Text('(est.)',
                          style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10)),
                      ],
                      const SizedBox(width: 8),
                      Text('${provider.totalJobs} jobs',
                        style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Rs ${provider.ratePerHour.toInt()}/hr',
                  style: GoogleFonts.inter(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                if (provider.city.isNotEmpty)
                  Text(provider.city,
                    style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
