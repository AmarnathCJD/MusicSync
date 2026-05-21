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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
      itemCount: curatedPresets.length + 1,
      separatorBuilder: (_, i) {
        if (i == 0) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(height: 1, thickness: 1, color: AppTones.hairline),
        );
      },
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              'PRESETS',
              style: t.labelMedium?.copyWith(
                color: AppTones.textMuted,
                letterSpacing: 1.4,
                fontSize: 10.5,
              ),
            ),
          );
        }
        final p = curatedPresets[i - 1];
        final active = state.wled.effect == p.fx;
        return _PresetRow(
          preset: p,
          active: active,
          onTap: () => state.applyPreset(
            fx: p.fx,
            palette: p.palette,
            speed: p.speed,
            intensity: p.intensity,
            color: p.color,
          ),
        );
      },
    );
  }
}

class _PresetRow extends StatelessWidget {
  final EffectPreset preset;
  final bool active;
  final VoidCallback onTap;

  const _PresetRow({
    required this.preset,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          children: [
            _SwatchTrio(colors: preset.swatch),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name,
                    style: t.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppTones.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preset.tagline,
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: const Text(
                'ACTIVE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: AppTones.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwatchTrio extends StatelessWidget {
  final List<Color> colors;
  const _SwatchTrio({required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 14,
      child: Stack(
        children: [
          for (var i = 0; i < colors.length && i < 3; i++)
            Positioned(
              left: i * 11.0,
              top: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i],
                  border: Border.all(color: AppTones.ink, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
