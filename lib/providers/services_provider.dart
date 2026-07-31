import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_model.dart';

class ServicesProvider extends ChangeNotifier {
  static final _sb = Supabase.instance.client;

  List<ServiceModel> _services = [];
  bool _loaded = false;
  bool _loading = false;
  RealtimeChannel? _channel;

  List<ServiceModel> get services => List.unmodifiable(_services);
  bool get loaded => _loaded;
  bool get loading => _loading;

  Future<void> fetch() async {
    if (_loaded || _loading) return;
    _loading = true;
    notifyListeners();

    try {
      final data = await _sb
          .from('services')
          .select('*')
          .eq('is_active', true)
          .order('name');

      _services = (data as List)
          .map((e) => ServiceModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _loaded = true;
    } catch (e) {
      debugPrint('ServicesProvider.fetch error: $e');
    }

    _loading = false;
    notifyListeners();
    _listenForChanges();
  }

  Future<void> refresh() async {
    _loaded = false;
    await fetch();
  }

  // Keeps the catalog in sync with admin edits (add/edit/deactivate a
  // service in the web dashboard) without requiring an app restart — mirrors
  // AppSettingsProvider._listenForChanges.
  void _listenForChanges() {
    if (_channel != null) return;
    _channel = _sb.channel('services_live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'services',
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
