import 'package:flutter/material.dart';

import '../theme.dart';

/// A single horizontal level meter, modern media-app style: thin track,
/// gradient fill from dim to accent. Subtle, not loud.
class VuMeter extends StatelessWidget {
  final String label;
  final double value; // 0..1
  final Color? color;

  const VuMeter({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                letterSpacing: 1.4,
                color: AppTones.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(color: AppTones.bg4),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: v,
                      child: Container(color: AppTones.accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 32,
            child: Text(
              '${(v * 100).round()}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11.5,
                fontFeatures: [FontFeature.tabularFigures()],
                color: AppTones.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical reactive bars — small "live preview" of the audio level.
class SpectrumPreview extends StatelessWidget {
  final double bass;
  final double mid;
  final double high;
  final bool active;

  const SpectrumPreview({
    super.key,
    required this.bass,
    required this.mid,
    required this.high,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(18, (i) {
          // distribute bands across bass/mid/high regions
          final region = i < 6 ? bass : (i < 12 ? mid : high);
          // pseudo-randomize per-bar height for organic feel
          final offset = ((i * 37) % 100) / 100.0;
          final v = (region * (0.6 + 0.4 * offset)).clamp(0.05, 1.0);
          return _Bar(value: active ? v : 0.05);
        }),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  const _Bar({required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      width: 4,
      height: 56 * value,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: AppTones.accent,
      ),
    );
  }
}

class BeatPip extends StatelessWidget {
  final bool active;
  const BeatPip({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppTones.accent : AppTones.bg4,
      ),
    );
  }
}
