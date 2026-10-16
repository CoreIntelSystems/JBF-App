import 'package:intl/intl.dart';

/// Money is stored as integer pesewas (GHS 12.50 = 1250) so balances never
/// suffer floating-point rounding.
final _amount = NumberFormat('#,##0.00');

String formatMoney(int pesewas, {String currency = 'GHS'}) {
  final sign = pesewas < 0 ? '-' : '';
  return '$sign$currency ${_amount.format(pesewas.abs() / 100)}';
}

/// Parses user input such as "20", "20.5" or "1,250.00" into pesewas.
/// Returns null for empty, negative or malformed input.
int? parseMoney(String input) {
  final t = input.trim().replaceAll(',', '');
  if (t.isEmpty) return null;
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final cedis = int.parse(m.group(1)!);
  final frac = (m.group(2) ?? '').padRight(2, '0');
  return cedis * 100 + int.parse(frac);
}

/// Text for an amount field, e.g. 1250 -> "12.50".
String moneyInput(int pesewas) => (pesewas / 100).toStringAsFixed(2);
