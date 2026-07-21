import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/error_helper.dart';
import '../models/service_request_model.dart';
import '../models/bid_model.dart';
import '../services/notify_service.dart';

const _kCloudName    = 'dbuhxbyq1';
const _kUploadPreset = 'servicehive_unsigned';

class RequestProvider extends ChangeNotifier {
  static final _db = Supabase.instance.client;

  // Same Cloudinary account/preset used everywhere else in the app (avatars,
  // KYC docs) — lets a customer attach a photo of the problem when posting a
  // service request.
  Future<String?> uploadRequestImage(Uint8List bytes, String filename) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$_kCloudName/auto/upload'),
      );
      req.fields['upload_preset'] = _kUploadPreset;
      req.fields['folder'] = 'service-requests';
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final resp = await req.send();
      if (resp.statusCode == 200) {
        final body = jsonDecode(await resp.stream.bytesToString());
        return body['secure_url'] as String;
      }
      debugPrint('Request image upload rejected: status=${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Request image upload failed: $e');
      return null;
    }
  }

  bool _loading = false;
  String? _error;
  bool get loading => _loading;
  String? get error => _error;

  // ── Customer ──────────────────────────────────────────────────────────────
  List<ServiceRequest> _myRequests = [];
  List<Bid> _bidsOnRequest = [];
  RealtimeChannel? _bidsChannel;

  List<ServiceRequest> get myRequests => List.unmodifiable(_myRequests);
  List<Bid> get bidsOnRequest => List.unmodifiable(_bidsOnRequest);

  // ── Provider ──────────────────────────────────────────────────────────────
  List<ServiceRequest> _availableRequests = [];
  RealtimeChannel? _availableReqChannel;

  List<ServiceRequest> get availableRequests => List.unmodifiable(_availableRequests);

  // Requests this provider has won (accepted_provider_id = them) — the "My
  // Jobs" tab. Separate from availableRequests (open requests they can bid
  // on) and separate from the old, disconnected `bookings` table that
  // ActiveJobsScreen used to read from and could never show anything real.
  List<ServiceRequest> _myProviderJobs = [];

  List<ServiceRequest> get myProviderJobs => List.unmodifiable(_myProviderJobs);

  Future<void> loadMyProviderJobs(String providerId, {bool silent = false}) async {
    try {
      if (!silent) { _loading = true; notifyListeners(); }
      final data = await _db
          .from('service_requests')
          .select()
          .eq('accepted_provider_id', providerId)
          .order('created_at', ascending: false);
      _myProviderJobs = (data as List)
          .map((j) => ServiceRequest.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('loadMyProviderJobs error: $e');
    }
    if (!silent) _loading = false;
    notifyListeners();
  }

  // ─────────────────────── Rating (customer rates a completed request) ────

  Future<bool> submitRating(String requestId, double rating, String review) async {
    try {
      await _db.from('service_requests').update({
        'rating': rating,
        'review': review,
      }).eq('id', requestId);

      final idx = _myRequests.indexWhere((r) => r.id == requestId);
      if (idx != -1) {
        _myRequests[idx] = _myRequests[idx].copyWith(rating: rating, review: review);
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('submitRating error: $e');
      return false;
    }
  }

  // ── Chat ──────────────────────────────────────────────────────────────────
  List<BidMessage> _messages = [];
  RealtimeChannel? _messagesChannel;
  Timer? _messagesPollTimer;

  List<BidMessage> get messages => List.unmodifiable(_messages);

  // ─────────────────────── Customer Methods ────────────────────────────────

  Future<bool> deleteRequest(String requestId, String customerId) async {
    try {
      await _db.from('service_requests').delete().eq('id', requestId).eq('customer_id', customerId).eq('status', 'open');
      _myRequests = _myRequests.where((r) => r.id != requestId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> createRequest({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String serviceName,
    required String description,
    required String city,
    required String area,
    required String address,
    double? latitude,
    double? longitude,
    String? imageUrl,
  }) async {
    try {
      _error = null;
      await _db.from('service_requests').insert({
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'service_name': serviceName,
        'description': description,
        'city': city,
        'area': area,
        'address': address,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (imageUrl != null) 'image_url': imageUrl,
        'status': 'open',
      });

      // Best-effort: notify online providers offering this service in the
      // customer's city so they see the new request without polling.
      try {
        final providers = await _db.from('provider_profiles')
            .select('id').eq('service_type', serviceName).eq('is_online', true);
        for (final p in (providers as List)) {
          NotifyService.notify(p['id'] as String?, 'New service request nearby', '$serviceName needed in $area, $city', type: 'booking');
        }
      } catch (_) { /* non-critical */ }

      await loadMyRequests(customerId);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadMyRequests(String customerId, {bool silent = false}) async {
    try {
      if (!silent) {
        _loading = true;
        notifyListeners();
      }
      final data = await _db
          .from('service_requests')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);
      _myRequests = data
          .map((j) => ServiceRequest.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      if (!silent) _loading = false;
      notifyListeners();
    }
  }

  Future<ServiceRequest?> fetchRequest(String requestId) async {
    try {
      final data = await _db
          .from('service_requests')
          .select()
          .eq('id', requestId)
          .single();
      return ServiceRequest.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadBidsForRequest(String requestId) async {
    try {
      final data = await _db
          .from('bids')
          .select()
          .eq('request_id', requestId)
          .order('price', ascending: true);
      _bidsOnRequest = (data as List)
          .map((j) => Bid.fromJson(j as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('loadBidsForRequest error: $e');
      _error = friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> subscribeToBids(String requestId) async {
    try { await _bidsChannel?.unsubscribe(); } catch (_) {}
    await loadBidsForRequest(requestId);

    _bidsChannel = _db
        .channel('bids_$requestId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bids',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'request_id',
            value: requestId,
          ),
          callback: (payload) {
            final bid = Bid.fromJson(payload.newRecord as Map<String, dynamic>);
            if (!_bidsOnRequest.any((b) => b.id == bid.id)) {
              _bidsOnRequest = [bid, ..._bidsOnRequest];
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bids',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'request_id',
            value: requestId,
          ),
          callback: (_) => loadBidsForRequest(requestId),
        )
        .subscribe();
  }

  Future<void> unsubscribeFromBids() async {
    await _bidsChannel?.unsubscribe();
    _bidsChannel = null;
    _bidsOnRequest = [];
    notifyListeners();
  }

  Future<bool> acceptBid({
    required String requestId,
    required String bidId,
    required String providerId,
    required String customerId,
  }) async {
    try {
      final otp = _generateOtp();

      // Fetch request + bid data before any updates (for booking creation)
      final reqData = await _db.from('service_requests').select().eq('id', requestId).maybeSingle();
      final bidData = await _db.from('bids').select().eq('id', bidId).maybeSingle();

      await _db.from('service_requests').update({
        'status': 'accepted',
        'accepted_bid_id': bidId,
        'accepted_provider_id': providerId,
        'otp_code': otp,
      }).eq('id', requestId);

      await _db.from('bids').update({'status': 'accepted'}).eq('id', bidId);
      await _db
          .from('bids')
          .update({'status': 'rejected'})
          .eq('request_id', requestId)
          .neq('id', bidId);

      // Create a booking record so it shows in both customer & provider booking lists
      if (reqData != null && bidData != null) {
        try {
          final serviceName = reqData['service_name'] as String? ?? '';
          String serviceIcon = 'Wrench';
          try {
            final svc = await _db
                .from('services')
                .select('icon')
                .ilike('name', serviceName)
                .maybeSingle();
            if (svc != null && svc['icon'] != null) serviceIcon = svc['icon'] as String;
          } catch (_) {}

          await _db.from('bookings').insert({
            'request_id':     requestId,
            'user_id':        customerId,
            'provider_id':    providerId,
            'service':        serviceName,
            'service_icon':   serviceIcon,
            'address':        reqData['address'] ?? '',
            'city':           reqData['city'] ?? '',
            'notes':          reqData['description'] ?? '',
            'scheduled_type': 'flexible',
            'price':          bidData['price'] ?? 0,
            'agreed_price':   bidData['price'] ?? 0,
            'status':         'confirmed',
          });
        } catch (e) {
          debugPrint('booking insert error (non-critical): $e');
        }
      }

      NotifyService.notify(providerId, 'Your bid was accepted!',
          "Your bid for ${reqData?['service_name'] ?? 'the'} request was accepted", type: 'booking');

      await loadMyRequests(customerId);
      await loadBidsForRequest(requestId);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String requestId,
    required String enteredOtp,
    required String customerId,
  }) async {
    try {
      final data = await _db
          .from('service_requests')
          .select('otp_code, accepted_provider_id, service_name')
          .eq('id', requestId)
          .single();

      final storedOtp = data['otp_code'] as String?;
      if (storedOtp == null || storedOtp != enteredOtp.trim()) return false;

      await _db.from('service_requests').update({
        'status': 'in_progress',
        'otp_verified': true,
      }).eq('id', requestId);

      NotifyService.notify(data['accepted_provider_id'] as String?, 'OTP verified',
          "Customer confirmed you've arrived for the ${data['service_name']} job. You can start work now.", type: 'booking');

      await loadMyRequests(customerId);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────── Provider Methods ────────────────────────────────

  Future<String?> fetchProviderServiceType(String providerId) async {
    try {
      final data = await _db
          .from('provider_profiles')
          .select('service_type')
          .eq('id', providerId)
          .single();
      return data['service_type'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadAvailableRequests({
    required String city,
    required String area,
    String? serviceType,
    bool silent = false,
  }) async {
    try {
      if (!silent) {
        _loading = true;
        notifyListeners();
      }

      final hasService = serviceType != null && serviceType.isNotEmpty;

      if (!hasService) {
        // No service type on the provider's profile — do not show requests
        // from unrelated categories. Force them to complete their profile
        // instead of leaking every open request in the city/area to them.
        _availableRequests = [];
        return;
      }

      final data = await _db
          .from('service_requests')
          .select()
          .eq('city', city)
          .eq('area', area)
          .ilike('service_name', '%$serviceType%')
          .eq('status', 'open')
          .order('created_at', ascending: false);

      _availableRequests = data
          .map((j) => ServiceRequest.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      if (!silent) _loading = false;
      notifyListeners();
    }
  }

  Future<void> subscribeToAvailableRequests({
    required String city,
    required String area,
    String? serviceType,
  }) async {
    await _availableReqChannel?.unsubscribe();

    final hasService = serviceType != null && serviceType.isNotEmpty;
    if (!hasService) {
      // No service type on the provider's profile — don't stream any
      // requests to them; matches the behavior of loadAvailableRequests.
      return;
    }

    _availableReqChannel = _db
        .channel('avail_req_${city}_${area}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'service_requests',
          callback: (payload) {
            final req = ServiceRequest.fromJson(
                payload.newRecord as Map<String, dynamic>);
            final serviceMatch =
                req.serviceName.toLowerCase().contains(serviceType.toLowerCase());
            if (req.city == city &&
                req.area == area &&
                serviceMatch &&
                req.status == 'open') {
              _availableRequests = [req, ..._availableRequests];
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  Future<void> unsubscribeFromAvailableRequests() async {
    await _availableReqChannel?.unsubscribe();
    _availableReqChannel = null;
  }

  Future<void> updateProviderLocation(String requestId, double lat, double lng) async {
    try {
      await _db.from('service_requests').update({
        'provider_lat': lat,
        'provider_lng': lng,
      }).eq('id', requestId);
    } catch (e) {
      debugPrint('updateProviderLocation error: $e');
    }
  }

  Future<bool> submitBid({
    required String requestId,
    required String providerId,
    required String providerName,
    required String providerPhone,
    required int price,
    required String message,
  }) async {
    try {
      await _db.from('bids').upsert(
        {
          'request_id': requestId,
          'provider_id': providerId,
          'provider_name': providerName,
          'provider_phone': providerPhone,
          'price': price,
          'message': message,
          'status': 'pending',
        },
        onConflict: 'request_id,provider_id',
      );

      try {
        final req = await _db.from('service_requests').select('customer_id, service_name').eq('id', requestId).maybeSingle();
        if (req != null) {
          NotifyService.notify(req['customer_id'] as String?, 'New bid received',
              '$providerName bid Rs $price on your ${req['service_name']} request', type: 'booking');
        }
      } catch (_) { /* non-critical */ }

      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<Bid?> getBidByProvider({
    required String requestId,
    required String providerId,
  }) async {
    try {
      final data = await _db
          .from('bids')
          .select()
          .eq('request_id', requestId)
          .eq('provider_id', providerId)
          .maybeSingle();
      if (data == null) return null;
      return Bid.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<List<ServiceRequest>> fetchProviderActiveJobs(String providerId) async {
    try {
      final data = await _db
          .from('service_requests')
          .select()
          .eq('accepted_provider_id', providerId)
          .inFilter('status', ['accepted', 'in_progress'])
          .order('created_at', ascending: false);
      return (data as List)
          .map((j) => ServiceRequest.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> markJobComplete(String requestId) async {
    try {
      await _db
          .from('service_requests')
          .update({'status': 'completed'})
          .eq('id', requestId)
          .eq('otp_verified', true);

      // Sync the linked booking (if any) via the real request_id FK.
      try {
        await _db
            .from('bookings')
            .update({'status': 'completed'})
            .eq('request_id', requestId)
            .inFilter('status', ['confirmed', 'in_progress']);
      } catch (_) {}

      try {
        final req = await _db.from('service_requests').select('customer_id, service_name').eq('id', requestId).maybeSingle();
        if (req != null) {
          NotifyService.notify(req['customer_id'] as String?, 'Job completed',
              "Your ${req['service_name']} request has been marked complete. Rate your experience!", type: 'booking');
        }
      } catch (_) { /* non-critical */ }

      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────── Chat Methods ─────────────────────────────────────

  Future<void> loadMessages(String bidId) async {
    try {
      final data = await _db
          .from('bid_messages')
          .select()
          .eq('bid_id', bidId)
          .order('created_at', ascending: true);
      _messages = (data as List)
          .map((j) => BidMessage.fromJson(j as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> subscribeToMessages(String bidId) async {
    await _messagesChannel?.unsubscribe();
    _messagesPollTimer?.cancel();
    await loadMessages(bidId);

    _messagesChannel = _db
        .channel('msg_$bidId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bid_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'bid_id',
            value: bidId,
          ),
          callback: (payload) {
            final msg = BidMessage.fromJson(payload.newRecord);
            _mergeMessage(msg);
          },
        )
        .subscribe();

    // Fallback poll: keeps the chat "live" even if Postgres Realtime
    // replication isn't enabled for this table, without needing a manual
    // refresh. Cheap since it only fetches rows newer than the last one.
    _messagesPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollNewMessages(bidId);
    });
  }

  Future<void> _pollNewMessages(String bidId) async {
    try {
      final since = _messages.isNotEmpty ? _messages.last.createdAt : null;
      var query = _db.from('bid_messages').select().eq('bid_id', bidId);
      if (since != null) {
        query = query.gt('created_at', since.toIso8601String());
      }
      final data = await query.order('created_at', ascending: true);
      for (final j in (data as List)) {
        _mergeMessage(BidMessage.fromJson(j as Map<String, dynamic>));
      }
    } catch (_) {
      // Silent: transient network hiccups shouldn't surface as chat errors.
    }
  }

  void _mergeMessage(BidMessage msg) {
    if (_messages.any((m) => m.id == msg.id)) return;
    _messages = [..._messages, msg]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();
  }

  Future<void> unsubscribeFromMessages() async {
    await _messagesChannel?.unsubscribe();
    _messagesChannel = null;
    _messagesPollTimer?.cancel();
    _messagesPollTimer = null;
    _messages = [];
    notifyListeners();
  }

  Future<bool> sendMessage({
    required String requestId,
    required String bidId,
    required String senderId,
    required String senderName,
    required String message,
    String? imageUrl,
  }) async {
    // Recipient must be resolved BEFORE the optimistic add (not after, like
    // the old post-insert-only lookup below used to do) so a blocked sender
    // never sees their own message appear then vanish — the block check
    // needs this id up front to short-circuit before anything is shown.
    String? recipientId;
    try {
      final bid = await _db.from('bids').select('provider_id').eq('id', bidId).maybeSingle();
      final req = await _db.from('service_requests').select('customer_id').eq('id', requestId).maybeSingle();
      final providerId = bid?['provider_id'] as String?;
      final customerId = req?['customer_id'] as String?;
      recipientId = senderId == providerId ? customerId : providerId;
    } catch (_) { /* recipient resolution is best-effort; block-check below just no-ops if unresolved */ }

    if (recipientId != null) {
      try {
        final blocked = await _db.rpc('is_blocked', params: {'blocker': recipientId, 'blocked': senderId}) as bool?;
        if (blocked == true) {
          _error = 'You can\'t message this user.';
          notifyListeners();
          return false;
        }
      } catch (_) { /* if the block check itself fails, don't block sending */ }
    }

    // Optimistic local message so the sender sees it instantly, like WhatsApp,
    // instead of waiting for the realtime round-trip.
    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = BidMessage(
      id: tempId,
      requestId: requestId,
      bidId: bidId,
      senderId: senderId,
      senderName: senderName,
      message: message,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
    );
    _messages = [..._messages, optimistic];
    notifyListeners();

    try {
      final inserted = await _db.from('bid_messages').insert({
        'request_id': requestId,
        'bid_id': bidId,
        'sender_id': senderId,
        'sender_name': senderName,
        'message': message,
        if (imageUrl != null) 'image_url': imageUrl,
      }).select().single();

      final real = BidMessage.fromJson(inserted);
      _messages = _messages.map((m) => m.id == tempId ? real : m).toList();
      notifyListeners();

      try {
        NotifyService.notify(recipientId, 'New message from $senderName', message, type: 'chat');
      } catch (_) { /* non-critical */ }

      return true;
    } catch (e) {
      _messages = _messages.where((m) => m.id != tempId).toList();
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────── Helpers ─────────────────────────────────────────

  String _generateOtp() {
    final rng = math.Random();
    return List.generate(6, (_) => rng.nextInt(10)).join();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _bidsChannel?.unsubscribe();
    _availableReqChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    _messagesPollTimer?.cancel();
    super.dispose();
  }
}
