import 'package:flutter/material.dart';

import 'notifier.dart';
import 'store.dart';

class SettingsPage extends StatelessWidget {
  final AppStore store;
  const SettingsPage(this.store, {super.key});

  Widget _header(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(t,
            style: TextStyle(
                color: Theme.of(c).colorScheme.primary,
                fontWeight: FontWeight.bold)),
      );

  Widget _stepper(String label, int v, int min, int max,
      void Function(int) set, String suffix) {
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: v > min ? () => set(v - 1) : null),
          SizedBox(
              width: 56,
              child: Text('$v$suffix', textAlign: TextAlign.center)),
          IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: v < max ? () => set(v + 1) : null),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final c = store.cfg;
          return ListView(
            children: [
              _header(context, 'Appearance'),
              for (var i = 0; i < 3; i++)
                RadioListTile<int>(
                  title: Text(const ['System default', 'Light', 'Dark'][i]),
                  value: i,
                  groupValue: c.theme,
                  onChanged: (v) => store.updateCfg((c) => c.theme = v ?? 0),
                ),
              SwitchListTile(
                title: const Text('Notes as grid'),
                value: c.grid,
                onChanged: (v) => store.updateCfg((c) => c.grid = v),
              ),
              _header(context, 'Pomodoro'),
              _stepper('Focus', c.work, 1, 120,
                  (v) => store.updateCfg((c) => c.work = v), ' min'),
              _stepper('Short break', c.short, 1, 30,
                  (v) => store.updateCfg((c) => c.short = v), ' min'),
              _stepper('Long break', c.long, 1, 60,
                  (v) => store.updateCfg((c) => c.long = v), ' min'),
              _stepper('Long break every', c.every, 2, 8,
                  (v) => store.updateCfg((c) => c.every = v), ''),
              SwitchListTile(
                title: const Text('Auto-start next phase'),
                value: c.auto,
                onChanged: (v) => store.updateCfg((c) => c.auto = v),
              ),
              _header(context, 'Reminders & alarms'),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Grant notification permissions'),
                subtitle: const Text(
                    'Needed for reminders, alarms and the timer.'),
                onTap: () async {
                  await Notifier.requestNotifications();
                  await Notifier.ensureExact();
                },
              ),
              const ListTile(
                leading: Icon(Icons.battery_alert_outlined),
                title: Text('Alarms not ringing?'),
                subtitle: Text(
                    'Some phones (Xiaomi, Huawei, Samsung…) kill background apps. '
                    'Set battery usage for Liteflow to "Unrestricted" in system settings.'),
              ),
            ],
          );
        },
      ),
    );
  }
}
