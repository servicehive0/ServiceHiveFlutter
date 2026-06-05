import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/location_dropdown.dart';
import '../../widgets/role_toggle.dart';
import '../../widgets/error_banner.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  bool _isWorker = false;
  int _step = 1;

  final _nameCtrl        = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _passCtrl        = TextEditingController();
  final _confirmCtrl     = TextEditingController();
  final _areaCtrl        = TextEditingController();
  final _addressCtrl     = TextEditingController();
  final _cnicCtrl        = TextEditingController();
  final _specCtrl        = TextEditingController();
  final _expCtrl         = TextEditingController();
  final _skillsCtrl      = TextEditingController();

  String? _selectedCity;
  String? _selectedArea;
  bool _agreedToTerms = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  int get _totalSteps => _isWorker ? 4 : 2;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl, _passCtrl, _confirmCtrl,
                     _areaCtrl, _addressCtrl, _cnicCtrl, _specCtrl, _expCtrl, _skillsCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _stepAnimate() {
    _animCtrl.reset();
    _animCtrl.forward();
  }

  String? _validate() {
    if (_step == 1) {
      if (_nameCtrl.text.trim().length < 3)   return 'Name must be at least 3 characters';
      if (!RegExp(r'^(03)[0-9]{9}$').hasMatch(_phoneCtrl.text.trim())) return 'Phone: 03XXXXXXXXX';
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_emailCtrl.text.trim())) return 'Enter a valid email';
      if (_passCtrl.text.length < 6)           return 'Password min 6 characters';
      if (_passCtrl.text != _confirmCtrl.text)  return 'Passwords do not match';
    }
    if (_step == 2) {
      if (_selectedCity == null) return 'Please select your city';
      if (_selectedArea == null) return 'Please select your area';
      if (_addressCtrl.text.trim().isEmpty) return 'Please enter your address';
      if (!_agreedToTerms) return 'Please agree to Terms & Conditions';
    }
    if (_isWorker && _step == 3) {
      if (!RegExp(r'^[0-9]{5}-[0-9]{7}-[0-9]{1}$').hasMatch(_cnicCtrl.text.trim()))
        return 'CNIC format: 42XXX-XXXXXXX-X';
    }
    if (_isWorker && _step == 4) {
      if (_specCtrl.text.isEmpty) return 'Enter your specialization';
      if (_expCtrl.text.isEmpty)  return 'Enter your experience';
    }
    return null;
  }

  Future<void> _next() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    if (_step < _totalSteps) {
      setState(() => _step++);
      _stepAnimate();
      if (_step == 2) context.read<LocationProvider>().fetch();
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passCtrl.text,
      role: _isWorker ? 'provider' : 'user',
      city: _selectedCity ?? '',
      area: _selectedArea ?? '',
      address: _addressCtrl.text.trim(),
    );
    if (ok && mounted) context.go('/verify-otp', extra: _emailCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loading = auth.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(top: -100, left: -100,
            child: Container(width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.08)))),
          Positioned(bottom: -80, right: -80,
            child: Container(width: 250, height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withOpacity(0.06)))),
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_step > 1) {
                            setState(() => _step--);
                            _stepAnimate();
                          } else {
                            context.go('/auth');
                          }
                        },
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      RoleToggle(isWorker: _isWorker, onChange: (v) {
                        setState(() { _isWorker = v; _step = 1; });
                        _stepAnimate();
                      }),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                    child: Column(
                      children: [
                        // Step indicator
                        Row(
                          children: List.generate(_totalSteps, (i) => Expanded(
                            child: Container(
                              margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 6 : 0),
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: i < _step ? AppColors.primary : AppColors.surface2,
                                boxShadow: i == _step - 1
                                    ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 6)]
                                    : null,
                              ),
                            ),
                          )),
                        ),
                        const SizedBox(height: 20),

                        // Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 40, offset: const Offset(0, 16))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Center(child: Column(children: [
                                RichText(text: TextSpan(children: [
                                  TextSpan(text: 'SERVICE', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                  TextSpan(text: 'HIVE', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                ])),
                                const SizedBox(height: 4),
                                Text(
                                  _isWorker ? 'Step $_step/$_totalSteps — Provider Setup' : 'Step $_step/$_totalSteps — Create Account',
                                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ])),
                              const SizedBox(height: 20),

                              // Login / Register tab
                              Center(child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  GestureDetector(
                                    onTap: () => context.go('/auth'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(100)),
                                      child: Text('Login', style: GoogleFonts.inter(color: AppColors.textMuted, fontWeight: FontWeight.w500, fontSize: 13)),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(100),
                                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 10)],
                                    ),
                                    child: Text('Register', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                                  ),
                                ]),
                              )),
                              const SizedBox(height: 24),

                              if (auth.errorMessage != null) ...[
                                ErrorBanner(message: auth.errorMessage!),
                                const SizedBox(height: 12),
                              ],

                              // Step content (fade in only, no fade-out-then-in)
                              FadeTransition(
                                opacity: _fadeAnim,
                                child: _buildStep(),
                              ),

                              const SizedBox(height: 24),
                              AppButton(
                                label: _step < _totalSteps ? 'NEXT STEP' : 'CREATE ACCOUNT',
                                icon: _step < _totalSteps ? Icons.arrow_forward_rounded : Icons.check_rounded,
                                isLoading: loading,
                                onTap: _next,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    if (!_isWorker) {
      return _step == 1 ? _step1() : _step2();
    }
    switch (_step) {
      case 1: return _step1();
      case 2: return _step2();
      case 3: return _step3();
      case 4: return _step4();
      default: return const SizedBox();
    }
  }

  // ── Step 1: Basic info ──────────────────────────────────────
  Widget _step1() => Column(children: [
    AppInput(label: 'Full Name', hint: 'Enter your full name', controller: _nameCtrl,
      prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 14),
    AppInput(label: 'Phone Number', hint: '03XXXXXXXXX', controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 14),
    AppInput(label: 'Email Address', hint: 'mail@example.com', controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 14),
    AppInput(label: 'Password', hint: '••••••••', controller: _passCtrl, isPassword: true,
      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 14),
    AppInput(label: 'Confirm Password', hint: '••••••••', controller: _confirmCtrl, isPassword: true,
      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textDim, size: 18)),
  ]);

  // ── Step 2: Location ────────────────────────────────────────
  Widget _step2() {
    final loc = context.watch<LocationProvider>();
    final areas = _selectedCity != null ? loc.areasFor(_selectedCity!) : <String>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Loading / error state
    if (loc.loading)
      const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
      )
    else if (loc.error != null && loc.cities.isEmpty)
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.error.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('Could not load cities. Check connection.',
              style: GoogleFonts.inter(color: AppColors.error, fontSize: 12))),
            GestureDetector(
              onTap: () => loc.refresh(),
              child: Text('Retry', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),

    LocationDropdown(
      label: 'City',
      hint: 'Select your city',
      icon: Icons.location_city_outlined,
      value: _selectedCity,
      items: loc.cities,
      onChanged: (v) => setState(() { _selectedCity = v; _selectedArea = null; }),
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
    const SizedBox(height: 14),
    AppInput(label: 'Complete Address', hint: 'House #, Street, Landmark', controller: _addressCtrl,
      maxLines: 2,
      prefixIcon: const Icon(Icons.home_outlined, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 16),

    // Terms checkbox
    GestureDetector(
      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
      behavior: HitTestBehavior.opaque,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: _agreedToTerms ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _agreedToTerms ? AppColors.primary : AppColors.border, width: 1.5),
          ),
          child: _agreedToTerms
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(child: RichText(text: TextSpan(children: [
          TextSpan(text: 'I agree to the ',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
          TextSpan(text: 'Terms & Conditions',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          TextSpan(text: ' of ServiceHive.',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
        ]))),
      ]),
    ),
  ]);}

  // ── Step 3: KYC (Worker) ────────────────────────────────────
  Widget _step3() => Column(children: [
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text('Identity Verification (KYC)',
        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    AppInput(label: 'CNIC Number', hint: '42XXX-XXXXXXX-X', controller: _cnicCtrl,
      keyboardType: TextInputType.number,
      prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 14),
    _UploadTile(label: 'CNIC Front', icon: Icons.credit_card_outlined),
    const SizedBox(height: 10),
    _UploadTile(label: 'CNIC Back', icon: Icons.credit_card_outlined),
    const SizedBox(height: 10),
    _UploadTile(label: 'Selfie with ID', icon: Icons.camera_alt_outlined),
  ]);

  // ── Step 4: Skills (Worker) ─────────────────────────────────
  Widget _step4() => Column(children: [
    AppInput(label: 'Specialization', hint: 'e.g. Electrician, Plumber', controller: _specCtrl,
      prefixIcon: const Icon(Icons.build_outlined, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 14),
    AppInput(label: 'Experience', hint: 'e.g. 5 years, 3 months', controller: _expCtrl,
      prefixIcon: const Icon(Icons.workspace_premium_outlined, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 14),
    AppInput(label: 'Skills', hint: 'e.g. Wiring, Solar, Industrial Panels',
      controller: _skillsCtrl, maxLines: 3,
      prefixIcon: const Icon(Icons.star_outline_rounded, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 10),
    _UploadTile(label: 'Work Portfolio', icon: Icons.image_outlined),
    const SizedBox(height: 10),
    _UploadTile(label: 'Certificates', icon: Icons.description_outlined),
  ]);
}

// ── Upload tile ─────────────────────────────────────────────────
class _UploadTile extends StatelessWidget {
  final String label;
  final IconData icon;
  const _UploadTile({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800,
          color: AppColors.textMuted, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          color: Colors.white.withOpacity(0.02),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppColors.textDim, size: 20),
          const SizedBox(width: 10),
          Text('Tap to Upload',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
        ]),
      ),
    ],
  );
}
