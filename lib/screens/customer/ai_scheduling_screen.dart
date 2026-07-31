import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/config.dart';
import '../../core/theme.dart';

const _kApiKey = kGroqApiKey;
const _kModel  = 'llama-3.3-70b-versatile';

class AiSchedulingScreen extends StatefulWidget {
  const AiSchedulingScreen({super.key});

  @override
  State<AiSchedulingScreen> createState() => _AiSchedulingScreenState();
}

class _AiSchedulingScreenState extends State<AiSchedulingScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  _Schedule? _result;
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
                  'You are a smart scheduling assistant for home services in Pakistan. '
                  'Analyze the job and suggest the optimal schedule. '
                  'Respond ONLY with valid JSON — no text outside:\n'
                  '{"best_time": "<Morning/Afternoon/Evening>", '
                  '"best_days": ["<e.g. Weekdays>", "<e.g. Avoid Friday>"], '
                  '"duration": "<e.g. 1-2 hours>", '
                  '"urgency": "<Low/Medium/High/Emergency>", '
                  '"prep_tips": ["<tip 1>", "<tip 2>", "<tip 3>"]}',
            },
            {'role': 'user', 'content': 'Job: $text'},
          ],
          'max_tokens': 300,
          'temperature': 0.3,
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final content = jsonDecode(res.body)['choices'][0]['message']['content'] as String;
        final s = content.indexOf('{');
        final e = content.lastIndexOf('}') + 1;
        if (s != -1 && e > s) {
          final data = jsonDecode(content.substring(s, e)) as Map<String, dynamic>;
          if (mounted) {
            setState(() => _result = _Schedule.fromJson(data));
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
                    Text('Smart Scheduling', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('AI picks the best time for your job', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                Text('Describe your job', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: TextField(
                    controller: _ctrl,
                    maxLines: 3,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'E.g. AC gas refill, bathroom tile fixing, full house deep cleaning...',
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
                      gradient: _loading ? null : const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
                      color: _loading ? AppColors.surface2 : null,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Center(child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.schedule_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('Analyze Schedule', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
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

            // Urgency + Best Time
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.schedule_rounded,
                      color: const Color(0xFFF59E0B),
                      label: 'Best Time',
                      value: _result!.bestTime,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.timer_rounded,
                      color: const Color(0xFF3B82F6),
                      label: 'Duration',
                      value: _result!.duration,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.warning_amber_rounded,
                      color: _urgencyColor(_result!.urgency),
                      label: 'Urgency',
                      value: _result!.urgency,
                    ),
                  ),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Best Days
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Best Days to Book', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: _result!.bestDays.map((d) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      ),
                      child: Text(d, style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w700)),
                    )).toList()),
                  ]),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Preparation Tips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.checklist_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text('Preparation Tips', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 12),
                    ..._result!.prepTips.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 22, height: 22,
                          margin: const EdgeInsets.only(right: 10, top: 1),
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Center(child: Text('${e.key + 1}', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800))),
                        ),
                        Expanded(child: Text(e.value, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.5))),
                      ]),
                    )),
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

  Color _urgencyColor(String u) {
    switch (u.toLowerCase()) {
      case 'emergency': return const Color(0xFFEF4444);
      case 'high':      return const Color(0xFFF59E0B);
      case 'medium':    return const Color(0xFF3B82F6);
      default:          return AppColors.success;
    }
  }
}

class _Schedule {
  final String bestTime;
  final List<String> bestDays;
  final String duration;
  final String urgency;
  final List<String> prepTips;

  const _Schedule({required this.bestTime, required this.bestDays, required this.duration, required this.urgency, required this.prepTips});

  factory _Schedule.fromJson(Map<String, dynamic> j) => _Schedule(
    bestTime: j['best_time'] as String? ?? 'Morning',
    bestDays: List<String>.from(j['best_days'] as List? ?? []),
    duration: j['duration'] as String? ?? '—',
    urgency:  j['urgency'] as String? ?? 'Medium',
    prepTips: List<String>.from(j['prep_tips'] as List? ?? []),
  );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _InfoCard({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 6),
      Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
      Text(label, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10), textAlign: TextAlign.center),
    ]),
  );
}
