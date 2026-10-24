import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns any thrown object into a short message that is safe to show users.
String friendlyError(Object e) {
  if (e is PostgrestException) {
    return e.message.isNotEmpty ? e.message : 'Database error (${e.code})';
  }
  if (e is AuthException) return e.message;
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] != null) return '${d['error']}';
    return 'Server function failed (${e.status})';
  }
  if (e is StorageException) return e.message;
  final s = e.toString();
  return s.startsWith('Exception: ') ? s.substring(11) : s;
}
