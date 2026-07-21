import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Device-level network state (not app data loading) — drives the app-wide
/// "No Internet" overlay in main.dart. Separate from any Supabase/API call
/// state since this reflects the OS network signal directly, so the overlay
/// appears/disappears immediately on connect/disconnect rather than only
/// after some request happens to fail.
class ConnectivityProvider extends ChangeNotifier {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get isOffline => _isOffline;

  ConnectivityProvider() {
    _init();
  }

  Future<void> _init() async {
    final initial = await Connectivity().checkConnectivity();
    _apply(initial);
    _sub = Connectivity().onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (offline != _isOffline) {
      _isOffline = offline;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
