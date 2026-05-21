import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'screens/audio_sync_screen.dart';
import 'screens/connection_screen.dart';
import 'screens/controls_screen.dart';
import 'screens/effects_screen.dart';
import 'theme.dart';

class HomeShell extends StatefulWidget {
  final AppState state;
  const HomeShell({super.key, required this.state});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _idx = 0;

  static const _tabs = <_TabSpec>[
    _TabSpec('Controls', Icons.tune_rounded),
    _TabSpec('Effects', Icons.bubble_chart_outlined),
    _TabSpec('Audio', Icons.graphic_eq_rounded),
    _TabSpec('Device', Icons.dns_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    final pages = [
      ControlsScreen(state: st),
      EffectsScreen(state: st),
      AudioSyncScreen(state: st),
      ConnectionScreen(state: st),
    ];

    return Scaffold(
      backgroundColor: AppTones.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(state: st, title: _tabs[_idx].label),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(_idx),
                  child: pages[_idx],
                ),
              ),
            ),
            _BottomBar(
              tabs: _tabs,
              index: _idx,
              onSelect: (i) => setState(() => _idx = i),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  const _TabSpec(this.label, this.icon);
}

class _Header extends StatelessWidget {
  final AppState state;
  final String title;
  const _Header({required this.state, required this.title});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final online = state.info.online;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTones.hairline, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MusicSync',
                  style: t.labelSmall?.copyWith(
                    letterSpacing: 1.4,
                    color: AppTones.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(title, style: t.displaySmall),
              ],
            ),
          ),
          _StatusPill(
            online: online,
            name: online ? state.info.name : 'Offline',
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Refresh',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh_rounded,
                size: 18, color: AppTones.textSecondary),
            onPressed: () => state.refreshDevice(),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool online;
  final String name;
  const _StatusPill({required this.online, required this.name});

  @override
  Widget build(BuildContext context) {
    final color = online ? AppTones.positive : AppTones.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTones.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTones.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            name,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppTones.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final List<_TabSpec> tabs;
  final int index;
  final ValueChanged<int> onSelect;
  const _BottomBar({
    required this.tabs,
    required this.index,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(8, 6, 8, 6 + bottomInset),
      decoration: const BoxDecoration(
        color: AppTones.ink,
        border: Border(top: BorderSide(color: AppTones.hairline, width: 1)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = i == index;
          final t = tabs[i];
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t.icon,
                      size: 19,
                      color: selected
                          ? AppTones.textPrimary
                          : AppTones.textMuted,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.3,
                        fontWeight:
                            selected ? FontWeight.w500 : FontWeight.w400,
                        color: selected
                            ? AppTones.textPrimary
                            : AppTones.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
