enum AdminRole {
  edcAdmin('edc_admin', 'EDC Admin'),
  dean('dean_admin', 'Dean Admin'),
  superAdmin('super_admin', 'Super Admin'),
  alumni('alumni', 'Alumnus');

  const AdminRole(this.db, this.label);
  final String db;
  final String label;

  static AdminRole fromDb(String v) =>
      values.firstWhere((r) => r.db == v, orElse: () => AdminRole.alumni);
}

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    this.verificationStatus,
  });

  final String id;
  final String fullName;
  final String email;
  final AdminRole role;
  final bool isActive;
  final String? verificationStatus;

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: (m['id'] ?? '').toString(),
        fullName: (m['full_name'] ?? '').toString(),
        email: (m['email'] ?? '').toString(),
        role: AdminRole.fromDb((m['role'] ?? 'edc_admin').toString()),
        isActive: m['is_active'] as bool? ?? false,
        verificationStatus: m['verification_status'] as String?,
      );
}

class AlumniVerificationItem {
  final String id;
  final String fullName;
  final String email;
  final String? admissionNo;
  final String? contactNo;
  final String? whatsappNo;
  final String? departmentName;
  final int? batchYear;
  final String? currentPosition;
  final String? organisation;
  final String? addressLine;
  final String? city;
  final String? state;
  final String verificationStatus; // 'pending', 'verified', 'rejected'
  final DateTime createdAt;
  final String? possibleDuplicateOf;
  final String? duplicateReviewStatus;
  final String? emailNormalized;
  final String? contactE164;
  final String? admissionNoNormalized;

  const AlumniVerificationItem({
    required this.id,
    required this.fullName,
    required this.email,
    this.admissionNo,
    this.contactNo,
    this.whatsappNo,
    this.departmentName,
    this.batchYear,
    this.currentPosition,
    this.organisation,
    this.addressLine,
    this.city,
    this.state,
    required this.verificationStatus,
    required this.createdAt,
    this.possibleDuplicateOf,
    this.duplicateReviewStatus,
    this.emailNormalized,
    this.contactE164,
    this.admissionNoNormalized,
  });

  factory AlumniVerificationItem.fromMap(Map<String, dynamic> m) =>
      AlumniVerificationItem(
        id: (m['id'] ?? '').toString(),
        fullName: (m['full_name'] ?? 'Alumnus').toString(),
        email: (m['email'] ?? '').toString(),
        admissionNo: m['admission_no'] as String?,
        contactNo: m['contact_no'] as String?,
        whatsappNo: m['whatsapp_no'] as String?,
        departmentName:
            m['department_name'] as String? ?? (m['department_id'] as String?),
        batchYear: m['batch_year'] is int
            ? m['batch_year'] as int
            : int.tryParse(m['batch_year']?.toString() ?? ''),
        currentPosition: m['current_position'] as String?,
        organisation: m['organisation'] as String?,
        addressLine: m['address_line'] as String?,
        city: m['city'] as String?,
        state: m['state'] as String?,
        verificationStatus: (m['verification_status'] ?? 'pending').toString(),
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        possibleDuplicateOf: m['possible_duplicate_of'] as String?,
        duplicateReviewStatus: m['duplicate_review_status'] as String?,
        emailNormalized: m['email_normalized'] as String?,
        contactE164: m['contact_e164'] as String?,
        admissionNoNormalized: m['admission_no_normalized'] as String?,
      );
}

class AlumniClaimItem {
  final String id;
  final String admissionNo;
  final String existingProfileId;
  final Map<String, dynamic> claimantDetails;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;

  const AlumniClaimItem({
    required this.id,
    required this.admissionNo,
    required this.existingProfileId,
    required this.claimantDetails,
    required this.status,
    this.adminNotes,
    required this.createdAt,
  });

  factory AlumniClaimItem.fromMap(Map<String, dynamic> m) => AlumniClaimItem(
        id: (m['id'] ?? '').toString(),
        admissionNo: (m['admission_no'] ?? '').toString(),
        existingProfileId: (m['existing_profile_id'] ?? '').toString(),
        claimantDetails: m['claimant_details'] is Map
            ? Map<String, dynamic>.from(m['claimant_details'])
            : {},
        status: (m['status'] ?? 'pending').toString(),
        adminNotes: m['admin_notes'] as String?,
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
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
