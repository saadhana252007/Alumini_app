import 'json_helpers.dart';

class TariffRule {
  const TariffRule({
    required this.id,
    required this.category,
    required this.subCategory,
    required this.roomType,
    required this.billingUnit,
    required this.isActive,
    this.rate,
    this.note,
  });

  final String id;
  final String category;
  final String subCategory;
  final String roomType;
  final double? rate;

  /// per_day | per_month | free | as_applicable | unspecified
  final String billingUnit;
  final String? note;
  final bool isActive;

  factory TariffRule.fromMap(Map<String, dynamic> m) => TariffRule(
        id: m['id'] as String,
        category: m['visitor_category'] as String,
        subCategory: str(m['sub_category']),
        roomType: m['room_type'] as String,
        rate: parseNum(m['rate']),
        billingUnit: m['billing_unit'] as String,
        note: m['note'] as String?,
        isActive: m['is_active'] as bool? ?? true,
      );
}

class ChargeBreakdown {
  const ChargeBreakdown({
    required this.days,
    required this.rooms,
    required this.unit,
    required this.gstPercent,
    this.unitRate,
    this.subtotal,
    this.gst,
    this.total,
    this.note,
  });

  final int days;
  final int rooms;
  final String unit;
  final double? unitRate;
  final double? subtotal;
  final double gstPercent;
  final double? gst;
  final double? total;
  final String? note;

  bool get isFree => unit == 'free';
  bool get isDetermined => total != null;

  factory ChargeBreakdown.fromMap(Map<String, dynamic> m) => ChargeBreakdown(
        days: (m['days'] as num?)?.toInt() ?? 1,
        rooms: (m['rooms'] as num?)?.toInt() ?? 1,
        unit: str(m['billing_unit'], 'unspecified'),
        unitRate: parseNum(m['unit_rate']),
        subtotal: parseNum(m['subtotal']),
        gstPercent: parseNum(m['gst_percent']) ?? 0,
        gst: parseNum(m['gst']),
        total: parseNum(m['total']),
        note: m['note'] as String?,
      );
}

/// Client-side estimate. The database function `calculate_charges` is the
/// authority; both implement the same rules.
class TariffCalculator {
  static const unspecifiedNote =
      'Rate not specified in the EDC tariff; to be determined by the institute.';
  static const monthlyNote =
      'Monthly rate charged per started 30-day month (prototype assumption - confirm with the institute).';

  static int billableDays(DateTime arrival, DateTime departure) {
    final secs = departure.difference(arrival).inSeconds;
    final days = (secs / 86400).ceil();
    return days < 1 ? 1 : days;
  }

  static double _round2(double v) => (v * 100).round() / 100;

  static TariffRule? findRule(
    List<TariffRule> rules,
    String category,
    String subCategory,
    String roomType,
  ) {
    TariffRule? exact;
    TariffRule? general;
    for (final r in rules) {
      if (!r.isActive || r.category != category || r.roomType != roomType) {
        continue;
      }
      if (r.subCategory == subCategory) exact = r;
      if (r.subCategory == '') general = r;
    }
    return exact ?? general;
  }

  static ChargeBreakdown calculate({
    required List<TariffRule> rules,
    required String category,
    required String subCategory,
    required String roomType,
    required int rooms,
    required DateTime arrival,
    required DateTime departure,
    required double gstPercent,
  }) {
    final days = billableDays(arrival, departure);
    final rule = findRule(rules, category, subCategory, roomType);

    if (rule == null ||
        rule.billingUnit == 'unspecified' ||
        rule.billingUnit == 'as_applicable' ||
        rule.rate == null && rule.billingUnit != 'free') {
      return ChargeBreakdown(
        days: days,
        rooms: rooms,
        unit: rule?.billingUnit ?? 'unspecified',
        gstPercent: gstPercent,
        note: unspecifiedNote,
      );
    }
    if (rule.billingUnit == 'free') {
      return ChargeBreakdown(
        days: days,
        rooms: rooms,
        unit: 'free',
        unitRate: 0,
        subtotal: 0,
        gstPercent: gstPercent,
        gst: 0,
        total: 0,
        note: 'Free boarding and lodging (Category A).',
      );
    }

    final rate = rule.rate!;
    double subtotal;
    String? note;
    if (rule.billingUnit == 'per_month') {
      final months = (days / 30).ceil();
      subtotal = rate * months * rooms;
      note = monthlyNote;
    } else {
      subtotal = rate * days * rooms;
    }
    subtotal = _round2(subtotal);
    final gst = _round2(subtotal * gstPercent / 100);
    return ChargeBreakdown(
      days: days,
      rooms: rooms,
      unit: rule.billingUnit,
      unitRate: rate,
      subtotal: subtotal,
      gstPercent: gstPercent,
      gst: gst,
      total: _round2(subtotal + gst),
      note: note,
    );
  }
}

class ApprovalStage {
  const ApprovalStage({
    required this.id,
    required this.roomType,
    required this.stageOrder,
    required this.stageName,
    required this.authorityLabel,
    required this.approverRole,
    required this.isActive,
  });

  final String id;
  final String roomType;
  final int stageOrder;
  final String stageName;
  final String authorityLabel;
  final String approverRole;
  final bool isActive;

  factory ApprovalStage.fromMap(Map<String, dynamic> m) => ApprovalStage(
        id: m['id'] as String,
        roomType: m['room_type'] as String,
        stageOrder: (m['stage_order'] as num).toInt(),
        stageName: m['stage_name'] as String,
        authorityLabel: str(m['authority_label']),
        approverRole: m['approver_role'] as String,
        isActive: m['is_active'] as bool? ?? true,
      );
}
