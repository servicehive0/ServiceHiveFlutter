import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationProvider extends ChangeNotifier {
  static final _sb = Supabase.instance.client;

  List<Map<String, dynamic>> _locations = [];
  bool    _loading = false;
  bool    _loaded  = false;
  String? _error;
  RealtimeChannel? _channel;

  bool    get loading => _loading;
  bool    get loaded  => _loaded;
  String? get error   => _error;

  List<String> get cities {
    final seen = <String>{};
    return _locations
        .map((l) => l['city'] as String)
        .where((c) => seen.add(c))
        .toList();
  }

  List<String> areasFor(String city) {
    try {
      final loc = _locations.firstWhere((l) => l['city'] == city);
      return List<String>.from(loc['areas'] as List? ?? []);
    } catch (_) {
      return [];
    }
  }

  Future<void> fetch() async {
    if (_loaded || _loading) return;
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      // Fetch locations joined with their areas in one round-trip
      final data = await _sb
          .from('locations')
          .select('id, city, location_areas(area)')
          .order('city');

      _locations = (data as List).map((loc) {
        final areaRows = loc['location_areas'] as List? ?? [];
        return {
          '_id':   loc['id']   as String,
          'city':  loc['city'] as String,
          'areas': areaRows.map((a) => a['area'] as String).toList(),
        };
      }).toList();

      _loaded = true;
    } catch (e) {
      _error = 'Could not load cities. Check your connection.';
      debugPrint('LocationProvider.fetch error: $e');
    }

    _loading = false;
    notifyListeners();
    _listenForChanges();
  }

  // Force re-fetch (pull-to-refresh)
  Future<void> refresh() async {
    _loaded = false;
    await fetch();
  }

  // Keeps cities/areas in sync with admin edits (add/remove a city or area
  // in the web dashboard) without requiring an app restart — mirrors
  // AppSettingsProvider._listenForChanges. Watches both tables since an
  // area-only edit doesn't touch the parent `locations` row.
  void _listenForChanges() {
    if (_channel != null) return;
    _channel = _sb.channel('locations_live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'locations',
          callback: (_) => refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'location_areas',
          callback: (_) => refresh(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) _sb.removeChannel(_channel!);
    super.dispose();
  }
}
