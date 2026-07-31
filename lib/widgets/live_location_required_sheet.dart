import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';

/// Blocks an action (posting a request, going online as a provider) until
/// the live-location toggle (same one from Edit Profile) is on. Offers to
/// turn it on right here instead of sending the user away to Edit Profile.
/// Returns `true` via Navigator.pop once location is actually enabled,
/// `false`/`null` if the user backs out.
Future<bool> requireLiveLocation(BuildContext context, {String reason = 'to continue'}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (_) => LiveLocationRequiredSheet(reason: reason),
  );
  return result ?? false;
}

class LiveLocationRequiredSheet extends StatefulWidget {
  final String reason;
  const LiveLocationRequiredSheet({super.key, this.reason = 'to continue'});

  @override
  State<LiveLocationRequiredSheet> createState() => _LiveLocationRequiredSheetState();
}

class _LiveLocationRequiredSheetState extends State<LiveLocationRequiredSheet> {
  bool _enabling = false;
  String? _error;

  Future<void> _enable() async {
    setState(() { _enabling = true; _error = null; });
    final ok = await context.read<AuthProvider>().startLiveLocation();
    if (!mounted) return;
    setState(() => _enabling = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Could not turn on location. Please allow location access in your phone settings and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(100)),
        )),
        const SizedBox(height: 20),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.warning.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.location_off_rounded, color: AppColors.warning, size: 30),
        ),
        const SizedBox(height: 18),
        Text('Turn On Live Location', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'Live location must be on ${widget.reason} — this lets the app share your real, current location.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _enabling ? null : _enable,
          child: Container(
            width: double.infinity, height: 50,
            decoration: BoxDecoration(
              gradient: _enabling ? null : const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              color: _enabling ? AppColors.surface2 : null,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Center(
              child: _enabling
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('Allow & Turn On Location', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ]),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.error, fontSize: 12)),
        ],
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => Navigator.pop(context, false),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Not now', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}
