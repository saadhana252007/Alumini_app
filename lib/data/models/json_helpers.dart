DateTime parseDt(dynamic v) => DateTime.parse(v as String).toLocal();
DateTime? parseDtOrNull(dynamic v) => v == null ? null : parseDt(v);
double? parseNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

String str(dynamic v, [String fallback = '']) => v == null ? fallback : '$v';
