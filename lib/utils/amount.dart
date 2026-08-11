import 'package:intl/intl.dart';

/// Amount utils — mirrors src/utils/amount.ts
String formatWithDots(String rawStr) {
  final cleaned = rawStr.replaceAll(RegExp(r'\s'), '');
  final digitsOnly = cleaned.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.isEmpty) return '';
  final parsed = int.tryParse(digitsOnly) ?? 0;
  return NumberFormat.decimalPattern('id_ID').format(parsed);
}

double parseRawAmount(String formattedStr) {
  final digitsOnly = formattedStr.replaceAll(RegExp(r'\D'), '');
  return double.tryParse(digitsOnly) ?? 0;
}

/// Currency formatting for id-ID, no decimals (matches Intl.NumberFormat id-ID currency IDR maximumFractionDigits 0)
String formatCurrency(double val) {
  final f = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );
  return f.format(val);
}

/// Compact: 1.5 M / 1.2 jt / 500 rb — mirrors formatCompact in ReportsScreen
String formatCompact(double val) {
  if (val >= 1000000000) return '${(val / 1000000000).toStringAsFixed(1)} M';
  if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)} jt';
  if (val >= 1000) return '${(val / 1000).round()} rb';
  return val.round().toString();
}
