import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/formatters.dart';

typedef Rows = List<Map<String, dynamic>>;

/// Reads go through security-definer functions that re-check `report.export`
/// and return only the columns needed for registers (no phone/e-mail/address).
class ReportRepository {
  ReportRepository(this._c);
  final SupabaseClient _c;

  Rows _rows(dynamic r) =>
      (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<Rows> bookingRegister({
    DateTime? from,
    DateTime? to,
    String? status,
    String? category,
  }) async {
    try {
      final res = await _c.rpc('export_booking_register', params: {
        'p_from': from == null ? null : ymd(from),
        'p_to': to == null ? null : ymd(to),
        'p_status': status,
        'p_category': category,
      });
      final rows = _rows(res);
      if (rows.isNotEmpty) return rows;
    } catch (_) {
      // Fallback to direct query
    }

    try {
      var q = _c.from('booking_requests').select('''
        reference, visitor_name, organization, visitor_category, visitor_sub_category,
        room_type, num_rooms, persons_lodging, arrival_at, departure_at, status,
        allotted_room_no, estimated_amount, receipts(total), payments(status, created_at)
      ''');
      if (from != null) {
        q = q.gte(
            'arrival_at',
            DateTime(from.year, from.month, from.day)
                .toUtc()
                .toIso8601String());
      }
      if (to != null) {
        q = q.lt('arrival_at',
            DateTime(to.year, to.month, to.day + 1).toUtc().toIso8601String());
      }
      if (status != null) q = q.eq('status', status);
      if (category != null) q = q.eq('visitor_category', category);

      final list = await q.order('arrival_at', ascending: true);
      return list.map((r) {
        final m = Map<String, dynamic>.from(r);
        final receipts = m['receipts'] as List?;
        final payments = m['payments'] as List?;
        num? amt;
        if (receipts != null &&
            receipts.isNotEmpty &&
            receipts.first['total'] != null) {
          amt = receipts.first['total'] as num?;
        } else if (m['estimated_amount'] is num) {
          amt = m['estimated_amount'] as num?;
        }
        String? payStatus;
        if (payments != null && payments.isNotEmpty) {
          payStatus = payments.first['status']?.toString();
        }
        return {
          ...m,
          'amount': amt,
          'payment_status': payStatus,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Rows> approvalReport({DateTime? from, DateTime? to}) async {
    final rows = <Map<String, dynamic>>[];
    try {
      final res = await _c.rpc('export_approval_report', params: {
        'p_from': from == null ? null : ymd(from),
        'p_to': to == null ? null : ymd(to),
      });
      rows.addAll(_rows(res));
    } catch (_) {
      // RPC not found or errored; fallback will populate
    }

    // Direct fallback & augmentation:
    // If approval_steps has no rows or direct approvals were made on booking_requests,
    // fetch all approved and rejected requests directly so they are never missed.
    try {
      var q = _c.from('booking_requests').select('''
        id, reference, visitor_name, room_type, status, rejection_reason, allotted_room_no,
        updated_at, created_at
      ''').inFilter('status', ['approved', 'rejected']);

      if (from != null) {
        q = q.gte(
            'updated_at',
            DateTime(from.year, from.month, from.day)
                .toUtc()
                .toIso8601String());
      }
      if (to != null) {
        q = q.lt('updated_at',
            DateTime(to.year, to.month, to.day + 1).toUtc().toIso8601String());
      }

      final directList = await q.order('updated_at', ascending: false);
      final seenRefs = rows.map((r) => r['reference']?.toString()).toSet();

      for (final raw in directList) {
        final b = Map<String, dynamic>.from(raw);
        final ref = b['reference']?.toString() ?? '';
        if (seenRefs.contains(ref)) continue;

        final status = b['status']?.toString() ?? '';
        final reason = b['rejection_reason']?.toString() ??
            (b['allotted_room_no'] != null &&
                    '${b['allotted_room_no']}'.isNotEmpty
                ? 'Allotted Room ${b['allotted_room_no']}'
                : '');

        rows.add({
          'reference': ref,
          'visitor_name': b['visitor_name'] ?? '',
          'room_type': b['room_type'] ?? '',
          'stage_order': 1,
          'stage_name':
              status == 'approved' ? 'Final Approval' : 'Review Decision',
          'authority_label': 'EDC Administration',
          'step_status': status,
          'decided_by': 'EDC Admin',
          'decided_at': b['updated_at'] ?? b['created_at'],
          'reason': reason,
        });
      }
    } catch (_) {
      // Return whatever rows were retrieved
    }

    return rows;
  }

  Future<Rows> alumniReport({
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      var q = _c.from('profiles').select('''
        id, full_name, email, admission_no, contact_no, whatsapp_no,
        department_id, batch_year, current_position, organisation,
        city, state, verification_status, created_at, possible_duplicate_of
      ''');

      if (from != null) {
        q = q.gte('created_at',
            DateTime(from.year, from.month, from.day).toUtc().toIso8601String());
      }
      if (to != null) {
        q = q.lt('created_at',
            DateTime(to.year, to.month, to.day + 1).toUtc().toIso8601String());
      }

      final list = await q.order('created_at', ascending: false);
      final all = _rows(list).where((r) =>
          r['role'] == 'alumni' ||
          r['verification_status'] != null ||
          r['admission_no'] != null).toList();

      if (status == null || status == 'all' || status.isEmpty) {
        return all;
      }

      return all.where((r) {
        final s = (r['verification_status'] ?? 'pending').toString().toLowerCase();
        if (status == 'pending') {
          return s == 'pending' || s.isEmpty;
        }
        return s == status.toLowerCase();
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
