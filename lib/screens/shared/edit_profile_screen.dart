import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/location_dropdown.dart';
import 'change_password_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();

  String? _selectedCity;
  String? _selectedArea;
  double? _latitude;
  double? _longitude;
  bool _saving          = false;
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill existing user data
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameCtrl.text    = user.name;
      _phoneCtrl.text   = user.phone;
      _addressCtrl.text = user.address;
      _selectedCity     = user.city.isNotEmpty ? user.city : null;
      _selectedArea     = user.area.isNotEmpty ? user.area : null;
      _latitude         = user.latitude;
      _longitude        = user.longitude;
    }
    // Fetch cities from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().fetch();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().length < 2) {
      _snack('Name must be at least 2 characters', error: true);
      return;
    }
    setState(() => _saving = true);

    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      name:      _nameCtrl.text.trim(),
      phone:     _phoneCtrl.text.trim(),
      city:      _selectedCity ?? '',
      area:      _selectedArea ?? '',
      address:   _addressCtrl.text.trim(),
      latitude:  _latitude,
      longitude: _longitude,
    );

    setState(() => _saving = false);

    if (!mounted) return;
    if (ok) {
      _snack('Profile updated successfully!');
      Navigator.pop(context);
    } else {
      _snack('Failed to update. Try again.', error: true);
    }
  }

  Future<void> _captureLocation() async {
    setState(() => _gettingLocation = true);

    try {
      // 1. Check if location service is ON
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (mounted) {
          _snack('Phone ka Location / GPS on karo, phir dobara try karo.', error: true);
        }
        setState(() => _gettingLocation = false);
        return;
      }

      // 2. Check permission
      LocationPermission perm = await Geolocator.checkPermission();

      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          // Open app settings so user can manually enable
          await Geolocator.openAppSettings();
          _snack('Permission denied. Settings se location allow karo.', error: true);
        }
        setState(() => _gettingLocation = false);
        return;
      }

      if (perm == LocationPermission.denied) {
        if (mounted) {
          _snack('Location permission allow karo.', error: true);
        }
        setState(() => _gettingLocation = false);
        return;
      }

      // 3. Get position (no timeLimit to avoid compatibility issues)
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      if (mounted) {
        setState(() {
          _latitude  = pos.latitude;
          _longitude = pos.longitude;
        });
        _snack('Location save ho gaya! Changes save karo.');
      }
    } catch (e) {
      if (mounted) {
        _snack('Location nahi mila. GPS on hai? Try again.', error: true);
      }
    }

    if (mounted) setState(() => _gettingLocation = false);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final loc  = context.watch<LocationProvider>();
    final areas = _selectedCity != null ? loc.areasFor(_selectedCity!) : <String>[];

    // initials for avatar
    final initials = user?.name.isNotEmpty == true
        ? user!.name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
        ),
        title: Text('Edit Profile',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark]),
                      boxShadow: [BoxShadow(
                          color: AppColors.primary.withOpacity(0.4), blurRadius: 20)],
                    ),
                    child: Center(
                      child: Text(initials,
                        style: GoogleFonts.inter(
                            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 30)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Email (read-only display)
            Center(
              child: Text(user?.email ?? '',
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
            ),
            const SizedBox(height: 28),

            // ── Personal Info ──────────────────────────────────
            _label('Personal Info'),
            const SizedBox(height: 12),
            AppInput(
              label: 'Full Name',
              hint: 'Your full name',
              controller: _nameCtrl,
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  color: AppColors.textDim, size: 18),
            ),
            const SizedBox(height: 14),
            AppInput(
              label: 'Phone Number',
              hint: '03XXXXXXXXX',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              prefixIcon: const Icon(Icons.phone_outlined,
                  color: AppColors.textDim, size: 18),
            ),
            const SizedBox(height: 28),

            // ── Location ───────────────────────────────────────
            _label('Location'),
            const SizedBox(height: 12),

            if (loc.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2),
                ),
              )
            else ...[
              LocationDropdown(
                label: 'City',
                hint: 'Select your city',
                icon: Icons.location_city_outlined,
                value: _selectedCity,
                items: loc.cities,
                onChanged: (v) => setState(() {
                  _selectedCity = v;
                  _selectedArea = null;
                }),
              ),
              const SizedBox(height: 14),
              LocationDropdown(
                label: 'Area',
                hint: _selectedCity == null ? 'Select city first' : 'Select your area',
                icon: Icons.map_outlined,
                value: _selectedArea,
                items: areas,
                enabled: _selectedCity != null && areas.isNotEmpty,
                onChanged: (v) => setState(() => _selectedArea = v),
              ),
            ],
            const SizedBox(height: 14),
            AppInput(
              label: 'Complete Address',
              hint: 'House # / Street / Landmark',
              controller: _addressCtrl,
              maxLines: 2,
              prefixIcon: const Icon(Icons.home_outlined,
                  color: AppColors.textDim, size: 18),
            ),
            const SizedBox(height: 14),

            // ── Current Location ─────────────────────────────
            _label('Current Location (GPS)'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _gettingLocation ? null : _captureLocation,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _latitude != null
                      ? AppColors.success.withOpacity(0.07)
                      : AppColors.error.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _latitude != null
                        ? AppColors.success.withOpacity(0.3)
                        : AppColors.error.withOpacity(0.4),
                  ),
                ),
                child: Row(children: [
                  // Red/Green pin icon
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_latitude != null
                          ? AppColors.success
                          : AppColors.error).withOpacity(0.12),
                    ),
                    child: _gettingLocation
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary),
                          )
                        : Icon(
                            Icons.location_on_rounded,
                            color: _latitude != null
                                ? AppColors.success
                                : AppColors.error,
                            size: 24,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _latitude != null
                              ? 'Location Saved'
                              : 'Location Not Set',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _latitude != null
                              ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                              : 'Tap to capture your current GPS location',
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _latitude != null
                        ? Icons.refresh_rounded
                        : Icons.gps_fixed_rounded,
                    color: _latitude != null
                        ? AppColors.success
                        : AppColors.error,
                    size: 20,
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Used to find nearby service providers.',
              style: GoogleFonts.inter(
                  color: AppColors.textDim, fontSize: 11),
            ),
            const SizedBox(height: 28),

            AppButton(
              label: 'SAVE CHANGES',
              icon: Icons.check_rounded,
              isLoading: _saving,
              onTap: _save,
            ),
            const SizedBox(height: 12),

            // Change Password button
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen()),
              ),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_reset_rounded,
                      color: AppColors.textMuted, size: 20),
                    const SizedBox(width: 10),
                    Text('Change Password',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(
    t.toUpperCase(),
    style: GoogleFonts.inter(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1),
  );
}
