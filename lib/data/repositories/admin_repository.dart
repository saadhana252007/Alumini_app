import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking.dart';
import '../models/profile.dart';
import '../models/tariff.dart';

class AdminRepository {
  AdminRepository(this._c);
  final SupabaseClient _c;

  Future<List<Profile>> profiles() async {
    final rows = await _c.from('profiles').select().order('full_name');
    return rows
        .where((m) => m['role'] != 'alumni')
        .map(Profile.fromMap)
        .toList();
  }

  Future<List<AlumniVerificationItem>> fetchAlumniVerifications(
      {String? status}) async {
    try {
      final rows = await _c
          .from('profiles')
          .select()
          .order('created_at', ascending: false);
      final allAlumni = rows
          .where(
              (m) => m['role'] == 'alumni' || m['verification_status'] != null)
          .map(AlumniVerificationItem.fromMap)
          .toList();

      if (status == null || status == 'all') {
        return allAlumni;
      }

      if (status == 'duplicates') {
        return allAlumni.where((item) =>
            item.possibleDuplicateOf != null ||
            item.duplicateReviewStatus == 'pending').toList();
      }

      return allAlumni.where((item) {
        final s = item.verificationStatus.trim().toLowerCase();
        if (status == 'pending') {
          return s == 'pending' || s.isEmpty;
        }
        return s == status.toLowerCase();
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> resolveDuplicate({
    required String profileId,
    required String action, // 'clear', 'merge', 'reject'
    String? masterProfileId,
  }) async {
    try {
      await _c.rpc('resolve_duplicate_review', params: {
        'p_profile_id': profileId,
        'p_action': action,
        'p_master_profile_id': masterProfileId,
      });
    } catch (_) {
      // Fallback direct updates if RPC not deployed yet
      if (action == 'clear') {
        await _c.from('profiles').update({
          'duplicate_review_status': 'cleared',
          'possible_duplicate_of': null,
        }).eq('id', profileId);
      } else if (action == 'reject') {
        await _c.from('profiles').update({
          'verification_status': 'rejected',
          'duplicate_review_status': 'cleared',
          'is_active': false,
        }).eq('id', profileId);
      } else if (action == 'merge' && masterProfileId != null) {
        await _c
            .from('booking_requests')
            .update({'created_by': masterProfileId}).eq('created_by', profileId);
        await _c
            .from('user_activity_log')
            .update({'user_id': masterProfileId}).eq('user_id', profileId);
        await _c
            .from('donation_intents')
            .update({'user_id': masterProfileId}).eq('user_id', profileId);
        await _c.from('profiles').update({
          'duplicate_review_status': 'merged',
          'is_active': false,
          'verification_status': 'rejected',
        }).eq('id', profileId);
      }
    }

    final me = _c.auth.currentUser?.id;
    if (me != null) {
      try {
        await _c.from('audit_logs').insert({
          'actor_id': me,
          'action': 'alumni.duplicate_resolved',
          'entity_table': 'profiles',
          'entity_id': profileId,
          'description': 'Duplicate resolution: $action. Master: ${masterProfileId ?? "none"}',
        });
      } catch (_) {}
    }
  }

  Future<List<AlumniClaimItem>> fetchAlumniClaims() async {
    try {
      final rows = await _c
          .from('alumni_claims')
          .select()
          .order('created_at', ascending: false);
      return (rows as List).map((m) => AlumniClaimItem.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> decideAlumniClaim({
    required String claimId,
    required bool approve,
    String? notes,
  }) async {
    final status = approve ? 'approved' : 'rejected';
    await _c.from('alumni_claims').update({
      'status': status,
      'admin_notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', claimId);

    final me = _c.auth.currentUser?.id;
    if (me != null) {
      try {
        await _c.from('audit_logs').insert({
          'actor_id': me,
          'action': 'alumni.claim_decided',
          'entity_table': 'alumni_claims',
          'entity_id': claimId,
          'description': 'Alumni admission claim marked $status. Notes: ${notes ?? "N/A"}',
        });
      } catch (_) {}
    }
  }

  Future<void> verifyAlumnus(String profileId,
      {required bool approve, String? notes}) async {
    final newStatus = approve ? 'verified' : 'rejected';
    await _c.from('profiles').update({
      'verification_status': newStatus,
      'is_active': approve,
    }).eq('id', profileId);

    try {
      final me = _c.auth.currentUser?.id;
      if (me != null) {
        await _c.from('audit_logs').insert({
          'actor_id': me,
          'action': 'alumni_verification',
          'entity_table': 'profiles',
          'entity_id': profileId,
          'description':
              'Alumnus profile verification marked as $newStatus. Notes: ${notes ?? "N/A"}',
        });
      }
    } catch (_) {}
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
      out
          .putIfAbsent(r['role'] as String, () => {})
          .add(r['permission'] as String);
    }
    return out;
  }

  Future<void> setPermission(
      String role, String permission, bool granted) async {
    if (granted) {
      await _c.from('role_permissions').upsert(
          {'role': role, 'permission': permission},
          ignoreDuplicates: true);
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
