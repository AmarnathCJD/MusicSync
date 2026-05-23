import 'package:flutter/material.dart';

import '../theme.dart';

/// Borderless section. Separation comes from generous spacing + a quiet header.
class SectionCard extends StatelessWidget {
  final String title;
  final String? caption;
  final Widget child;
  final Widget? trailing;

  /// kept for backwards compatibility; ignored visually.
  final IconData? icon;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.caption,
    this.trailing,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: t.labelSmall?.copyWith(
                        fontSize: 10.5,
                        letterSpacing: 1.6,
                        color: AppTones.textMuted,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 4),
                      Text(caption!, style: t.bodyMedium),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? format;
  final ValueChanged<double> onChanged;

  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTones.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                format?.call(value) ?? value.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 13,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: AppTones.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackShape: const _RichTrackShape(),
              trackHeight: 6,
              thumbShape: const _GlowThumbShape(),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              overlayColor: AppTones.accent.withValues(alpha: 0.12),
              activeTrackColor: AppTones.accent,
              inactiveTrackColor: AppTones.bg3,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped track. Inactive side is a soft tonal fill, active side is a
/// horizontal gradient from a deeper accent at left to bright accent at the
/// thumb, giving the slider visible "weight" without shouting.
class _RichTrackShape extends SliderTrackShape {
  const _RichTrackShape();

  static const double _height = 6.0;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackTop = offset.dy + (parentBox.size.height - _height) / 2;
    return Rect.fromLTWH(
      offset.dx,
      trackTop,
      parentBox.size.width,
      _height,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final radius = Radius.circular(rect.height / 2);

    // Inactive: tonal track that sits on the section background.
    final inactive = Paint()..color = AppTones.bg3;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      inactive,
    );

    // Active: gradient from dim accent → bright accent at the thumb.
    final activeRect =
        Rect.fromLTRB(rect.left, rect.top, thumbCenter.dx, rect.bottom);
    if (activeRect.width > 0) {
      final active = Paint()
        ..shader = LinearGradient(
          colors: [
            AppTones.accentDim,
            AppTones.accent,
          ],
        ).createShader(activeRect);
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, radius),
        active,
      );
    }
  }
}

/// Two-layer thumb: a soft halo behind a crisp accent-bordered disc.
class _GlowThumbShape extends SliderComponentShape {
  const _GlowThumbShape();

  static const double _radius = 8.0;
  static const double _haloRadius = 14.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_haloRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    // Soft glow halo
    final halo = Paint()
      ..color = AppTones.accent.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, _haloRadius, halo);
    // Outer ring
    final ring = Paint()..color = AppTones.accent;
    canvas.drawCircle(center, _radius, ring);
    // Inner light disc gives the thumb its "pressable" look
    final inner = Paint()..color = AppTones.bg0;
    canvas.drawCircle(center, _radius - 2.5, inner);
    final core = Paint()..color = AppTones.accent;
    canvas.drawCircle(center, _radius - 4.5, core);
  }
}

/// A thin section header used between sub-groups inside a panel-less screen.
class GroupHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const GroupHeader({super.key, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10.5,
                letterSpacing: 1.6,
                color: AppTones.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
