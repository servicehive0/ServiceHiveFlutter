import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../models/service_request_model.dart';
import '../../providers/request_provider.dart';

class ActiveJobMapScreen extends StatefulWidget {
  final String requestId;
  // isProvider=true  → provider screen: sends live GPS, sees route to customer
  // isProvider=false → customer screen: watches provider marker move
  final bool isProvider;

  const ActiveJobMapScreen({
    super.key,
    required this.requestId,
    required this.isProvider,
  });

  @override
  State<ActiveJobMapScreen> createState() => _ActiveJobMapScreenState();
}

class _ActiveJobMapScreenState extends State<ActiveJobMapScreen> {
  final _mapController = MapController();

  ServiceRequest? _request;
  LatLng? _providerPos;
  List<LatLng> _routePoints = [];
  bool _loading = true;
  bool _routeLoading = false;

  Timer? _pollTimer;
  Timer? _locationTimer;

  static const _defaultCenter = LatLng(31.5204, 74.3587); // Lahore

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    // Load request once
    final req = await context.read<RequestProvider>().fetchRequest(widget.requestId);
    if (!mounted) return;
    setState(() { _request = req; _loading = false; });

    if (widget.isProvider) _startSendingLocation();

    // Poll DB every 3 seconds for updated provider coordinates
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollRequest());
    await _pollRequest(); // first poll immediately
  }

  // ── Provider: send GPS to Supabase every 5s ──────────────────────────────

  Future<void> _startSendingLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return;

    // Send first reading immediately
    await _sendCurrentLocation();

    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sendCurrentLocation());
  }

  Future<void> _sendCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      await context.read<RequestProvider>().updateProviderLocation(
        widget.requestId, pos.latitude, pos.longitude,
      );
    } catch (_) {}
  }

  // ── Poll for latest request state (provider coords) ──────────────────────

  Future<void> _pollRequest() async {
    if (!mounted) return;
    final req = await context.read<RequestProvider>().fetchRequest(widget.requestId);
    if (!mounted || req == null) return;
    setState(() => _request = req);

    final pLat = req.providerLat;
    final pLng = req.providerLng;
    if (pLat == null || pLng == null) return;

    final newPos = LatLng(pLat, pLng);
    final moved = _providerPos == null ||
        _providerPos!.latitude != newPos.latitude ||
        _providerPos!.longitude != newPos.longitude;

    setState(() => _providerPos = newPos);

    // Re-draw route when provider position changes
    if (moved && req.latitude != null && req.longitude != null) {
      await _fetchRoute(newPos, LatLng(req.latitude!, req.longitude!));
    }
  }

  // ── OSRM routing (free, no API key) ──────────────────────────────────────

  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    if (_routeLoading) return;
    setState(() => _routeLoading = true);
    try {
      final url =
          'http://router.project-osrm.org/route/v1/driving/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200 || !mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final coords = (data['routes'] as List?)?.first['geometry']['coordinates'] as List?;
      if (coords == null || !mounted) return;
      setState(() {
        _routePoints = coords
            .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  // ── Open in external maps ─────────────────────────────────────────────────

  Future<void> _openExternalMaps() async {
    final req = _request;
    if (req == null) return;
    final query = Uri.encodeComponent('${req.address}, ${req.area}, ${req.city}');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Fit both markers on screen ────────────────────────────────────────────

  void _fitBoth() {
    final req = _request;
    if (req == null) return;
    final custPos = (req.latitude != null && req.longitude != null)
        ? LatLng(req.latitude!, req.longitude!)
        : null;
    final provPos = _providerPos;

    if (custPos != null && provPos != null) {
      final bounds = LatLngBounds.fromPoints([custPos, provPos]);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
    } else if (provPos != null) {
      _mapController.move(provPos, 15);
    } else if (custPos != null) {
      _mapController.move(custPos, 15);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final req = _request;
    final custPos = (req?.latitude != null && req?.longitude != null)
        ? LatLng(req!.latitude!, req.longitude!)
        : null;
    final provPos = _providerPos;
    final initialCenter = provPos ?? custPos ?? _defaultCenter;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : Stack(children: [

              // ── Map ────────────────────────────────────────────────────
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: initialCenter, initialZoom: 14),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.servicehive.app',
                  ),

                  // Route polyline
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: _routePoints,
                        color: AppColors.primary,
                        strokeWidth: 5,
                        borderColor: AppColors.primary.withValues(alpha: 0.25),
                        borderStrokeWidth: 10,
                      ),
                    ]),

                  // Markers
                  MarkerLayer(markers: [
                    // Customer home marker
                    if (custPos != null)
                      Marker(
                        point: custPos,
                        width: 52, height: 62,
                        child: const _MapPin(
                          color: AppColors.success,
                          icon: Icons.home_rounded,
                          label: 'Customer',
                        ),
                      ),

                    // Provider live marker
                    if (provPos != null)
                      Marker(
                        point: provPos,
                        width: 52, height: 62,
                        child: const _MapPin(
                          color: AppColors.primary,
                          icon: Icons.directions_car_rounded,
                          label: 'Provider',
                        ),
                      ),
                  ]),
                ],
              ),

              // ── Top bar ────────────────────────────────────────────────
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                        ),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text('Live Tracking', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            if (req != null)
                              Text(req.serviceName, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 6, height: 6,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success),
                              ),
                              const SizedBox(width: 5),
                              Text('LIVE', style: GoogleFonts.inter(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),

              // ── Right-side FABs ────────────────────────────────────────
              // bottom offset scales with screen height (with a safe floor)
              // so these don't overlap the bottom info panel on short screens
              // or when the route-info row makes that panel taller.
              Positioned(
                right: 16,
                bottom: (MediaQuery.of(context).size.height * 0.28).clamp(200, 320),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Fit both markers
                  GestureDetector(
                    onTap: _fitBoth,
                    child: const _MapFab(icon: Icons.fit_screen_rounded),
                  ),
                  const SizedBox(height: 10),
                  // Center on provider
                  if (provPos != null)
                    GestureDetector(
                      onTap: () => _mapController.move(provPos, _mapController.camera.zoom),
                      child: const _MapFab(icon: Icons.my_location_rounded),
                    ),
                ]),
              ),

              // ── Bottom info panel ──────────────────────────────────────
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: const Border(top: BorderSide(color: AppColors.border)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Center(child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(100)),
                    )),
                    const SizedBox(height: 16),

                    if (req != null) ...[
                      // Provider location status row
                      Row(children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.1),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            widget.isProvider ? 'Your Location' : 'Provider',
                            style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            provPos != null ? 'Sharing live location' : 'Waiting for location...',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ])),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            const Icon(Icons.home_rounded, color: AppColors.success, size: 16),
                            Text(req.area, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(req.city, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                      ]),

                      const SizedBox(height: 14),

                      // Route info
                      if (_routePoints.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(children: [
                            const Icon(Icons.route_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Text('Route calculated', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                          ]),
                        )
                      else if (provPos == null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(children: [
                            const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Text('Waiting for provider location...', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                          ]),
                        ),

                      // Open in external maps button
                      GestureDetector(
                        onTap: _openExternalMaps,
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('Open in Maps App', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                          ])),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ]),
    );
  }
}

// ── Map Pin widget ────────────────────────────────────────────────────────────

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;

  const _MapPin({required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8, spreadRadius: 1)],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
    Container(width: 2.5, height: 12, color: color),
  ]);
}

// ── Floating action button ────────────────────────────────────────────────────

class _MapFab extends StatelessWidget {
  final IconData icon;
  const _MapFab({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10)],
    ),
    child: Icon(icon, color: AppColors.primary, size: 22),
  );
}
