import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/services_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/floating_particles.dart';
import '../../widgets/location_dropdown.dart';
import '../../widgets/role_toggle.dart';

class LoginScreen extends StatefulWidget {
  final bool startInWorkerRegister;
  const LoginScreen({super.key, this.startInWorkerRegister = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // Mode
  late bool _isLogin = !widget.startInWorkerRegister;
  late bool _isWorker = widget.startInWorkerRegister;

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
  String? _selectedSpec;
  final _experienceCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  bool _agreedToTerms = false;
  int _step = 1;
  int get _totalSteps => _isWorker ? 4 : 2;

  // KYC files picked during registration (step 3/4). Keyed by the same names
  // AuthProvider.setPendingProviderFiles/register expects: cnic_front,
  // cnic_back, selfie, portfolio, certificates.
  final Map<String, Uint8List> _kycFiles = {};
  final Map<String, String> _kycFileNames = {};
  String? _kycUploadingKey;

  Future<void> _pickKycFile(String key) async {
    // Selfie must be a live camera capture (matches KYC intent — proves the
    // applicant physically holds the ID at signup time); everything else
    // allows picking an existing photo/scan from the gallery.
    ImageSource? source;
    if (key == 'selfie') {
      source = ImageSource.camera;
    } else {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: Text('Take Photo', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: Text('Choose from Gallery', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      );
    }
    if (source == null) return;

    try {
      setState(() => _kycUploadingKey = key);
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (picked == null) {
        setState(() => _kycUploadingKey = null);
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _kycFiles[key] = bytes;
        _kycFileNames[key] = picked.name;
        _kycUploadingKey = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _kycUploadingKey = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not access camera/gallery. Check app permissions.', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // location loaded from backend via LocationProvider

  String? _selectedCity;
  String? _selectedArea;

  late AnimationController _cardCtrl;
  late Animation<double> _cardOpacity;
  late Animation<Offset> _cardSlide;

  late AnimationController _stepCtrl;

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _cardOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _cardCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut));
    _cardCtrl.forward();

    _stepCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
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
    _experienceCtrl.dispose(); _skillsCtrl.dispose();
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
      if (!RegExp(r'^[0-9]{5}-[0-9]{7}-[0-9]{1}$').hasMatch(_cnicCtrl.text.trim())) return 'CNIC must be 13 digits, format 42XXX-XXXXXXX-X';
      if (!_kycFiles.containsKey('cnic_front') || !_kycFiles.containsKey('cnic_back')) return 'Please upload both sides of your CNIC';
      if (!_kycFiles.containsKey('selfie')) return 'Please upload a selfie holding your ID';
    }
    if (_isWorker && _step == 4) {
      if (_selectedSpec == null || _selectedSpec!.isEmpty) return 'Please select your specialization';
      final exp = _experienceCtrl.text.trim();
      if (exp.isEmpty) return 'Experience required (e.g. 5y, 3m, 2w)';
      if (!RegExp(r'^\d+[ymwd](\s+\d+[ymwd])*$').hasMatch(exp)) return 'Format: 5y / 3m / 2w / 10d (number + y/m/w/d)';
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
      if (_step == 3) {
        final svcs = context.read<ServicesProvider>();
        if (!svcs.loaded && !svcs.loading) svcs.fetch();
      }
      return;
    }
    final auth = context.read<AuthProvider>();
    if (_isWorker && _kycFiles.isNotEmpty) {
      auth.setPendingProviderFiles(_kycFiles);
    }
    final success = await auth.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passCtrl.text,
      role: _isWorker ? 'provider' : 'user',
      city: _selectedCity ?? '',
      area: _selectedArea ?? '',
      address: _addressCtrl.text.trim(),
      cnic: _isWorker ? _cnicCtrl.text.trim() : '',
      specialization: _isWorker ? (_selectedSpec ?? '') : '',
      skills: _isWorker ? _skillsCtrl.text.trim() : '',
      experience: _isWorker ? _experienceCtrl.text.trim() : '',
    );
    if (success && mounted) context.go('/verify-otp', extra: auth.pendingEmail ?? _emailCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.status == AuthStatus.loading;
    final approved = auth.justApproved;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(top: -100, left: -100,
            child: Container(width: 350, height: 350,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.12)))),
          Positioned(bottom: -80, right: -80,
            child: Container(width: 280, height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF6366F1).withValues(alpha: 0.08)))),
          const Positioned.fill(child: FloatingParticles()),

          SafeArea(
            child: Column(
              children: [
                // ── Approved banner ──────────────────────────────────
                if (approved)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Account verified! You can now login as a provider.',
                          style: GoogleFonts.inter(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => auth.justApproved = false),
                        child: const Icon(Icons.close_rounded, color: AppColors.success, size: 18),
                      ),
                    ]),
                  ),

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
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 20))],
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
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 20))],
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
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
      maxLength: 50,
      prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 14),
    AppInput(label: 'Phone Number', hint: '03XXXXXXXXX', controller: _phoneCtrl,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 11,
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
      inputFormatters: [_CnicInputFormatter()],
      maxLength: 15,
      prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 14),
    _UploadTile(
      label: 'CNIC Front', icon: Icons.credit_card_outlined,
      fileName: _kycFileNames['cnic_front'], uploading: _kycUploadingKey == 'cnic_front',
      onTap: () => _pickKycFile('cnic_front'),
    ),
    const SizedBox(height: 10),
    _UploadTile(
      label: 'CNIC Back', icon: Icons.credit_card_outlined,
      fileName: _kycFileNames['cnic_back'], uploading: _kycUploadingKey == 'cnic_back',
      onTap: () => _pickKycFile('cnic_back'),
    ),
    const SizedBox(height: 10),
    _UploadTile(
      label: 'Selfie with ID', icon: Icons.camera_alt_outlined,
      fileName: _kycFileNames['selfie'], uploading: _kycUploadingKey == 'selfie',
      onTap: () => _pickKycFile('selfie'),
    ),
  ]);

  Widget _step4() {
    final servicesProv = context.watch<ServicesProvider>();
    final serviceNames = servicesProv.services.map((s) => s.name).toList();
    return Column(children: [
    if (servicesProv.loading)
      const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
      )
    else
      LocationDropdown(
        label: 'Specialization',
        hint: serviceNames.isEmpty ? 'No services yet — add from admin' : 'Select your service type',
        icon: Icons.build_outlined,
        value: _selectedSpec,
        items: serviceNames,
        onChanged: (v) => setState(() => _selectedSpec = v),
      ),
    const SizedBox(height: 14),
    AppInput(label: 'Experience', hint: '5y / 3m / 2w / 10d', controller: _experienceCtrl,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9ymwd\s]'))],
      maxLength: 10,
      prefixIcon: const Icon(Icons.workspace_premium_outlined, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 14),
    AppInput(label: 'Skills & Expertise', hint: 'e.g. Wiring, Solar panels',
      controller: _skillsCtrl, maxLines: 3,
      prefixIcon: const Icon(Icons.star_outline_rounded, color: AppColors.textDim, size: 18)),
    const SizedBox(height: 10),
    _UploadTile(
      label: 'Work Portfolio (Optional)', icon: Icons.image_outlined,
      fileName: _kycFileNames['portfolio'], uploading: _kycUploadingKey == 'portfolio',
      onTap: () => _pickKycFile('portfolio'),
    ),
    const SizedBox(height: 10),
    _UploadTile(
      label: 'Certificates (Optional)', icon: Icons.description_outlined,
      fileName: _kycFileNames['certificates'], uploading: _kycUploadingKey == 'certificates',
      onTap: () => _pickKycFile('certificates'),
    ),
    ]);
  }
}

// Auto-inserts the two hyphens as the user types digits (42401-1234567-1)
// and hard-caps at 13 digits, so a CNIC can never be typed too short/long
// or with hyphens in the wrong place — matches Pakistan's fixed CNIC format.
class _CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digits.length > 13 ? digits.substring(0, 13) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      buffer.write(capped[i]);
      if (i == 4 || i == 11) buffer.write('-');
    }
    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
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
              boxShadow: isCurrent ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8)] : null,
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
  final String? fileName;
  final bool uploading;
  final VoidCallback onTap;
  const _UploadTile({required this.label, required this.icon, required this.onTap, this.fileName, this.uploading = false});

  @override
  Widget build(BuildContext context) {
    final done = fileName != null && !uploading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: uploading ? null : onTap,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: done ? AppColors.primary : AppColors.border),
              color: Colors.white.withValues(alpha: 0.02),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (uploading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                else
                  Icon(done ? Icons.check_circle_rounded : icon, color: done ? AppColors.primary : AppColors.textDim, size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    uploading ? 'Uploading...' : (done ? fileName! : 'Tap to Upload'),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: done ? Colors.white : AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
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
            color: Colors.white.withValues(alpha: enabled ? 0.04 : 0.02),
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
                Flexible(child: Text(hint,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14))),
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
                Flexible(child: Text(item,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600))),
              ])).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
