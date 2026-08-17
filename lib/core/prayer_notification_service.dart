import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class PrayerNotificationService {
  PrayerNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  static const _prayers = ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];

  Future<void> scheduleToday({
    required Map<String, String> timings,
    required bool enabled,
    required int minutesBefore,
  }) async {
    for (var id = 1000; id < 1050; id++) {
      await _plugin.cancel(id);
    }
    if (!enabled) return;

    final now = tz.TZDateTime.now(tz.local);
    for (var index = 0; index < _prayers.length; index++) {
      final name = _prayers[index];
      var time = _parseToday(timings[name], now);
      if (time == null) continue;

      if (time.isBefore(now)) {
        time = time.add(const Duration(days: 1));
      }

      // 1. Ezan Vakti Bildirimi
      await _schedule(
        id: 1000 + index,
        at: time,
        title: '🕌 $name Vakti Girdi',
        body: '$name ezan vakti geldi. Haydin namaza!',
      );

      // 2. Vakit Öncesi Uyarı Bildirimi (Kilit Ekranı & Tam Ekran)
      var reminder = time.subtract(Duration(minutes: minutesBefore));
      if (reminder.isBefore(now)) {
        reminder = reminder.add(const Duration(days: 1));
      }
      await _schedule(
        id: 1020 + index,
        at: reminder,
        title: '🔔 $name Vaktine $minutesBefore Dakika Kaldı',
        body: 'Ezan okunmasına $minutesBefore dakika kaldı. Abdestinizi alıp hazırlanabilirsiniz.',
      );
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

  Future<void> _schedule({
    required int id,
    required tz.TZDateTime at,
    required String title,
    required String body,
  }) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      at,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'namaz_vakitleri_max_v2',
          'Namaz Vakitleri & Hatırlatmalar',
          channelDescription: 'Tam ekran ve kilit ekranı ezan/vakit öncesi hatırlatıcı bildirimleri',
          importance: Importance.max,
          priority: Priority.max,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
