import 'package:intl/intl.dart';

final _date = DateFormat('d MMM yyyy');
final _dateTime = DateFormat('d MMM yyyy, HH:mm');

String formatDate(DateTime? d) => d == null ? '' : _date.format(d);
String formatDateTime(DateTime d) => _dateTime.format(d.toLocal());

String capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
