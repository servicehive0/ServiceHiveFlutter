import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/config.dart';
import '../../core/theme.dart';

const _kApiKey = kGroqApiKey;
const _kModel  = 'llama-3.3-70b-versatile';

const _kServices = [
  'Electrician', 'Plumber', 'Carpenter', 'AC Technician',
  'Painter', 'Cleaning', 'Gas Fitter', 'CCTV Installation',
];

const _kExamples = [
  ('💡', 'Lights aren\'t working in one room'),
  ('🚿', 'There\'s a water leak in the bathroom'),
  ('❄️', 'AC isn\'t cooling properly'),
  ('🔨', 'The door lock is broken'),
  ('🖌️', 'Need the house painted'),
  ('🧹', 'Need a deep cleaning'),
];

class AiServiceFinderScreen extends StatefulWidget {
  const AiServiceFinderScreen({super.key});

  @override
  State<AiServiceFinderScreen> createState() => _AiServiceFinderScreenState();
}

class _AiServiceFinderScreenState extends State<AiServiceFinderScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _service;
  String? _reason;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _detect() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _loading = true; _error = null; _service = null; _reason = null; });

    try {
      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $_kApiKey',
        },
        body: jsonEncode({
          'model': _kModel,
          'messages': [
            {
              'role': 'system',
              'content': '''You are a home service classifier for Pakistan.
Given a problem description, identify which service is needed from this list ONLY: ${_kServices.join(', ')}.
Respond ONLY with valid JSON — no explanation outside JSON:
{"service": "Exact Service Name", "reason": "One short sentence in simple English/Urdu why this service fits"}''',
            },
            {'role': 'user', 'content': text},
          ],
          'max_tokens': 120,
          'temperature': 0.2,
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final content =
            jsonDecode(res.body)['choices'][0]['message']['content'] as String;
        final s = content.indexOf('{');
        final e = content.lastIndexOf('}') + 1;
        if (s != -1 && e > s) {
          final data = jsonDecode(content.substring(s, e)) as Map<String, dynamic>;
          setState(() {
            _service = data['service'] as String?;
            _reason  = data['reason']  as String?;
          });
          return;
        }
      }
      throw Exception('Unexpected response');
    } catch (_) {
      setState(() => _error = 'Could not detect service. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.auto_fix_high_rounded,
                          color: Color(0xFF3B82F6), size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Smart Service Finder',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    Text('Describe your problem — AI finds the right service',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
            ),
          ),

          // ── Input card ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.35)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Describe your problem (English or Urdu both work)',
                      style: GoogleFonts.inter(
                          color: AppColors.textDim,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      maxLines: 3,
                      style:
                          GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'E.g. My AC isn\'t cooling and the fan speed has dropped...',
                        hintStyle: GoogleFonts.inter(
                            color: AppColors.textDim, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _loading ? null : _detect,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: _loading
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
                        color: _loading ? AppColors.surface2 : null,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: _loading
                            ? null
                            : [
                                BoxShadow(
                                  color:
                                      const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                  blurRadius: 14,
                                )
                              ],
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_rounded,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Service Dhundo',
                                      style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ── Error ──────────────────────────────────────────────────────────
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 15),
                  const SizedBox(width: 6),
                  Text(_error!,
                      style: GoogleFonts.inter(
                          color: AppColors.error, fontSize: 12)),
                ]),
              ),
            ),

          // ── Result card ────────────────────────────────────────────────────
          if (_service != null) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D1B3E), Color(0xFF1D1035)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                          blurRadius: 24)
                    ],
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      const Icon(Icons.auto_awesome,
                          color: Color(0xFF3B82F6), size: 14),
                      const SizedBox(width: 6),
                      Text('AI RECOMMENDATION',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF3B82F6),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ]),
                    const SizedBox(height: 12),
                    Text(_service!,
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900)),
                    if (_reason != null) ...[
                      const SizedBox(height: 8),
                      Text(_reason!,
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              height: 1.55)),
                    ],
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () =>
                          context.push('/service-request/create', extra: _service),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 50),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                blurRadius: 14)
                          ],
                        ),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          const Icon(Icons.send_rounded,
                              color: Colors.white, size: 17),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text('Post Request for $_service',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ],

          // ── Examples ───────────────────────────────────────────────────────
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('EXAMPLES',
                  style: GoogleFonts.inter(
                      color: AppColors.textDim,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final (emoji, text) = _kExamples[i];
                  return GestureDetector(
                    onTap: () {
                      _ctrl.text = text;
                      _detect();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        Text(emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(text,
                                style: GoogleFonts.inter(
                                    color: AppColors.textMuted, fontSize: 13))),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            color: AppColors.textDim, size: 12),
                      ]),
                    ),
                  );
                },
                childCount: _kExamples.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
