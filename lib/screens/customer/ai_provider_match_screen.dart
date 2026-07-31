import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/config.dart';
import '../../core/theme.dart';

const _kApiKey = kGroqApiKey;
const _kModel  = 'llama-3.3-70b-versatile';

class AiProviderMatchScreen extends StatefulWidget {
  const AiProviderMatchScreen({super.key});

  @override
  State<AiProviderMatchScreen> createState() => _AiProviderMatchScreenState();
}

class _AiProviderMatchScreenState extends State<AiProviderMatchScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  _MatchProfile? _result;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _analyze() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _loading = true; _error = null; _result = null; });

    try {
      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {'content-type': 'application/json', 'Authorization': 'Bearer $_kApiKey'},
        body: jsonEncode({
          'model': _kModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a provider-matching expert for home services in Pakistan. '
                  'Analyze the job and generate an ideal provider profile. '
                  'Respond ONLY with valid JSON — no text outside:\n'
                  '{"service_type": "<e.g. Electrician>", '
                  '"required_skills": ["<skill 1>", "<skill 2>", "<skill 3>"], '
                  '"experience_level": "<Junior/Mid-level/Senior/Expert>", '
                  '"questions_to_ask": ["<question 1>", "<question 2>", "<question 3>"], '
                  '"red_flags": ["<red flag 1>", "<red flag 2>"], '
                  '"match_tip": "<one sentence advice on choosing the right provider>"}',
            },
            {'role': 'user', 'content': 'Problem: $text'},
          ],
          'max_tokens': 400,
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
            setState(() => _result = _MatchProfile.fromJson(data));
          }
          return;
        }
      }
      throw Exception('bad response');
    } catch (_) {
      if (mounted) setState(() => _error = 'AI unavailable. Please try again.');
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Provider Match AI', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Find the perfect provider for your job', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
            ),
          ),

          // Input
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Describe your problem', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: TextField(
                    controller: _ctrl,
                    maxLines: 3,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'E.g. There\'s a short circuit in the main line, 3 rooms affected...',
                      hintStyle: GoogleFonts.inter(color: AppColors.textDim, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _loading ? null : _analyze,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: _loading ? null : const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]),
                      color: _loading ? AppColors.surface2 : null,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Center(child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.person_search_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('Find Ideal Provider', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13)),
              ),
            ),

          if (_result != null) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Service type + experience
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1D1035), Color(0xFF0D1B3E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(color: const Color(0xFFEC4899).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.verified_user_rounded, color: Color(0xFFEC4899), size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('You need a', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11)),
                        Text(_result!.serviceType, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEC4899).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.3)),
                          ),
                          child: Text(_result!.experienceLevel, style: GoogleFonts.inter(color: const Color(0xFFEC4899), fontSize: 10, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Required skills
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _Section(
                  icon: Icons.build_rounded,
                  color: const Color(0xFF3B82F6),
                  title: 'Required Skills',
                  child: Wrap(spacing: 8, runSpacing: 8, children: _result!.requiredSkills.map((s) => _Chip(label: s, color: const Color(0xFF3B82F6))).toList()),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Questions to ask
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _Section(
                  icon: Icons.help_outline_rounded,
                  color: const Color(0xFFF59E0B),
                  title: 'Questions to Ask',
                  child: Column(children: _result!.questionsToAsk.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${e.key + 1}.', style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.value, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.4))),
                    ]),
                  )).toList()),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Red flags
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _Section(
                  icon: Icons.flag_rounded,
                  color: const Color(0xFFEF4444),
                  title: 'Red Flags to Watch',
                  child: Column(children: _result!.redFlags.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 14),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13))),
                    ]),
                  )).toList()),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Match tip
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: AppColors.success, size: 16),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_result!.matchTip, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.5))),
                  ]),
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _MatchProfile {
  final String serviceType;
  final List<String> requiredSkills;
  final String experienceLevel;
  final List<String> questionsToAsk;
  final List<String> redFlags;
  final String matchTip;

  const _MatchProfile({required this.serviceType, required this.requiredSkills, required this.experienceLevel, required this.questionsToAsk, required this.redFlags, required this.matchTip});

  factory _MatchProfile.fromJson(Map<String, dynamic> j) => _MatchProfile(
    serviceType:     j['service_type'] as String? ?? 'Technician',
    requiredSkills:  List<String>.from(j['required_skills'] as List? ?? []),
    experienceLevel: j['experience_level'] as String? ?? 'Mid-level',
    questionsToAsk:  List<String>.from(j['questions_to_ask'] as List? ?? []),
    redFlags:        List<String>.from(j['red_flags'] as List? ?? []),
    matchTip:        j['match_tip'] as String? ?? '',
  );
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;
  const _Section({required this.icon, required this.color, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 12),
      child,
    ]),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
  );
}
