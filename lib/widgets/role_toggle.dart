import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

class RoleToggle extends StatelessWidget {
  final bool isWorker;
  final ValueChanged<bool> onChange;

  const RoleToggle({super.key, required this.isWorker, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return _SliderToggle(
      leftLabel: 'GET\nSERVICE',
      rightLabel: 'PROVIDE\nSERVICE',
      isRight: isWorker,
      onChanged: onChange,
    );
  }
}

class AuthToggle extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onChanged;

  const AuthToggle({super.key, required this.isLogin, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SliderToggle(
      leftLabel: 'LOGIN',
      rightLabel: 'REGISTER',
      isRight: !isLogin,
      onChanged: (isRight) => onChanged(!isRight),
    );
  }
}

class _SliderToggle extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final bool isRight;
  final ValueChanged<bool> onChanged;

  const _SliderToggle({
    required this.leftLabel,
    required this.rightLabel,
    required this.isRight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = (screenWidth * 0.55).clamp(200.0, 300.0);
    const padding = 4.0;
    final tabWidth = (width - padding * 2) / 2;

    return Container(
      width: width,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF141414).withOpacity(0.95),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(96),
          child: Stack(
            children: [
              // Sliding pill
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                left: isRight ? tabWidth : 0,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3b82f6), Color(0xFF1d4ed8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(96),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12),
                    ],
                  ),
                ),
              ),

              // Labels
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(false),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: GoogleFonts.inter(
                            color: !isRight ? Colors.white : const Color(0xFF64748b),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.3,
                          ),
                          child: Text(leftLabel, textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(true),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: GoogleFonts.inter(
                            color: isRight ? Colors.white : const Color(0xFF64748b),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.3,
                          ),
                          child: Text(rightLabel, textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
