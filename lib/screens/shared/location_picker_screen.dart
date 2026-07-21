import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const LocationPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapController = MapController();
  LatLng _center = const LatLng(31.5204, 74.3587); // Lahore default
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
    } else {
      _goToMyLocation();
    }
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _center = loc);
      _mapController.move(loc, 16);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 15,
            onPositionChanged: (camera, _) => setState(() => _center = camera.center),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.servicehive.app',
            ),
          ],
        ),

        // Center pin — tail sits exactly at map center
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.45), blurRadius: 10)],
              ),
            ),
            Container(width: 2.5, height: 18, color: AppColors.primary),
            const SizedBox(height: 18), // push pin tip to center
          ]),
        ),

        // Top bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.bg, AppColors.bg.withValues(alpha: 0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                  ),
                  child: Row(children: [
                    const Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Drag map to set your location',
                      style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),

        // GPS button
        Positioned(
          right: 16, bottom: 160,
          child: GestureDetector(
            onTap: _locating ? null : _goToMyLocation,
            child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10)],
              ),
              child: _locating
                  ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                  : const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 22),
            ),
          ),
        ),

        // Bottom panel
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.97),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: const Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(100)),
              )),
              const SizedBox(height: 14),
              // Coordinates preview
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${_center.latitude.toStringAsFixed(6)},  ${_center.longitude.toStringAsFixed(6)}',
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              // Confirm button
              GestureDetector(
                onTap: () => Navigator.pop(context, _center),
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.35), blurRadius: 15)],
                  ),
                  child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text('Confirm Location', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ])),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
