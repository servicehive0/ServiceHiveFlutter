import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _selectedType = 'Complaint';
  bool _sending = false;
  bool _sent = false;

  final List<String> _types = ['Complaint', 'General Inquiry', 'Technical Issue', 'Billing', 'Other'];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_subjectCtrl.text.trim().isEmpty) {
      _snack('Please enter a subject', error: true);
      return;
    }
    if (_messageCtrl.text.trim().length < 20) {
      _snack('Message must be at least 20 characters', error: true);
      return;
    }
    setState(() => _sending = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() { _sending = false; _sent = true; });
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
        ),
        title: Text('Contact Us', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: _sent ? _buildSuccess() : _buildForm(user),
    );
  }

  Widget _buildForm(user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.headset_mic_outlined, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text('We typically respond within 24 hours.',
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 24),

          Text('FROM', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              const Icon(Icons.person_outline_rounded, color: AppColors.textDim, size: 18),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user?.name ?? 'User', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(user?.email ?? '', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),

          Text('TYPE', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _types.map((type) => GestureDetector(
              onTap: () => setState(() => _selectedType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedType == type ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: _selectedType == type ? AppColors.primary : AppColors.border),
                ),
                child: Text(type, style: GoogleFonts.inter(
                  color: _selectedType == type ? AppColors.primary : AppColors.textMuted,
                  fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),

          AppInput(label: 'Subject', hint: 'Brief description of your issue',
            controller: _subjectCtrl,
            prefixIcon: const Icon(Icons.subject_rounded, color: AppColors.textDim, size: 18)),
          const SizedBox(height: 14),
          AppInput(label: 'Message', hint: 'Describe your issue in detail...',
            controller: _messageCtrl, maxLines: 5,
            prefixIcon: const Icon(Icons.message_outlined, color: AppColors.textDim, size: 18)),
          const SizedBox(height: 28),

          AppButton(label: 'SEND MESSAGE', icon: Icons.send_rounded, isLoading: _sending, onTap: _send),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withOpacity(0.1),
                border: Border.all(color: AppColors.success.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 24),
            Text('Message Sent!', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('We have received your message and will get back to you within 24 hours.',
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text('Go Back', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
