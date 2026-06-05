import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import 'edit_profile_screen.dart';
import 'contact_us_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isProvider = user?.role == 'provider';
    final initials = user?.name.isNotEmpty == true
        ? user!.name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
              child: Text('Profile', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ),

          // Profile card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.15), AppColors.surface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20)],
                          ),
                          child: Center(
                            child: Text(initials, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
                          ),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: GestureDetector(
                            onTap: () {},
                            child: Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.bg, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.name ?? 'User',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(user?.email ?? '',
                            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                          if (user != null && user.phone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(user!.phone, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12)),
                          ],
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            ),
                            child: Text(isProvider ? 'Service Provider' : 'Customer',
                              style: GoogleFonts.inter(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Menu
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                _MenuItem(icon: Icons.person_outline_rounded, label: 'Edit Profile',
                  subtitle: 'Update your personal info',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
                _MenuItem(icon: Icons.notifications_outlined, label: 'Notifications',
                  subtitle: 'Manage your alerts',
                  onTap: () => context.push('/notifications')),
                _MenuItem(icon: Icons.security_rounded, label: 'Security',
                  subtitle: 'Password & account safety',
                  onTap: () => _showComingSoon(context, 'Security')),
                _MenuItem(icon: Icons.help_outline_rounded, label: 'Help & Support',
                  subtitle: 'FAQs and guides',
                  onTap: () => _showComingSoon(context, 'Help & Support')),
                _MenuItem(icon: Icons.headset_mic_outlined, label: 'Contact Us',
                  subtitle: 'Send a complaint or message',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsScreen()))),
                _MenuItem(icon: Icons.info_outline_rounded, label: 'About ServiceHive',
                  subtitle: 'Version 1.0.0',
                  onTap: () => _showAbout(context)),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Logout
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text('Logout', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800)),
                      content: Text('Are you sure you want to logout?', style: GoogleFonts.inter(color: AppColors.textMuted)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted))),
                        TextButton(onPressed: () => Navigator.pop(context, true),
                          child: Text('Logout', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w700))),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await auth.logout();
                    if (context.mounted) context.go('/auth');
                  }
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withOpacity(0.2)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Text('Logout', style: GoogleFonts.inter(color: AppColors.error, fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$title — Coming Soon', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.surface2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('ServiceHive', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Version 1.0.0', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Professional home services at your fingertips.',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context),
          child: Text('OK', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w700)))],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.label, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          if (subtitle != null)
            Text(subtitle!, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textDim, size: 14),
      ]),
    ),
  );
}
