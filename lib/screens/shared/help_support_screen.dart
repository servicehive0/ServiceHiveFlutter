import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import 'contact_us_screen.dart';

class _Faq {
  final String question;
  final String answer;
  const _Faq(this.question, this.answer);
}

// Distinct from ContactUsScreen (which is a complaint/message form) — this
// is a self-serve FAQ so customers/providers can answer their own question
// about how the actual bidding/OTP/rating flow works before needing to
// contact support at all.
const _customerFaqs = [
  _Faq('How do I book a service?',
      'Post a request describing what you need — nearby providers will send you bids with their price and a message. Compare bids and accept the one you like best.'),
  _Faq('How does payment work?',
      'You agree on a price directly with the provider through their bid. Pay them in person once the job is done — ServiceHive doesn\'t process payments.'),
  _Faq('What is the OTP for?',
      'When your provider arrives, they\'ll show you a 6-digit code on their app. Enter it in your Requests tab to confirm they\'ve arrived and start the job — this protects both of you.'),
  _Faq('How do I rate a provider?',
      'After a job is marked complete, open it from your Bookings tab and leave a star rating with an optional review.'),
  _Faq('Can I cancel a request?',
      'You can delete an open request (before any bid is accepted) from your Requests tab. Once a bid is accepted, contact the provider directly via chat.'),
  _Faq('How do I message my provider?',
      'Once you\'ve accepted a bid, a Chat option appears on that request — messages are delivered in real time.'),
];

const _providerFaqs = [
  _Faq('How do I get requests?',
      'Go online from your Dashboard and set your specialization in your Profile. You\'ll then see matching open requests in your area on the Requests tab.'),
  _Faq('How do I bid on a request?',
      'Open a request from your Requests tab, enter your price and a short message, then submit. The customer will review all bids and pick one.'),
  _Faq('What happens after my bid is accepted?',
      'The job appears in your Jobs tab. Show the customer the OTP code displayed there when you arrive — once they verify it, the job moves to in-progress.'),
  _Faq('How do I mark a job complete?',
      'After the customer verifies your OTP, a Mark Complete button appears on the job. Tap it once you\'ve finished the work.'),
  _Faq('How are my earnings tracked?',
      'Every completed job\'s price is added to your Earnings tab automatically, with a full transaction history.'),
  _Faq('Why can\'t I see any requests?',
      'Make sure you\'re online and have set a specialization in your Profile — requests are matched by service type and city.'),
];

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role;
    final faqs = role == 'provider' ? _providerFaqs : _customerFaqs;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
        ),
        title: Text('Help & Support', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('FREQUENTLY ASKED QUESTIONS', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 12),
          ...List.generate(faqs.length, (i) => _FaqTile(
                faq: faqs[i],
                expanded: _expandedIndex == i,
                onTap: () => setState(() => _expandedIndex = _expandedIndex == i ? null : i),
              )),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.headset_mic_outlined, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text("Still stuck? Reach our support team directly.",
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13))),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsScreen())),
                child: Text('Contact Us', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final _Faq faq;
  final bool expanded;
  final VoidCallback onTap;
  const _FaqTile({required this.faq, required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: expanded ? AppColors.primary.withOpacity(0.35) : AppColors.border),
      ),
      child: Column(children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: Text(faq.question, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 22),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(faq.answer, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.5)),
            ),
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}
