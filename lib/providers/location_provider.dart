import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
const _kLocBase = kBaseUrl;

class LocationProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _locations = [];
  bool _loading = false;
  bool _loaded  = false;
  String? _error;

  bool   get loading => _loading;
  bool   get loaded  => _loaded;
  String? get error  => _error;

  List<String> get cities =>
      _locations.map((l) => l['city'] as String).toList();

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
      final res = await http
          .get(Uri.parse('$_kLocBase/locations'))
          .timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        _locations = List<Map<String, dynamic>>.from(data['data'] as List);
        _loaded    = true;
      } else {
        _error = data['message'] as String? ?? 'Failed to load locations';
      }
    } catch (_) {
      _error = 'Could not load cities. Check your connection.';
    }

    _loading = false;
    notifyListeners();
  }

  // Force re-fetch (pull to refresh)
  Future<void> refresh() async {
    _loaded = false;
    await fetch();
  }
}
