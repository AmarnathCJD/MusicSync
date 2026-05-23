import 'package:flutter/material.dart';

import '../../data/presets.dart';
import '../../state/app_state.dart';
import '../theme.dart';

class EffectsScreen extends StatelessWidget {
  final AppState state;
  const EffectsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width;
    final crossAxis = width > 720
        ? 3
        : width > 480
            ? 2
            : 2;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 14),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Curated atmospheres',
                  style: t.titleLarge?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a tile to apply. The active scene stays highlighted.',
                  style: t.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxis,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.55,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final p = curatedPresets[i];
                // Presets are const, so identity-compare is the right way to
                // tell whether a tile is the currently-streaming one.
                final active = p.off
                    ? !state.wled.on
                    : identical(state.currentPreset, p);
                return _PresetTile(
                  preset: p,
                  active: active,
                  onTap: () => state.applyPreset(p),
                );
              },
              childCount: curatedPresets.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _PresetTile extends StatefulWidget {
  final EffectPreset preset;
  final bool active;
  final VoidCallback onTap;

  const _PresetTile({
    required this.preset,
    required this.active,
    required this.onTap,
  });

  @override
  State<_PresetTile> createState() => _PresetTileState();
}

class _PresetTileState extends State<_PresetTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.preset;
    final swatch = p.swatch;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: widget.active
                ? AppTones.bg3
                : (_hover ? AppTones.bg2 : AppTones.bg2),
            border: Border.all(
              color: widget.active ? AppTones.accent : AppTones.lineSoft,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _SwatchStack(colors: swatch),
                      const Spacer(),
                      if (widget.active)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTones.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppTones.accent.withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 1.4,
                              color: AppTones.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                          color: AppTones.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.tagline,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTones.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwatchStack extends StatelessWidget {
  final List<Color> colors;
  const _SwatchStack({required this.colors});

  @override
  Widget build(BuildContext context) {
    final count = colors.length.clamp(0, 3);
    return SizedBox(
      width: 14.0 + (count - 1) * 9.0,
      height: 14,
      child: Stack(
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: i * 9.0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i],
                  border: Border.all(color: AppTones.bg1, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: colors[i].withValues(alpha: 0.4),
                      blurRadius: 7,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
