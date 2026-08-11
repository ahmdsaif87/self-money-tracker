/// Date utils — mirrors src/utils/date.ts
String toLocalDateKey(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

DateTime parseLocalDate(String iso) {
  final parts = iso.split('-').map(int.tryParse).toList();
  if (parts.length < 3 || parts.any((n) => n == null)) {
    return DateTime.fromMillisecondsSinceEpoch(0); // invalid marker
  }
  return DateTime(parts[0]!, parts[1]! - 1, parts[2]!);
}
