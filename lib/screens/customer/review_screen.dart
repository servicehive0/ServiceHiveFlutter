import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/booking_provider.dart';
import '../../widgets/app_button.dart';

class ReviewScreen extends StatefulWidget {
  final String bookingId;
  const ReviewScreen({super.key, required this.bookingId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  double _rating = 0;
  final _ctrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a rating', style: GoogleFonts.inter()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    context.read<BookingProvider>().submitReview(widget.bookingId, _rating, _ctrl.text.trim());
    setState(() => _isLoading = false);
    if (mounted) context.go('/customer');
  }

  static const _labels = ['', 'Terrible', 'Poor', 'Average', 'Good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    final booking = context.read<BookingProvider>().getById(widget.bookingId);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
        child: Column(
          children: [
            // Back
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Star icon
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFBBF24).withOpacity(0.1),
                border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 40),
            ),

            const SizedBox(height: 20),
            Text('Rate Your Experience', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (booking != null)
              Text('How was ${booking.providerName}\'s ${booking.serviceType} service?',
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                textAlign: TextAlign.center),

            const SizedBox(height: 36),

            // Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = i + 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedScale(
                      scale: _rating >= i + 1 ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.star_rounded,
                        color: _rating >= i + 1 ? const Color(0xFFFBBF24) : AppColors.surface3,
                        size: 44,
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 8),
            if (_rating > 0)
              Text(_labels[_rating.toInt()],
                style: GoogleFonts.inter(color: const Color(0xFFFBBF24), fontSize: 14, fontWeight: FontWeight.w700)),

            const SizedBox(height: 32),

            // Review text
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _ctrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Write your review (optional)...',
                  hintStyle: GoogleFonts.inter(color: AppColors.textDim, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 28),
            AppButton(label: 'SUBMIT REVIEW', icon: Icons.check_rounded, isLoading: _isLoading, onTap: _submit),
          ],
        ),
      ),
    );
  }
}
