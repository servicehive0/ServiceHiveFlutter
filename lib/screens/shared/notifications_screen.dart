import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/notification_model.dart';
import '../../providers/booking_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookingProvider>();
    final notifs = bp.notifications;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text('Notifications', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
                if (notifs.any((n) => !n.isRead))
                  GestureDetector(
                    onTap: () => bp.markNotifsRead(),
                    child: Text('Mark all read', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: notifs.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.notifications_none_rounded, color: AppColors.textDim, size: 52),
                      const SizedBox(height: 14),
                      Text('No notifications', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14)),
                    ]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    itemCount: notifs.length,
                    itemBuilder: (_, i) {
                      final n = notifs[i];
                      return _NotifTile(notif: n, timeAgo: _timeAgo(n.time));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final String timeAgo;
  const _NotifTile({required this.notif, required this.timeAgo});

  Color get _color {
    switch (notif.type) {
      case NotifType.booking: return AppColors.primary;
      case NotifType.payment: return AppColors.success;
      case NotifType.system: return AppColors.textMuted;
      case NotifType.chat: return const Color(0xFF6366F1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: notif.isRead ? AppColors.surface : AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: notif.isRead ? AppColors.border : AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(notif.type.icon, color: _color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(notif.title, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
            if (!notif.isRead)
              Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary)),
          ]),
          const SizedBox(height: 4),
          Text(notif.body, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
          const SizedBox(height: 6),
          Text(timeAgo, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10)),
        ])),
      ]),
    );
  }
}
