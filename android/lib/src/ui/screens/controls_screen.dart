import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/section_card.dart';

class ControlsScreen extends StatelessWidget {
  final AppState state;
  const ControlsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final w = state.wled;
    final col = Color.fromARGB(
      255,
      w.primaryRgb[0],
      w.primaryRgb[1],
      w.primaryRgb[2],
    );
    final hex =
        col.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 40),
      children: [
        _Hero(
          color: col,
          hex: hex,
          on: w.on,
          brightness: w.brightness,
          onTap: () => _openPicker(state, context, col),
          onPowerToggle: () => state.setPower(!w.on),
        ),
        SectionCard(
          title: 'Brightness',
          trailing: _NumBadge(value: w.brightness.toString()),
          child: LabeledSlider(
            label: 'Master',
            value: w.brightness.toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            format: (v) => v.round().toString(),
            onChanged: (v) => state.setBrightness(v.round()),
          ),
        ),
        SectionCard(
          title: 'Effect tuning',
          child: Column(
            children: [
              LabeledSlider(
                label: 'Speed',
                value: w.speed.toDouble(),
                min: 0,
                max: 255,
                divisions: 255,
                format: (v) => v.round().toString(),
                onChanged: (v) => state.setSpeed(v.round()),
              ),
              LabeledSlider(
                label: 'Intensity',
                value: w.intensity.toDouble(),
                min: 0,
                max: 255,
                divisions: 255,
                format: (v) => v.round().toString(),
                onChanged: (v) => state.setIntensity(v.round()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openPicker(AppState state, BuildContext context, Color current) {
    Color picked = current;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pick color', style: Theme.of(ctx).textTheme.titleLarge),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaBorderRadius: BorderRadius.circular(10),
            onColorChanged: (c) => picked = c,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final argb = picked.value;
              final r = (argb >> 16) & 0xFF;
              final g = (argb >> 8) & 0xFF;
              final b = argb & 0xFF;
              state.setColor([r, g, b]);
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final Color color;
  final String hex;
  final bool on;
  final int brightness;
  final VoidCallback onTap;
  final VoidCallback onPowerToggle;

  const _Hero({
    required this.color,
    required this.hex,
    required this.on,
    required this.brightness,
    required this.onTap,
    required this.onPowerToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Brightness influences the visible intensity of the color preview,
    // so the hero subtly reflects the live state.
    final dimFactor = (brightness.clamp(0, 255) / 255.0);
    final preview = on
        ? Color.lerp(AppTones.bg1, color, 0.25 + 0.75 * dimFactor)!
        : AppTones.bg2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          height: 188,
          decoration: BoxDecoration(
            color: preview,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      on ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                        color: on
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onPowerToggle,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.power_settings_new_rounded,
                        size: 18,
                        color: on
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '#$hex',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: Colors.white.withValues(alpha: on ? 0.95 : 0.5),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tap to change primary color',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumBadge extends StatelessWidget {
  final String value;
  const _NumBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(
        fontSize: 13,
        color: AppTones.textPrimary,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
