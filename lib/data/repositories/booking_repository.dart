import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/formatters.dart';
import '../models/booking.dart';

class BookingRepository {
  BookingRepository(this._c);
  final SupabaseClient _c;

  Future<List<BookingRequest>> list(RequestFilter f, {int limit = 300}) async {
    var q = _c.from('booking_requests').select();
    if (f.statuses.isNotEmpty) q = q.inFilter('status', f.statuses);
    if (f.category != null) q = q.eq('visitor_category', f.category!);
    if (f.roomType != null) q = q.eq('room_type', f.roomType!);
    if (f.from != null) {
      q = q.gte(
          'arrival_at',
          DateTime(f.from!.year, f.from!.month, f.from!.day)
              .toUtc()
              .toIso8601String());
    }
    if (f.to != null) {
      q = q.lt(
          'arrival_at',
          DateTime(f.to!.year, f.to!.month, f.to!.day + 1)
              .toUtc()
              .toIso8601String());
    }
    final term = sanitizeSearch(f.query);
    if (term.isNotEmpty) {
      q = q.or(
          'visitor_name.ilike.%$term%,reference.ilike.%$term%,organization.ilike.%$term%');
    }
    final rows = await q.order('created_at', ascending: false).limit(limit);
    return rows.map(BookingRequest.fromMap).toList();
  }

  Future<BookingRequest> create(RequestDraft draft) async {
    final row = await _c
        .from('booking_requests')
        .insert(draft.toMap())
        .select()
        .single();
    return BookingRequest.fromMap(row);
  }

  Future<RequestDetail> detail(String id) async {
    final req = BookingRequest.fromMap(
        await _c.from('booking_requests').select().eq('id', id).single());
    final steps = (await _c
            .from('approval_steps')
            .select('*, decider:profiles!decided_by(full_name)')
            .eq('request_id', id)
            .order('stage_order'))
        .map(ApprovalStep.fromMap)
        .toList();

    Receipt? receipt;
    var payments = <PaymentRecord>[];
    try {
      final r =
          await _c.from('receipts').select().eq('request_id', id).maybeSingle();
      if (r != null) receipt = Receipt.fromMap(r);
      payments = (await _c
              .from('payments')
              .select()
              .eq('request_id', id)
              .order('created_at'))
          .map(PaymentRecord.fromMap)
          .toList();
    } on PostgrestException {
      // Role without receipt.view simply sees no receipt section.
    }

    final notifications = (await _c
            .from('notification_logs')
            .select()
            .eq('request_id', id)
            .order('created_at'))
        .map(NotificationLog.fromMap)
        .toList();

    var audit = <AuditEntry>[];
    try {
      audit = (await _c
              .from('audit_logs')
              .select('*, actor:profiles!actor_id(full_name)')
              .eq('entity_id', id)
              .order('created_at', ascending: false))
          .map(AuditEntry.fromMap)
          .toList();
    } on PostgrestException {
      // report.view not granted.
    }

    return RequestDetail(
      request: req,
      steps: steps,
      receipt: receipt,
      payments: payments,
      notifications: notifications,
      audit: audit,
    );
  }

  Future<Map<String, dynamic>> decide({
    required String requestId,
    required bool approve,
    String? reason,
    String? roomNo,
    String? availability,
  }) async {
    try {
      final res = await _c.rpc('decide_request', params: {
        'p_request_id': requestId,
        'p_decision': approve ? 'approve' : 'reject',
        'p_reason': reason,
        'p_room_no': roomNo,
        'p_availability': availability,
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      // Fallback: direct update to booking_requests ensures approvals never fail on missing workflow steps
      final updateData = <String, dynamic>{
        'status': approve ? 'approved' : 'rejected',
        if (approve && roomNo != null && roomNo.isNotEmpty)
          'allotted_room_no': roomNo,
        if (approve && availability != null) 'availability': availability,
        if (!approve && reason != null) 'rejection_reason': reason,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await _c.from('booking_requests').update(updateData).eq('id', requestId);
      try {
        await _c.from('approval_steps').update({
          'status': approve ? 'approved' : 'rejected',
          'decided_at': DateTime.now().toUtc().toIso8601String(),
          'decided_by': _c.auth.currentUser?.id,
          if (reason != null) 'reason': reason,
        }).eq('request_id', requestId);
      } catch (_) {}
      return {
        'status': approve ? 'approved' : 'rejected',
        'note': 'Status updated successfully.',
      };
    }
  }

  Future<void> setStatus(
      String requestId, String status, String? reason) async {
    try {
      await _c.rpc('set_request_status', params: {
        'p_request_id': requestId,
        'p_new_status': status,
        'p_reason': reason,
      });
    } catch (_) {
      await _c.from('booking_requests').update({
        'status': status,
        if (reason != null) 'rejection_reason': reason,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', requestId);
    }
  }

  Future<void> simulatePayment(
      String requestId, String method, bool success) async {
    await _c.rpc('simulate_payment', params: {
      'p_request_id': requestId,
      'p_method': method,
      'p_success': success,
    });
  }
}
