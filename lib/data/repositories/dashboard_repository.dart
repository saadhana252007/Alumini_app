import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking.dart';

class DashboardRepository {
  DashboardRepository(this._c);
  final SupabaseClient _c;

  Future<Map<String, int>> stats() async {
    final res = await _c.rpc('dashboard_stats');
    final m = Map<String, dynamic>.from(res as Map);
    return m.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  Future<List<BookingRequest>> upcomingArrivals({int limit = 5}) async {
    final rows = await _c
        .from('booking_requests')
        .select()
        .eq('status', RequestStatus.approved)
        .gte('arrival_at', DateTime.now().toUtc().toIso8601String())
        .order('arrival_at')
        .limit(limit);
    return rows.map(BookingRequest.fromMap).toList();
  }

  Future<List<AuditEntry>> recentActivity({int limit = 8}) async {
    final rows = await _c
        .from('audit_logs')
        .select('*, actor:profiles!actor_id(full_name)')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(AuditEntry.fromMap).toList();
  }
}
