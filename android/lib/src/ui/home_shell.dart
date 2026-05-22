import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'screens/audio_sync_screen.dart';
import 'screens/connection_screen.dart';
import 'screens/controls_screen.dart';
import 'screens/effects_screen.dart';
import 'theme.dart';
import 'widgets/ambient_background.dart';

class HomeShell extends StatefulWidget {
  final AppState state;
  const HomeShell({super.key, required this.state});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _idx = 0;

  static const _tabs = <_TabSpec>[
    _TabSpec('Controls', 'Light & color', Icons.tune_rounded),
    _TabSpec('Effects', 'Presets', Icons.auto_awesome_outlined),
    _TabSpec('Audio', 'Music sync', Icons.graphic_eq_rounded),
    _TabSpec('Device', 'Connection', Icons.dns_outlined),
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
      backgroundColor: AppTones.bg0,
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(state: st, current: _tabs[_idx]),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.015),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    );
                  },
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
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final String hint;
  final IconData icon;
  const _TabSpec(this.label, this.hint, this.icon);
}

class _TopBar extends StatelessWidget {
  final AppState state;
  final _TabSpec current;
  const _TopBar({required this.state, required this.current});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final online = state.info.online;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.hint.toUpperCase(),
                  style: t.labelSmall,
                ),
                const SizedBox(height: 4),
                Text(current.label, style: t.displaySmall),
              ],
            ),
          ),
          _StatusPill(
            online: online,
            name: online ? state.info.name : 'Offline',
          ),
          const SizedBox(width: 8),
          _IconAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onTap: () => state.refreshDevice(),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTones.bg2.withOpacity(0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTones.lineSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTones.textPrimary,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _hover ? AppTones.bg3 : AppTones.bg2.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTones.lineSoft),
            ),
            child: Icon(widget.icon,
                size: 17,
                color: _hover
                    ? AppTones.textPrimary
                    : AppTones.textSecondary),
          ),
        ),
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
      margin: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppTones.bg2,
        border: Border.all(color: AppTones.lineSoft),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          return Expanded(
            child: _BottomItem(
              spec: tabs[i],
              selected: i == index,
              onTap: () => onSelect(i),
            ),
          );
        }),
      ),
    );
  }
}

class _BottomItem extends StatefulWidget {
  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;
  const _BottomItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_BottomItem> createState() => _BottomItemState();
}

class _BottomItemState extends State<_BottomItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active
                ? AppTones.bg3
                : _hover
                    ? AppTones.bg2
                    : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.spec.icon,
                size: 19,
                color: active
                    ? AppTones.accent
                    : _hover
                        ? AppTones.textSecondary
                        : AppTones.textMuted,
              ),
              const SizedBox(height: 5),
              Text(
                widget.spec.label,
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.4,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active
                      ? AppTones.textPrimary
                      : _hover
                          ? AppTones.textSecondary
                          : AppTones.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
