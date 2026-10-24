import 'package:supabase_flutter/supabase_flutter.dart';

/// Triggers the `send-notification` Edge Function. E-mail credentials live
/// only on the server; without them the function logs a clearly labelled
/// SIMULATED e-mail instead of sending.
class NotificationService {
  NotificationService(this._c);
  final SupabaseClient _c;

  /// Never throws: a failed e-mail must not undo a booking decision.
  Future<String> notify(String requestId, String event) async {
    try {
      final res = await _c.functions
          .invoke('send-notification', body: {'request_id': requestId, 'event': event});
      final d = res.data;
      final mode = d is Map ? d['mode'] : null;
      if (mode == 'sent') return 'E-mail notification sent.';
      if (mode == 'simulated') {
        return 'E-mail notification SIMULATED (no mail credentials configured).';
      }
      return 'E-mail notification processed.';
    } catch (e) {
      return 'E-mail notification could not be sent.';
    }
  }
}
