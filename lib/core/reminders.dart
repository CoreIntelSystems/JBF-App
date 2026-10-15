import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/secure_store.dart';

/// Local reminders on this phone. No internet or SMS needed.
abstract class Reminders {
  /// Day of the month (1 to 28) for the monthly dues reminder, or null.
  Future<int?> duesDay();

  /// Turns the monthly dues reminder on ([day]) or off (null).
  Future<bool> setDuesDay(int? day);

  /// Schedules a one-off reminder, e.g. the day before a meeting.
  Future<void> scheduleOnce(int id, DateTime when, String title, String body);

  Future<void> cancel(int id);
}

class LocalReminders implements Reminders {
  LocalReminders(this._store);

  final SecureStore _store;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const duesId = 1;
  static const _duesKey = 'reminder_dues_day';
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Dues days and meetings',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Accra'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  Future<bool> _permission() async =>
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission() ??
      true;

  @override
  Future<int?> duesDay() async =>
      int.tryParse(await _store.pref(_duesKey) ?? '');

  @override
  Future<bool> setDuesDay(int? day) async {
    await _init();
    await _plugin.cancel(id: duesId);
    await _store.setPref(_duesKey, day?.toString());
    if (day == null) return true;
    final allowed = await _permission();
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, day, 9);
    if (!at.isAfter(now)) {
      at = tz.TZDateTime(tz.local, now.year, now.month + 1, day, 9);
    }
    await _plugin.zonedSchedule(
      id: duesId,
      scheduledDate: at,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Monthly dues day',
      body:
          'Remind members to pay this month\'s dues. Open the app to see '
          'who owes.',
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
    return allowed;
  }

  @override
  Future<void> scheduleOnce(
    int id,
    DateTime when,
    String title,
    String body,
  ) async {
    await _init();
    await _plugin.cancel(id: id);
    final at = tz.TZDateTime.from(when, tz.local);
    if (!at.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _permission();
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: at,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }
}

/// Keeps reminders in memory; used in tests.
class MemoryReminders implements Reminders {
  int? _day;
  final scheduled = <int, (DateTime, String, String)>{};

  @override
  Future<int?> duesDay() async => _day;

  @override
  Future<bool> setDuesDay(int? day) async {
    _day = day;
    return true;
  }

  @override
  Future<void> scheduleOnce(int id, DateTime when, String t, String b) async =>
      scheduled[id] = (when, t, b);

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}
