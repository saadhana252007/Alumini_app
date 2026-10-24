enum AdminRole {
  edcAdmin('edc_admin', 'EDC Admin'),
  dean('dean_admin', 'Dean Admin'),
  superAdmin('super_admin', 'Super Admin');

  const AdminRole(this.db, this.label);
  final String db;
  final String label;

  static AdminRole fromDb(String v) => values.firstWhere((r) => r.db == v);
}

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
  });

  final String id;
  final String fullName;
  final String email;
  final AdminRole role;
  final bool isActive;

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        fullName: m['full_name'] as String,
        email: m['email'] as String,
        role: AdminRole.fromDb(m['role'] as String),
        isActive: m['is_active'] as bool? ?? false,
      );
}

/// The signed-in administrator plus the permissions of their role.
/// UI uses [can] only to hide controls - the database enforces the real rules.
class AdminSession {
  const AdminSession({required this.profile, required this.permissions});

  final Profile profile;
  final Set<String> permissions;

  bool can(String permission) => permissions.contains(permission);
}
