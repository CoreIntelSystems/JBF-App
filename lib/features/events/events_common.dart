import 'package:flutter/material.dart';

import '../../core/reminders.dart';

/// Asks for a date, then a time.
Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  final now = DateTime.now();
  final day = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(now.year - 5),
    lastDate: DateTime(now.year + 5),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

/// A stable notification id for an event or meeting.
int reminderId(String id) => 1000 + (id.hashCode & 0x3fffffff);

/// Reminds this phone the evening before (or two hours before, for
/// something happening soon).
Future<void> scheduleOccasionReminder(
  Reminders reminders,
  String id,
  String title,
  DateTime when,
  String? venue,
) async {
  final evening = DateTime(when.year, when.month, when.day - 1, 18);
  final at = evening.isAfter(DateTime.now())
      ? evening
      : when.subtract(const Duration(hours: 2));
  try {
    await reminders.scheduleOnce(
      reminderId(id),
      at,
      title,
      '${_time(when)}${venue == null ? '' : ' at $venue'}',
    );
  } catch (_) {
    // A reminder failing must never stop the event from being saved.
  }
}

String _time(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.day}/${d.month}/${d.year} $h:$m';
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        Expanded(flex: 3, child: Text(value)),
      ],
    ),
  );
}
