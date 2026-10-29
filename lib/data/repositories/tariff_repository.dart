import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/json_helpers.dart';
import '../models/tariff.dart';

class TariffRepository {
  TariffRepository(this._c);
  final SupabaseClient _c;

  Future<List<TariffRule>> rules() async {
    final rows = await _c
        .from('tariff_rules')
        .select()
        .order('visitor_category')
        .order('sub_category')
        .order('room_type');
    return rows.map(TariffRule.fromMap).toList();
  }

  Future<double> gstPercent() async {
    final row = await _c
        .from('app_settings')
        .select('value')
        .eq('key', 'gst_percent')
        .maybeSingle();
    return parseNum(row?['value']) ?? 0;
  }

  Future<void> updateRule(String id,
      {double? rate,
      required String unit,
      required bool active,
      String? note}) async {
    await _c.from('tariff_rules').update({
      'rate': rate,
      'billing_unit': unit,
      'is_active': active,
      'note': note,
    }).eq('id', id);
  }

  Future<void> setGst(double percent) async {
    await _c.from('app_settings').upsert({
      'key': 'gst_percent',
      'value': percent,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
