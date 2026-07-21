import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Must be a top-level (or static) function — background messages are
/// handled in a separate isolate that never sees this app's normal state,
/// so this can only do isolate-safe work (nothing here needs to touch the
/// UI; the OS already shows the notification banner from the FCM payload
/// itself when the app is killed/backgrounded).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {}

/// Real phone-level push notifications, on top of the existing in-app
/// realtime list (NotificationsProvider). That path already shows new
/// notifications instantly while the app is open; this service only fills
/// the gap where the app is fully closed and nothing in Dart is running to
/// notice a new `notifications` row — the OS/Firebase does that instead,
/// triggered server-side by a Supabase Edge Function (see
/// supabase/functions/send-push).
class PushService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifs = FlutterLocalNotificationsPlugin();
  static GoRouter? _router;
  static bool _initialized = false;

  static Future<void> initBackgroundHandler() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  }

  /// Called once from the top-level app widget so tap-handling can navigate.
  static Future<void> init(GoRouter router) async {
    _router = router;
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifs.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        _handleTapData(jsonDecode(payload) as Map<String, dynamic>);
      },
    );

    // Foreground FCM messages don't show a system banner on their own —
    // show one via local notifications so it's consistent with what the
    // user sees when the app is backgrounded/killed.
    FirebaseMessaging.onMessage.listen((message) {
      final notif = message.notification;
      if (notif == null) return;
      _localNotifs.show(
        message.hashCode,
        notif.title,
        notif.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'servicehive_default',
            'ServiceHive Notifications',
            channelDescription: 'Bids, bookings, chat messages and account updates',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });

    // Tapped a notification while the app was backgrounded (not killed).
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTapData(message.data));

    // App was fully killed and opened via tapping the notification.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleTapData(initialMessage.data);
  }

  static void _handleTapData(Map<String, dynamic> data) {
    if (_router == null) return;
    // Chat deep-linking needs the other party's display name (a required
    // route param) which isn't in the push payload — rather than
    // reconstructing that with an extra lookup, every notification tap
    // opens the Notifications screen, matching what tapping a notification
    // inside the app already does today.
    _router!.push('/notifications');
  }

  /// Requests permission (a no-op if already granted; required on Android 13+
  /// and iOS) and upserts this device's token onto the user's row, mirroring
  /// the existing avatar_url update pattern in AuthProvider.
  static Future<void> registerToken(String userId) async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await _messaging.getToken();
      if (token == null) return;
      await Supabase.instance.client.from('users').update({'fcm_token': token}).eq('id', userId);

      // Re-register if the token rotates while logged in (FCM tokens can
      // change, e.g. after an app reinstall or long idle period).
      _messaging.onTokenRefresh.listen((newToken) {
        Supabase.instance.client.from('users').update({'fcm_token': newToken}).eq('id', userId).then((_) {}, onError: (_) {});
      });
    } catch (e) {
      debugPrint('PushService.registerToken error: $e');
    }
  }

  /// Clears this device's token so a logged-out device stops receiving
  /// pushes meant for the account that was signed out of it.
  static Future<void> clearToken(String userId) async {
    try {
      await Supabase.instance.client.from('users').update({'fcm_token': null}).eq('id', userId);
    } catch (_) {
      // best-effort
    }
  }
}
