/// Next future DateTime at [h]:[m], optionally on a given weekday (1=Mon..7=Sun).
DateTime nextTime(int h, int m, [int? weekday]) {
  final now = DateTime.now();
  var d = DateTime(now.year, now.month, now.day, h, m);
  for (var i = 0; i < 9; i++) {
    if (d.isAfter(now) && (weekday == null || d.weekday == weekday)) return d;
    d = DateTime(d.year, d.month, d.day + 1, h, m);
  }
  return d;
}

int nowMs() => DateTime.now().millisecondsSinceEpoch;

class Note {
  int id;
  String title;
  String body;
  int color;
  bool pinned;
  int updated;
  Note({
    required this.id,
    this.title = '',
    this.body = '',
    this.color = 0,
    this.pinned = false,
    int? updated,
  }) : updated = updated ?? nowMs();

  Map<String, dynamic> toJson() =>
      {'id': id, 't': title, 'b': body, 'c': color, 'p': pinned, 'u': updated};

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'],
        title: j['t'] ?? '',
        body: j['b'] ?? '',
        color: j['c'] ?? 0,
        pinned: j['p'] ?? false,
        updated: j['u'],
      );
}

class Task {
  int id;
  String title;
  String notes;
  int due; // ms since epoch, 0 = none
  bool remind;
  int prio; // 0 low, 1 normal, 2 high
  int repeat; // 0 none, 1 daily, 2 weekly
  bool done;
  Task({
    required this.id,
    this.title = '',
    this.notes = '',
    this.due = 0,
    this.remind = true,
    this.prio = 1,
    this.repeat = 0,
    this.done = false,
  });

  DateTime? get dueAt =>
      due == 0 ? null : DateTime.fromMillisecondsSinceEpoch(due);
  bool get overdue => !done && due > 0 && due < nowMs();

  Map<String, dynamic> toJson() => {
        'id': id,
        't': title,
        'n': notes,
        'd': due,
        'r': remind,
        'p': prio,
        'rp': repeat,
        'x': done,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'],
        title: j['t'] ?? '',
        notes: j['n'] ?? '',
        due: j['d'] ?? 0,
        remind: j['r'] ?? true,
        prio: j['p'] ?? 1,
        repeat: j['rp'] ?? 0,
        done: j['x'] ?? false,
      );
}

class Alarm {
  int id;
  int hour;
  int minute;
  String label;
  List<int> days; // 1..7 (Mon..Sun); empty = once
  bool enabled;
  int fireAt; // for one-shot alarms
  Alarm({
    required this.id,
    this.hour = 7,
    this.minute = 0,
    this.label = '',
    List<int>? days,
    this.enabled = true,
    this.fireAt = 0,
  }) : days = days ?? [];

  bool get active => enabled && (days.isNotEmpty || fireAt > nowMs());

  DateTime? get next {
    if (!active) return null;
    if (days.isEmpty) return DateTime.fromMillisecondsSinceEpoch(fireAt);
    DateTime? best;
    for (final d in days) {
      final t = nextTime(hour, minute, d);
      if (best == null || t.isBefore(best)) best = t;
    }
    return best;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'h': hour,
        'm': minute,
        'l': label,
        'd': days,
        'e': enabled,
        'f': fireAt,
      };

  factory Alarm.fromJson(Map<String, dynamic> j) => Alarm(
        id: j['id'],
        hour: j['h'] ?? 7,
        minute: j['m'] ?? 0,
        label: j['l'] ?? '',
        days: List<int>.from(j['d'] ?? const []),
        enabled: j['e'] ?? true,
        fireAt: j['f'] ?? 0,
      );
}

class Cfg {
  int theme; // 0 system, 1 light, 2 dark
  int work, short, long, every;
  bool auto, grid;
  Cfg({
    this.theme = 0,
    this.work = 25,
    this.short = 5,
    this.long = 15,
    this.every = 4,
    this.auto = false,
    this.grid = true,
  });

  Map<String, dynamic> toJson() => {
        'th': theme,
        'w': work,
        's': short,
        'l': long,
        'e': every,
        'a': auto,
        'g': grid,
      };

  factory Cfg.fromJson(Map<String, dynamic> j) => Cfg(
        theme: j['th'] ?? 0,
        work: j['w'] ?? 25,
        short: j['s'] ?? 5,
        long: j['l'] ?? 15,
        every: j['e'] ?? 4,
        auto: j['a'] ?? false,
        grid: j['g'] ?? true,
      );
}

class Pomo {
  int phase; // 0 focus, 1 short break, 2 long break
  bool running;
  int endMs;
  int left; // ms remaining while paused
  int cycle; // focus sessions finished in the current set
  int done; // focus sessions finished today
  String day;
  Pomo({
    this.phase = 0,
    this.running = false,
    this.endMs = 0,
    this.left = 25 * 60000,
    this.cycle = 0,
    this.done = 0,
    this.day = '',
  });

  int get remaining =>
      running ? (endMs - nowMs()).clamp(0, 1 << 40).toInt() : left;

  Map<String, dynamic> toJson() => {
        'ph': phase,
        'run': running,
        'end': endMs,
        'left': left,
        'cy': cycle,
        'done': done,
        'day': day,
      };

  factory Pomo.fromJson(Map<String, dynamic> j) => Pomo(
        phase: j['ph'] ?? 0,
        running: j['run'] ?? false,
        endMs: j['end'] ?? 0,
        left: j['left'] ?? 25 * 60000,
        cycle: j['cy'] ?? 0,
        done: j['done'] ?? 0,
        day: j['day'] ?? '',
      );
}
