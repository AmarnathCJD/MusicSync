import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/section_card.dart';
import '../widgets/vu_meter.dart';

enum _AudioSource { system, mic }

class AudioSyncScreen extends StatefulWidget {
  final AppState state;
  const AudioSyncScreen({super.key, required this.state});

  @override
  State<AudioSyncScreen> createState() => _AudioSyncScreenState();
}

class _AudioSyncScreenState extends State<AudioSyncScreen> {
  /// Selected source: system audio or microphone. Persisted only in memory —
  /// resets to system on app relaunch.
  _AudioSource _source = _AudioSource.system;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final running = state.mode != SyncMode.off;
    final lvl = state.lastLevel;

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      children: [
        _Hero(
          running: running,
          source: _source,
          beat: lvl.beat,
          bass: lvl.bass,
          mid: lvl.mid,
          high: lvl.high,
          level: lvl.level,
          onTap: () async {
            if (running) {
              await state.stopAudioSync();
            } else {
              final ok = _source == _AudioSource.mic
                  ? await state.startMicSync()
                  : await state.startAudioSync();
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_source == _AudioSource.mic
                      ? 'Microphone permission denied'
                      : 'Audio capture permission denied'),
                ));
              }
            }
          },
          onSourceChanged: running
              ? null
              : (s) => setState(() => _source = s),
        ),
        SectionCard(
          title: 'Live levels',
          trailing: _LiveTag(active: running),
          child: Column(
            children: [
              VuMeter(label: 'BASS', value: lvl.bass),
              VuMeter(label: 'MID', value: lvl.mid),
              VuMeter(label: 'HIGH', value: lvl.high),
              const SizedBox(height: 4),
              VuMeter(label: 'LEVEL', value: lvl.level),
            ],
          ),
        ),
        SectionCard(
          title: 'Color',
          caption: 'Tint the visualizer — Auto cycles through the spectrum',
          child: _TintPicker(
            value: state.settings.audioTintHue,
            onChanged: (h) {
              state.settings.audioTintHue = h;
              state.saveSettings();
            },
          ),
        ),
        SectionCard(
          title: 'Visualizer feel',
          caption: 'Shape how audio drives the lights',
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

class _Hero extends StatelessWidget {
  final bool running;
  final _AudioSource source;
  final bool beat;
  final double bass;
  final double mid;
  final double high;
  final double level;
  final VoidCallback onTap;
  /// null disables the toggle (used while sync is running).
  final ValueChanged<_AudioSource>? onSourceChanged;

  const _Hero({
    required this.running,
    required this.source,
    required this.beat,
    required this.bass,
    required this.mid,
    required this.high,
    required this.level,
    required this.onTap,
    required this.onSourceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: 296,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: running
                ? [AppTones.bloom, AppTones.bg2]
                : [AppTones.bg2, AppTones.bg1],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatePill(running: running, beat: beat),
                const Spacer(),
                Text(
                  '${(level * 100).round()}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTones.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SourceToggle(
              source: source,
              onChanged: onSourceChanged,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SpectrumPreview(
                bass: bass,
                mid: mid,
                high: high,
                active: running,
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color:
                      running ? Colors.black.withValues(alpha: 0.35) : AppTones.accent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      running
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      size: 18,
                      color: running ? AppTones.textPrimary : AppTones.bg0,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      running
                          ? 'Stop sync'
                          : source == _AudioSource.mic
                              ? 'Start mic sync'
                              : 'Start sync',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: running ? AppTones.textPrimary : AppTones.bg0,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceToggle extends StatelessWidget {
  final _AudioSource source;
  final ValueChanged<_AudioSource>? onChanged;
  const _SourceToggle({required this.source, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            _segment(
              context,
              label: 'System',
              icon: Icons.tv_rounded,
              active: source == _AudioSource.system,
              onTap: disabled ? null : () => onChanged!(_AudioSource.system),
            ),
            _segment(
              context,
              label: 'Mic',
              icon: Icons.mic_rounded,
              active: source == _AudioSource.mic,
              onTap: disabled ? null : () => onChanged!(_AudioSource.mic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? Colors.white.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  final bool running;
  final bool beat;
  const _StatePill({required this.running, required this.beat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BeatPip(active: running && beat),
          const SizedBox(width: 8),
          Text(
            running ? 'LIVE' : 'IDLE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
              color: running
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of hue-tint chips plus an Auto option for spectrum rotation.
/// [value] is a hue in [0, 1] for a locked tint, or -1.0 for Auto.
class _TintPicker extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _TintPicker({required this.value, required this.onChanged});

  // Curated tints — names are for tooltips, hues are the visualizer base.
  static const _tints = <_TintOption>[
    _TintOption(hue: 0.00, label: 'Red'),
    _TintOption(hue: 0.08, label: 'Orange'),
    _TintOption(hue: 0.14, label: 'Yellow'),
    _TintOption(hue: 0.33, label: 'Green'),
    _TintOption(hue: 0.50, label: 'Cyan'),
    _TintOption(hue: 0.62, label: 'Blue'),
    _TintOption(hue: 0.76, label: 'Violet'),
    _TintOption(hue: 0.88, label: 'Magenta'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _AutoChip(active: value < 0, onTap: () => onChanged(-1.0)),
        for (final t in _tints)
          _HueChip(
            hue: t.hue,
            label: t.label,
            active: value >= 0 && (value - t.hue).abs() < 0.01,
            onTap: () => onChanged(t.hue),
          ),
      ],
    );
  }
}

class _TintOption {
  final double hue;
  final String label;
  const _TintOption({required this.hue, required this.label});
}

class _AutoChip extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _AutoChip({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Auto — spectrum rotation',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFFE53935),
                Color(0xFFFFEB3B),
                Color(0xFF43A047),
                Color(0xFF00BCD4),
                Color(0xFF1E88E5),
                Color(0xFFAB47BC),
                Color(0xFFE53935),
              ],
            ),
            border: Border.all(
              color: active ? AppTones.accent : Colors.white.withValues(alpha: 0.12),
              width: active ? 2.0 : 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _HueChip extends StatelessWidget {
  final double hue;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _HueChip({
    required this.hue,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = HSVColor.fromAHSV(1.0, hue * 360.0, 0.85, 0.95).toColor();
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: active ? AppTones.accent : Colors.white.withValues(alpha: 0.12),
              width: active ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: active ? 0.55 : 0.30),
                blurRadius: active ? 10 : 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveTag extends StatelessWidget {
  final bool active;
  const _LiveTag({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTones.accent : AppTones.textMuted;
    return Text(
      active ? 'LIVE' : 'IDLE',
      style: TextStyle(
        fontSize: 10,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}
