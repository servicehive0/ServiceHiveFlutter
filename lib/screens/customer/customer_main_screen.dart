import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/provider_list_provider.dart';
import 'ai_assistant_screen.dart';
import 'customer_home_tab.dart';
import 'my_bookings_screen.dart';
import '../shared/profile_screen.dart';
import '../shared/chats_list_screen.dart';

class CustomerMainScreen extends StatefulWidget {
  final int initialTab;
  const CustomerMainScreen({super.key, this.initialTab = 0});

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final userId = auth.user?.id ?? '';
      context.read<BookingProvider>().load(userId, 'user');
      context.read<ProviderListProvider>().fetch();
      if (userId.isNotEmpty) context.read<NotificationsProvider>().init(userId);
    });
  }

  // 5 tabs: Home(0), Chats(1), AI(2-center), Bookings(3), Profile(4)
  final List<Widget> _screens = const [
    CustomerHomeTab(),
    ChatsListScreen(),
    AiAssistantScreen(),
    MyBookingsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: _BottomNav(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.current, required this.onTap});

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home', isAi: false),
    (icon: Icons.chat_bubble_outline_rounded, label: 'Chats', isAi: false),
    (icon: Icons.auto_awesome, label: 'AI', isAi: true),
    (icon: Icons.calendar_today_rounded, label: 'Bookings', isAi: false),
    (icon: Icons.person_outline_rounded, label: 'Profile', isAi: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == current;

              if (item.isAi) {
                // Special center AI button
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: active
                                ? const LinearGradient(
                                    colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFF4C1D95), Color(0xFF1E3A5F)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6).withOpacity(0.55),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6).withOpacity(0.25),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                          ),
                          child: const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 2),
                        Text('AI',
                          style: GoogleFonts.inter(
                            color: active ? const Color(0xFF8B5CF6) : AppColors.textDim,
                            fontSize: 10,
                            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                          )),
                      ],
                    ),
                  ),
                );
              }

              // Normal nav item
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Icon(item.icon,
                          color: active ? AppColors.primary : AppColors.textDim,
                          size: 22),
                      ),
                      const SizedBox(height: 2),
                      Text(item.label,
                        style: GoogleFonts.inter(
                          color: active ? AppColors.primary : AppColors.textDim,
                          fontSize: 10,
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
    );
  }
}
