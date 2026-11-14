import 'dart:async';

import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';
import 'util.dart';

const noteColors = <Color?>[
  null,
  Color(0xFFFFF59D),
  Color(0xFFA5D6A7),
  Color(0xFF90CAF9),
  Color(0xFFF48FB1),
  Color(0xFFCE93D8),
  Color(0xFFFFCC80),
  Color(0xFF80DEEA),
];

void openNote(BuildContext c, AppStore s, Note? n) => Navigator.push(
    c, MaterialPageRoute(builder: (_) => NoteEditor(s, n)));

class NotesPage extends StatefulWidget {
  final AppStore store;
  const NotesPage(this.store, {super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  String _q = '';

  Widget _card(Note n) {
    final c = noteColors[n.color];
    final fg = c == null ? null : Colors.black87;
    return Card(
      color: c,
      margin: const EdgeInsets.all(4),
      child: InkWell(
        onTap: () => openNote(context, widget.store, n),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (n.pinned) Icon(Icons.push_pin, size: 16, color: fg),
              if (n.title.isNotEmpty)
                Text(n.title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16, color: fg)),
              if (n.title.isNotEmpty && n.body.isNotEmpty)
                const SizedBox(height: 4),
              if (n.body.isNotEmpty)
                Text(n.body,
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final l = s.notes
            .where((n) =>
                _q.isEmpty ||
                n.title.toLowerCase().contains(_q) ||
                n.body.toLowerCase().contains(_q))
            .toList()
          ..sort((a, b) => a.pinned != b.pinned
              ? (a.pinned ? -1 : 1)
              : b.updated.compareTo(a.updated));

        Widget content;
        if (s.cfg.grid) {
          final left = <Widget>[], right = <Widget>[];
          for (var i = 0; i < l.length; i++) {
            (i.isEven ? left : right).add(_card(l[i]));
          }
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: left)),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: right)),
            ],
          );
        } else {
          content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: l.map(_card).toList());
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search notes',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: l.isEmpty
                  ? const Empty(Icons.sticky_note_2_outlined, 'No notes yet')
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 88),
                      child: content,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class NoteEditor extends StatefulWidget {
  final AppStore store;
  final Note? note;
  const NoteEditor(this.store, this.note, {super.key});

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final Note _n;
  late final TextEditingController _t, _b;
  Timer? _deb;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _n = widget.note ?? Note(id: widget.store.newId());
    _t = TextEditingController(text: _n.title);
    _b = TextEditingController(text: _n.body);
  }

  @override
  void dispose() {
    _deb?.cancel();
    _t.dispose();
    _b.dispose();
    super.dispose();
  }

  void _commit() {
    if (_deleted) return;
    _n.title = _t.text.trim();
    _n.body = _b.text.trimRight();
    if (_n.title.isEmpty && _n.body.isEmpty) {
      widget.store.deleteNote(_n.id);
    } else {
      widget.store.saveNote(_n);
    }
  }

  void _changed() {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 800), _commit);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete note?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && mounted) {
      _deleted = true;
      widget.store.deleteNote(_n.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = noteColors[_n.color];
    final fg = bg == null ? null : Colors.black87;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) => _commit(),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Pin',
              icon: Icon(
                  _n.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () {
                setState(() => _n.pinned = !_n.pinned);
                _changed();
              },
            ),
            IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _t,
                  onChanged: (_) => _changed(),
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: fg),
                  decoration: const InputDecoration(
                      hintText: 'Title', border: InputBorder.none),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _b,
                    onChanged: (_) => _changed(),
                    autofocus: widget.note == null,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: fg),
                    decoration: const InputDecoration(
                        hintText: 'Note', border: InputBorder.none),
                  ),
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: noteColors.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () {
                      setState(() => _n.color = i);
                      _changed();
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: noteColors[i] ?? Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _n.color == i
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          width: _n.color == i ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
