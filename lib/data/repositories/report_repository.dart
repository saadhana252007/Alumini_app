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
    final res = await _c.rpc('export_booking_register', params: {
      'p_from': from == null ? null : ymd(from),
      'p_to': to == null ? null : ymd(to),
      'p_status': status,
      'p_category': category,
    });
    return _rows(res);
  }

  Future<Rows> approvalReport({DateTime? from, DateTime? to}) async {
    final res = await _c.rpc('export_approval_report', params: {
      'p_from': from == null ? null : ymd(from),
      'p_to': to == null ? null : ymd(to),
    });
    return _rows(res);
  }
}
