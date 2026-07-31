import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bid_model.dart';
import '../models/booking_model.dart';
import '../models/notification_model.dart';
import '../services/notify_service.dart';

class BookingProvider extends ChangeNotifier {
  static final _sb = Supabase.instance.client;

  List<BookingModel>              _bookings      = [];
  List<BidMessage>                _chatMessages  = [];
  RealtimeChannel?                _chatChannel;
  Timer?                          _chatPollTimer;
  List<NotificationModel>         _notifications = [];
  bool                            _loading       = false;
  String?                         _currentUserId;
  String?                         _currentUserRole;

  // ─── Public getters ───────────────────────────────────────────────────────

  bool                    get loading           => _loading;
  List<BookingModel>      get bookings          => List.unmodifiable(_bookings);
  List<NotificationModel> get notifications     => List.unmodifiable(_notifications);
  int get unreadNotifCount => _notifications.where((n) => !n.isRead).length;

  List<BookingModel> customerBookings(String customerId) =>
      _bookings.where((b) => b.customerId == customerId || b.customerId == (_currentUserId ?? '')).toList();

  List<BookingModel> providerBookings(String providerId) =>
      _bookings.where((b) => b.providerId == providerId || b.providerId == (_currentUserId ?? '')).toList();

  List<BookingModel> get pendingProviderBookings =>
      _bookings.where((b) => b.status == BookingStatus.pending).toList();

  List<BookingModel> get activeProviderJobs =>
      _bookings.where((b) =>
          b.status == BookingStatus.accepted ||
          b.status == BookingStatus.inProgress).toList();

  BookingModel? getById(String id) {
    try { return _bookings.firstWhere((b) => b.id == id); }
    catch (_) { return null; }
  }

  List<BidMessage> get chatMessages => List.unmodifiable(_chatMessages);

  double get totalProviderEarnings => _bookings
      .where((b) => b.status == BookingStatus.completed)
      .fold(0.0, (sum, b) => sum + (b.agreedPrice ?? b.offeredPrice ?? 0));

  int get completedProviderJobs =>
      _bookings.where((b) => b.status == BookingStatus.completed).length;

  double get providerRating {
    final rated = _bookings.where((b) => b.rating != null).toList();
    if (rated.isEmpty) return 0;
    return rated.fold(0.0, (s, b) => s + b.rating!) / rated.length;
  }

  // ─── Load bookings from Supabase ─────────────────────────────────────────

  Future<void> load(String userId, String role) async {
    _currentUserId   = userId;
    _currentUserRole = role;
    _loading = true;
    notifyListeners();

    try {
      final query = _sb.from('bookings').select('*, customer:user_id(name, phone), provider:provider_id(name, phone)');
      final data  = role == 'provider'
          ? await query.eq('provider_id', userId).order('created_at', ascending: false)
          : await query.eq('user_id',     userId).order('created_at', ascending: false);

      _bookings = (data as List).map((e) => _rowToModel(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('BookingProvider.load error: $e');
    }

    _loading = false;
    notifyListeners();
  }

  // ─── Create booking ───────────────────────────────────────────────────────

  Future<BookingModel?> createBooking({
    required String   providerId,
    required String   providerName,
    required String   providerPhone,
    required String   serviceType,
    required String   serviceIcon,
    required String   address,
    required String   city,
    required String   description,
    required DateTime scheduledDate,
    required String   timeSlot,
    required double   offeredPrice,
  }) async {
    final userId = _sb.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return null;

    try {
      final payload = {
        'user_id':        userId,
        'provider_id':    providerId,
        'service':        serviceType,
        'service_icon':   serviceIcon,
        'address':        address,
        'city':           city,
        'notes':          description,
        'scheduled_type': 'scheduled',
        'scheduled_date': scheduledDate.toIso8601String().substring(0, 10),
        'scheduled_time': timeSlot,
        'price':          offeredPrice,
        'status':         'pending',
      };

      final row     = await _sb.from('bookings').insert(payload).select().single();
      final booking = _rowToModel(row as Map<String, dynamic>);

      _bookings.insert(0, booking);
      _addNotif(
        'Booking Sent!',
        'Your $serviceType request has been sent to $providerName.',
        NotifType.booking,
      );
      notifyListeners();
      return booking;
    } catch (e) {
      debugPrint('createBooking error: $e');
      return null;
    }
  }

  // ─── Status transitions ───────────────────────────────────────────────────

  Future<void> acceptBooking(String id, {double? agreedPrice}) async {
    await _updateStatus(id, BookingStatus.accepted, agreedPrice: agreedPrice);
    final b = getById(id);
    if (b != null) {
      _addNotif('Booking Accepted', 'You accepted booking from ${b.customerName}.', NotifType.booking);
    }
  }

  Future<void> rejectBooking(String id) async {
    await _updateStatus(id, BookingStatus.rejected);
    final b = getById(id);
    if (b != null) {
      _addNotif('Booking Rejected', 'You rejected booking from ${b.customerName}.', NotifType.booking);
    }
  }

  Future<void> startJob(String id)    => _updateStatus(id, BookingStatus.inProgress);

  Future<void> completeJob(String id) async {
    await _updateStatus(id, BookingStatus.completed);
    final b = getById(id);
    if (b != null) {
      _addNotif('Job Completed', '${b.serviceType} job marked as completed.', NotifType.booking);
    }
  }

  Future<void> cancelBooking(String id) async {
    await _updateStatus(id, BookingStatus.cancelled);
    _addNotif('Booking Cancelled', 'Your booking has been cancelled.', NotifType.booking);
  }

  // ─── Review ───────────────────────────────────────────────────────────────

  Future<void> submitReview(String id, double rating, String review) async {
    try {
      await _sb.from('bookings').update({'rating': rating, 'review': review}).eq('id', id);
      final idx = _bookings.indexWhere((b) => b.id == id);
      if (idx != -1) {
        _bookings[idx] = _bookings[idx].copyWith(rating: rating, review: review);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('submitReview error: $e');
    }
  }

  // ─── Messaging (persisted to bid_messages.booking_id, same table + pattern
  // as the bidding-system chat) ──────────────────────────────────────────────

  Future<void> loadChat(String bookingId) async {
    try {
      final data = await _sb
          .from('bid_messages')
          .select()
          .eq('booking_id', bookingId)
          .order('created_at', ascending: true);
      _chatMessages = (data as List)
          .map((j) => BidMessage.fromJson(j as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('loadChat error: $e');
    }
  }

  Future<void> subscribeToChat(String bookingId) async {
    await _chatChannel?.unsubscribe();
    _chatPollTimer?.cancel();
    await loadChat(bookingId);

    _chatChannel = _sb
        .channel('booking_msg_$bookingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bid_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: bookingId,
          ),
          callback: (payload) {
            final msg = BidMessage.fromJson(payload.newRecord);
            _mergeChatMessage(msg);
          },
        )
        .subscribe();

    // Fallback poll: keeps the chat "live" even if Postgres Realtime
    // replication isn't enabled/drops silently — mirrors RequestProvider's
    // bid-chat safety net, which booking-chat previously had none of.
    _chatPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollNewChatMessages(bookingId);
    });
  }

  Future<void> _pollNewChatMessages(String bookingId) async {
    try {
      final since = _chatMessages.isNotEmpty ? _chatMessages.last.createdAt : null;
      var query = _sb.from('bid_messages').select().eq('booking_id', bookingId);
      if (since != null) {
        query = query.gt('created_at', since.toIso8601String());
      }
      final data = await query.order('created_at', ascending: true);
      for (final j in (data as List)) {
        _mergeChatMessage(BidMessage.fromJson(j as Map<String, dynamic>));
      }
    } catch (_) {
      // Silent: transient network hiccups shouldn't surface as chat errors.
    }
  }

  Future<void> unsubscribeFromChat() async {
    await _chatChannel?.unsubscribe();
    _chatChannel = null;
    _chatPollTimer?.cancel();
    _chatPollTimer = null;
    _chatMessages = [];
    notifyListeners();
  }

  void _mergeChatMessage(BidMessage msg) {
    if (_chatMessages.any((m) => m.id == msg.id)) return;
    _chatMessages = [..._chatMessages, msg]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();
  }

  Future<bool> sendMessage(String bookingId, String senderId, String text) async {
    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = BidMessage(
      id: tempId,
      bookingId: bookingId,
      senderId: senderId,
      senderName: '',
      message: text,
      createdAt: DateTime.now(),
    );
    _chatMessages = [..._chatMessages, optimistic];
    notifyListeners();

    try {
      final inserted = await _sb.from('bid_messages').insert({
        'booking_id': bookingId,
        'sender_id': senderId,
        'sender_name': '',
        'message': text,
      }).select().single();

      final real = BidMessage.fromJson(inserted);
      _chatMessages = _chatMessages.map((m) => m.id == tempId ? real : m).toList();
      notifyListeners();

      // Booking-chat previously never notified the recipient at all (unlike
      // bid-chat's RequestProvider.sendMessage) — this closes that gap.
      try {
        final booking = getById(bookingId);
        if (booking != null) {
          final isCustomer = booking.customerId == senderId;
          final recipientId = isCustomer ? booking.providerId : booking.customerId;
          final senderName = isCustomer ? booking.customerName : booking.providerName;
          NotifyService.notify(recipientId, 'New message from $senderName', text, type: 'chat');
        }
      } catch (_) { /* non-critical */ }

      return true;
    } catch (e) {
      debugPrint('sendMessage error: $e');
      _chatMessages = _chatMessages.where((m) => m.id != tempId).toList();
      notifyListeners();
      return false;
    }
  }

  // ─── Notifications ────────────────────────────────────────────────────────

  void markNotifsRead() {
    for (final n in _notifications) { n.isRead = true; }
    notifyListeners();
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  Future<void> _updateStatus(
    String        id,
    BookingStatus status, {
    double?       agreedPrice,
  }) async {
    try {
      final updates = <String, dynamic>{'status': _statusToString(status)};
      if (agreedPrice != null) updates['agreed_price'] = agreedPrice;
      await _sb.from('bookings').update(updates).eq('id', id);

      final idx = _bookings.indexWhere((b) => b.id == id);
      if (idx != -1) {
        _bookings[idx] = _bookings[idx].copyWith(status: status, agreedPrice: agreedPrice);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('_updateStatus error: $e');
    }
  }

  void _addNotif(String title, String body, NotifType type) {
    _notifications.insert(0, NotificationModel(
      id:    'n${DateTime.now().millisecondsSinceEpoch}',
      title: title, body: body, type: type,
      time:  DateTime.now(),
    ));
  }

  static BookingModel _rowToModel(Map<String, dynamic> r) {
    final customer = r['customer'] as Map<String, dynamic>?;
    final provider = r['provider'] as Map<String, dynamic>?;
    return BookingModel(
      id:            r['id']           as String,
      customerId:    r['user_id']      as String,
      customerName:  customer?['name'] as String? ?? 'Customer',
      customerPhone: customer?['phone'] as String? ?? '',
      providerId:    r['provider_id']  as String? ?? '',
      providerName:  provider?['name'] as String? ?? 'Provider',
      providerPhone: provider?['phone'] as String? ?? '',
      serviceType:   r['service']      as String,
      serviceIcon:   r['service_icon'] as String? ?? r['service_slug'] as String? ?? '',
      address:       r['address']      as String,
      city:          r['city']         as String? ?? '',
      description:   r['notes']        as String? ?? '',
      scheduledDate: r['scheduled_date'] != null
          ? DateTime.tryParse(r['scheduled_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      timeSlot:      r['scheduled_time'] as String? ?? '',
      offeredPrice:  (r['price']       as num?)?.toDouble() ?? 0,
      agreedPrice:   (r['agreed_price'] as num?)?.toDouble(),
      status:        _parseStatus(r['status'] as String? ?? 'pending'),
      createdAt:     DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      rating:        (r['rating']      as num?)?.toDouble(),
      review:        r['review']       as String?,
    );
  }

  static BookingStatus _parseStatus(String s) {
    switch (s) {
      case 'confirmed':  return BookingStatus.accepted;
      case 'in_progress': return BookingStatus.inProgress;
      case 'completed':  return BookingStatus.completed;
      case 'cancelled':  return BookingStatus.cancelled;
      case 'rejected':   return BookingStatus.rejected;
      default:           return BookingStatus.pending;
    }
  }

  static String _statusToString(BookingStatus s) {
    switch (s) {
      case BookingStatus.accepted:    return 'confirmed';
      case BookingStatus.inProgress:  return 'in_progress';
      case BookingStatus.completed:   return 'completed';
      case BookingStatus.cancelled:   return 'cancelled';
      case BookingStatus.rejected:    return 'rejected';
      default:                        return 'pending';
    }
  }

  @override
  void dispose() {
    _chatChannel?.unsubscribe();
    _chatPollTimer?.cancel();
    super.dispose();
  }
}
