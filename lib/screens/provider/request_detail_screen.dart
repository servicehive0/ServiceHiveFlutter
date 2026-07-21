import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../widgets/app_input.dart';

class RequestDetailScreen extends StatefulWidget {
  final String bookingId;
  const RequestDetailScreen({super.key, required this.bookingId});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _priceCtrl = TextEditingController();
  bool _negotiate = false;

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>().getById(widget.bookingId);
    if (booking == null) {
      return Scaffold(backgroundColor: AppColors.bg,
        body: Center(child: Text('Request not found', style: GoogleFonts.inter(color: Colors.white))));
    }

    final alreadyHandled = booking.status != BookingStatus.pending;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('Request Detail', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),

          // Customer card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Customer', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
                      child: Center(child: Text(booking.customerName[0],
                        style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 20))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(booking.customerName, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(booking.customerPhone, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // Job details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Row('Service', booking.serviceType),
                  _Row('Date', '${booking.scheduledDate.day}/${booking.scheduledDate.month}/${booking.scheduledDate.year}'),
                  _Row('Time', booking.timeSlot),
                  _Row('Address', booking.address),
                  _Row('Offered Price', 'Rs ${booking.offeredPrice?.toInt() ?? 0}', valueColor: AppColors.primary),
                ]),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // Description
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Problem Description', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Text(booking.description, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.6)),
                ]),
              ),
            ),
          ),

          if (alreadyHandled)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: booking.status.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: booking.status.color.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    Icon(booking.status.icon, color: booking.status.color, size: 18),
                    const SizedBox(width: 10),
                    Text('This request is already ${booking.status.label.toLowerCase()}.',
                      style: GoogleFonts.inter(color: booking.status.color, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),

          // Negotiate price toggle
          if (!alreadyHandled) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: () => setState(() => _negotiate = !_negotiate),
                  child: Row(children: [
                    Checkbox(
                      value: _negotiate,
                      onChanged: (v) => setState(() => _negotiate = v ?? false),
                      activeColor: AppColors.primary,
                      checkColor: Colors.white,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    Text('Negotiate price (suggest different amount)',
                      style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                  ]),
                ),
              ),
            ),
            if (_negotiate)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: AppInput(
                    label: 'Your Price (Rs)',
                    hint: 'Enter your proposed price',
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppColors.textDim, size: 18),
                  ),
                ),
              ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      bottomNavigationBar: alreadyHandled ? null : _buildActions(context, booking),
    );
  }

  Widget _buildActions(BuildContext context, BookingModel booking) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              context.read<BookingProvider>().rejectBooking(booking.id);
              context.pop();
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.error.withOpacity(0.3))),
              child: Center(child: Text('Reject', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w700))),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () {
              double? agreed;
              if (_negotiate && _priceCtrl.text.trim().isNotEmpty) {
                agreed = double.tryParse(_priceCtrl.text.trim());
              }
              context.read<BookingProvider>().acceptBooking(booking.id, agreedPrice: agreed ?? booking.offeredPrice);
              context.pop();
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.success, Color(0xFF059669)]),
                borderRadius: BorderRadius.circular(100),
                boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.3), blurRadius: 12)],
              ),
              child: Center(child: Text('Accept Job', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _Row(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      SizedBox(width: 90, child: Text(label, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12))),
      Expanded(child: Text(value, style: GoogleFonts.inter(color: valueColor ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );
}
