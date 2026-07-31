import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory cache in front of the `get_public_avatar` RPC — every chat/bid/
/// profile screen was independently re-calling this RPC on every mount, even
/// for a user just viewed seconds ago (RLS blocks a direct cross-user
/// `.from('users')` read, so the RPC itself can't be skipped, only repeated
/// calls for the same id). Caches a null/empty result too, so a user with no
/// avatar isn't re-queried every time they're shown.
class AvatarCache {
  static final _db = Supabase.instance.client;
  static final Map<String, String?> _cache = {};

  static Future<String?> getAvatar(String userId) async {
    if (_cache.containsKey(userId)) return _cache[userId];
    try {
      final url = await _db.rpc('get_public_avatar', params: {'user_id': userId}) as String?;
      _cache[userId] = (url != null && url.isNotEmpty) ? url : null;
      return _cache[userId];
    } catch (_) {
      return null;
    }
  }

  /// Called after a user updates their own avatar, so the next view of
  /// their profile doesn't keep serving the stale cached URL.
  static void invalidate(String userId) => _cache.remove(userId);
}
