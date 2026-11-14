import 'package:flutter/material.dart';

import 'alarms_page.dart';
import 'notes_page.dart';
import 'notifier.dart';
import 'pomodoro_page.dart';
import 'settings_page.dart';
import 'store.dart';
import 'tasks_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifier.init();
  final store = AppStore();
  await store.load();
  runApp(App(store));
}

class App extends StatelessWidget {
  final AppStore store;
  const App(this.store, {super.key});

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: false, // Material 2
        brightness: b,
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      );

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: store.theme,
        builder: (_, t, __) => MaterialApp(
          title: 'Liteflow',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: ThemeMode.values[t],
          home: Home(store),
        ),
      );
}

class Home extends StatefulWidget {
  final AppStore store;
  const Home(this.store, {super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int _i = 0;
  static const _titles = ['Notes', 'Tasks', 'Alarms', 'Focus'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Notifier.requestNotifications());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.store.onResume();
  }

  Widget _body() {
    final s = widget.store;
    switch (_i) {
      case 0:
        return NotesPage(s);
      case 1:
        return TasksPage(s);
      case 2:
        return AlarmsPage(s);
      default:
        return PomodoroPage(s);
    }
  }

  Widget? _fab() {
    final s = widget.store;
    switch (_i) {
      case 0:
        return FloatingActionButton(
          heroTag: 'fab',
          tooltip: 'New note',
          onPressed: () => openNote(context, s, null),
          child: const Icon(Icons.add),
        );
      case 1:
        return FloatingActionButton(
          heroTag: 'fab',
          tooltip: 'New task',
          onPressed: () => openTask(context, s, null),
          child: const Icon(Icons.add),
        );
      case 2:
        return FloatingActionButton(
          heroTag: 'fab',
          tooltip: 'New alarm',
          onPressed: () => editAlarm(context, s, null),
          child: const Icon(Icons.alarm_add),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_titles[_i]),
          actions: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SettingsPage(widget.store)),
              ),
            ),
          ],
        ),
        body: _body(),
        floatingActionButton: _fab(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _i,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => setState(() => _i = i),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.sticky_note_2_outlined),
                activeIcon: Icon(Icons.sticky_note_2),
                label: 'Notes'),
            BottomNavigationBarItem(
                icon: Icon(Icons.check_circle_outline),
                activeIcon: Icon(Icons.check_circle),
                label: 'Tasks'),
            BottomNavigationBarItem(
                icon: Icon(Icons.alarm), label: 'Alarms'),
            BottomNavigationBarItem(
                icon: Icon(Icons.timer_outlined),
                activeIcon: Icon(Icons.timer),
                label: 'Focus'),
          ],
        ),
      );
}
