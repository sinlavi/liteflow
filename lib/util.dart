import 'package:flutter/material.dart';

const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String fmtTime(BuildContext c, int h, int m) =>
    MaterialLocalizations.of(c).formatTimeOfDay(
      TimeOfDay(hour: h, minute: m),
      alwaysUse24HourFormat: MediaQuery.of(c).alwaysUse24HourFormat,
    );

String fmtDue(BuildContext c, DateTime d) {
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final days =
      (DateTime(d.year, d.month, d.day).difference(today).inHours / 24).round();
  final day = days == 0
      ? 'Today'
      : days == 1
          ? 'Tomorrow'
          : days == -1
              ? 'Yesterday'
              : MaterialLocalizations.of(c).formatShortDate(d);
  return '$day, ${fmtTime(c, d.hour, d.minute)}';
}

String fmtDur(Duration d) {
  final m = d.inMinutes;
  if (m < 1) return 'less than a minute';
  final days = m ~/ 1440, h = (m % 1440) ~/ 60, mm = m % 60;
  if (days > 0) return '${days}d ${h}h ${mm}m';
  if (h > 0) return '${h}h ${mm}m';
  return '${mm}m';
}

String daysLabel(List<int> days) {
  if (days.isEmpty) return 'Once';
  final s = [...days]..sort();
  if (s.length == 7) return 'Every day';
  if (s.join() == '12345') return 'Weekdays';
  if (s.join() == '67') return 'Weekends';
  return s.map((d) => dayNames[d - 1]).join(', ');
}

class Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const Empty(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).disabledColor),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(color: Theme.of(context).disabledColor)),
          ],
        ),
      );
}
