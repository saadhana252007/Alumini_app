library;

/// Identity normalizers and string helpers for alumni registration and verification.

class Normalizers {
  /// Normalized email: trimmed, lowercase. Returns empty string if null/empty.
  static String normalizeEmail(String? email) {
    if (email == null) return '';
    return email.trim().toLowerCase();
  }

  /// Normalized phone to E.164 (+91XXXXXXXXXX for Indian numbers).
  /// Strips spaces, dashes, parentheses.
  /// Handles:
  /// - 10 digits (e.g. 9876543210) -> +919876543210
  /// - Leading 0 (e.g. 09876543210) -> +919876543210
  /// - 91 prefix without plus (e.g. 919876543210) -> +919876543210
  /// - Standard +91 prefix (e.g. +91 98765-43210) -> +919876543210
  /// - International numbers with plus (e.g. +14155552671) -> +14155552671
  static String normalizePhone(String? phone) {
    if (phone == null) return '';
    final raw = phone.trim();
    if (raw.isEmpty) return '';

    // If starts with +, strip other non-digit chars
    if (raw.startsWith('+')) {
      final digits = raw.substring(1).replaceAll(RegExp(r'\D'), '');
      return '+$digits';
    }

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91$digits';
    } else if (digits.length == 11 && digits.startsWith('0')) {
      return '+91${digits.substring(1)}';
    } else if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    } else if (digits.isNotEmpty) {
      return '+$digits';
    }
    return '';
  }

  /// Normalized admission number: trimmed, uppercase, strips spaces and special chars.
  /// E.g. ' 25je0133 ' -> '25JE0133', 'ism 12345' -> 'ISM12345', '98-je-0124' -> '98JE0124'
  /// Returns null if empty.
  static String? normalizeAdmissionNo(String? adm) {
    if (adm == null) return null;
    final cleaned =
        adm.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase().trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Normalized name: trims, collapses multiple spaces into one.
  static String normalizeName(String? name) {
    if (name == null) return '';
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Name comparison key: collapsed spaces, lowercase.
  static String nameMatchKey(String? name) {
    if (name == null) return '';
    return normalizeName(name).toLowerCase();
  }

  /// Mask email for privacy: a•••••@domain.com
  static String maskEmail(String? email) {
    if (email == null || !email.contains('@')) return '•••••@email.com';
    final parts = email.trim().toLowerCase().split('@');
    final user = parts[0];
    final domain = parts[1];
    if (user.isEmpty) return '•••••@$domain';
    if (user.length == 1) return '${user[0]}•••••@$domain';
    return '${user[0]}•••••@$domain';
  }

  /// Mask phone for privacy: +91•••••••210
  static String maskPhone(String? phone) {
    final e164 = normalizePhone(phone);
    if (e164.length < 5) return '••••••••••';
    final prefix = e164.startsWith('+91') ? '+91' : e164.substring(0, 3);
    final last3 = e164.substring(e164.length - 3);
    return '$prefix•••••••$last3';
  }
}
