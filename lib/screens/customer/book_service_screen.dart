import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/booking_provider.dart';
import '../../providers/provider_list_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';

class BookServiceScreen extends StatefulWidget {
  final String providerId;
  const BookServiceScreen({super.key, required this.providerId});

  @override
  State<BookServiceScreen> createState() => _BookServiceScreenState();
}

class _BookServiceScreenState extends State<BookServiceScreen> {
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTime = '10:00 AM - 12:00 PM';
  bool _isLoading = false;

  static const _timeSlots = [
    '8:00 AM - 10:00 AM',
    '10:00 AM - 12:00 PM',
    '12:00 PM - 2:00 PM',
    '2:00 PM - 4:00 PM',
    '4:00 PM - 6:00 PM',
    '6:00 PM - 8:00 PM',
  ];

  @override
  void dispose() {
    _addressCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_addressCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please fill all fields', style: GoogleFonts.inter()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null || price < 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enter a valid price', style: GoogleFonts.inter()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    final provider = context.read<ProviderListProvider>().getById(widget.providerId);
    if (provider == null) return;

    context.read<BookingProvider>().createBooking(
      providerId: provider.id,
      providerName: provider.name,
      providerPhone: provider.phone,
      serviceType: provider.serviceType,
      serviceIcon: provider.serviceIcon,
      address: _addressCtrl.text.trim(),
      city: provider.city,
      description: _descCtrl.text.trim(),
      scheduledDate: _selectedDate,
      timeSlot: _selectedTime,
      offeredPrice: price,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SuccessDialog(onDone: () {
          context.go('/customer?tab=2');
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProviderListProvider>().getById(widget.providerId);
    if (provider == null) {
      return Scaffold(backgroundColor: AppColors.bg,
        body: Center(child: Text('Provider not found', style: GoogleFonts.inter(color: Colors.white))));
    }

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
                  Text('Book Service', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),

          // Provider info strip
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                      ),
                      child: Center(child: Text(provider.name[0],
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(provider.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(provider.serviceType, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    Text('Rs ${provider.ratePerHour.toInt()}/hr',
                      style: GoogleFonts.inter(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date picker
                  _SectionTitle('Select Date'),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        builder: (ctx, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(primary: AppColors.primary),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 18),
                            const SizedBox(width: 12),
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textDim, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _SectionTitle('Select Time Slot'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _timeSlots.map((t) {
                      final active = t == _selectedTime;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedTime = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? AppColors.primary : AppColors.surface2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: active ? AppColors.primary : AppColors.border),
                          ),
                          child: Text(t,
                            style: GoogleFonts.inter(
                              color: active ? Colors.white : AppColors.textMuted,
                              fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  AppInput(
                    label: 'Your Address',
                    hint: 'Enter your complete address',
                    controller: _addressCtrl,
                    prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.textDim, size: 18),
                  ),
                  const SizedBox(height: 16),
                  AppInput(
                    label: 'Describe Your Problem',
                    hint: 'Explain what needs to be done...',
                    controller: _descCtrl,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  AppInput(
                    label: 'Your Offered Price (Rs)',
                    hint: 'e.g. 2000',
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppColors.textDim, size: 18),
                  ),
                  const SizedBox(height: 8),
                  Text('Provider will confirm or negotiate the price.',
                    style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11)),

                  const SizedBox(height: 28),
                  AppButton(label: 'SEND BOOKING REQUEST', icon: Icons.send_rounded, isLoading: _isLoading, onTap: _submit),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
    style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700));
}

class _SuccessDialog extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessDialog({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withOpacity(0.1),
                border: Border.all(color: AppColors.success.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 38),
            ),
            const SizedBox(height: 18),
            Text('Request Sent!', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Your booking request has been sent. The provider will respond shortly.',
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onDone,
              child: Container(
                width: double.infinity, height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Center(child: Text('VIEW MY BOOKINGS',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
