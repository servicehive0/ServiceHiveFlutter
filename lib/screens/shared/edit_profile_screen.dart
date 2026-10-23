import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/provider_list_provider.dart';
import '../../providers/services_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/location_dropdown.dart';

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

  String? _selectedSpecialization;
  bool _savingSpecialization = false;
  final _skillInputCtrl = TextEditingController();
  final _skillInputFocus = FocusNode();
  List<String> _skills = [];
  final _experienceCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();

  // Which visibility toggle (if any) is mid-save — per-key rather than one
  // shared bool, so flipping one switch doesn't spin all of them.
  String? _savingVisibilityKey;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<LocationProvider>().fetch();
      if (user?.role == 'provider') {
        await context.read<ServicesProvider>().fetch();
        // service_type/skills/experience have always worked here — select
        // them on their own first so a problem with the newer about/
        // rate_per_hour columns (e.g. one not existing yet in this DB) can
        // never take the whole query down and blank out fields that were
        // already saving fine.
        try {
          final data = await Supabase.instance.client
              .from('provider_profiles')
              .select('service_type, skills, experience')
              .eq('id', user!.id)
              .maybeSingle();
          if (!mounted) return;
          final current = data?['service_type'] as String?;
          if (current != null && current.isNotEmpty) {
            setState(() => _selectedSpecialization = current);
          }
          final skills = data?['skills'];
          _skills = skills is List
              ? List<String>.from(skills)
              : (skills is String && skills.isNotEmpty
                  ? skills.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
                  : <String>[]);
          _experienceCtrl.text = data?['experience'] as String? ?? '';
          if (mounted) setState(() {});
        } catch (e, st) {
          debugPrint('EditProfileScreen provider-profile load error: $e\n$st');
        }
        try {
          final extra = await Supabase.instance.client
              .from('provider_profiles')
              .select('about, rate_per_hour')
              .eq('id', user!.id)
              .maybeSingle();
          if (!mounted) return;
          _aboutCtrl.text = extra?['about'] as String? ?? '';
          final rate = extra?['rate_per_hour'] as num?;
          _rateCtrl.text = (rate != null && rate > 0) ? rate.toInt().toString() : '';
          if (mounted) setState(() {});
        } catch (e, st) {
          debugPrint('EditProfileScreen about/rate load error: $e\n$st');
        }
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _skillInputCtrl.dispose();
    _skillInputFocus.dispose();
    _experienceCtrl.dispose();
    _aboutCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  // Comma or Enter commits whatever's typed as a new skill chip — lets
  // someone type "Wiring, Solar panels" in one go (comma-separated, same as
  // before) or add them one at a time and still end up with the same list.
  void _commitSkillInput() {
    final raw = _skillInputCtrl.text;
    final parts = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    final added = <String>[];
    for (final s in parts) {
      if (!_skills.contains(s)) added.add(s);
    }
    if (added.isEmpty) {
      _skillInputCtrl.clear();
      return;
    }
    setState(() {
      _skills = [..._skills, ...added];
      _skillInputCtrl.clear();
    });
  }

  void _removeSkill(String skill) {
    setState(() => _skills = _skills.where((s) => s != skill).toList());
  }

  Future<bool> _saveSkillsExperience() async {
    _commitSkillInput();
    try {
      await Supabase.instance.client.from('provider_profiles').upsert({
        'id': context.read<AuthProvider>().user!.id,
        'skills': _skills,
        'experience': _experienceCtrl.text.trim(),
        'about': _aboutCtrl.text.trim(),
        'rate_per_hour': num.tryParse(_rateCtrl.text.trim()) ?? 0,
      }, onConflict: 'id');
      return true;
    } catch (e, st) {
      debugPrint('_saveSkillsExperience error: $e\n$st');
      return false;
    }
  }

  Future<void> _saveSpecialization(String serviceType) async {
    setState(() { _selectedSpecialization = serviceType; _savingSpecialization = true; });
    final ok = await context.read<AuthProvider>().updateProviderSpecialization(serviceType);
    if (!mounted) return;
    setState(() => _savingSpecialization = false);
    _snack(ok ? 'Specialization saved!' : 'Failed to save. Try again.', error: !ok);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().length < 2) {
      _snack('Name must be at least 2 characters', error: true);
      return;
    }
    setState(() => _saving = true);

    final auth = context.read<AuthProvider>();
    var ok = await auth.updateProfile(
      name:      _nameCtrl.text.trim(),
      phone:     _phoneCtrl.text.trim(),
      city:      _selectedCity ?? '',
      area:      _selectedArea ?? '',
      address:   _addressCtrl.text.trim(),
      latitude:  _latitude,
      longitude: _longitude,
    );

    if (ok && auth.user?.role == 'provider') {
      ok = await _saveSkillsExperience();
    }

    setState(() => _saving = false);

    if (!mounted) return;
    if (ok) {
      _snack('Profile updated successfully!');
      Navigator.pop(context);
    } else {
      _snack('Failed to update. Try again.', error: true);
    }
  }


  Future<void> _toggleLiveLocation(bool on) async {
    final auth = context.read<AuthProvider>();

    // A provider being Online requires live location to stay on (see
    // provider_home_tab.dart's _toggleOnline) — if they turned it off here
    // while online, they'd show as "Online" with no working location,
    // which is exactly what that linkage is meant to prevent. Block the
    // OFF direction here instead; going offline first is the only way.
    if (!on && auth.user?.role == 'provider' && context.read<ProviderListProvider>().isOnline) {
      _snack('Go offline first to turn off location.', error: true);
      return;
    }

    setState(() => _gettingLocation = true);
    if (on) {
      final started = await auth.startLiveLocation();
      if (!started && mounted) {
        _snack('Could not start live location. Check GPS/permissions.', error: true);
      } else if (mounted) {
        setState(() {
          _latitude  = auth.user?.latitude;
          _longitude = auth.user?.longitude;
        });
      }
    } else {
      auth.stopLiveLocation();
    }
    if (mounted) setState(() => _gettingLocation = false);
  }

  Future<void> _toggleVisibility({bool? showPhone, bool? showEmail}) async {
    final key = showPhone != null ? 'phone' : 'email';
    setState(() => _savingVisibilityKey = key);
    final ok = await context.read<AuthProvider>().updateVisibility(
      showPhone: showPhone, showEmail: showEmail,
    );
    if (!mounted) return;
    setState(() => _savingVisibilityKey = null);
    if (!ok) _snack('Could not save. Try again.', error: true);
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
                      gradient: user?.avatarUrl == null
                          ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark])
                          : null,
                      image: user?.avatarUrl != null
                          ? DecorationImage(image: CachedNetworkImageProvider(user!.avatarUrl!), fit: BoxFit.cover)
                          : null,
                      boxShadow: [BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 20)],
                    ),
                    child: user?.avatarUrl == null
                        ? Center(
                            child: Text(initials,
                              style: GoogleFonts.inter(
                                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 30)),
                          )
                        : null,
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
            // While ON, AuthProvider pushes a fresh GPS fix to `users` every
            // 30s for as long as the app stays open (foreground-only — true
            // always-on background tracking needs a native foreground
            // service, out of scope here).
            Builder(builder: (context) {
              final liveOn = context.watch<AuthProvider>().liveLocationEnabled;
              return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Icon(
                  liveOn ? Icons.location_on_rounded : Icons.location_off_rounded,
                  color: liveOn ? AppColors.success : AppColors.textDim,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Live Location (GPS)',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                        _gettingLocation
                            ? 'Getting location...'
                            : liveOn && _latitude != null
                                ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                                : liveOn
                                    ? 'Tracking...'
                                    : 'Share your live location while app is open',
                        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _gettingLocation
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      )
                    : Switch(
                        value: liveOn,
                        activeThumbColor: AppColors.primary,
                        onChanged: _toggleLiveLocation,
                      ),
              ]),
              );
            }),
            const SizedBox(height: 28),

            // ── Privacy ─────────────────────────────────────────
            // Lets a user hide phone/email from OTHER users viewing their
            // profile (customer_profile_screen.dart / provider_profile_screen.dart)
            // — doesn't affect what admins or the app itself can see, only
            // the public-profile view.
            _label('Privacy'),
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final u = context.watch<AuthProvider>().user;
              return Column(children: [
                _visibilityRow(
                  icon: Icons.phone_outlined,
                  title: 'Show Phone Number',
                  subtitle: 'Let others see your phone on your profile',
                  value: u?.showPhone ?? true,
                  saving: _savingVisibilityKey == 'phone',
                  onChanged: (v) => _toggleVisibility(showPhone: v),
                ),
                const SizedBox(height: 10),
                _visibilityRow(
                  icon: Icons.email_outlined,
                  title: 'Show Email',
                  subtitle: 'Let others see your email on your profile',
                  value: u?.showEmail ?? true,
                  saving: _savingVisibilityKey == 'email',
                  onChanged: (v) => _toggleVisibility(showEmail: v),
                ),
              ]);
            }),
            const SizedBox(height: 28),

            // ── Specialization (providers only) ────────────────
            // Locked/read-only — a provider randomly switching their trade
            // would invalidate their KYC/experience, so this only offers a
            // one-time set-if-missing path (still stuck on "Profile
            // Incomplete" from before this screen existed) rather than a
            // freely editable dropdown.
            if (user?.role == 'provider') ...[
              _label('Specialization'),
              const SizedBox(height: 12),
              _selectedSpecialization != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        const Icon(Icons.build_outlined, color: AppColors.textDim, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_selectedSpecialization!,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        const Icon(Icons.lock_outline_rounded, color: AppColors.textDim, size: 16),
                      ]),
                    )
                  : Consumer<ServicesProvider>(
                      builder: (context, services, _) {
                        if (services.loading) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CircularProgressIndicator(
                                  color: AppColors.primary, strokeWidth: 2),
                            ),
                          );
                        }
                        return LocationDropdown(
                          label: 'Service Type',
                          hint: 'Select your specialization',
                          icon: Icons.build_outlined,
                          value: _selectedSpecialization,
                          items: services.services.map((s) => s.name).toList(),
                          onChanged: (v) {
                            if (v != null) _saveSpecialization(v);
                          },
                        );
                      },
                    ),
              const SizedBox(height: 6),
              Text(
                _selectedSpecialization == null
                    ? 'Required to receive matching service requests.'
                    : 'Contact support to change your specialization.',
                style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11),
              ),
              if (_savingSpecialization) ...[
                const SizedBox(height: 8),
                const Center(
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // ── Skills & Experience ──────────────────────────
              // Unlike specialization, these are meant to change over time
              // (a provider picks up new skills, gains more years) so they
              // stay freely editable and save with the rest of the form.
              _label('Skills & Experience'),
              const SizedBox(height: 12),
              _skillsChipInput(),
              const SizedBox(height: 14),
              AppInput(
                label: 'Experience',
                hint: '5y / 3m / 2w / 10d',
                controller: _experienceCtrl,
                prefixIcon: const Icon(Icons.workspace_premium_outlined, color: AppColors.textDim, size: 18),
              ),
              const SizedBox(height: 14),
              AppInput(
                label: 'About',
                hint: 'Tell customers a bit about yourself and your work',
                controller: _aboutCtrl,
                maxLines: 4,
                prefixIcon: const Icon(Icons.info_outline_rounded, color: AppColors.textDim, size: 18),
              ),
              const SizedBox(height: 14),
              AppInput(
                label: 'Rate (Rs / hour)',
                hint: 'e.g. 500',
                controller: _rateCtrl,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.attach_money_rounded, color: AppColors.textDim, size: 18),
              ),
              const SizedBox(height: 28),
            ],

            AppButton(
              label: 'SAVE CHANGES',
              icon: Icons.check_rounded,
              isLoading: _saving,
              onTap: _save,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _visibilityRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool saving,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, color: value ? AppColors.success : AppColors.textDim, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text(subtitle,
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        saving
            ? const SizedBox(
                width: 24, height: 24,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              )
            : Switch(
                value: value,
                activeThumbColor: AppColors.primary,
                onChanged: onChanged,
              ),
      ]),
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

  // Tag-style input: type a skill, hit comma/Enter (or just move on and tap
  // Save) and it becomes its own removable chip, so multiple skills read as
  // distinct labels instead of one long comma-separated string.
  Widget _skillsChipInput() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SKILLS',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          if (_skills.isNotEmpty) ...[
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _skills.map((s) => Container(
                padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _removeSkill(s),
                      child: Icon(Icons.close_rounded, size: 16, color: AppColors.primary.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              )).toList(),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _skillInputCtrl,
            focusNode: _skillInputFocus,
            style: GoogleFonts.inter(color: AppColors.text, fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              hintText: _skills.isEmpty ? 'e.g. Wiring, Solar panels' : 'Add another skill…',
              hintStyle: GoogleFonts.inter(color: AppColors.textDim, fontSize: 15),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              _commitSkillInput();
              _skillInputFocus.requestFocus();
            },
            onChanged: (v) {
              if (v.endsWith(',')) _commitSkillInput();
            },
          ),
        ],
      ),
    );
  }
}
