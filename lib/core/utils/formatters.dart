import 'package:intl/intl.dart';

final _dateFmt = DateFormat('dd MMM yyyy');
final _dateTimeFmt = DateFormat('dd MMM yyyy, HH:mm');
final _moneyFmt = NumberFormat('#,##0.00', 'en_IN');

String fmtDate(DateTime? d) => d == null ? '-' : _dateFmt.format(d.toLocal());
String fmtDateTime(DateTime? d) =>
    d == null ? '-' : _dateTimeFmt.format(d.toLocal());

/// Money in Indian rupees. Written as "Rs." (not the rupee glyph) so PDFs
/// render correctly with the built-in fonts.
String fmtMoney(num? v, {String whenNull = 'To be determined'}) =>
    v == null ? whenNull : 'Rs. ${_moneyFmt.format(v)}';

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Removes characters that would break PostgREST `or(...)` / `ilike` filters.
String sanitizeSearch(String input) =>
    input.replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();

String humanize(String s) {
  if (s.isEmpty) return s;
  final t = s.replaceAll('_', ' ');
  return t[0].toUpperCase() + t.substring(1);
}
