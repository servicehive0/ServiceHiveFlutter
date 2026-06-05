import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/provider_model.dart';
import '../../providers/provider_list_provider.dart';

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

  static const _filters = [
    'All', 'Electrical', 'Plumbing', 'AC Service',
    'Painting', 'Cleaning', 'Repair', 'Carpentry', 'Gardening',
  ];

  @override
  void initState() {
    super.initState();
    _selectedService = widget.initialService;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProviderListProvider>();
    List<ProviderModel> results = _query.isNotEmpty
        ? prov.search(_query)
        : (_selectedService != null && _selectedService != 'All')
            ? prov.byService(_selectedService!)
            : prov.providers;

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
                // Filter chips
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final f = _filters[i];
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
                    itemBuilder: (_, i) => _ProviderTile(provider: results[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final ProviderModel provider;
  const _ProviderTile({required this.provider});

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
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(provider.serviceType,
                    style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 13),
                      const SizedBox(width: 3),
                      Text('${provider.rating} (${provider.reviewCount})',
                        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 10),
                      const Icon(Icons.location_on_rounded, color: AppColors.textDim, size: 11),
                      const SizedBox(width: 2),
                      Text(provider.area,
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
                  style: GoogleFonts.inter(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${provider.totalJobs} jobs',
                  style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
