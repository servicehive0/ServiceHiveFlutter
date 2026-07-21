import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/provider_list_provider.dart';
import 'provider_home_tab.dart';
import 'requests_screen.dart';
import 'active_jobs_screen.dart';
import '../shared/chats_list_screen.dart';
import '../shared/profile_screen.dart';

class ProviderMainScreen extends StatefulWidget {
  final int initialTab;
  const ProviderMainScreen({super.key, this.initialTab = 0});

  @override
  State<ProviderMainScreen> createState() => _ProviderMainScreenState();
}

class _ProviderMainScreenState extends State<ProviderMainScreen> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final userId = auth.user?.id ?? '';
      context.read<BookingProvider>().load(userId, 'provider');
      if (userId.isNotEmpty) context.read<NotificationsProvider>().init(userId);
      // Load real online/offline status from DB
      final providerList = context.read<ProviderListProvider>();
      await providerList.initMyOnlineStatus(userId);

      // liveLocationEnabled is in-memory only and always resets to false on
      // a fresh app launch, but is_online persists in the DB — without this,
      // reopening the app after being Online left the DB still showing
      // Online (and admin's location column stuck on the last stale fix)
      // while GPS tracking silently never resumed. Try to resume it now
      // that we know the DB says this provider was online; if GPS/permission
      // isn't available anymore, fall back to actually going offline instead
      // of leaving a stale "Online" status with dead location behind it.
      if (providerList.isOnline && userId.isNotEmpty) {
        final resumed = await auth.startLiveLocation();
        if (!resumed) await providerList.toggleMyOnline(userId);
      }
    });
  }

  static const _items = [
    (icon: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.inbox_rounded, label: 'Requests'),
    (icon: Icons.work_rounded, label: 'Jobs'),
    (icon: Icons.chat_bubble_outline_rounded, label: 'Chats'),
    (icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      ProviderHomeTab(onGoToRequests: () => setState(() => _tab = 1)),
      const RequestsScreen(),
      const ActiveJobsScreen(),
      const ChatsListScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: List.generate(_items.length, (i) {
                final active = i == _tab;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tab = i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: active ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Icon(_items[i].icon,
                            color: active ? AppColors.primary : AppColors.textDim, size: 21),
                        ),
                        const SizedBox(height: 2),
                        Text(_items[i].label,
                          style: GoogleFonts.inter(
                            color: active ? AppColors.primary : AppColors.textDim,
                            fontSize: 9,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          )),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
