import 'package:flutter/material.dart';

import '../theme.dart';

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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                letterSpacing: 1.2,
                color: AppTones.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Container(
                height: 4,
                color: AppTones.hairline,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: Container(color: AppTones.textPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 30,
            child: Text(
              '${(v * 100).round()}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontFeatures: [FontFeature.tabularFigures()],
                color: AppTones.textSecondary,
              ),
            ),
          ),
        ],
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
      duration: const Duration(milliseconds: 90),
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppTones.accent : AppTones.hairline,
      ),
    );
  }
}
