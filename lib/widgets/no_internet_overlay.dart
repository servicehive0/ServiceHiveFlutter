import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import 'floating_particles.dart';

/// Full-screen "you're offline" cover, shown app-wide (see main.dart) the
/// instant the device loses network — mirrors MaintenanceScreen's visual
/// style so a connectivity drop reads as a deliberate, on-brand state
/// rather than a broken/blank screen. Auto-dismisses itself: this is a
/// pure presentational widget with no dismiss/retry button, since
/// ConnectivityProvider already removes it the moment the OS reports the
/// network is back — nothing for the user to tap.
class NoInternetOverlay extends StatelessWidget {
  const NoInternetOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      child: Stack(
        children: [
          Positioned(top: -100, left: -100, child: _orb(AppColors.primary.withOpacity(0.15), 350)),
          Positioned(bottom: -100, right: -100, child: _orb(const Color(0xFF6366F1).withOpacity(0.1), 300)),
          const Positioned.fill(child: FloatingParticles(count: 40)),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
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
                          boxShadow: [
                            BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 30, spreadRadius: 5),
                          ],
                        ),
                        child: const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 40),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'SERVICE',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                        ),
                        TextSpan(
                          text: 'HIVE',
                          style: GoogleFonts.inter(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('No Internet Connection',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text(
                    'Please check your Wi-Fi or mobile data.\nWe\'ll reconnect automatically.',
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13.5, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: 140,
                    child: LinearProgressIndicator(
                      backgroundColor: AppColors.surface2,
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Waiting for connection…',
                      style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w500)),
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
