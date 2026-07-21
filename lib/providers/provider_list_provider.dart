import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/provider_model.dart';

class ProviderListProvider extends ChangeNotifier {
  static final _sb = Supabase.instance.client;

  List<ProviderModel> _providers = [];
  bool    _isOnline = false;
  bool    _loaded   = false;
  bool    _loading  = false;

  bool              get isOnline  => _isOnline;
  bool              get loaded    => _loaded;
  bool              get loading   => _loading;
  List<ProviderModel> get providers => List.unmodifiable(_providers);

  List<ProviderModel> byService(String serviceType) =>
      _providers.where((p) => p.serviceType.toLowerCase() == serviceType.toLowerCase()).toList();

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
          .select('id, name, phone, city, area, provider_profiles(*)')
          .eq('role', 'provider');

      _providers = (data as List).map((e) => _rowToModel(e as Map<String, dynamic>)).toList();
      _loaded = true;
    } catch (e) {
      debugPrint('ProviderListProvider.fetch error: $e');
      // Leave _providers empty — screens show empty state instead of crashing
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _loaded = false;
    await fetch();
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

  // ─── Row mapping (public — reused by ProviderProfileScreen's direct-fetch
  // fallback when a provider isn't in the already-cached _providers list,
  // e.g. reached via a deep link or before .fetch() has run) ───────────────

  static ProviderModel rowToModel(Map<String, dynamic> r) => _rowToModel(r);

  static ProviderModel _rowToModel(Map<String, dynamic> r) {
    // provider_profiles is returned as a list (one-to-one) — take first or null
    final profiles = r['provider_profiles'] as List?;
    final p        = (profiles != null && profiles.isNotEmpty)
        ? profiles.first as Map<String, dynamic>
        : <String, dynamic>{};

    final rawSkills = p['skills'];
    final skills = rawSkills is List
        ? List<String>.from(rawSkills)
        : <String>[];

    return ProviderModel(
      id:            r['id']                             as String,
      name:          r['name']                           as String? ?? 'Provider',
      phone:         r['phone']                          as String? ?? '',
      city:          r['city']                           as String? ?? '',
      area:          r['area']                           as String? ?? '',
      serviceType:   p['service_type']                   as String? ?? '',
      serviceIcon:   p['service_icon']                   as String? ?? '',
      skills:        skills,
      rating:        (p['rating']        as num?)?.toDouble() ?? 0.0,
      totalJobs:     (p['total_jobs']    as num?)?.toInt()    ?? 0,
      totalEarnings: (p['total_earnings'] as num?)?.toDouble() ?? 0.0,
      isOnline:      p['is_online']                      as bool?   ?? false,
      experience:    p['experience']                     as String? ?? '',
      about:         p['about']                          as String? ?? '',
      reviewCount:   (p['review_count']  as num?)?.toInt()    ?? 0,
      ratePerHour:   (p['rate_per_hour'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
