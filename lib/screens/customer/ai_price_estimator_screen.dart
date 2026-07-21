import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/services_provider.dart';
import '../../services/ai_insights_service.dart';

const _complexityLabels = {1: 'Very simple', 2: 'Simple', 3: 'Typical', 4: 'Involved', 5: 'Complex'};

class _Estimate {
  final int minPrice;
  final int maxPrice;
  final String serviceType;

  const _Estimate({required this.minPrice, required this.maxPrice, required this.serviceType});
}

class AiPriceEstimatorScreen extends StatefulWidget {
  const AiPriceEstimatorScreen({super.key});

  @override
  State<AiPriceEstimatorScreen> createState() => _AiPriceEstimatorScreenState();
}

class _AiPriceEstimatorScreenState extends State<AiPriceEstimatorScreen> {
  final _ctrl = TextEditingController();
  String? _selectedService;
  int _complexity = 3;
  bool _loading = false;
  _Estimate? _estimate;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<ServicesProvider>();
      if (!prov.loaded && !prov.loading) prov.fetch();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Predicted by OUR OWN trained regression model (One-Hot Encoding +
  // Random Forest, see Service-Hive-ML/train_price.py) — not an LLM call.
  Future<void> _estimate_() async {
    if (_selectedService == null) return;

    final city = context.read<AuthProvider>().user?.city;
    setState(() { _loading = true; _error = null; _estimate = null; });

    final result = await AiInsightsService.predictPriceML(
      serviceType: _selectedService!,
      city: city,
      complexity: _complexity,
    );

    if (!mounted) return;
    if (result != null && result['min_price'] != null) {
      setState(() => _estimate = _Estimate(
            minPrice: (result['min_price'] as num).toInt(),
            maxPrice: (result['max_price'] as num).toInt(),
            serviceType: _selectedService!,
          ));
    } else {
      setState(() => _error = 'Could not estimate. Please try again.');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final city = context.watch<AuthProvider>().user?.city ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.price_check_rounded,
                          color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Price Estimator',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    Text('ML-powered PKR estimate for your service',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
            ),
          ),

          // ── Input card ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // City chip
                  if (city.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.location_on_rounded,
                            color: Color(0xFF10B981), size: 13),
                        const SizedBox(width: 4),
                        Text(city,
                            style: GoogleFonts.inter(
                                color: const Color(0xFF10B981),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),

                  Text('Choose a service and its complexity to get an estimated price range.',
                      style: GoogleFonts.inter(
                          color: AppColors.textDim,
                          fontSize: 11,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: 14),

                  Text('Service Type',
                      style: GoogleFonts.inter(
                          color: AppColors.textDim,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Consumer<ServicesProvider>(
                    builder: (context, servicesProv, _) => Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedService,
                          isExpanded: true,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          dropdownColor: AppColors.surface2,
                          hint: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text('Select a service',
                                style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 14)),
                          ),
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                          items: servicesProv.services
                              .map((s) => DropdownMenuItem(value: s.name, child: Text(s.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedService = v),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('Job Complexity — ${_complexityLabels[_complexity]}',
                      style: GoogleFonts.inter(
                          color: AppColors.textDim,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  Slider(
                    value: _complexity.toDouble(),
                    min: 1, max: 5, divisions: 4,
                    activeColor: const Color(0xFF10B981),
                    inactiveColor: AppColors.surface2,
                    onChanged: (v) => setState(() => _complexity = v.round()),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: (_loading || _selectedService == null) ? null : _estimate_,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: (_loading || _selectedService == null)
                            ? null
                            : const LinearGradient(colors: [
                                Color(0xFF10B981),
                                Color(0xFF059669)
                              ]),
                        color: (_loading || _selectedService == null) ? AppColors.surface2 : null,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: (_loading || _selectedService == null)
                            ? null
                            : [
                                BoxShadow(
                                    color: const Color(0xFF10B981)
                                        .withOpacity(0.3),
                                    blurRadius: 14)
                              ],
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calculate_rounded,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Price Estimate Karo',
                                      style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ── Error ──────────────────────────────────────────────────────────
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 15),
                  const SizedBox(width: 6),
                  Text(_error!,
                      style: GoogleFonts.inter(
                          color: AppColors.error, fontSize: 12)),
                ]),
              ),
            ),

          // ── Result ─────────────────────────────────────────────────────────
          if (_estimate != null) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Price range hero card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF082D20), Color(0xFF0A1628)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.45)),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          blurRadius: 24)
                    ],
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      const Icon(Icons.auto_awesome,
                          color: Color(0xFF10B981), size: 14),
                      const SizedBox(width: 6),
                      Text('AI PRICE ESTIMATE',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF10B981),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                      const Spacer(),
                      Text(_estimate!.serviceType,
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 20),

                    // Price range display
                    Row(children: [
                      Expanded(
                        child: _PriceBox(
                          label: 'MINIMUM',
                          amount: _estimate!.minPrice,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('—',
                            style: GoogleFonts.inter(
                                color: AppColors.textDim, fontSize: 20)),
                      ),
                      Expanded(
                        child: _PriceBox(
                          label: 'MAXIMUM',
                          amount: _estimate!.maxPrice,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Icon(Icons.info_outline_rounded,
                            color: Color(0xFF10B981), size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                'Predicted by our trained ML model from real service pricing.',
                                style: GoogleFonts.inter(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    height: 1.5))),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),

            // Disclaimer
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '* Yeh estimate hai — actual price provider ki bid pe depend karti hai.',
                  style: GoogleFonts.inter(
                      color: AppColors.textDim,
                      fontSize: 11,
                      height: 1.5),
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Price box ─────────────────────────────────────────────────────────────────

class _PriceBox extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;

  const _PriceBox({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text('Rs ${_fmt(amount)}',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
        ]),
      );

  String _fmt(int n) {
    if (n >= 1000) {
      final s = n.toString();
      return s.length > 3 ? '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}' : s;
    }
    return n.toString();
  }
}
