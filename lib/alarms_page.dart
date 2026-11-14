import 'package:flutter/material.dart';

import 'models.dart';
import 'notifier.dart';
import 'store.dart';
import 'util.dart';

Future<void> editAlarm(BuildContext c, AppStore s, Alarm? a) =>
    showModalBottomSheet<void>(
      context: c,
      isScrollControlled: true,
      builder: (_) => AlarmSheet(s, a),
    );

class AlarmsPage extends StatelessWidget {
  final AppStore store;
  const AlarmsPage(this.store, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final l = [...store.alarms]..sort((a, b) =>
            (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
        DateTime? next;
        for (final a in l) {
          final n = a.next;
          if (n != null && (next == null || n.isBefore(next))) next = n;
        }
        if (l.isEmpty) return const Empty(Icons.alarm, 'No alarms yet');
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: l.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  next == null
                      ? 'No alarms set'
                      : 'Next alarm in ${fmtDur(next.difference(DateTime.now()))}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            }
            return _tile(context, l[i - 1]);
          },
        );
      },
    );
  }

  Widget _tile(BuildContext context, Alarm a) {
    final on = a.active;
    final muted = on ? null : Theme.of(context).disabledColor;
    return Dismissible(
      key: ValueKey(a.id),
      background: Container(color: Colors.red),
      onDismissed: (_) {
        store.deleteAlarm(a.id);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: const Text('Alarm deleted'),
            action:
                SnackBarAction(label: 'UNDO', onPressed: () => store.saveAlarm(a)),
          ));
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          onTap: () => editAlarm(context, store, a),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fmtTime(context, a.hour, a.minute),
                          style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w300,
                              color: muted)),
                      Text(
                        [if (a.label.isNotEmpty) a.label, daysLabel(a.days)]
                            .join(' · '),
                        style: TextStyle(color: muted),
                      ),
                    ],
                  ),
                ),
                Switch(value: on, onChanged: (_) => store.toggleAlarm(a)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AlarmSheet extends StatefulWidget {
  final AppStore store;
  final Alarm? alarm;
  const AlarmSheet(this.store, this.alarm, {super.key});

  @override
  State<AlarmSheet> createState() => _AlarmSheetState();
}

class _AlarmSheetState extends State<AlarmSheet> {
  late int _h, _m;
  late Set<int> _days;
  late final TextEditingController _l;

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _h = a?.hour ?? 7;
    _m = a?.minute ?? 0;
    _days = Set<int>.from(a?.days ?? const <int>[]);
    _l = TextEditingController(text: a?.label);
  }

  @override
  void dispose() {
    _l.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final r = await showTimePicker(
        context: context, initialTime: TimeOfDay(hour: _h, minute: _m));
    if (r != null && mounted) {
      setState(() {
        _h = r.hour;
        _m = r.minute;
      });
    }
  }

  void _save() {
    final a = widget.alarm ?? Alarm(id: widget.store.newId());
    a.hour = _h;
    a.minute = _m;
    a.label = _l.text.trim();
    a.days = _days.toList()..sort();
    a.enabled = true;
    widget.store.saveAlarm(a);
    Notifier.ensureExact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton(
                onPressed: _pickTime,
                child: Text(fmtTime(context, _h, _m),
                    style: const TextStyle(
                        fontSize: 52, fontWeight: FontWeight.w300)),
              ),
              TextField(
                controller: _l,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Label', prefixIcon: Icon(Icons.label_outline)),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(
                      label: Text(dayNames[i]),
                      selected: _days.contains(i + 1),
                      onSelected: (v) => setState(
                          () => v ? _days.add(i + 1) : _days.remove(i + 1)),
                    ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                      onPressed: () => setState(() => _days = {1, 2, 3, 4, 5}),
                      child: const Text('Weekdays')),
                  TextButton(
                      onPressed: () =>
                          setState(() => _days = {1, 2, 3, 4, 5, 6, 7}),
                      child: const Text('Every day')),
                  TextButton(
                      onPressed: () => setState(() => _days = <int>{}),
                      child: const Text('Once')),
                ],
              ),
              Row(
                children: [
                  if (widget.alarm != null)
                    TextButton(
                      onPressed: () {
                        widget.store.deleteAlarm(widget.alarm!.id);
                        Navigator.pop(context);
                      },
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  const Spacer(),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  ElevatedButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
