import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notifier.dart';

/// Single app-wide store: persistence (one JSON blob) + pomodoro engine.
class AppStore extends ChangeNotifier {
  late SharedPreferences _p;
  final List<Note> notes = [];
  final List<Task> tasks = [];
  final List<Alarm> alarms = [];
  Cfg cfg = Cfg();
  Pomo pomo = Pomo();
  int _seq = 10;

  /// Theme mode index; lets only MaterialApp rebuild on theme change.
  final ValueNotifier<int> theme = ValueNotifier(0);

  /// Ticks once per second while the timer runs.
  final ValueNotifier<int> tick = ValueNotifier(0);
  Timer? _timer;

  int newId() => _seq++;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p.getString('d');
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _seq = j['seq'] ?? 10;
        for (final e in (j['notes'] as List? ?? [])) {
          notes.add(Note.fromJson(Map<String, dynamic>.from(e)));
        }
        for (final e in (j['tasks'] as List? ?? [])) {
          tasks.add(Task.fromJson(Map<String, dynamic>.from(e)));
        }
        for (final e in (j['alarms'] as List? ?? [])) {
          alarms.add(Alarm.fromJson(Map<String, dynamic>.from(e)));
        }
        if (j['cfg'] != null) {
          cfg = Cfg.fromJson(Map<String, dynamic>.from(j['cfg']));
        }
        if (j['pomo'] != null) {
          pomo = Pomo.fromJson(Map<String, dynamic>.from(j['pomo']));
        }
      } catch (e) {
        debugPrint('load failed: $e');
      }
    }
    theme.value = cfg.theme;
    _rollDay();
    if (!pomo.running && pomo.left <= 0) pomo.left = dur(pomo.phase);
    expire();
    if (pomo.running) {
      _ticker();
      _onTick();
    }
  }

  void _save() {
    _p.setString(
      'd',
      jsonEncode({
        'seq': _seq,
        'notes': notes.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'alarms': alarms.map((e) => e.toJson()).toList(),
        'cfg': cfg.toJson(),
        'pomo': pomo.toJson(),
      }),
    );
  }

  void _commit() {
    _save();
    notifyListeners();
  }

  void onResume() {
    expire();
    if (pomo.running) _onTick();
  }

  // ---------- notes ----------
  void saveNote(Note n) {
    n.updated = nowMs();
    final i = notes.indexWhere((e) => e.id == n.id);
    if (i < 0) {
      notes.add(n);
    } else {
      notes[i] = n;
    }
    _commit();
  }

  void deleteNote(int id) {
    final before = notes.length;
    notes.removeWhere((e) => e.id == id);
    if (notes.length != before) _commit();
  }

  // ---------- tasks ----------
  void saveTask(Task t) {
    final i = tasks.indexWhere((e) => e.id == t.id);
    if (i < 0) {
      tasks.add(t);
    } else {
      tasks[i] = t;
    }
    _commit();
    Notifier.syncTask(t);
  }

  void deleteTask(int id) {
    tasks.removeWhere((e) => e.id == id);
    _commit();
    Notifier.cancelTask(id);
  }

  void toggleTask(Task t) {
    if (!t.done && t.repeat != 0 && t.due > 0) {
      // recurring: jump to the next occurrence instead of completing
      var d = DateTime.fromMillisecondsSinceEpoch(t.due);
      final now = DateTime.now();
      do {
        d = DateTime(d.year, d.month, d.day + (t.repeat == 1 ? 1 : 7), d.hour,
            d.minute);
      } while (!d.isAfter(now));
      t.due = d.millisecondsSinceEpoch;
    } else {
      t.done = !t.done;
    }
    _commit();
    Notifier.syncTask(t);
  }

  // ---------- alarms ----------
  void _refreshAlarm(Alarm a) {
    a.fireAt = a.days.isEmpty
        ? nextTime(a.hour, a.minute).millisecondsSinceEpoch
        : 0;
  }

  void saveAlarm(Alarm a) {
    _refreshAlarm(a);
    final i = alarms.indexWhere((e) => e.id == a.id);
    if (i < 0) {
      alarms.add(a);
    } else {
      alarms[i] = a;
    }
    _commit();
    Notifier.syncAlarm(a);
  }

  void toggleAlarm(Alarm a) {
    a.enabled = !a.active;
    _refreshAlarm(a);
    _commit();
    Notifier.syncAlarm(a);
  }

  void deleteAlarm(int id) {
    alarms.removeWhere((e) => e.id == id);
    _commit();
    Notifier.cancelAlarm(id);
  }

  /// Switch off one-shot alarms that have already rung.
  void expire() {
    var changed = false;
    final n = nowMs();
    for (final a in alarms) {
      if (a.enabled && a.days.isEmpty && a.fireAt <= n) {
        a.enabled = false;
        changed = true;
      }
    }
    if (changed) _commit();
  }

  // ---------- settings ----------
  void updateCfg(void Function(Cfg) f) {
    f(cfg);
    theme.value = cfg.theme;
    if (!pomo.running) pomo.left = dur(pomo.phase);
    _commit();
  }

  // ---------- pomodoro ----------
  int dur(int phase) =>
      (phase == 0 ? cfg.work : (phase == 1 ? cfg.short : cfg.long)) * 60000;

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  void _rollDay() {
    final t = _today();
    if (pomo.day != t) {
      pomo.day = t;
      pomo.done = 0;
    }
  }

  void _ticker() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTick() {
    if (pomo.running && pomo.endMs <= nowMs()) _complete();
    tick.value++;
  }

  void pomoStart() {
    _rollDay();
    if (pomo.left <= 0) pomo.left = dur(pomo.phase);
    pomo.running = true;
    pomo.endMs = nowMs() + pomo.left;
    Notifier.pomoSchedule(
        DateTime.fromMillisecondsSinceEpoch(pomo.endMs), pomo.phase);
    _ticker();
    _commit();
    tick.value++;
  }

  void pomoPause() {
    pomo.left = pomo.remaining;
    pomo.running = false;
    Notifier.pomoCancel();
    _stop();
    _commit();
    tick.value++;
  }

  void pomoReset() {
    pomo.running = false;
    pomo.left = dur(pomo.phase);
    Notifier.pomoCancel();
    _stop();
    _commit();
    tick.value++;
  }

  void pomoSkip() {
    Notifier.pomoCancel();
    _stop();
    _advance(false);
    _commit();
    tick.value++;
  }

  void _advance(bool count) {
    if (pomo.phase == 0) {
      if (count) pomo.done++;
      pomo.cycle++;
      pomo.phase = pomo.cycle % cfg.every == 0 ? 2 : 1;
    } else {
      pomo.phase = 0;
    }
    pomo.left = dur(pomo.phase);
    pomo.running = false;
  }

  void _complete() {
    _rollDay();
    _advance(true);
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    if (cfg.auto) {
      pomoStart();
    } else {
      _stop();
      _commit();
    }
  }
}
