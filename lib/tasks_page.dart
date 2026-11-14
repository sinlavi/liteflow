import 'package:flutter/material.dart';

import 'models.dart';
import 'notifier.dart';
import 'store.dart';
import 'util.dart';

void openTask(BuildContext c, AppStore s, Task? t) => Navigator.push(
    c, MaterialPageRoute(builder: (_) => TaskEditor(s, t)));

class TasksPage extends StatefulWidget {
  final AppStore store;
  const TasksPage(this.store, {super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  int _f = 0; // 0 active, 1 done, 2 all
  static const _filters = ['Active', 'Done', 'All'];

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final l = s.tasks
            .where((t) => _f == 0 ? !t.done : (_f == 1 ? t.done : true))
            .toList()
          ..sort((a, b) {
            if (a.done != b.done) return a.done ? 1 : -1;
            final ad = a.due == 0 ? 1 << 60 : a.due;
            final bd = b.due == 0 ? 1 << 60 : b.due;
            final c = ad.compareTo(bd);
            return c != 0 ? c : b.prio.compareTo(a.prio);
          });
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_filters[i]),
                        selected: _f == i,
                        onSelected: (_) => setState(() => _f = i),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: l.isEmpty
                  ? const Empty(Icons.check_circle_outline, 'Nothing here')
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: l.length,
                      itemBuilder: (_, i) => _tile(l[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _tile(Task t) {
    final s = widget.store;
    final sub = <String>[
      if (t.dueAt != null) fmtDue(context, t.dueAt!),
      if (t.repeat == 1) 'Daily',
      if (t.repeat == 2) 'Weekly',
    ].join(' · ');
    Widget bg(Alignment a) => Container(
          color: Colors.red,
          alignment: a,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        );
    return Dismissible(
      key: ValueKey(t.id),
      background: bg(Alignment.centerLeft),
      secondaryBackground: bg(Alignment.centerRight),
      onDismissed: (_) {
        s.deleteTask(t.id);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: const Text('Task deleted'),
            action: SnackBarAction(
                label: 'UNDO', onPressed: () => s.saveTask(t)),
          ));
      },
      child: ListTile(
        leading: Checkbox(value: t.done, onChanged: (_) => s.toggleTask(t)),
        title: Text(
          t.title,
          style: t.done
              ? const TextStyle(
                  decoration: TextDecoration.lineThrough, color: Colors.grey)
              : null,
        ),
        subtitle: sub.isEmpty
            ? null
            : Text(sub,
                style: TextStyle(color: t.overdue ? Colors.red : null)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (t.remind && t.due > 0 && !t.done)
              const Icon(Icons.notifications_active, size: 18),
            if (t.prio != 1)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.flag,
                    size: 20,
                    color: t.prio == 2 ? Colors.red : Colors.blueGrey),
              ),
          ],
        ),
        onTap: () => openTask(context, s, t),
      ),
    );
  }
}

class TaskEditor extends StatefulWidget {
  final AppStore store;
  final Task? task;
  const TaskEditor(this.store, this.task, {super.key});

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late final TextEditingController _t, _n;
  DateTime? _due;
  bool _remind = true;
  int _prio = 1;
  int _repeat = 0;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _t = TextEditingController(text: t?.title);
    _n = TextEditingController(text: t?.notes);
    _due = t?.dueAt;
    _remind = t?.remind ?? true;
    _prio = t?.prio ?? 1;
    _repeat = t?.repeat ?? 0;
  }

  @override
  void dispose() {
    _t.dispose();
    _n.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final init = _due ?? now.add(const Duration(hours: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(init),
    );
    if (t == null || !mounted) return;
    setState(() => _due = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  void _save() {
    final title = _t.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a title')));
      return;
    }
    final t = widget.task ?? Task(id: widget.store.newId());
    t.title = title;
    t.notes = _n.text.trim();
    t.due = _due?.millisecondsSinceEpoch ?? 0;
    t.remind = _remind;
    t.prio = _prio;
    t.repeat = _due == null ? 0 : _repeat;
    widget.store.saveTask(t);
    if (t.remind && t.due > 0) Notifier.ensureExact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'New task' : 'Edit task'),
        actions: [
          if (widget.task != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                widget.store.deleteTask(widget.task!.id);
                Navigator.pop(context);
              },
            ),
          IconButton(
              tooltip: 'Save',
              icon: const Icon(Icons.check),
              onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _t,
            autofocus: widget.task == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _n,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(_due == null ? 'No due date' : fmtDue(context, _due!)),
            trailing: _due == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _due = null)),
            onTap: _pickDue,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Remind me'),
            value: _remind && _due != null,
            onChanged: _due == null ? null : (v) => setState(() => _remind = v),
          ),
          const SizedBox(height: 8),
          const Text('Repeat'),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                  label: Text(const ['None', 'Daily', 'Weekly'][i]),
                  selected: _repeat == i,
                  onSelected:
                      _due == null ? null : (_) => setState(() => _repeat = i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Priority'),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                  label: Text(const ['Low', 'Normal', 'High'][i]),
                  selected: _prio == i,
                  onSelected: (_) => setState(() => _prio = i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
