import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers.dart';
import '../core/utils/errors.dart';
import '../data/models/profile.dart';
import 'busy.dart';

final sessionProvider =
    AsyncNotifierProvider<SessionViewModel, AdminSession?>(SessionViewModel.new);

class SessionViewModel extends AsyncNotifier<AdminSession?> {
  StreamSubscription<AuthState>? _sub;

  @override
  Future<AdminSession?> build() async {
    final client = ref.watch(supabaseClientProvider);
    await _sub?.cancel();
    _sub = client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        state = const AsyncData(null);
      }
    });
    ref.onDispose(() => _sub?.cancel());
    try {
      return await ref.read(authRepositoryProvider).loadSession();
    } catch (_) {
      return null;
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> signIn(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.signIn(email, password);
      final session = await repo.loadSession();
      if (session == null) {
        await repo.signOut();
        state = const AsyncData(null);
        return 'This account is not an active administrator account. '
            'Administrator accounts are created by the Super Admin.';
      }
      state = AsyncData(session);
      return null;
    } catch (e) {
      state = const AsyncData(null);
      return friendlyError(e);
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }
}

class LoginViewModel extends BusyNotifier {
  Future<Outcome> submit(String email, String password) => run(() async {
        final err =
            await ref.read(sessionProvider.notifier).signIn(email.trim(), password);
        if (err != null) throw Exception(err);
        return null;
      });
}

final loginViewModelProvider =
    NotifierProvider<LoginViewModel, BusyState>(LoginViewModel.new);

extension PermissionX on WidgetRef {
  AdminSession? get session => watch(sessionProvider).valueOrNull;
  bool can(String permission) => session?.can(permission) ?? false;
}
