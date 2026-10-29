import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../data/models/booking.dart';
import '../data/models/profile.dart';
import '../data/models/tariff.dart';
import 'busy.dart';

final profilesProvider = FutureProvider.autoDispose<List<Profile>>(
    (ref) => ref.watch(adminRepositoryProvider).profiles());

final alumniFilterStatusProvider = StateProvider<String>((ref) => 'pending');

final alumniVerificationsProvider =
    FutureProvider.autoDispose<List<AlumniVerificationItem>>((ref) {
  final status = ref.watch(alumniFilterStatusProvider);
  return ref
      .watch(adminRepositoryProvider)
      .fetchAlumniVerifications(status: status);
});

final alumniClaimsProvider =
    FutureProvider.autoDispose<List<AlumniClaimItem>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchAlumniClaims();
});

final rolePermissionsProvider =
    FutureProvider.autoDispose<Map<String, Set<String>>>(
        (ref) => ref.watch(adminRepositoryProvider).rolePermissions());

final workflowsProvider = FutureProvider.autoDispose<List<ApprovalStage>>(
    (ref) => ref.watch(adminRepositoryProvider).workflows());

final auditLogProvider = FutureProvider.autoDispose<List<AuditEntry>>(
    (ref) => ref.watch(adminRepositoryProvider).audit());

class AdminActionsViewModel extends BusyNotifier {
  Future<Outcome> createAdmin({
    required String email,
    required String fullName,
    required String role,
    required String password,
  }) =>
      run(() async {
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) {
          throw Exception('Enter a valid e-mail address.');
        }
        if (fullName.trim().length < 3) throw Exception('Enter the full name.');
        if (password.length < 12) {
          throw Exception('Initial password must be at least 12 characters.');
        }
        await ref.read(adminRepositoryProvider).createAdmin(
            email: email.trim(),
            fullName: fullName.trim(),
            role: role,
            password: password);
        ref.invalidate(profilesProvider);
        return 'Administrator account created. Share the initial password securely.';
      });

  Future<Outcome> updateProfile(String id, {String? role, bool? isActive}) =>
      run(() async {
        await ref
            .read(adminRepositoryProvider)
            .updateProfile(id, role: role, isActive: isActive);
        ref.invalidate(profilesProvider);
        return 'Account updated.';
      });

  Future<Outcome> setPermission(String role, String permission, bool granted) =>
      run(() async {
        await ref
            .read(adminRepositoryProvider)
            .setPermission(role, permission, granted);
        ref.invalidate(rolePermissionsProvider);
        return null;
      });

  Future<Outcome> saveStage({
    String? id,
    required String roomType,
    required int order,
    required String name,
    required String authority,
    required String role,
    required bool active,
  }) =>
      run(() async {
        if (name.trim().isEmpty) throw Exception('Stage name is required.');
        if (order < 1) throw Exception('Stage order must be 1 or higher.');
        await ref.read(adminRepositoryProvider).saveStage(
            id: id,
            roomType: roomType,
            order: order,
            name: name.trim(),
            authority: authority.trim(),
            role: role,
            active: active);
        ref.invalidate(workflowsProvider);
        return 'Approval stage saved. It applies to new requests only.';
      });

  Future<Outcome> deleteStage(String id) => run(() async {
        await ref.read(adminRepositoryProvider).deleteStage(id);
        ref.invalidate(workflowsProvider);
        return 'Approval stage removed. It applies to new requests only.';
      });

  Future<Outcome> verifyAlumnus(String id,
          {required bool approve, String? notes}) =>
      run(() async {
        await ref
            .read(adminRepositoryProvider)
            .verifyAlumnus(id, approve: approve, notes: notes);
        ref.invalidate(alumniVerificationsProvider);
        return approve
            ? 'Alumnus profile verified successfully.'
            : 'Alumnus profile rejected.';
      });

  Future<Outcome> resolveDuplicate({
    required String profileId,
    required String action,
    String? masterProfileId,
  }) =>
      run(() async {
        await ref.read(adminRepositoryProvider).resolveDuplicate(
              profileId: profileId,
              action: action,
              masterProfileId: masterProfileId,
            );
        ref.invalidate(alumniVerificationsProvider);
        if (action == 'clear') {
          return 'Profile cleared: marked as distinct person (not a duplicate).';
        } else if (action == 'reject') {
          return 'Duplicate registration rejected.';
        } else {
          return 'Profile successfully merged into master account.';
        }
      });

  Future<Outcome> decideClaim({
    required String claimId,
    required bool approve,
    String? notes,
  }) =>
      run(() async {
        await ref.read(adminRepositoryProvider).decideAlumniClaim(
              claimId: claimId,
              approve: approve,
              notes: notes,
            );
        ref.invalidate(alumniClaimsProvider);
        return approve ? 'Claim approved.' : 'Claim rejected.';
      });
}

final adminActionsProvider = NotifierProvider<AdminActionsViewModel, BusyState>(
    AdminActionsViewModel.new);
