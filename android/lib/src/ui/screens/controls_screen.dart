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
    final hex = '#${col.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SectionCard(
          title: 'Power',
          trailing: Switch(
            value: w.on,
            onChanged: state.setPower,
          ),
          child: Text(
            w.on ? 'On' : 'Off',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTones.textSecondary,
                ),
          ),
        ),
        const SectionDivider(),
        SectionCard(
          title: 'Brightness',
          trailing: Text(
            w.brightness.toString(),
            style: const TextStyle(
              fontSize: 12.5,
              fontFeatures: [FontFeature.tabularFigures()],
              color: AppTones.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
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
        const SectionDivider(),
        SectionCard(
          title: 'Color',
          trailing: GestureDetector(
            onTap: () => _openPicker(context, col),
            child: Container(
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
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: col,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hex,
                    style: const TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 0.6,
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: AppTones.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: GestureDetector(
            onTap: () => _openPicker(context, col),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: col,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SectionDivider(),
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

  void _openPicker(BuildContext context, Color current) {
    Color picked = current;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Color',
          style: Theme.of(ctx).textTheme.titleLarge,
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaBorderRadius: BorderRadius.circular(4),
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
              state.setColor([picked.red, picked.green, picked.blue]);
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
