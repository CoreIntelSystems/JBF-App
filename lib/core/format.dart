import 'package:intl/intl.dart';

final _date = DateFormat('d MMM yyyy');
final _dateTime = DateFormat('d MMM yyyy, HH:mm');

String formatDate(DateTime? d) => d == null ? '' : _date.format(d);
String formatDateTime(DateTime d) => _dateTime.format(d.toLocal());

String capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

final _month = DateFormat('MMM yyyy');

/// `2026-10` -> `Oct 2026`.
String formatPeriod(String? period) {
  if (period == null) return '';
  final parts = period.split('-');
  if (parts.length != 2) return period;
  return _month.format(DateTime(int.parse(parts[0]), int.parse(parts[1])));
}
