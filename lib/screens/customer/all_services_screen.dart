import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
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

class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({super.key});

  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<ServicesProvider>();
    if (!prov.loaded && !prov.loading) {
      Future.microtask(prov.fetch);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicesProv = context.watch<ServicesProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('All Services', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                      if (!servicesProv.loading)
                        Text('${servicesProv.services.length} service${servicesProv.services.length == 1 ? '' : 's'} available',
                          style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: servicesProv.loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : RefreshIndicator(
                      onRefresh: () => context.read<ServicesProvider>().refresh(),
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      child: servicesProv.services.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: Center(
                                child: Text('No services available yet.',
                                  style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 14)),
                              ),
                            ),
                          ],
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                          itemCount: servicesProv.services.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 116,
                          ),
                          itemBuilder: (_, i) {
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
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, height: 1.3),
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
                        ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
