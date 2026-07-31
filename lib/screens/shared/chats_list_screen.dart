import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error_helper.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/avatar_cache.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  static final _db = Supabase.instance.client;

  List<_ChatThread> _threads = [];
  bool _loading = true;
  String? _error;
  String? _myId;
  // bid_id -> hidden_at, only for threads the current user deleted whose
  // last message is still older than the hide — a newer incoming message
  // un-hides the thread automatically (matches WhatsApp's "delete for me"
  // behavior: it comes back if the other person messages again).
  Map<String, DateTime> _hiddenAt = {};
  RealtimeChannel? _channel;
  bool _reloadInFlight = false;
  bool _reloadQueued = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  // Live-updates thread ordering/previews the instant any message arrives
  // in any of this user's chats, mirroring React's ChatsListTab.jsx — before
  // this, the list only refreshed via the manual refresh icon or
  // pull-to-refresh, which meant refreshing far too often. Postgres Changes
  // can't filter to "any message in one of my threads" server-side (only
  // single-column equality filters are supported), so every insert from
  // every user's chat reaches this client — debounced + in-flight-guarded
  // below so a burst of unrelated messages can't race overlapping reloads.
  void _subscribe() {
    _channel = _db.channel('chats_list_${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bid_messages',
          callback: (_) => _scheduleReload(),
        )
        .subscribe();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  @override
  void dispose() {
    if (_channel != null) _db.removeChannel(_channel!);
    _debounce?.cancel();
    super.dispose();
  }

  // Guards against overlapping reloads: a burst of unrelated bid_messages
  // inserts (from other users' chats, since the subscription can't be
  // filtered to just this user's threads server-side) could otherwise fire
  // several concurrent _doLoad() calls that race and leave stale state.
  Future<void> _load() async {
    if (_reloadInFlight) { _reloadQueued = true; return; }
    _reloadInFlight = true;
    try {
      await _doLoad();
    } finally {
      _reloadInFlight = false;
      if (_reloadQueued) {
        _reloadQueued = false;
        _load();
      }
    }
  }

  Future<void> _doLoad() async {
    setState(() { _loading = true; _error = null; });
    final user = context.read<AuthProvider>().user;
    if (user == null) { setState(() => _loading = false); return; }

    final isProvider = user.role == 'provider';
    _myId = user.id;

    try {
      await _loadHidden(user.id);
      if (isProvider) {
        // 1. All bids by this provider
        final bidsData = await _db
            .from('bids')
            .select('id, request_id, status, created_at')
            .eq('provider_id', user.id)
            .order('created_at', ascending: false);
        final bids = bidsData as List;
        if (bids.isEmpty) {
          if (mounted) setState(() { _threads = []; _loading = false; });
          return;
        }

        // 2. Request info for those bids
        final reqIds = bids.map((b) => b['request_id'] as String).toList();
        final reqsData = await _db
            .from('service_requests')
            .select('id, service_name, customer_name, customer_id, status')
            .inFilter('id', reqIds);
        final reqsMap = <String, Map<String, dynamic>>{
          for (final r in reqsData as List) r['id'] as String: r as Map<String, dynamic>
        };

        // 3. Last message per bid
        final bidIds = bids.map((b) => b['id'] as String).toList();
        final msgsData = await _db
            .from('bid_messages')
            .select('bid_id, message, created_at, sender_id')
            .inFilter('bid_id', bidIds)
            .order('created_at', ascending: false);
        final lastMsgMap = <String, Map<String, dynamic>>{};
        for (final msg in msgsData as List) {
          final bid = msg['bid_id'] as String;
          if (!lastMsgMap.containsKey(bid)) lastMsgMap[bid] = msg as Map<String, dynamic>;
        }

        final threads = bids.map((bid) {
          final bidId = bid['id'] as String;
          final req = reqsMap[bid['request_id'] as String];
          final lastMsg = lastMsgMap[bidId];
          return _ChatThread(
            bidId: bidId,
            requestId: bid['request_id'] as String,
            otherId: req?['customer_id'] as String? ?? '',
            serviceName: req?['service_name'] as String? ?? 'Service',
            otherName: req?['customer_name'] as String? ?? 'Customer',
            lastMessage: lastMsg?['message'] as String?,
            lastTime: lastMsg != null ? DateTime.tryParse(lastMsg['created_at'] as String) : null,
            isMe: lastMsg?['sender_id'] == user.id,
            bidStatus: bid['status'] as String? ?? 'pending',
            otherIsProvider: false,
          );
        }).toList();

        _sortThreads(threads);
        await _loadAvatars(threads);
        final visible = _filterHidden(threads);
        if (mounted) setState(() { _threads = visible; _loading = false; });
      } else {
        // Customer role
        // 1. All requests by customer
        final reqsData = await _db
            .from('service_requests')
            .select('id, service_name, status')
            .eq('customer_id', user.id)
            .order('created_at', ascending: false);
        final requests = reqsData as List;
        if (requests.isEmpty) {
          if (mounted) setState(() { _threads = []; _loading = false; });
          return;
        }

        // 2. All bids on those requests
        final reqIds = requests.map((r) => r['id'] as String).toList();
        final bidsData = await _db
            .from('bids')
            .select('id, request_id, provider_id, provider_name, status')
            .inFilter('request_id', reqIds)
            .order('created_at', ascending: false);
        final bids = bidsData as List;
        if (bids.isEmpty) {
          if (mounted) setState(() { _threads = []; _loading = false; });
          return;
        }

        final reqsMap = <String, Map<String, dynamic>>{
          for (final r in requests) r['id'] as String: r as Map<String, dynamic>
        };

        // 3. Last message per bid
        final bidIds = bids.map((b) => b['id'] as String).toList();
        final msgsData = await _db
            .from('bid_messages')
            .select('bid_id, message, created_at, sender_id')
            .inFilter('bid_id', bidIds)
            .order('created_at', ascending: false);
        final lastMsgMap = <String, Map<String, dynamic>>{};
        for (final msg in msgsData as List) {
          final bid = msg['bid_id'] as String;
          if (!lastMsgMap.containsKey(bid)) lastMsgMap[bid] = msg as Map<String, dynamic>;
        }

        final threads = bids.map((bid) {
          final bidId = bid['id'] as String;
          final req = reqsMap[bid['request_id'] as String];
          final lastMsg = lastMsgMap[bidId];
          return _ChatThread(
            bidId: bidId,
            requestId: bid['request_id'] as String,
            otherId: bid['provider_id'] as String? ?? '',
            serviceName: req?['service_name'] as String? ?? 'Service',
            otherName: bid['provider_name'] as String? ?? 'Provider',
            lastMessage: lastMsg?['message'] as String?,
            lastTime: lastMsg != null ? DateTime.tryParse(lastMsg['created_at'] as String) : null,
            isMe: lastMsg?['sender_id'] == user.id,
            otherIsProvider: true,
            bidStatus: bid['status'] as String? ?? 'pending',
          );
        }).toList();

        _sortThreads(threads);
        await _loadAvatars(threads);
        final visible = _filterHidden(threads);
        if (mounted) setState(() { _threads = visible; _loading = false; });
      }
    } catch (e) {
      debugPrint('ChatsListScreen error: $e');
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  // users_select_own RLS only allows reading your own row, so a direct
  // .from('users') lookup of the other party's avatar always came back
  // empty — AvatarCache wraps the SECURITY DEFINER RPC that bypasses this,
  // and caches the result so re-viewing the same person's chat doesn't
  // re-hit the RPC every time.
  Future<void> _loadAvatars(List<_ChatThread> threads) async {
    final ids = threads.map((t) => t.otherId).where((id) => id.isNotEmpty).toSet();
    await Future.wait(ids.map((id) async {
      final url = await AvatarCache.getAvatar(id);
      if (url != null) {
        for (final t in threads.where((t) => t.otherId == id)) {
          t.avatarUrl = url;
        }
      }
    }));
  }

  Future<void> _loadHidden(String userId) async {
    try {
      final rows = await _db.from('hidden_chats').select('bid_id, hidden_at').eq('user_id', userId);
      _hiddenAt = {
        for (final r in (rows as List))
          r['bid_id'] as String: DateTime.parse(r['hidden_at'] as String),
      };
    } catch (_) {
      _hiddenAt = {};
    }
  }

  // A hidden thread stays hidden only while its last message is still
  // older than when it was hidden — a newer reply un-hides it.
  List<_ChatThread> _filterHidden(List<_ChatThread> threads) {
    return threads.where((t) {
      final hiddenAt = _hiddenAt[t.bidId];
      if (hiddenAt == null) return true;
      if (t.lastTime != null && t.lastTime!.isAfter(hiddenAt)) return true;
      return false;
    }).toList();
  }

  Future<void> _deleteThread(_ChatThread thread) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Chat?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'This removes the conversation with ${thread.otherName} from your list. They can still see it.',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || _myId == null) return;

    setState(() => _threads = _threads.where((t) => t.bidId != thread.bidId).toList());
    try {
      await _db.from('hidden_chats').upsert({'user_id': _myId, 'bid_id': thread.bidId});
    } catch (_) {
      // Non-critical for the current session — worst case it reappears on next _load().
    }
  }

  void _sortThreads(List<_ChatThread> threads) {
    threads.sort((a, b) {
      if (a.lastTime == null && b.lastTime == null) return 0;
      if (a.lastTime == null) return 1;
      if (b.lastTime == null) return -1;
      return b.lastTime!.compareTo(a.lastTime!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.bg.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chats', style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                      if (!_loading && _threads.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('${_threads.length} conversation${_threads.length == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 19),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : _error != null
                      ? _buildError()
                      : _threads.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppColors.primary,
                              backgroundColor: AppColors.surface,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                                itemCount: _threads.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, i) => Dismissible(
                                  key: ValueKey(_threads[i].bidId),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) async {
                                    await _deleteThread(_threads[i]);
                                    return false; // _deleteThread already updates _threads/setState
                                  },
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 24),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                  ),
                                  child: _ChatTile(
                                    thread: _threads[i],
                                    onTap: () => context.push(
                                      '/service-request/${_threads[i].requestId}/chat/${_threads[i].bidId}',
                                      extra: _threads[i].otherName,
                                    ),
                                  ),
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84, height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.primary.withValues(alpha: 0.16), AppColors.primary.withValues(alpha: 0.04)],
            ),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryLight, size: 34),
        ),
        const SizedBox(height: 20),
        Text('No conversations yet', style: GoogleFonts.inter(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Chats with providers will appear here.', style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 13), textAlign: TextAlign.center),
      ],
    ),
  );

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error.withValues(alpha: 0.1),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
          ),
          child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 32),
        ),
        const SizedBox(height: 16),
        Text('Could not load chats', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: _load,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text('Retry', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      ],
    ),
  );
}

// ─── Data class ──────────────────────────────────────────────────────────────

class _ChatThread {
  final String bidId;
  final String requestId;
  final String otherId;
  final String serviceName;
  final String otherName;
  final String? lastMessage;
  final DateTime? lastTime;
  final bool isMe;
  final String bidStatus;
  final bool otherIsProvider;
  String? avatarUrl;

  _ChatThread({
    required this.bidId,
    required this.requestId,
    required this.otherId,
    required this.serviceName,
    required this.otherName,
    this.lastMessage,
    this.lastTime,
    required this.isMe,
    required this.bidStatus,
    required this.otherIsProvider,
  });
}

// ─── Chat Tile ────────────────────────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  final _ChatThread thread;
  final VoidCallback onTap;

  const _ChatTile({required this.thread, required this.onTap});

  String _timeLabel(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  Color get _statusColor {
    switch (thread.bidStatus) {
      case 'accepted': return AppColors.success;
      case 'rejected': return AppColors.error;
      default: return AppColors.warning;
    }
  }

  String get _statusLabel {
    switch (thread.bidStatus) {
      case 'accepted': return 'Accepted';
      case 'rejected': return 'Rejected';
      default: return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMsg = thread.lastMessage != null;
    final statusColor = _statusColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar — tapping opens the other party's profile (customer or
            // provider), separate from the row's own onTap which opens chat.
            GestureDetector(
              onTap: thread.otherId.isEmpty
                  ? null
                  : () => context.push(thread.otherIsProvider ? '/provider/${thread.otherId}' : '/customer/${thread.otherId}'),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                      image: (thread.avatarUrl != null && thread.avatarUrl!.isNotEmpty)
                          ? DecorationImage(image: CachedNetworkImageProvider(thread.avatarUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: (thread.avatarUrl == null || thread.avatarUrl!.isEmpty)
                        ? Center(child: Text(
                            thread.otherName.isNotEmpty ? thread.otherName[0].toUpperCase() : '?',
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                          ))
                        : null,
                  ),
                  Positioned(
                    right: -2, bottom: -2,
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                        border: Border.all(color: AppColors.bg, width: 2.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.otherName,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (thread.lastTime != null) ...[
                        const SizedBox(width: 8),
                        Text(_timeLabel(thread.lastTime), style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          _statusLabel,
                          style: GoogleFonts.inter(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          thread.serviceName,
                          style: GoogleFonts.inter(color: AppColors.textDim, fontSize: 11.5, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasMsg
                        ? '${thread.isMe ? "You: " : ""}${thread.lastMessage!}'
                        : 'No messages yet — tap to chat',
                    style: GoogleFonts.inter(
                      color: hasMsg ? AppColors.textMuted : AppColors.textDim,
                      fontSize: 12.5,
                      fontWeight: hasMsg ? FontWeight.w500 : FontWeight.w400,
                      fontStyle: hasMsg ? FontStyle.normal : FontStyle.italic,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.textDim, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
