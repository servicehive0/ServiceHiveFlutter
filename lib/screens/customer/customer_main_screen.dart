import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import 'customer_home_tab.dart';
import 'search_screen.dart';
import 'my_bookings_screen.dart';
import '../shared/profile_screen.dart';

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
  }

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.search_rounded, label: 'Search'),
    (icon: Icons.calendar_today_rounded, label: 'Bookings'),
    (icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      const CustomerHomeTab(),
      const SearchScreen(),
      const MyBookingsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: _BottomNav(
        current: _tab,
        items: _items,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final List<({IconData icon, String label})> items;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.current, required this.items, required this.onTap});

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
            children: List.generate(items.length, (i) {
              final active = i == current;
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
                          color: active ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Icon(items[i].icon,
                          color: active ? AppColors.primary : AppColors.textDim, size: 22),
                      ),
                      const SizedBox(height: 2),
                      Text(items[i].label,
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
