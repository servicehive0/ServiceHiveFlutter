import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

class LocationDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const LocationDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // If current value is not in items list, reset to null
    final safeValue = (value != null && items.contains(value)) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(enabled ? 0.04 : 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: safeValue != null
                  ? AppColors.primary
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              hint: Row(children: [
                const SizedBox(width: 14),
                Icon(icon, color: AppColors.textDim, size: 18),
                const SizedBox(width: 10),
                Text(hint,
                    style: GoogleFonts.inter(
                        color: AppColors.textDim, fontSize: 14)),
              ]),
              isExpanded: true,
              dropdownColor: AppColors.surface2,
              icon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color:
                      safeValue != null ? AppColors.primary : AppColors.textDim,
                ),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              borderRadius: BorderRadius.circular(12),
              onChanged: enabled ? onChanged : null,
              items: items
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item,
                            style: GoogleFonts.inter(
                                color: Colors.white, fontSize: 14)),
                      ))
                  .toList(),
              selectedItemBuilder: (_) => items
                  .map((item) => Row(children: [
                        Icon(icon, color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Text(item,
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ]))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
