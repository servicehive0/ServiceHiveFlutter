import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../services/avatar_cache.dart';

class BidChatScreen extends StatefulWidget {
  final String requestId;
  final String bidId;
  final String otherUserName;

  const BidChatScreen({
    super.key,
    required this.requestId,
    required this.bidId,
    required this.otherUserName,
  });

  @override
  State<BidChatScreen> createState() => _BidChatScreenState();
}

class _BidChatScreenState extends State<BidChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _uploadingImage = false;
  String? _otherAvatarUrl;
  String? _otherUserId;
  bool _otherIsProvider = false;
  bool _iBlockedThem = false;
  bool _theyBlockedMe = false;

  @override
  void initState() {
    super.initState();
    context.read<RequestProvider>().subscribeToMessages(widget.bidId);
    _loadOtherAvatar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    context.read<RequestProvider>().unsubscribeFromMessages();
    super.dispose();
  }

  // The screen only receives the other party's display name, not their
  // user id or avatar (the Bid/ServiceRequest models this route is built
  // from don't carry avatar_url) — resolve it here: look up the bid's
  // provider_id and the request's customer_id, then whichever one ISN'T
  // the current logged-in user is who we're chatting with.
  Future<void> _loadOtherAvatar() async {
    try {
      final myId = context.read<AuthProvider>().user?.id;
      if (myId == null) return;
      final db = Supabase.instance.client;

      final bid = await db.from('bids').select('provider_id').eq('id', widget.bidId).maybeSingle();
      final req = await db.from('service_requests').select('customer_id').eq('id', widget.requestId).maybeSingle();

      final providerId = bid?['provider_id'] as String?;
      final customerId = req?['customer_id'] as String?;
      final otherId = providerId == myId ? customerId : providerId;
      if (otherId == null) return;
      if (mounted) setState(() {
        _otherUserId = otherId;
        _otherIsProvider = otherId == providerId;
      });

      final url = await AvatarCache.getAvatar(otherId);
      if (mounted && url != null) {
        setState(() => _otherAvatarUrl = url);
      }

      final iBlocked = await db.rpc('is_blocked', params: {'blocker': myId, 'blocked': otherId}) as bool?;
      final theyBlocked = await db.rpc('is_blocked', params: {'blocker': otherId, 'blocked': myId}) as bool?;
      if (mounted) {
        setState(() {
          _iBlockedThem = iBlocked == true;
          _theyBlockedMe = theyBlocked == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _blockUser() async {
    if (_otherUserId == null) return;
    final myId = context.read<AuthProvider>().user?.id;
    if (myId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Block ${widget.otherUserName}?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'They will no longer be able to send you messages. You can still see this conversation.',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Block', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await Supabase.instance.client.from('blocked_users').insert({
        'blocker_id': myId,
        'blocked_id': _otherUserId,
      });
      if (mounted) {
        setState(() => _iBlockedThem = true);
        _showSnack('${widget.otherUserName} has been blocked.');
      }
    } catch (_) {
      if (mounted) _showSnack('Could not block. Try again.', error: true);
    }
  }

  Future<void> _unblockUser() async {
    final otherId = _otherUserId;
    if (otherId == null) return;
    final myId = context.read<AuthProvider>().user?.id;
    if (myId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Unblock ${widget.otherUserName}?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'They will be able to send you messages again.',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Unblock', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await Supabase.instance.client
          .from('blocked_users')
          .delete()
          .eq('blocker_id', myId)
          .eq('blocked_id', otherId);
      if (mounted) {
        setState(() => _iBlockedThem = false);
        _showSnack('${widget.otherUserName} has been unblocked.');
      }
    } catch (_) {
      if (mounted) _showSnack('Could not unblock. Try again.', error: true);
    }
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

  Future<void> _pickAndSendImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
            title: Text('Take Photo', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
            title: Text('Choose from Gallery', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null || !mounted) return;

    XFile? picked;
    Uint8List? bytes;
    try {
      picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1200);
      if (picked == null) return;
      bytes = await picked.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not access camera/gallery. Check app permissions.', error: true);
      return;
    }
    if (!mounted) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _uploadingImage = true);
    final imageUrl = await context.read<RequestProvider>().uploadRequestImage(bytes, picked.name);
    if (!mounted) return;
    setState(() => _uploadingImage = false);

    if (imageUrl == null) {
      _showSnack('Image upload failed. Try again.', error: true);
      return;
    }

    final ok = await context.read<RequestProvider>().sendMessage(
      requestId: widget.requestId,
      bidId: widget.bidId,
      senderId: user.id,
      senderName: user.name,
      message: '',
      imageUrl: imageUrl,
    );
    if (mounted && ok) _scrollToBottom();
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending || _theyBlockedMe) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _sending = true);
    _ctrl.clear();

    final rp = context.read<RequestProvider>();
    final ok = await rp.sendMessage(
      requestId: widget.requestId,
      bidId: widget.bidId,
      senderId: user.id,
      senderName: user.name,
      message: text,
    );

    if (mounted) {
      setState(() => _sending = false);
      if (!ok) {
        _ctrl.text = text; // restore text on failure
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send. Try again.', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.watch<RequestProvider>().messages;
    final userId = context.read<AuthProvider>().user?.id ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppColors.bg,
      // Without this, the keyboard opening pushed the whole Column (including
      // the fixed header) upward instead of just the message input — the
      // header's hardcoded top padding meant it visibly drifted off-position.
      // The input row already adds MediaQuery.viewInsets.bottom itself, so
      // only that needs to move.
      resizeToAvoidBottomInset: false,
      body: Column(children: [
        // Header
        SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: _otherUserId == null
                  ? null
                  : () => context.push(_otherIsProvider ? '/provider/$_otherUserId' : '/customer/$_otherUserId'),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.15),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  image: (_otherAvatarUrl != null)
                      ? DecorationImage(image: CachedNetworkImageProvider(_otherAvatarUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: _otherAvatarUrl == null
                    ? Center(child: Text(
                        widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
                        style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16),
                      ))
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: _otherUserId == null
                  ? null
                  : () => context.push(_otherIsProvider ? '/provider/$_otherUserId' : '/customer/$_otherUserId'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.otherUserName, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              Text(
                _iBlockedThem
                    ? 'You blocked this person'
                    : (_theyBlockedMe ? 'This person has blocked you' : 'Bid Chat'),
                style: GoogleFonts.inter(color: (_iBlockedThem || _theyBlockedMe) ? AppColors.error : AppColors.textMuted, fontSize: 12),
              ),
            ]))),
            if (!_theyBlockedMe || _iBlockedThem)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                color: AppColors.surface2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (v) { if (v == 'block') _blockUser(); if (v == 'unblock') _unblockUser(); },
                itemBuilder: (_) => [
                  if (_iBlockedThem)
                    PopupMenuItem(
                      value: 'unblock',
                      child: Text('Unblock ${widget.otherUserName}', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    )
                  else
                    PopupMenuItem(
                      value: 'block',
                      child: Text('Block ${widget.otherUserName}', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
          ]),
          ),
        ),

        // Messages — realtime + a 2s poll already keep this live, but a
        // pull-to-refresh is still offered as a manual-override safety net,
        // matching every other "live" screen in this app.
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<RequestProvider>().loadMessages(widget.bidId),
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: messages.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 120),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textDim, size: 36),
                            const SizedBox(height: 10),
                            Text('No messages yet', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Ask about pricing, timing, etc.', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12)),
                          ]),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      final isMe = msg.senderId == userId;
                      return _MessageBubble(
                        text: msg.message,
                        senderName: msg.senderName,
                        imageUrl: msg.imageUrl,
                        avatarUrl: isMe ? null : _otherAvatarUrl,
                        isMe: isMe,
                        time: msg.createdAt,
                      );
                    },
                  ),
          ),
        ),

        // Input — disabled entirely if the other party has blocked me,
        // since sending would just fail server-side anyway.
        if (_theyBlockedMe)
          Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              const Icon(Icons.block_rounded, color: AppColors.error, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('This person has blocked you. You can\'t send messages.',
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13))),
            ]),
          )
        else
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: _uploadingImage ? null : _pickAndSendImage,
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _uploadingImage
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 22),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: GoogleFonts.inter(color: AppColors.textDim, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 10)],
                  ),
                  child: _sending
                      ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final String senderName;
  final String? imageUrl;
  final String? avatarUrl;
  final bool isMe;
  final DateTime time;

  const _MessageBubble({
    required this.text,
    required this.senderName,
    this.imageUrl,
    this.avatarUrl,
    required this.isMe,
    required this.time,
  });

  void _openFullscreen(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl!),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final hasText = text.trim().isNotEmpty;

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
                color: AppColors.primary.withOpacity(0.15),
                image: (avatarUrl != null)
                    ? DecorationImage(image: CachedNetworkImageProvider(avatarUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: avatarUrl == null
                  ? Center(child: Text(
                      senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800),
                    ))
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (hasImage)
                  GestureDetector(
                    onTap: () => _openFullscreen(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl!,
                        width: 200, height: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(
                                width: 200, height: 200,
                                color: AppColors.surface2,
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                              ),
                        errorBuilder: (_, __, ___) => Container(
                          width: 200, height: 200,
                          color: AppColors.surface2,
                          child: const Icon(Icons.broken_image_outlined, color: AppColors.textDim),
                        ),
                      ),
                    ),
                  ),
                if (hasImage && hasText) const SizedBox(height: 4),
                if (hasText)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isMe
                          ? const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isMe ? null : AppColors.surface2,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      border: isMe ? null : Border.all(color: AppColors.border),
                      boxShadow: isMe
                          ? [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.2), blurRadius: 8)]
                          : null,
                    ),
                    child: Text(text, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, height: 1.4)),
                  ),
                const SizedBox(height: 4),
                Text(timeStr, style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 10)),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
