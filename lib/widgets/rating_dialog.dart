import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/request_provider.dart';

class RatingDialog extends StatefulWidget {
  final String requestId;
  const RatingDialog({super.key, required this.requestId});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 0;
  final _reviewCtrl = TextEditingController();
  bool _submitting = false;

  static const _labels = {1: 'Poor', 2: 'Fair', 3: 'Good', 4: 'Great', 5: 'Excellent'};

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _submitting = true);
    final ok = await context.read<RequestProvider>().submitRating(widget.requestId, _rating, _reviewCtrl.text.trim());
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rate this Service', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('How was your experience?', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 13)),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => setState(() => _rating = i + 1.0),
                child: AnimatedScale(
                  scale: _rating >= i + 1 ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.star_rounded,
                      color: _rating >= i + 1 ? const Color(0xFFFBBF24) : AppColors.surface3, size: 36),
                  ),
                ),
              )),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Text(_labels[_rating.toInt()] ?? '', style: GoogleFonts.inter(color: const Color(0xFFFBBF24), fontSize: 13, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _reviewCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Share a few words about your experience (optional)...',
                  hintStyle: GoogleFonts.inter(color: AppColors.textDim, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: (_rating == 0 || _submitting) ? null : _submit,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: (_rating == 0 || _submitting) ? null : const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                    color: (_rating == 0 || _submitting) ? AppColors.surface2 : null,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Submit Rating', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Maybe later', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
