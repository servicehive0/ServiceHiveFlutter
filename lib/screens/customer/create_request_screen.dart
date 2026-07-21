import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/location_dropdown.dart';
import '../../widgets/live_location_required_sheet.dart';
import '../shared/location_picker_screen.dart';

const _kCreateApiKey = kGroqApiKey;
const _kCreateModel  = 'llama-3.3-70b-versatile';

class CreateRequestScreen extends StatefulWidget {
  final String serviceName;
  const CreateRequestScreen({super.key, required this.serviceName});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _descCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  LatLng? _pickedLocation;

  // Delivery address for THIS booking only — starts pre-filled from the
  // customer's profile, but editing it here never touches their profile.
  // Lets someone whose profile is set to one area post a request for a
  // different city/area they're currently at (e.g. visiting family).
  String? _deliveryCity;
  String? _deliveryArea;

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _addrCtrl.text = user?.address ?? '';
    _deliveryCity = user?.city.isNotEmpty == true ? user!.city : null;
    _deliveryArea = user?.area.isNotEmpty == true ? user!.area : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LocationProvider>().fetch();
    });
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    // Ask for location permission up front, the moment the user actually
    // wants to use location — not later at submit time. Previously this
    // requirement was only enforced in _submit(), so a user could open the
    // map, drag a pin, confirm it, fill in the rest of the form, and only
    // then get a second, unrelated "turn on live location" prompt — feels
    // like the app is asking twice for the same permission at random points.
    final auth = context.read<AuthProvider>();
    if (!auth.liveLocationEnabled) {
      final enabled = await requireLiveLocation(context, reason: 'to pin your location on the map');
      if (!enabled || !mounted) return;
    }

    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: _pickedLocation?.latitude,
          initialLng: _pickedLocation?.longitude,
        ),
      ),
    );
    if (result != null) setState(() => _pickedLocation = result);
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
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
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1200);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() { _pickedImage = picked; _pickedImageBytes = bytes; });
    } catch (_) {
      if (!mounted) return;
      _snack('Could not access camera/gallery. Check app permissions.', error: true);
    }
  }

  void _removeImage() => setState(() { _pickedImage = null; _pickedImageBytes = null; });

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    if (_descCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please describe the problem');
      return;
    }
    if (_deliveryCity == null || _deliveryArea == null) {
      setState(() => _error = 'Please select the city and area for this booking');
      return;
    }
    if (_addrCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the address for this booking');
      return;
    }

    // Live location is mandatory before posting — same GPS toggle from
    // Edit Profile. If it isn't on, walk the user through turning it on
    // right here instead of just refusing.
    if (!auth.liveLocationEnabled) {
      final enabled = await requireLiveLocation(context, reason: 'before you can post a request');
      if (!enabled || !mounted) return;
    }
    if (_pickedLocation == null) {
      setState(() => _error = 'Please confirm your location on the map');
      return;
    }

    setState(() { _loading = true; _error = null; });

    String? imageUrl;
    if (_pickedImageBytes != null && _pickedImage != null) {
      setState(() => _uploadingImage = true);
      imageUrl = await context.read<RequestProvider>().uploadRequestImage(_pickedImageBytes!, _pickedImage!.name);
      if (!mounted) return;
      setState(() => _uploadingImage = false);
      if (imageUrl == null) {
        setState(() { _loading = false; _error = 'Image upload failed. Try again or remove the photo.'; });
        return;
      }
    }

    final rp = context.read<RequestProvider>();
    final ok = await rp.createRequest(
      customerId: user.id,
      customerName: user.name,
      customerPhone: user.phone,
      serviceName: widget.serviceName,
      description: _descCtrl.text.trim(),
      city: _deliveryCity!,
      area: _deliveryArea!,
      address: _addrCtrl.text.trim(),
      latitude: _pickedLocation?.latitude,
      longitude: _pickedLocation?.longitude,
      imageUrl: imageUrl,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok && rp.myRequests.isNotEmpty) {
      context.pushReplacement('/service-request/${rp.myRequests.first.id}/bids');
    } else {
      setState(() => _error = rp.error ?? 'Failed to post request. Try again.');
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _openAiWrite() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiWriteSheet(serviceName: widget.serviceName),
    );
    if (result != null && result.isNotEmpty) _descCtrl.text = result;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final hasPinned = _pickedLocation != null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
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
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Post a Request', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(widget.serviceName, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ])),
              ]),
            ),
          ),

          // Service badge
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D1035), Color(0xFF0D1B3E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.home_repair_service_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.serviceName, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('${user?.area ?? ''}, ${user?.city ?? ''}', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Text('OPEN BID', style: GoogleFonts.inter(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Description field
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Describe the Problem *', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openAiWrite,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)]),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.auto_awesome, color: Colors.white, size: 11),
                        const SizedBox(width: 4),
                        Text('AI Write', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _descCtrl,
                    maxLines: 5,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'E.g. Fan not working, wiring issue in bedroom, need new socket installed...',
                      hintStyle: GoogleFonts.inter(color: AppColors.textDim, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Photo attach
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Photo (Optional)', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (_pickedImageBytes != null)
                  Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(_pickedImageBytes!, width: double.infinity, height: 160, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 8, top: 8,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ])
                else
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                      ),
                      child: Column(children: [
                        const Icon(Icons.add_a_photo_outlined, color: AppColors.textDim, size: 24),
                        const SizedBox(height: 6),
                        Text('Attach a photo of the problem', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Delivery address for THIS booking (independent of profile)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Booking Address *', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Where should the provider come? This can be different from your profile address.',
                  style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11, height: 1.4)),
                const SizedBox(height: 10),
                Consumer<LocationProvider>(
                  builder: (_, loc, __) {
                    final areas = _deliveryCity != null ? loc.areasFor(_deliveryCity!) : <String>[];
                    return Column(children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: LocationDropdown(
                            label: 'City',
                            hint: 'Select city',
                            icon: Icons.location_city_outlined,
                            value: _deliveryCity,
                            items: loc.cities,
                            onChanged: (v) => setState(() { _deliveryCity = v; _deliveryArea = null; }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LocationDropdown(
                            label: 'Area',
                            hint: _deliveryCity == null ? 'Select city first' : 'Select area',
                            icon: Icons.map_outlined,
                            value: _deliveryArea,
                            items: areas,
                            enabled: _deliveryCity != null && areas.isNotEmpty,
                            onChanged: (v) => setState(() => _deliveryArea = v),
                          ),
                        ),
                      ]),
                    ]);
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _addrCtrl,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'House #, Street, Block...',
                      hintStyle: GoogleFonts.inter(color: AppColors.textDim, fontSize: 13),
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Map location picker ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: _pickLocation,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: hasPinned
                        ? AppColors.success.withValues(alpha: 0.07)
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasPinned
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: hasPinned
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasPinned ? Icons.location_on_rounded : Icons.map_rounded,
                        color: hasPinned ? AppColors.success : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        hasPinned ? 'Location Pinned on Map' : 'Pin Location on Map',
                        style: GoogleFonts.inter(
                          color: hasPinned ? AppColors.success : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        hasPinned
                            ? '${_pickedLocation!.latitude.toStringAsFixed(5)}, ${_pickedLocation!.longitude.toStringAsFixed(5)}'
                            : 'Required — confirm exactly where you are',
                        style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11),
                      ),
                    ])),
                    Icon(
                      hasPinned ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                      color: hasPinned ? AppColors.success : AppColors.textDim,
                      size: 20,
                    ),
                  ]),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // Info note
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your request will be sent to all ${widget.serviceName} providers in ${_deliveryArea ?? 'your selected area'}, ${_deliveryCity ?? ''}. They will bid — you choose the best one.',
                      style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, height: 1.5),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          if (_error != null) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 12))),
                ]),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: GestureDetector(
          onTap: _loading ? null : _submit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 54,
            decoration: BoxDecoration(
              gradient: _loading ? null : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
              color: _loading ? AppColors.surface2 : null,
              borderRadius: BorderRadius.circular(100),
              boxShadow: _loading ? [] : [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 15)],
            ),
            child: Center(
              child: _loading
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      if (_uploadingImage) ...[
                        const SizedBox(width: 12),
                        Text('Uploading photo...', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ])
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Text('Post Request', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── AI Write Bottom Sheet ─────────────────────────────────────────────────────

class _AiWriteSheet extends StatefulWidget {
  final String serviceName;
  const _AiWriteSheet({required this.serviceName});

  @override
  State<_AiWriteSheet> createState() => _AiWriteSheetState();
}

class _AiWriteSheetState extends State<_AiWriteSheet> {
  final _ctrl   = TextEditingController();
  bool _loading = false;
  String? _result;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _generate() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;
    setState(() { _loading = true; _error = null; _result = null; });

    try {
      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $_kCreateApiKey',
        },
        body: jsonEncode({
          'model': _kCreateModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a professional service request writer for Pakistan home services. '
                  'The user will describe their problem casually in Urdu/English. '
                  'Rewrite it as a clear, professional service request description in 2-4 sentences. '
                  'Include: what the problem is, where it is (if mentioned), and what they need done. '
                  'Write ONLY the description — no greetings, no labels, no extra text.',
            },
            {
              'role': 'user',
              'content': 'Service needed: ${widget.serviceName}\nProblem: $raw',
            },
          ],
          'max_tokens': 200,
          'temperature': 0.5,
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final text = jsonDecode(res.body)['choices'][0]['message']['content'] as String;
        setState(() => _result = text.trim());
      } else {
        throw Exception('HTTP ${res.statusCode}');
      }
    } catch (_) {
      setState(() => _error = 'AI unavailable. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(100)),
        )),
        const SizedBox(height: 20),

        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI Description Writer', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              Text('Casually likho — AI professional bana dega', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        const SizedBox(height: 18),

        Container(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _ctrl,
            maxLines: 3,
            autofocus: true,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'E.g. fan ki speed bahut kam ho gayi hai, bedroom mein...',
              hintStyle: GoogleFonts.inter(color: AppColors.textDim, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 12),

        GestureDetector(
          onTap: _loading ? null : _generate,
          child: Container(
            width: double.infinity, height: 46,
            decoration: BoxDecoration(
              gradient: _loading ? null : const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)]),
              color: _loading ? AppColors.surface2 : null,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Center(
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Generate Description', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 12)),
        ],

        if (_result != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 13),
                const SizedBox(width: 5),
                Text('Generated Description', style: GoogleFonts.inter(color: const Color(0xFF8B5CF6), fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              Text(_result!, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.55)),
            ]),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context, _result),
            child: Container(
              width: double.infinity, height: 46,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
              ),
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                const SizedBox(width: 8),
                Text('Use This Description', style: GoogleFonts.inter(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 14)),
              ])),
            ),
          ),
        ],
        ]),
      ),
    );
  }
}
