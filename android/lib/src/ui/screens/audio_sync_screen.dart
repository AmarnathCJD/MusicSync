import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/section_card.dart';
import '../widgets/vu_meter.dart';

class AudioSyncScreen extends StatelessWidget {
  final AppState state;
  const AudioSyncScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final running = state.mode == SyncMode.audio;
    final lvl = state.lastLevel;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SectionCard(
          title: 'System audio',
          caption: running
              ? 'Capturing system audio and streaming to your WLED.'
              : 'Tap start, then accept Android’s screen-capture prompt. Required to read other apps’ audio. Nothing is recorded.',
          trailing: BeatPip(active: running && lvl.beat),
          child: _SyncButton(
            running: running,
            onTap: () async {
              if (running) {
                await state.stopAudioSync();
              } else {
                final ok = await state.startAudioSync();
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Audio capture permission denied'),
                  ));
                }
              }
            },
          ),
        ),
        const SectionDivider(),
        SectionCard(
          title: 'Spectrum',
          trailing: Text(
            running ? 'LIVE' : 'IDLE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
              color: running ? AppTones.accent : AppTones.textMuted,
            ),
          ),
          child: Column(
            children: [
              VuMeter(label: 'BASS', value: lvl.bass),
              VuMeter(label: 'MID', value: lvl.mid),
              VuMeter(label: 'HIGH', value: lvl.high),
              const SizedBox(height: 6),
              VuMeter(label: 'LEVEL', value: lvl.level),
            ],
          ),
        ),
        const SectionDivider(),
        SectionCard(
          title: 'Visualizer',
          child: Column(
            children: [
              LabeledSlider(
                label: 'Beat punch',
                value: state.settings.beatGain,
                min: 0.0,
                max: 1.5,
                onChanged: (v) {
                  state.settings.beatGain = v;
                  state.saveSettings();
                },
              ),
              LabeledSlider(
                label: 'Hue drift',
                value: state.settings.hueDrift,
                min: 0.0,
                max: 0.08,
                format: (v) => v.toStringAsFixed(3),
                onChanged: (v) {
                  state.settings.hueDrift = v;
                  state.saveSettings();
                },
              ),
              LabeledSlider(
                label: 'Warmth',
                value: state.settings.warmth,
                min: 0.0,
                max: 0.4,
                onChanged: (v) {
                  state.settings.warmth = v;
                  state.saveSettings();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SyncButton extends StatelessWidget {
  final bool running;
  final VoidCallback onTap;
  const _SyncButton({required this.running, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: running ? AppTones.surface : AppTones.textPrimary,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: running ? AppTones.hairline : AppTones.textPrimary,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 16,
                color: running ? AppTones.textPrimary : AppTones.ink,
              ),
              const SizedBox(width: 8),
              Text(
                running ? 'Stop' : 'Start sync',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: running ? AppTones.textPrimary : AppTones.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
