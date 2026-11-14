import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'store.dart';

class PomodoroPage extends StatelessWidget {
  final AppStore store;
  const PomodoroPage(this.store, {super.key});

  static const _names = ['Focus', 'Short break', 'Long break'];
  static const _colors = [
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, store.tick]),
      builder: (context, _) {
        final p = store.pomo;
        final total = store.dur(p.phase);
        final rem = p.remaining;
        final secs = (rem / 1000).ceil();
        final color = _colors[p.phase];
        final progress = (1 - rem / total).clamp(0.0, 1.0).toDouble();
        final every = store.cfg.every;
        final filled = p.phase == 2 ? every : p.cycle % every;
        final time =
            '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';

        return Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_names[p.phase],
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: color)),
                const SizedBox(height: 24),
                SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        color: color,
                        backgroundColor: color.withOpacity(0.15),
                      ),
                      Center(
                        child: Text(
                          time,
                          style: const TextStyle(
                            fontSize: 58,
                            fontWeight: FontWeight.w300,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < every; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                            i < filled ? Icons.circle : Icons.circle_outlined,
                            size: 12,
                            color: color),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 32,
                      tooltip: 'Reset',
                      icon: const Icon(Icons.replay),
                      onPressed: store.pomoReset,
                    ),
                    const SizedBox(width: 20),
                    FloatingActionButton(
                      heroTag: 'pomo',
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      onPressed: p.running ? store.pomoPause : store.pomoStart,
                      child: Icon(
                          p.running ? Icons.pause : Icons.play_arrow,
                          size: 34),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      iconSize: 32,
                      tooltip: 'Skip',
                      icon: const Icon(Icons.skip_next),
                      onPressed: store.pomoSkip,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Completed today: ${p.done}',
                    style: Theme.of(context).textTheme.subtitle1),
              ],
            ),
          ),
        );
      },
    );
  }
}
