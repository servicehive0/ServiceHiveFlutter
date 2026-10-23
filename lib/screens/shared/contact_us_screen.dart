import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String? _specialization;
  String? _supportPhone;
  String? _supportEmail;

  final List<String> _types = ['Complaint', 'General Inquiry', 'Technical Issue', 'Billing', 'Other'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSpecialization();
      _loadSupportInfo();
    });
  }

  // Admin-editable in the web Admin Dashboard → Global Settings, so support
  // contact info can be updated without an app release.
  Future<void> _loadSupportInfo() async {
    try {
      final row = await Supabase.instance.client
          .from('platform_settings')
          .select('support_phone, support_email')
          .eq('id', 1)
          .maybeSingle();
      if (mounted && row != null) {
        setState(() {
          _supportPhone = (row['support_phone'] as String?)?.trim();
          _supportEmail = (row['support_email'] as String?)?.trim();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSpecialization() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || user.role != 'provider') return;
    try {
      final row = await Supabase.instance.client
          .from('provider_profiles')
          .select('service_type')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted && row != null) {
        setState(() => _specialization = row['service_type'] as String?);
      }
    } catch (_) {}
  }

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
    final user = context.read<AuthProvider>().user;
    try {
      await Supabase.instance.client.from('contact_messages').insert({
        'name':    user?.name ?? 'User',
        'email':   user?.email ?? '',
        'phone':   user?.phone,
        'subject': '$_selectedType: ${_subjectCtrl.text.trim()}',
        'message': _messageCtrl.text.trim(),
        'sender_role':           user?.role,
        'sender_specialization': _specialization,
      });
      if (!mounted) return;
      setState(() => _sending = false);
      _subjectCtrl.clear();
      _messageCtrl.clear();
      _showThankYouDialog();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack('Could not send message. Please try again.', error: true);
    }
  }

  void _showThankYouDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84, height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 44),
              ),
              const SizedBox(height: 22),
              Text('Thank You!', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(
                'Thanks for reaching out to us. Our support team has received your message and will get back to you within 24 hours.',
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13.5, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'DONE',
                  icon: Icons.arrow_back_rounded,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      body: _buildForm(user),
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
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.headset_mic_outlined, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text('We typically respond within 24 hours.',
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13))),
            ]),
          ),

          if ((_supportPhone?.isNotEmpty ?? false) || (_supportEmail?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('NEED URGENT HELP?', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 10),
                if (_supportPhone?.isNotEmpty ?? false)
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse('tel:$_supportPhone')),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        const Icon(Icons.phone_rounded, color: AppColors.primary, size: 16),
                        const SizedBox(width: 10),
                        Text(_supportPhone!, style: GoogleFonts.inter(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                if (_supportEmail?.isNotEmpty ?? false)
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse('mailto:$_supportEmail')),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        const Icon(Icons.email_rounded, color: AppColors.primary, size: 16),
                        const SizedBox(width: 10),
                        Text(_supportEmail!, style: GoogleFonts.inter(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 24),

          Text('FROM', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              const Icon(Icons.person_outline_rounded, color: AppColors.textDim, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?.name ?? 'User', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(user?.email ?? '', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
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
                  color: _selectedType == type ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
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

}
