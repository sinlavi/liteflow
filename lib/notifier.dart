import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Thin wrapper over flutter_local_notifications.
/// IDs: pomodoro = 1, task = id*10, alarm = id*10 + weekday (0 = daily/once).
class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _askedExact = false;

  static const _reminder = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Task reminders',
      channelDescription: 'Reminders for tasks',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static const _pomo = NotificationDetails(
    android: AndroidNotificationDetails(
      'pomodoro',
      'Pomodoro',
      channelDescription: 'Focus and break timer',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  // Rings on the alarm stream with the system alarm tone, repeating
  // (FLAG_INSISTENT = 4) until the notification is dismissed.
  static final _alarm = NotificationDetails(
    android: AndroidNotificationDetails(
      'alarms',
      'Alarms',
      channelDescription: 'Alarm clock',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound: const UriAndroidNotificationSound(
          'content://settings/system/alarm_alert'),
      enableVibration: true,
      additionalFlags: Int32List.fromList(<int>[4]),
    ),
  );

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
  }

  static Future<void> requestNotifications() async {
    try {
      await _android?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// Android 12/12L only: opens the "Alarms & reminders" settings page.
  static Future<void> ensureExact() async {
    if (_askedExact) return;
    try {
      final ok = await _android?.canScheduleExactNotifications();
      if (ok == false) {
        _askedExact = true;
        await _android?.requestExactAlarmsPermission();
      }
    } catch (_) {}
  }

  static Future<AndroidScheduleMode> _mode() async {
    try {
      final ok = await _android?.canScheduleExactNotifications();
      if (ok == false) return AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {}
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  static Future<void> _sched(
    int id,
    String title,
    String body,
    DateTime when,
    NotificationDetails d, {
    DateTimeComponents? match,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        d,
        androidScheduleMode: await _mode(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: match,
      );
    } catch (e) {
      debugPrint('schedule failed: $e');
    }
  }

  // ---- tasks ----
  static Future<void> cancelTask(int id) => _plugin.cancel(id * 10);

  static Future<void> syncTask(Task t) async {
    await _plugin.cancel(t.id * 10);
    if (t.done || !t.remind || t.due == 0) return;
    var when = DateTime.fromMillisecondsSinceEpoch(t.due);
    final now = DateTime.now();
    DateTimeComponents? m;
    if (t.repeat == 1 || t.repeat == 2) {
      while (!when.isAfter(now)) {
        when = DateTime(when.year, when.month,
            when.day + (t.repeat == 1 ? 1 : 7), when.hour, when.minute);
      }
      m = t.repeat == 1
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime;
    } else if (!when.isAfter(now)) {
      return;
    }
    await _sched(t.id * 10, 'Task due', t.title, when, _reminder, match: m);
  }

  // ---- alarms ----
  static String _hm(Alarm a) =>
      '${a.hour.toString().padLeft(2, '0')}:${a.minute.toString().padLeft(2, '0')}';

  static Future<void> cancelAlarm(int id) async {
    for (var i = 0; i < 8; i++) {
      await _plugin.cancel(id * 10 + i);
    }
  }

  static Future<void> syncAlarm(Alarm a) async {
    await cancelAlarm(a.id);
    if (!a.enabled) return;
    final title = a.label.isEmpty ? 'Alarm' : a.label;
    final body = _hm(a);
    if (a.days.isEmpty) {
      final when = DateTime.fromMillisecondsSinceEpoch(a.fireAt);
      if (when.isAfter(DateTime.now())) {
        await _sched(a.id * 10, title, body, when, _alarm);
      }
    } else if (a.days.length == 7) {
      await _sched(a.id * 10, title, body, nextTime(a.hour, a.minute), _alarm,
          match: DateTimeComponents.time);
    } else {
      for (final d in a.days) {
        await _sched(a.id * 10 + d, title, body,
            nextTime(a.hour, a.minute, d), _alarm,
            match: DateTimeComponents.dayOfWeekAndTime);
      }
    }
  }

  // ---- pomodoro ----
  static Future<void> pomoSchedule(DateTime when, int phase) => _sched(
        1,
        phase == 0 ? 'Focus session complete' : 'Break is over',
        phase == 0 ? 'Time for a break.' : 'Ready to focus?',
        when,
        _pomo,
      );

  static Future<void> pomoCancel() => _plugin.cancel(1);
}
