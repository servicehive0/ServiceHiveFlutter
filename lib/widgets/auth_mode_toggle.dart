import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

class AuthModeToggle extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onChange;

  const AuthModeToggle({super.key, required this.isLogin, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Tab(label: 'LOGIN', active: isLogin, onTap: () => onChange(true)),
          _Tab(label: 'REGISTER', active: !isLogin, onTap: () => onChange(false)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.surface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: AppColors.border) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: active ? AppColors.text : AppColors.textDim,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
