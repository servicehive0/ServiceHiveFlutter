import 'package:supabase_flutter/supabase_flutter.dart';

/// Fire-and-forget notification insert — mirrors the React web app's
/// src/lib/notify.js so both apps write to the same `notifications` table
/// and notifications sync across web/mobile regardless of which app
/// triggered the event. Failures are swallowed: a failed notification must
/// never block the real action (bid, accept, complete, chat) it's attached to.
class NotifyService {
  static Future<void> notify(String? userId, String title, String body, {String type = 'system', String? bidId, String? requestId}) async {
    if (userId == null || userId.isEmpty) return;
    try {
      await Supabase.instance.client.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        if (bidId != null) 'bid_id': bidId,
        if (requestId != null) 'request_id': requestId,
      });
    } catch (_) {
      // best-effort
    }
  }
}
