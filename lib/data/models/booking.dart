import '../../core/constants.dart';
import 'json_helpers.dart';
import 'tariff.dart';

class RequestStatus {
  static const pending = 'pending';
  static const awaiting = 'awaiting_approval';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
  static const completed = 'completed';

  static String label(String s) => requestStatuses[s] ?? s;

  static bool isOpen(String s) => s == pending || s == awaiting;

  /// Mirrors the guard trigger in the database.
  static bool canTransition(String from, String to) {
    switch (from) {
      case pending:
        return {awaiting, approved, rejected, cancelled}.contains(to);
      case awaiting:
        return {approved, rejected, cancelled}.contains(to);
      case approved:
        return {completed, cancelled}.contains(to);
      default:
        return false;
    }
  }
}

typedef RequestFilter = ({
  List<String> statuses,
  String? category,
  String? roomType,
  DateTime? from,
  DateTime? to,
  String query,
});

class BookingRequest {
  const BookingRequest({
    required this.id,
    required this.reference,
    required this.visitorName,
    required this.address,
    required this.nationality,
    required this.mobile,
    required this.purpose,
    required this.personsLodging,
    required this.personsFood,
    required this.childrenUnder12,
    required this.guestDetails,
    required this.numRooms,
    required this.category,
    required this.subCategory,
    required this.roomType,
    required this.arrivalAt,
    required this.departureAt,
    required this.lodgingBilledTo,
    required this.foodBilledTo,
    required this.isStudentGuest,
    required this.forwardedByDsw,
    required this.extendedStayApproved,
    required this.indenterName,
    required this.status,
    required this.currentStage,
    required this.createdAt,
    this.organization,
    this.email,
    this.indenterDesignation,
    this.indenterEmpCode,
    this.indenterDepartment,
    this.indenterPhone,
    this.indenterEmail,
    this.forwardingAuthority,
    this.availability,
    this.allottedRoomNo,
    this.rejectionReason,
    this.estimatedAmount,
  });

  final String id;
  final String reference;
  final String visitorName;
  final String? organization;
  final String address;
  final String nationality;
  final String mobile;
  final String? email;
  final String purpose;
  final int personsLodging;
  final int personsFood;
  final int childrenUnder12;
  final List<Map<String, dynamic>> guestDetails;
  final int numRooms;
  final String category;
  final String subCategory;
  final String roomType;
  final DateTime arrivalAt;
  final DateTime departureAt;
  final String lodgingBilledTo;
  final String foodBilledTo;
  final bool isStudentGuest;
  final bool forwardedByDsw;
  final bool extendedStayApproved;
  final String indenterName;
  final String? indenterDesignation;
  final String? indenterEmpCode;
  final String? indenterDepartment;
  final String? indenterPhone;
  final String? indenterEmail;
  final String? forwardingAuthority;
  final String? availability;
  final String? allottedRoomNo;
  final String status;
  final int currentStage;
  final String? rejectionReason;
  final double? estimatedAmount;
  final DateTime createdAt;

  String get categoryLabel =>
      subCategory.isEmpty ? category : '$category($subCategory)';

  factory BookingRequest.fromMap(Map<String, dynamic> m) => BookingRequest(
        id: m['id'] as String,
        reference: m['reference'] as String,
        visitorName: m['visitor_name'] as String,
        organization: m['organization'] as String?,
        address: str(m['address']),
        nationality: str(m['nationality'], 'indian'),
        mobile: str(m['mobile']),
        email: m['email'] as String?,
        purpose: str(m['purpose'], 'official'),
        personsLodging: (m['persons_lodging'] as num).toInt(),
        personsFood: (m['persons_food'] as num).toInt(),
        childrenUnder12: (m['children_under_12'] as num?)?.toInt() ?? 0,
        guestDetails: ((m['guest_details'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        numRooms: (m['num_rooms'] as num).toInt(),
        category: m['visitor_category'] as String,
        subCategory: str(m['visitor_sub_category']),
        roomType: m['room_type'] as String,
        arrivalAt: parseDt(m['arrival_at']),
        departureAt: parseDt(m['departure_at']),
        lodgingBilledTo: str(m['lodging_billed_to']),
        foodBilledTo: str(m['food_billed_to']),
        isStudentGuest: m['is_student_guest'] as bool? ?? false,
        forwardedByDsw: m['forwarded_by_dsw'] as bool? ?? false,
        extendedStayApproved: m['extended_stay_approved'] as bool? ?? false,
        indenterName: str(m['indenter_name']),
        indenterDesignation: m['indenter_designation'] as String?,
        indenterEmpCode: m['indenter_emp_code'] as String?,
        indenterDepartment: m['indenter_department'] as String?,
        indenterPhone: m['indenter_phone'] as String?,
        indenterEmail: m['indenter_email'] as String?,
        forwardingAuthority: m['forwarding_authority'] as String?,
        availability: m['availability'] as String?,
        allottedRoomNo: m['allotted_room_no'] as String?,
        status: m['status'] as String,
        currentStage: (m['current_stage'] as num).toInt(),
        rejectionReason: m['rejection_reason'] as String?,
        estimatedAmount: parseNum(m['estimated_amount']),
        createdAt: parseDt(m['created_at']),
      );
}

class ApprovalStep {
  const ApprovalStep({
    required this.id,
    required this.stageOrder,
    required this.stageName,
    required this.authorityLabel,
    required this.approverRole,
    required this.status,
    this.decidedByName,
    this.decidedAt,
    this.reason,
  });

  final String id;
  final int stageOrder;
  final String stageName;
  final String authorityLabel;
  final String approverRole;
  final String status; // pending|approved|rejected|skipped|cancelled
  final String? decidedByName;
  final DateTime? decidedAt;
  final String? reason;

  factory ApprovalStep.fromMap(Map<String, dynamic> m) {
    final d = m['decider'];
    return ApprovalStep(
      id: m['id'] as String,
      stageOrder: (m['stage_order'] as num).toInt(),
      stageName: m['stage_name'] as String,
      authorityLabel: str(m['authority_label']),
      approverRole: m['approver_role'] as String,
      status: m['status'] as String,
      decidedByName: d is Map ? d['full_name'] as String? : null,
      decidedAt: parseDtOrNull(m['decided_at']),
      reason: m['reason'] as String?,
    );
  }
}

class Receipt {
  const Receipt({
    required this.id,
    required this.receiptNo,
    required this.breakdown,
    required this.issuedAt,
    this.total,
  });

  final String id;
  final String receiptNo;
  final ChargeBreakdown breakdown;
  final double? total;
  final DateTime issuedAt;

  factory Receipt.fromMap(Map<String, dynamic> m) => Receipt(
        id: m['id'] as String,
        receiptNo: m['receipt_no'] as String,
        breakdown: ChargeBreakdown.fromMap(
            Map<String, dynamic>.from(m['breakdown'] as Map)),
        total: parseNum(m['total']),
        issuedAt: parseDt(m['issued_at']),
      );
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.amount,
    required this.status,
    required this.method,
    required this.reference,
    required this.createdAt,
  });

  final String id;
  final double amount;
  final String status; // simulated_success | simulated_failed
  final String method;
  final String reference;
  final DateTime createdAt;

  bool get isSuccess => status == 'simulated_success';

  factory PaymentRecord.fromMap(Map<String, dynamic> m) => PaymentRecord(
        id: m['id'] as String,
        amount: parseNum(m['amount']) ?? 0,
        status: m['status'] as String,
        method: str(m['method']),
        reference: str(m['reference']),
        createdAt: parseDt(m['created_at']),
      );
}

class NotificationLog {
  const NotificationLog({
    required this.event,
    required this.recipient,
    required this.subject,
    required this.mode,
    required this.createdAt,
    this.error,
  });

  final String event;
  final String recipient;
  final String subject;
  final String mode; // sent | simulated | failed
  final String? error;
  final DateTime createdAt;

  factory NotificationLog.fromMap(Map<String, dynamic> m) => NotificationLog(
        event: str(m['event']),
        recipient: str(m['recipient']),
        subject: str(m['subject']),
        mode: str(m['mode']),
        error: m['error'] as String?,
        createdAt: parseDt(m['created_at']),
      );
}

class AuditEntry {
  const AuditEntry({
    required this.action,
    required this.entityType,
    required this.details,
    required this.createdAt,
    this.actorName,
  });

  final String action;
  final String entityType;
  final Map<String, dynamic> details;
  final String? actorName;
  final DateTime createdAt;

  factory AuditEntry.fromMap(Map<String, dynamic> m) {
    final a = m['actor'];
    return AuditEntry(
      action: str(m['action']),
      entityType: str(m['entity_type']),
      details: m['details'] is Map
          ? Map<String, dynamic>.from(m['details'] as Map)
          : <String, dynamic>{},
      actorName: a is Map ? a['full_name'] as String? : null,
      createdAt: parseDt(m['created_at']),
    );
  }

  String get description {
    switch (action) {
      case 'request.submitted':
        return 'Request submitted (${details['reference'] ?? ''})';
      case 'request.approved':
        return 'Request ${details['reference'] ?? ''} approved at stage ${details['stage'] ?? ''}';
      case 'request.rejected':
        return 'Request ${details['reference'] ?? ''} rejected';
      case 'request.cancelled':
        return 'Request ${details['reference'] ?? ''} cancelled';
      case 'request.completed':
        return 'Request ${details['reference'] ?? ''} marked completed';
      case 'payment.simulated':
        return 'Simulated payment recorded (${details['reference'] ?? ''})';
      case 'report.exported':
        return 'Report exported (${details['report'] ?? ''})';
      default:
        final parts = action.split('.');
        return parts.length == 2
            ? '${parts.first[0].toUpperCase()}${parts.first.substring(1)} ${parts.last}'
            : action;
    }
  }
}

class RequestDetail {
  const RequestDetail({
    required this.request,
    required this.steps,
    required this.payments,
    required this.notifications,
    required this.audit,
    this.receipt,
  });

  final BookingRequest request;
  final List<ApprovalStep> steps;
  final Receipt? receipt;
  final List<PaymentRecord> payments;
  final List<NotificationLog> notifications;
  final List<AuditEntry> audit;

  ApprovalStep? get currentStep {
    for (final s in steps) {
      if (s.status == 'pending' && s.stageOrder >= request.currentStage) {
        return s;
      }
    }
    return null;
  }

  bool get hasSuccessfulPayment => payments.any((p) => p.isSuccess);
}

/// Mutable form state for a new requisition (visitor-entered fields only).
class RequestDraft {
  String visitorName = '';
  String organization = '';
  String address = '';
  String nationality = 'indian';
  String mobile = '';
  String email = '';
  String purpose = 'official';
  int personsLodging = 1;
  int personsFood = 0;
  int childrenUnder12 = 0;
  int numRooms = 1;
  List<Map<String, String>> guestDetails = [];
  String category = 'D';
  String subCategory = '';
  String roomType = 'standard';
  DateTime? arrivalAt;
  DateTime? departureAt;
  String lodgingBilledTo = 'institute';
  String foodBilledTo = 'visitor';
  bool isStudentGuest = false;
  bool forwardedByDsw = false;
  bool extendedStayApproved = false;
  String indenterName = '';
  String indenterDesignation = '';
  String indenterEmpCode = '';
  String indenterDepartment = '';
  String indenterPhone = '';
  String indenterEmail = '';
  String forwardingAuthority = '';

  /// Client-side mirror of the database validation. Returns the first problem.
  String? validate(DateTime now) {
    if (arrivalAt == null || departureAt == null) {
      return 'Select arrival and departure date and time.';
    }
    if (arrivalAt!.isBefore(now.add(const Duration(hours: 24)))) {
      return 'Bookings must be made at least 24 hours before arrival.';
    }
    if (!departureAt!.isAfter(arrivalAt!)) {
      return 'Departure must be after arrival.';
    }
    if (numRooms < 1) return 'At least one room is required.';
    if (personsLodging < 1) return 'At least one person needs lodging.';
    if (childrenUnder12 > personsLodging) {
      return 'Children below 12 cannot exceed the number of persons.';
    }
    if ((personsLodging - childrenUnder12) > numRooms * 2) {
      return 'Maximum 2 persons per room (children below 12 excluded).';
    }
    if (purpose == 'personal' &&
        departureAt!.difference(arrivalAt!) > const Duration(days: 3) &&
        !extendedStayApproved) {
      return 'Personal visits are limited to 3 days unless an extended stay was approved beforehand.';
    }
    if (isStudentGuest && !forwardedByDsw) {
      return 'Student requisitions must be forwarded by DSW.';
    }
    if (category == 'E' && subCategory.isEmpty) {
      return 'Select the Category E sub-type.';
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    String? nz(String s) => s.trim().isEmpty ? null : s.trim();
    return {
      'visitor_name': visitorName.trim(),
      'organization': nz(organization),
      'address': address.trim(),
      'nationality': nationality,
      'mobile': mobile.trim(),
      'email': nz(email),
      'purpose': purpose,
      'persons_lodging': personsLodging,
      'persons_food': personsFood,
      'children_under_12': childrenUnder12,
      'guest_details': isStudentGuest ? guestDetails : <Map<String, String>>[],
      'num_rooms': numRooms,
      'visitor_category': category,
      'visitor_sub_category': category == 'E' ? subCategory : '',
      'room_type': roomType,
      'arrival_at': arrivalAt!.toUtc().toIso8601String(),
      'departure_at': departureAt!.toUtc().toIso8601String(),
      'lodging_billed_to': lodgingBilledTo,
      'food_billed_to': foodBilledTo,
      'is_student_guest': isStudentGuest,
      'forwarded_by_dsw': forwardedByDsw,
      'extended_stay_approved': extendedStayApproved,
      'indenter_name': indenterName.trim(),
      'indenter_designation': nz(indenterDesignation),
      'indenter_emp_code': nz(indenterEmpCode),
      'indenter_department': nz(indenterDepartment),
      'indenter_phone': nz(indenterPhone),
      'indenter_email': nz(indenterEmail),
      'forwarding_authority': nz(forwardingAuthority),
    };
  }
}
