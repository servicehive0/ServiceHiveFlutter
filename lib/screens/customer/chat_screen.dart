import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/bid_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/avatar_cache.dart';

class ChatScreen extends StatefulWidget {
  final String bookingId;
  const ChatScreen({super.key, required this.bookingId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  String? _otherAvatarUrl;

  @override
  void initState() {
    super.initState();
    context.read<BookingProvider>().subscribeToChat(widget.bookingId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOtherAvatar());
  }

  Future<void> _loadOtherAvatar() async {
    try {
      final userId = context.read<AuthProvider>().user?.id ?? '';
      final booking = context.read<BookingProvider>().getById(widget.bookingId);
      if (booking == null) return;
      final isCustomer = booking.customerId == userId;
      final otherId = isCustomer ? booking.providerId : booking.customerId;
      final url = await AvatarCache.getAvatar(otherId);
      if (mounted && url != null) {
        setState(() => _otherAvatarUrl = url);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    context.read<BookingProvider>().unsubscribeFromChat();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _sending = true);
    _ctrl.clear();

    final ok = await context.read<BookingProvider>().sendMessage(widget.bookingId, user.id, text);

    if (mounted) {
      setState(() => _sending = false);
      if (ok) _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookingProvider>();
    final booking = bp.getById(widget.bookingId);
    final messages = bp.chatMessages;
    final userId = context.read<AuthProvider>().user?.id ?? '';
    final isCustomer = booking?.customerId == userId;
    final otherName = isCustomer ? (booking?.providerName ?? 'Provider') : (booking?.customerName ?? 'Customer');
    final otherId = isCustomer ? booking?.providerId : booking?.customerId;
    final otherProfileRoute = isCustomer ? '/provider/$otherId' : '/customer/$otherId';

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: otherId == null ? null : () => context.push(otherProfileRoute),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                          image: (_otherAvatarUrl != null)
                              ? DecorationImage(image: CachedNetworkImageProvider(_otherAvatarUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _otherAvatarUrl == null
                            ? Center(child: Text(otherName.isNotEmpty ? otherName[0] : '?',
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)))
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(otherName, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(booking?.serviceType ?? '', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<BookingProvider>().loadChat(widget.bookingId),
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: messages.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 120),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textDim, size: 48),
                                const SizedBox(height: 12),
                                Text('Start the conversation', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      itemCount: messages.length,
                      itemBuilder: (_, i) => _MessageBubble(
                        message: messages[i],
                        isMe: messages[i].senderId == userId,
                      ),
                    ),
            ),
          ),

          // Input
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: GoogleFonts.inter(color: AppColors.textDim, fontSize: 14),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10)],
                    ),
                    child: _sending
                        ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final BidMessage message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface3,
              ),
              child: const Icon(Icons.person_rounded, color: AppColors.textDim, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : AppColors.surface2,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(message.message,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 4),
                  Text(
                    '${message.createdAt.hour}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
