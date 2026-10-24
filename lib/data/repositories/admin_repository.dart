import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking.dart';
import '../models/profile.dart';
import '../models/tariff.dart';

class AdminRepository {
  AdminRepository(this._c);
  final SupabaseClient _c;

  Future<List<Profile>> profiles() async {
    final rows = await _c.from('profiles').select().order('full_name');
    return rows.map(Profile.fromMap).toList();
  }

  Future<void> updateProfile(String id, {String? role, bool? isActive}) async {
    final values = <String, dynamic>{
      if (role != null) 'role': role,
      if (isActive != null) 'is_active': isActive,
    };
    if (values.isEmpty) return;
    await _c.from('profiles').update(values).eq('id', id);
  }

  /// Account creation needs the service-role key, so it runs inside the
  /// `admin-create-user` Edge Function, which re-checks `admin.manage`.
  Future<void> createAdmin({
    required String email,
    required String fullName,
    required String role,
    required String password,
  }) async {
    final res = await _c.functions.invoke('admin-create-user', body: {
      'email': email,
      'full_name': fullName,
      'role': role,
      'password': password,
    });
    final d = res.data;
    if (d is Map && d['error'] != null) throw Exception('${d['error']}');
  }

  Future<Map<String, Set<String>>> rolePermissions() async {
    final rows = await _c.from('role_permissions').select();
    final out = <String, Set<String>>{
      'edc_admin': {},
      'dean_admin': {},
      'super_admin': {},
    };
    for (final r in rows) {
      out.putIfAbsent(r['role'] as String, () => {}).add(r['permission'] as String);
    }
    return out;
  }

  Future<void> setPermission(String role, String permission, bool granted) async {
    if (granted) {
      await _c
          .from('role_permissions')
          .upsert({'role': role, 'permission': permission}, ignoreDuplicates: true);
    } else {
      await _c
          .from('role_permissions')
          .delete()
          .eq('role', role)
          .eq('permission', permission);
    }
  }

  Future<List<ApprovalStage>> workflows() async {
    final rows = await _c
        .from('approval_workflows')
        .select()
        .order('room_type')
        .order('stage_order');
    return rows.map(ApprovalStage.fromMap).toList();
  }

  Future<void> saveStage({
    String? id,
    required String roomType,
    required int order,
    required String name,
    required String authority,
    required String role,
    required bool active,
  }) async {
    final values = {
      'room_type': roomType,
      'stage_order': order,
      'stage_name': name,
      'authority_label': authority,
      'approver_role': role,
      'is_active': active,
    };
    if (id == null) {
      await _c.from('approval_workflows').insert(values);
    } else {
      await _c.from('approval_workflows').update(values).eq('id', id);
    }
  }

  Future<void> deleteStage(String id) async {
    await _c.from('approval_workflows').delete().eq('id', id);
  }

  Future<List<AuditEntry>> audit({int limit = 100}) async {
    final rows = await _c
        .from('audit_logs')
        .select('*, actor:profiles!actor_id(full_name)')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(AuditEntry.fromMap).toList();
  }
}
