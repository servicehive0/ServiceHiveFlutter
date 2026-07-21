import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/bid_model.dart';
import '../../models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';

const _kBidAiKey   = kGroqApiKey;
const _kBidAiModel = 'llama-3.3-70b-versatile';

class ServiceRequestDetailScreen extends StatefulWidget {
  final String requestId;
  const ServiceRequestDetailScreen({super.key, required this.requestId});

  @override
  State<ServiceRequestDetailScreen> createState() => _ServiceRequestDetailScreenState();
}

class _ServiceRequestDetailScreenState extends State<ServiceRequestDetailScreen> {
  ServiceRequest? _request;
  Bid? _myBid;
  bool _loading = true;
  Timer? _pollTimer;

  final _priceCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _openAiAssist() async {
    final req = _request;
    if (req == null) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiBidAssistSheet(
        serviceName: req.serviceName,
        description: req.description,
        city: req.city,
      ),
    );
    if (result != null && mounted) {
      if (result['price'] != null) _priceCtrl.text = result['price'].toString();
      if (result['message'] != null) _msgCtrl.text = result['message'] as String;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    // Poll every 5 seconds — redirect to active job if bid gets accepted
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _priceCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _pollStatus() async {
    if (!mounted) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final req = await context.read<RequestProvider>().fetchRequest(widget.requestId);
    if (!mounted || req == null) return;

    // If our bid was accepted, go to the active job screen
    if (req.acceptedProviderId == user.id &&
        (req.status == 'accepted' || req.status == 'in_progress')) {
      _pollTimer?.cancel();
      context.pushReplacement('/provider/service-job/${widget.requestId}');
    }
  }

  Future<void> _load() async {
    final rp = context.read<RequestProvider>();
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final req = await rp.fetchRequest(widget.requestId);
    final bid = await rp.getBidByProvider(requestId: widget.requestId, providerId: user.id);

    if (!mounted) return;

    // Already accepted — go directly to active job screen
    if (req != null &&
        req.acceptedProviderId == user.id &&
        (req.status == 'accepted' || req.status == 'in_progress')) {
      _pollTimer?.cancel();
      context.pushReplacement('/provider/service-job/${widget.requestId}');
      return;
    }

    setState(() {
      _request = req;
      _myBid = bid;
      _loading = false;
      if (bid != null) {
        _priceCtrl.text = bid.price.toString();
        _msgCtrl.text = bid.message;
      }
    });
  }

  Future<void> _submitBid() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final price = int.tryParse(_priceCtrl.text.trim());
    if (price == null || price <= 0) {
      setState(() => _error = 'Please enter a valid price');
      return;
    }
    if (_msgCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please add a message about your services');
      return;
    }

    setState(() { _submitting = true; _error = null; });

    final ok = await context.read<RequestProvider>().submitBid(
      requestId: widget.requestId,
      providerId: user.id,
      providerName: user.name,
      providerPhone: user.phone,
      price: price,
      message: _msgCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bid submitted!', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      setState(() => _error = context.read<RequestProvider>().error ?? 'Failed to submit bid');
    }
  }

  Widget _buildContent() {
    final req = _request!;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
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
              Expanded(child: Text('Request Details', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Text('OPEN', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ),

        // Request info
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(req.serviceName, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  Text(_timeAgo(req.createdAt), style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11)),
                ]),
                const SizedBox(height: 14),
                Text('Problem Description', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(req.description, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, height: 1.55)),
                if (req.imageUrl != null && req.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(req.imageUrl!, height: 180, width: double.infinity, fit: BoxFit.cover),
                  ),
                ],
                const Divider(color: AppColors.border, height: 24),
                _InfoRow(icon: Icons.person_rounded, label: req.customerName),
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.location_on_rounded, label: '${req.area}, ${req.city}'),
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.home_rounded, label: req.address),
              ]),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // My bid section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _myBid != null ? 'Update Your Bid' : 'Submit a Bid',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _myBid != null ? 'Your current bid: Rs ${_myBid!.price}' : 'Set your price and a short message',
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
              ),
            ]),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 14)),

        // Price input
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Text('Rs', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'Your price',
                      hintStyle: GoogleFonts.inter(color: AppColors.textDim, fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Message label + AI Assist button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(children: [
              Text('Your Message *', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: _openAiAssist,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)]),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 11),
                    const SizedBox(width: 4),
                    Text('AI Assist', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
          ),
        ),

        // Message input
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _msgCtrl,
                maxLines: 4,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Introduce yourself. How will you solve this? Estimated time? Any tools needed?',
                  hintStyle: GoogleFonts.inter(color: AppColors.textDim, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),
        ),

        if (_error != null) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
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
    );
  }

  Widget get _buildActions => Container(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: _submitting ? null : _submitBid,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: _submitting
                ? null
                : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
            color: _submitting ? AppColors.surface2 : null,
            borderRadius: BorderRadius.circular(100),
            boxShadow: _submitting ? [] : [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 15)],
          ),
          child: Center(
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_myBid != null ? Icons.edit_rounded : Icons.gavel_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _myBid != null ? 'Update Bid' : 'Submit Bid',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ]),
          ),
        ),
      ),
      if (_myBid != null) ...[
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => context.push(
            '/service-request/${widget.requestId}/chat/${_myBid!.id}',
            extra: _request?.customerName ?? 'Customer',
          ),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Chat with Customer', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            ])),
          ),
        ),
      ],
    ]),
  );

  @override
  Widget build(BuildContext _context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : _request == null
              ? Center(child: Text('Request not found', style: GoogleFonts.inter(color: Colors.white)))
              : _buildContent(),
      bottomNavigationBar: (!_loading && _request != null) ? _buildActions : null,
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.textDim, size: 15),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13))),
    ],
  );
}

// ── AI Bid Assist Bottom Sheet ─────────────────────────────────────────────────
class _AiBidAssistSheet extends StatefulWidget {
  final String serviceName;
  final String description;
  final String city;
  const _AiBidAssistSheet({required this.serviceName, required this.description, required this.city});

  @override
  State<_AiBidAssistSheet> createState() => _AiBidAssistSheetState();
}

class _AiBidAssistSheetState extends State<_AiBidAssistSheet> {
  bool _loading = false;
  int? _suggestedPrice;
  String? _suggestedMessage;
  String? _timeEstimate;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; _suggestedPrice = null; _suggestedMessage = null; });
    try {
      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {'content-type': 'application/json', 'Authorization': 'Bearer $_kBidAiKey'},
        body: jsonEncode({
          'model': _kBidAiModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a smart bid assistant for home service providers in Pakistan. '
                  'Analyze the customer job and suggest an optimal bid. '
                  'Respond ONLY with valid JSON — no text outside:\n'
                  '{"suggested_price": <integer PKR fair market rate>, '
                  '"time_estimate": "<e.g. 2-3 hours>", '
                  '"bid_message": "<professional 2-3 sentence bid message in English>"}',
            },
            {
              'role': 'user',
              'content': 'Service: ${widget.serviceName}\nCity: ${widget.city}\nProblem: ${widget.description}',
            },
          ],
          'max_tokens': 300,
          'temperature': 0.4,
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final content = jsonDecode(res.body)['choices'][0]['message']['content'] as String;
        final s = content.indexOf('{');
        final e = content.lastIndexOf('}') + 1;
        if (s != -1 && e > s) {
          final data = jsonDecode(content.substring(s, e)) as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _suggestedPrice   = (data['suggested_price'] as num?)?.toInt();
              _suggestedMessage = data['bid_message'] as String?;
              _timeEstimate     = data['time_estimate'] as String?;
            });
          }
          return;
        }
      }
      throw Exception('bad response');
    } catch (_) {
      if (mounted) setState(() => _error = 'AI unavailable. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(100)))),
        const SizedBox(height: 20),

        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)]), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI Bid Assistant', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              Text('Smart suggestions for your bid', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),

        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(children: [
              const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              const SizedBox(height: 14),
              Text('AI analyzing the job...', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
            ]),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [
              Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _generate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.border)),
                  child: Text('Retry', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          )
        else if (_suggestedPrice != null) ...[
          // Price card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.price_check_rounded, color: AppColors.success, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Suggested Price', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11)),
                  Text('Rs ${_fmt(_suggestedPrice!)}', style: GoogleFonts.inter(color: AppColors.success, fontSize: 24, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (_timeEstimate != null)
                    Text('Est. time: $_timeEstimate', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          // Message card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Suggested Message', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_suggestedMessage ?? '', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.5)),
            ]),
          ),
          const SizedBox(height: 16),
          // Apply button
          GestureDetector(
            onTap: () => Navigator.pop(context, {'price': _suggestedPrice, 'message': _suggestedMessage}),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.circular(100),
                boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3), blurRadius: 15)],
              ),
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Apply AI Suggestions', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              ])),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _generate,
            child: Center(child: Text('Regenerate ↻', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w600))),
          ),
        ],
      ]),
    );
  }
}
