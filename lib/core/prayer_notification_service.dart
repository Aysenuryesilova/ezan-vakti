import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class PrayerNotificationService {
  PrayerNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  static const _prayers = ['İmsak', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];

  Future<void> scheduleToday({
    required Map<String, String> timings,
    required bool enabled,
    required int minutesBefore,
  }) async {
    for (var id = 1000; id < 1020; id++) {
      await _plugin.cancel(id);
    }
    if (!enabled) return;

    final now = tz.TZDateTime.now(tz.local);
    for (var index = 0; index < _prayers.length; index++) {
      final name = _prayers[index];
      final time = _parseToday(timings[name], now);
      if (time == null) continue;
      await _schedule(
          id: 1000 + index,
          at: time,
          title: '$name vakti',
          body: '$name vakti geldi.');
      final reminder = time.subtract(Duration(minutes: minutesBefore));
      if (reminder.isAfter(now)) {
        await _schedule(
          id: 1010 + index,
          at: reminder,
          title: '$name vaktine $minutesBefore dakika kaldı',
          body: 'Hazırlanmak için hatırlatma.',
        );
      }
    }
  }

  tz.TZDateTime? _parseToday(String? value, tz.TZDateTime now) {
    final parts = value?.split(':');
    if (parts == null || parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  }

  Future<void> _schedule(
      {required int id,
      required tz.TZDateTime at,
      required String title,
      required String body}) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      at,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'namaz_vakitleri',
          'Namaz Vakitleri',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
