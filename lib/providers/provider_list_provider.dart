import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/provider_model.dart';
import '../services/avatar_cache.dart';

class ProviderListProvider extends ChangeNotifier {
  static final _sb = Supabase.instance.client;

  List<ProviderModel> _providers = [];
  bool    _isOnline = false;
  bool    _loaded   = false;
  bool    _loading  = false;
  String? _lastError;
  RealtimeChannel? _profilesChannel;
  Timer? _onlineTimer;

  bool              get isOnline  => _isOnline;
  bool              get loaded    => _loaded;
  bool              get loading   => _loading;
  String?           get lastError => _lastError;
  List<ProviderModel> get providers => List.unmodifiable(_providers);

  List<ProviderModel> byService(String serviceType) =>
      _providers.where((p) => p.serviceType.toLowerCase() == serviceType.toLowerCase()).toList();

  // Powers the customer home screen's "Top Providers" row. Ranked by rating
  // then total_jobs (tiebreaker), not just insertion order. Falls back to
  // ALL providers (not only those currently toggled online) so the section
  // isn't blank just because nobody happens to be online right now — a
  // provider being a good match is about their track record, not whether
  // they're online at this exact second.
  List<ProviderModel> topProviders({String? city, String? area, String? serviceType, int limit = 10}) {
    var list = _providers.where((p) {
      if (city != null && city.isNotEmpty && p.city.toLowerCase() != city.toLowerCase()) return false;
      if (area != null && area.isNotEmpty && p.area.toLowerCase() != area.toLowerCase()) return false;
      if (serviceType != null && serviceType.isNotEmpty && p.serviceType.toLowerCase() != serviceType.toLowerCase()) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      final byRating = b.rating.compareTo(a.rating);
      if (byRating != 0) return byRating;
      return b.totalJobs.compareTo(a.totalJobs);
    });

    return list.take(limit).toList();
  }

  List<ProviderModel> search(String query) {
    if (query.isEmpty) return _providers;
    final q = query.toLowerCase();
    return _providers.where((p) =>
        p.name.toLowerCase().contains(q)          ||
        p.serviceType.toLowerCase().contains(q)   ||
        p.skills.any((s) => s.toLowerCase().contains(q))).toList();
  }

  ProviderModel? getById(String id) {
    try { return _providers.firstWhere((p) => p.id == id); }
    catch (_) { return null; }
  }

  // ─── Fetch providers from Supabase ───────────────────────────────────────

  Future<void> fetch() async {
    if (_loaded || _loading) return;
    _loading = true;
    notifyListeners();

    try {
      // Join users (role=provider) with their provider_profiles
      final data = await _sb
          .from('users')
          .select('id, name, phone, city, area, show_phone, show_email, provider_profiles(*)')
          .eq('role', 'provider')
          // providers waiting for the admin's approval are not shown to customers
          .eq('is_verified', true);

      _providers = (data as List).map((e) => _rowToModel(e as Map<String, dynamic>)).toList();
      _loaded = true;
      _lastError = null;
    } catch (e) {
      debugPrint('ProviderListProvider.fetch error: $e');
      _lastError = e.toString();
      // Leave _providers empty — screens show empty state instead of crashing
    }

    _loading = false;
    notifyListeners();

    _loadAvatars();
    _subscribeToLiveUpdates();
    _onlineTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      var changed = false;
      for (final p in _providers) {
        if (p.refreshOnline()) changed = true;
      }
      if (changed) notifyListeners();
    });
  }

  Future<void> refresh() async {
    _loaded = false;
    await fetch();
  }

  // Avatars aren't in the users/provider_profiles select above — AvatarCache
  // is the same per-user cached lookup every other profile screen already
  // uses, so this doesn't duplicate a fetch path, just runs it for the whole
  // list once after it loads.
  Future<void> _loadAvatars() async {
    for (final p in _providers) {
      final url = await AvatarCache.getAvatar(p.id);
      if (url != null && url != p.avatarUrl) {
        p.avatarUrl = url;
        notifyListeners();
      }
    }
  }

  // Keeps is_online and rating/jobs live while the app is open, instead of
  // only ever reflecting whatever was true the one time fetch() ran —
  // matches the realtime behavior the individual profile-view screens
  // already have.
  void _subscribeToLiveUpdates() {
    _profilesChannel ??= _sb
        .channel('provider_list_profiles')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'provider_profiles',
          callback: (payload) {
            final row = payload.newRecord;
            final idx = _providers.indexWhere((p) => p.id == row['id']);
            if (idx == -1) return;
            final p = _providers[idx];
            p.switchedOn = row['is_online'] as bool? ?? p.switchedOn;
            p.lastSeenAt = DateTime.tryParse(row['last_seen_at'] as String? ?? '') ?? p.lastSeenAt;
            p.rating = (row['rating'] as num?)?.toDouble() ?? p.rating;
            p.totalJobs = (row['total_jobs'] as num?)?.toInt() ?? p.totalJobs;
            p.reviewCount = (row['review_count'] as num?)?.toInt() ?? p.reviewCount;
            p.refreshOnline();
            notifyListeners();
          },
        )
        .subscribe();
  }

  // ─── Load current online status from DB on app start ─────────────────────

  Future<void> initMyOnlineStatus(String providerId) async {
    try {
      final data = await _sb
          .from('provider_profiles')
          .select('is_online')
          .eq('id', providerId)
          .maybeSingle();
      _isOnline = data?['is_online'] as bool? ?? false;
      notifyListeners();
    } catch (_) {}
  }

  // ─── Toggle own online/offline status ────────────────────────────────────

  Future<void> toggleMyOnline(String providerId) async {
    if (providerId.isEmpty) return;
    final newStatus = !_isOnline;
    _isOnline = newStatus;
    notifyListeners();

    try {
      // upsert handles both: row exists (update) and row missing (insert)
      final result = await _sb
          .from('provider_profiles')
          .upsert(
            {'id': providerId, 'is_online': newStatus},
            onConflict: 'id',
          )
          .select('id, is_online');

      if (result.isEmpty) {
        // RLS blocked the operation — revert local state
        debugPrint('toggleMyOnline: DB update blocked (check RLS policy on provider_profiles)');
        _isOnline = !newStatus;
        notifyListeners();
      } else {
        // Confirm from DB what the actual value is
        final saved = result.first['is_online'] as bool? ?? newStatus;
        if (saved != newStatus) {
          _isOnline = saved;
          notifyListeners();
        }
        debugPrint('toggleMyOnline: is_online set to $saved in DB');
      }
    } catch (e) {
      debugPrint('toggleMyOnline error: $e');
      _isOnline = !newStatus;
      notifyListeners();
    }
  }

  // Keep the original no-arg version for screens that call it without a userId
  void toggleOnline(String providerId) {
    final idx = _providers.indexWhere((p) => p.id == providerId);
    if (idx != -1) {
      _providers[idx].isOnline = !_providers[idx].isOnline;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_profilesChannel != null) _sb.removeChannel(_profilesChannel!);
    _onlineTimer?.cancel();
    super.dispose();
  }

  // ─── Row mapping (public — reused by ProviderProfileScreen's direct-fetch
  // fallback when a provider isn't in the already-cached _providers list,
  // e.g. reached via a deep link or before .fetch() has run) ───────────────

  static ProviderModel rowToModel(Map<String, dynamic> r) => _rowToModel(r);

  static ProviderModel _rowToModel(Map<String, dynamic> r) {
    // provider_profiles usually comes back as a list (one-to-one embed), but
    // Postgrest returns it as a bare object instead for some rows — casting
    // straight to List crashed with "type '_Map<String, dynamic>' is not a
    // subtype of type 'List<dynamic>?'" for any provider hitting that shape,
    // which is what made the whole list fetch fail. Handle both.
    final rawProfiles = r['provider_profiles'];
    final Map<String, dynamic> p;
    if (rawProfiles is List) {
      p = rawProfiles.isNotEmpty ? rawProfiles.first as Map<String, dynamic> : <String, dynamic>{};
    } else if (rawProfiles is Map) {
      p = rawProfiles as Map<String, dynamic>;
    } else {
      p = <String, dynamic>{};
    }

    final rawSkills = p['skills'];
    final skills = rawSkills is List
        ? List<String>.from(rawSkills)
        : <String>[];

    return ProviderModel(
      id:            r['id']                             as String,
      name:          r['name']                           as String? ?? 'Provider',
      phone:         r['phone']                          as String? ?? '',
      email:         r['email']                          as String?,
      city:          r['city']                           as String? ?? '',
      area:          r['area']                           as String? ?? '',
      serviceType:   p['service_type']                   as String? ?? '',
      serviceIcon:   p['service_icon']                   as String? ?? '',
      skills:        skills,
      rating:        (p['rating']        as num?)?.toDouble() ?? 0.0,
      totalJobs:     (p['total_jobs']    as num?)?.toInt()    ?? 0,
      totalEarnings: (p['total_earnings'] as num?)?.toDouble() ?? 0.0,
      isOnline:      ProviderModel.onlineNow(p['is_online'] as bool? ?? false, DateTime.tryParse(p['last_seen_at'] as String? ?? '')),
      switchedOn:    p['is_online']                      as bool?   ?? false,
      lastSeenAt:    DateTime.tryParse(p['last_seen_at'] as String? ?? ''),
      experience:    p['experience']                     as String? ?? '',
      about:         p['about']                          as String? ?? '',
      reviewCount:   (p['review_count']  as num?)?.toInt()    ?? 0,
      ratePerHour:   (p['rate_per_hour'] as num?)?.toDouble() ?? 0.0,
      showPhone:     r['show_phone']    as bool? ?? true,
      showEmail:     r['show_email']    as bool? ?? true,
    );
  }
}
