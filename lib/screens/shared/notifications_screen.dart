import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // Deep-links a tapped notification to the exact screen it's about, instead
  // of just sitting there as a static list — a chat notification opens that
  // bid's chat directly, a booking notification opens the request/job.
  // Falls back to doing nothing extra (just closes this screen) when the
  // notification predates the bid_id/request_id columns or carries neither.
  Future<void> _handleTap(BuildContext context, NotificationModel n) async {
    context.read<NotificationsProvider>().markRead(n.id);
    if (n.type == NotifType.chat && n.bidId != null && n.requestId != null) {
      context.pop();
      context.push('/service-request/${n.requestId}/chat/${n.bidId}');
      return;
    }
    if (n.requestId != null) {
      final role = context.read<AuthProvider>().user?.role;
      if (role == 'provider') {
        // An open request (not yet won) still takes bids; once accepted it
        // moves to the job screen — check current status to route correctly.
        String status = 'open';
        try {
          final row = await Supabase.instance.client
              .from('service_requests').select('status').eq('id', n.requestId as Object).maybeSingle();
          status = row?['status'] as String? ?? 'open';
        } catch (_) {}
        if (!context.mounted) return;
        context.pop();
        if (status == 'open') {
          context.push('/provider/service-request/${n.requestId}');
        } else {
          context.push('/provider/service-job/${n.requestId}');
        }
      } else {
        context.pop();
        context.push('/service-request/${n.requestId}/bids');
      }
      return;
    }
    // No target — nothing further to navigate to.
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final np = context.watch<NotificationsProvider>();
    final notifs = np.items;

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
                    onTap: () => np.markAllRead(),
                    child: Text('Mark all read', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: np.loading && notifs.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: np.refresh,
                    color: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    child: notifs.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 120),
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.notifications_none_rounded, color: AppColors.textDim, size: 52),
                                    const SizedBox(height: 14),
                                    Text('No notifications', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14)),
                                  ]),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                            itemCount: notifs.length,
                            itemBuilder: (_, i) {
                              final n = notifs[i];
                              return _NotifTile(
                                notif: n,
                                timeAgo: _timeAgo(n.time),
                                onTap: () => _handleTap(context, n),
                              );
                            },
                          ),
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
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.timeAgo, required this.onTap});

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: notif.isRead ? AppColors.surface : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: notif.isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: _color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(notif.type.icon, color: _color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(notif.title, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (!notif.isRead)
              Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary)),
          ]),
          const SizedBox(height: 4),
          Text(notif.body, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(timeAgo, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10)),
        ])),
      ]),
      ),
    );
  }
}
