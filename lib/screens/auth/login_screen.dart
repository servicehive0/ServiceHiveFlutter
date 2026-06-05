import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/floating_particles.dart';
import '../../widgets/role_toggle.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // Mode
  bool _isLogin = true;
  bool _isWorker = false;

  // Login controllers
  final _loginIdCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();

  // Register controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _specializationCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  bool _agreedToTerms = false;
  int _step = 1;
  int get _totalSteps => _isWorker ? 4 : 2;

  // location loaded from backend via LocationProvider

  String? _selectedCity;
  String? _selectedArea;

  late AnimationController _cardCtrl;
  late Animation<double> _cardOpacity;
  late Animation<Offset> _cardSlide;

  late AnimationController _stepCtrl;
  late Animation<Offset> _stepSlide;

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _cardOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _cardCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut));
    _cardCtrl.forward();

    _stepCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _stepSlide = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(_stepCtrl);
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _stepCtrl.dispose();
    _loginIdCtrl.dispose();
    _loginPassCtrl.dispose();
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _passCtrl.dispose(); _confirmPassCtrl.dispose(); _cityCtrl.dispose();
    _areaCtrl.dispose(); _addressCtrl.dispose(); _cnicCtrl.dispose();
    _specializationCtrl.dispose(); _experienceCtrl.dispose(); _skillsCtrl.dispose();
    super.dispose();
  }

  void _switchMode(bool toLogin) {
    if (_isLogin == toLogin) return;
    final slideFrom = toLogin ? -0.12 : 0.12;
    _cardSlide = Tween<Offset>(
      begin: Offset(slideFrom, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutExpo));
    _cardCtrl.reset();
    setState(() {
      _isLogin = toLogin;
      _step = 1;
    });
    _cardCtrl.forward();
  }

  void _animateStep() {
    _stepCtrl.reset();
    _stepCtrl.forward();
  }

  Future<void> _login() async {
    final auth = context.read<AuthProvider>();
    final role = _isWorker ? 'provider' : 'user';
    final success = await auth.login(_loginIdCtrl.text.trim(), _loginPassCtrl.text, role: role);
    if (!mounted) return;
    if (success) {
      context.go('/dashboard');
    } else if (auth.status == AuthStatus.otpPending && auth.pendingEmail != null) {
      context.go('/verify-otp', extra: auth.pendingEmail);
    }
  }

  String? _validateStep() {
    if (_step == 1) {
      if (_nameCtrl.text.trim().length < 3) return 'Name must be at least 3 characters';
      if (!RegExp(r'^(03)[0-9]{9}$').hasMatch(_phoneCtrl.text.trim())) return 'Phone: 03XXXXXXXXX';
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_emailCtrl.text.trim())) return 'Valid email required';
      if (_passCtrl.text.length < 6) return 'Password min 6 characters';
      if (_passCtrl.text != _confirmPassCtrl.text) return 'Passwords do not match';
    }
    if (_step == 2) {
      if (_selectedCity == null) return 'Please select your city';
      if (_selectedArea == null) return 'Please select your area';
      if (_addressCtrl.text.isEmpty) return 'Please enter your address';
      if (!_agreedToTerms) return 'Please agree to Terms & Conditions';
    }
    if (_isWorker && _step == 3) {
      if (!RegExp(r'^[0-9]{5}-[0-9]{7}-[0-9]{1}$').hasMatch(_cnicCtrl.text.trim())) return 'CNIC: 42XXX-XXXXXXX-X';
    }
    if (_isWorker && _step == 4) {
      if (_specializationCtrl.text.isEmpty) return 'Please enter specialization';
      if (_experienceCtrl.text.isEmpty) return 'Please enter experience';
    }
    return null;
  }

  Future<void> _next() async {
    final error = _validateStep();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    if (_step < _totalSteps) {
      setState(() => _step++);
      _animateStep();
      if (_step == 2) context.read<LocationProvider>().fetch();
      return;
    }
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passCtrl.text,
      role: _isWorker ? 'provider' : 'user',
      city: _selectedCity ?? '',
      area: _selectedArea ?? '',
      address: _addressCtrl.text.trim(),
    );
    if (success && mounted) context.go('/verify-otp', extra: auth.pendingEmail ?? _emailCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(top: -100, left: -100,
            child: Container(width: 350, height: 350,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.12)))),
          Positioned(bottom: -80, right: -80,
            child: Container(width: 280, height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF6366F1).withOpacity(0.08)))),
          const Positioned.fill(child: FloatingParticles()),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (!_isLogin && _step > 1) {
                            setState(() => _step--);
                            _animateStep();
                          } else {
                            context.go('/');
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
                      RoleToggle(
                        isWorker: _isWorker,
                        onChange: (v) {
                          setState(() { _isWorker = v; _step = 1; });
                          auth.clearError();
                        },
                      ),
                    ],
                  ),
                ),

                // Login — natural size card, centered
                if (_isLogin)
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: FadeTransition(
                          opacity: _cardOpacity,
                          child: SlideTransition(
                            position: _cardSlide,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 440),
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, 20))],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Center(child: AppLogo()),
                                  const SizedBox(height: 24),
                                  Center(child: AuthToggle(isLogin: true, onChanged: _switchMode)),
                                  const SizedBox(height: 24),
                                  if (auth.errorMessage != null) ErrorBanner(message: auth.errorMessage!),
                                  _buildLoginContent(isLoading),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Register — fixed card, form scrolls inside
                if (!_isLogin)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: FadeTransition(
                        opacity: _cardOpacity,
                        child: SlideTransition(
                          position: _cardSlide,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 440),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, 20))],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                                  child: Column(
                                    children: [
                                      const Center(child: AppLogo()),
                                      const SizedBox(height: 20),
                                      Center(child: AuthToggle(isLogin: false, onChanged: _switchMode)),
                                      const SizedBox(height: 16),
                                      _StepIndicator(current: _step, total: _totalSteps),
                                      const SizedBox(height: 16),
                                      if (auth.errorMessage != null) ...[
                                        ErrorBanner(message: auth.errorMessage!),
                                        const SizedBox(height: 8),
                                      ],
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      transitionBuilder: (child, animation) => FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                                            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                                          child: child,
                                        ),
                                      ),
                                      child: _buildRegisterContent(isLoading),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildLoginContent(bool isLoading) {
    return Column(
      key: const ValueKey('login'),
      mainAxisSize: MainAxisSize.min,
      children: [
        AppInput(
          label: 'Email or Phone Number',
          hint: 'Enter Email or 03XXXXXXXXX',
          controller: _loginIdCtrl,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textDim, size: 18),
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        AppInput(
          label: 'Password',
          hint: 'Enter your password',
          controller: _loginPassCtrl,
          isPassword: true,
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textDim, size: 18),
          validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => context.go('/forgot-password'),
            child: Text('Forgot Password?',
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 24),
        AppButton(label: 'LOGIN NOW', icon: Icons.arrow_forward_rounded, isLoading: isLoading, onTap: _login),
      ],
    );
  }

  Widget _buildRegisterContent(bool isLoading) {
    return Column(
      key: ValueKey('register_$_step'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStepContent(),
        const SizedBox(height: 24),
        AppButton(
          label: _step < _totalSteps ? 'NEXT STEP' : 'REGISTER NOW',
          icon: _step < _totalSteps ? Icons.arrow_forward_rounded : Icons.check_rounded,
          isLoading: isLoading,
          onTap: _next,
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    if (!_isWorker) {
      switch (_step) {
        case 1: return _step1();
        case 2: return _step2();
      }
    } else {
      switch (_step) {
        case 1: return _step1();
        case 2: return _step2();
        case 3: return _step3();
        case 4: return _step4();
      }
    }
    return const SizedBox();
  }

  Widget _step1() => Column(children: [
    AppInput(label: 'Full Name', hint: 'Enter Full Name', controller: _nameCtrl,
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
    AppInput(label: 'Confirm Password', hint: '••••••••', controller: _confirmPassCtrl, isPassword: true,
      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textDim, size: 18)),
  ]);

  Widget _step2() {
    final loc   = context.watch<LocationProvider>();
    final areas = _selectedCity != null ? loc.areasFor(_selectedCity!) : <String>[];

    return Column(children: [
    if (loc.loading)
      const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
      ),
    _LocationDropdown(
      label: 'City',
      hint: loc.loading ? 'Loading cities…' : 'Select your city',
      icon: Icons.location_city_outlined,
      value: _selectedCity,
      items: loc.cities,
      onChanged: (v) => setState(() { _selectedCity = v; _selectedArea = null; }),
    ),
    const SizedBox(height: 14),
    _LocationDropdown(
      label: 'Area',
      hint: _selectedCity == null ? 'Select city first' : 'Select your area',
      icon: Icons.map_outlined,
      value: _selectedArea,
      items: areas,
      enabled: _selectedCity != null && areas.isNotEmpty,
      onChanged: (v) => setState(() => _selectedArea = v),
    ),
    const SizedBox(height: 14),
    AppInput(label: 'Complete Address', hint: 'House # / Street / Landmark', controller: _addressCtrl,
      maxLines: 2,
      prefixIcon: const Icon(Icons.home_outlined, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 16),
    GestureDetector(
      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: _agreedToTerms ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _agreedToTerms ? AppColors.primary : AppColors.border, width: 1.5),
            ),
            child: _agreedToTerms ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: RichText(text: TextSpan(children: [
            TextSpan(text: 'I agree to the ', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
            TextSpan(text: 'Terms & Conditions', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            TextSpan(text: ' of ServiceHive.', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
          ]))),
        ],
      ),
    ),
  ]);
  }

  Widget _step3() => Column(children: [
    Text('Identity Verification (KYC)', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 14),
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

  Widget _step4() => Column(children: [
    AppInput(label: 'Specialization', hint: 'e.g. Electrician, Plumber', controller: _specializationCtrl,
      prefixIcon: const Icon(Icons.build_outlined, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 14),
    AppInput(label: 'Experience', hint: 'e.g. 5 years', controller: _experienceCtrl,
      prefixIcon: const Icon(Icons.workspace_premium_outlined, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 14),
    AppInput(label: 'Skills & Expertise', hint: 'e.g. Wiring, Solar panels',
      controller: _skillsCtrl, maxLines: 3,
      prefixIcon: const Icon(Icons.star_outline_rounded, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 10),
    _UploadTile(label: 'Work Portfolio', icon: Icons.image_outlined),
    const SizedBox(height: 10),
    _UploadTile(label: 'Certificates', icon: Icons.description_outlined),
  ]);
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final done = i < current;
        final isCurrent = i == current - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: done ? AppColors.primary : AppColors.surface2,
              boxShadow: isCurrent ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8)] : null,
            ),
          ),
        );
      }),
    );
  }
}

class _UploadTile extends StatelessWidget {
  final String label;
  final IconData icon;
  const _UploadTile({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            color: Colors.white.withOpacity(0.02),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.textDim, size: 20),
              const SizedBox(width: 10),
              Text('Tap to Upload', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const _LocationDropdown({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(enabled ? 0.04 : 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: (value != null && items.contains(value)) ? value : null,
              hint: Row(children: [
                const SizedBox(width: 14),
                Icon(icon, color: AppColors.textDim, size: 18),
                const SizedBox(width: 10),
                Text(hint, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14)),
              ]),
              isExpanded: true,
              dropdownColor: AppColors.surface,
              icon: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              borderRadius: BorderRadius.circular(12),
              onChanged: enabled ? onChanged : null,
              items: items.map((item) => DropdownMenuItem(
                value: item,
                child: Text(item, style: GoogleFonts.inter(color: AppColors.text, fontSize: 14)),
              )).toList(),
              selectedItemBuilder: (_) => items.map((item) => Row(children: [
                Icon(icon, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Text(item, style: GoogleFonts.inter(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
              ])).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
