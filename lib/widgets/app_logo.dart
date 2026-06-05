import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

class AppLogo extends StatelessWidget {
  final double fontSize;
  final double iconSize;

  const AppLogo({super.key, this.fontSize = 22, this.iconSize = 26});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.shield_rounded, color: AppColors.primary, size: iconSize),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(children: [
            TextSpan(
              text: 'SERVICE',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            TextSpan(
              text: 'HIVE',
              style: GoogleFonts.inter(
                color: AppColors.primary,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
