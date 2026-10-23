import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/floating_particles.dart';

// Shown instead of the login/auth screen while Admin Dashboard → Global
// Settings → "Enable maintenance mode" is on (see router.dart redirect).
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final message = context.watch<AppSettingsProvider>().maintenanceMessage;
    final isLoggedIn = context.watch<AuthProvider>().isAuthenticated;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(top: -100, left: -100, child: _orb(AppColors.primary.withValues(alpha: 0.15), 350)),
          Positioned(bottom: -100, right: -100, child: _orb(const Color(0xFF6366F1).withValues(alpha: 0.1), 300)),
          const Positioned.fill(child: FloatingParticles(count: 40)),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 5)],
                    ),
                    child: const Icon(Icons.build_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 28),
                  Text('Under Maintenance',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(message,
                      style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14, height: 1.6),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(
                      onTap: () => context.read<AppSettingsProvider>().fetchPlatformSettings(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text('Check Again', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                    if (isLoggedIn) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => context.read<AuthProvider>().logout(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.logout_rounded, color: AppColors.textMuted, size: 16),
                            const SizedBox(width: 8),
                            Text('Logout', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(Color color, double size) =>
      Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}
