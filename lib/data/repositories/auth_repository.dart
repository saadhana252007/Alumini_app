import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class AuthRepository {
  AuthRepository(this._c);
  final SupabaseClient _c;

  Future<void> signIn(String email, String password) =>
      _c.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _c.auth.signOut();

  /// Returns null when nobody is signed in OR the account has no active
  /// administrator profile (public sign-up never creates one).
  Future<AdminSession?> loadSession() async {
    final user = _c.auth.currentUser;
    if (user == null) return null;
    final row =
        await _c.from('profiles').select().eq('id', user.id).maybeSingle();
    if (row == null || row['is_active'] != true) return null;
    final perms = await _c
        .from('role_permissions')
        .select('permission')
        .eq('role', row['role'] as String);
    return AdminSession(
      profile: Profile.fromMap(row),
      permissions: {for (final p in perms) p['permission'] as String},
    );
  }
}
