import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

/// Real, DB-backed notifications — replaces the old in-memory-only list on
/// BookingProvider (which never persisted anything and reset on every app
/// restart). Reads/writes the same `notifications` table the React web app
/// uses, so events triggered from either app show up on both.
class NotificationsProvider extends ChangeNotifier {
  static final _db = Supabase.instance.client;

  List<NotificationModel> _items = [];
  bool _loading = false;
  RealtimeChannel? _channel;
  String? _userId;

  List<NotificationModel> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  int get unreadCount => _items.where((n) => !n.isRead).length;

  Future<void> init(String userId) async {
    if (_userId == userId && _channel != null) return;
    _userId = userId;
    await _load();
    _subscribe();
  }

  Future<void> _load() async {
    if (_userId == null) return;
    _loading = true;
    notifyListeners();
    try {
      final data = await _db
          .from('notifications')
          .select()
          .eq('user_id', _userId as Object)
          .order('created_at', ascending: false)
          .limit(50);
      _items = (data as List).map((n) => _fromRow(n as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('NotificationsProvider load error: $e');
    }
    _loading = false;
    notifyListeners();
  }

  void _subscribe() {
    if (_userId == null) return;
    _channel?.unsubscribe();
    _channel = _db.channel('notifications_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: _userId),
          callback: (payload) {
            final row = _fromRow(payload.newRecord);
            if (_items.any((n) => n.id == row.id)) return;
            _items = [row, ..._items];
            notifyListeners();
          },
        )
        .subscribe();
  }

  Future<void> markAllRead() async {
    if (_userId == null) return;
    for (final n in _items) { n.isRead = true; }
    notifyListeners();
    try {
      await _db.from('notifications').update({'is_read': true}).eq('user_id', _userId as Object).eq('is_read', false);
    } catch (e) {
      debugPrint('markAllRead error: $e');
    }
  }

  NotificationModel _fromRow(Map<String, dynamic> row) {
    final typeStr = row['type'] as String? ?? 'system';
    final type = NotifType.values.firstWhere((t) => t.name == typeStr, orElse: () => NotifType.system);
    return NotificationModel(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      type: type,
      time: DateTime.parse(row['created_at'] as String),
      isRead: row['is_read'] as bool? ?? false,
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
