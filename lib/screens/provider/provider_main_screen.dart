import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import 'provider_home_tab.dart';
import 'requests_screen.dart';
import 'active_jobs_screen.dart';
import 'earnings_screen.dart';
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
  }

  static const _items = [
    (icon: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.inbox_rounded, label: 'Requests'),
    (icon: Icons.work_rounded, label: 'Jobs'),
    (icon: Icons.payments_outlined, label: 'Earnings'),
    (icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      const ProviderHomeTab(),
      const RequestsScreen(),
      const ActiveJobsScreen(),
      const EarningsScreen(),
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
