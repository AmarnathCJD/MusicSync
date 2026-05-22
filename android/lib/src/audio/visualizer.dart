import 'dart:math' as math;
import 'dart:typed_data';

import 'audio_capture.dart';

/// Converts AudioLevel events into per-LED RGB byte strips for UDP DRGB.
/// Mirrors the visualization model from main.py: HSV palette rotation,
/// bass-driven brightness, center-pulse falloff, beat highlight.
class Visualizer {
  Visualizer({required this.ledCount});

  int ledCount;

  // tunables
  double hueDrift = 0.015;
  double warmth = 0.05;
  double beatGain = 0.55;
  double saturationMin = 0.55;
  double smoothingRise = 0.6;
  double smoothingFall = 0.35;
  /// Tint hue (0..1). -1 means "auto" — rotate freely through the spectrum.
  /// When set to a specific hue, output stays near that hue, with mid/high
  /// content only nudging it within a narrow window so the strip looks
  /// distinctly "red" (or whatever).
  double tintHue = -1.0;

  // state
  double _hue = 0.0;
  double _smoothLevel = 0.0;
  double _beatPulse = 0.0;

  void reset() {
    _hue = 0.0;
    _smoothLevel = 0.0;
    _beatPulse = 0.0;
  }

  Uint8List render(AudioLevel a) {
    final n = ledCount;
    final out = Uint8List(n * 3);

    // Smooth the overall level (asymmetric).
    final raw = a.level.clamp(0.0, 1.5);
    final alpha = raw > _smoothLevel ? smoothingRise : smoothingFall;
    _smoothLevel = _smoothLevel + alpha * (raw - _smoothLevel);

    // Hue rotation, biased by mid/high content. If a tint is selected, lock
    // the base hue to it and only nudge slightly so the color stays in
    // family.
    if (tintHue >= 0) {
      _hue = tintHue;
    } else {
      _hue = (_hue + hueDrift + a.mid * 0.004 + a.high * 0.002) % 1.0;
    }

    // Beat pulse decays each frame.
    if (a.beat) _beatPulse = math.min(1.0, _beatPulse + beatGain);
    _beatPulse *= 0.88;

    final brightness = (_smoothLevel * 0.85 + _beatPulse * 0.4).clamp(0.0, 1.0);
    final saturation = (saturationMin + a.mid * 0.4 + warmth).clamp(0.0, 1.0);

    final center = (n - 1) / 2.0;
    final maxDist = center == 0 ? 1.0 : center;

    for (var i = 0; i < n; i++) {
      // distance falloff so the middle pumps with the bass.
      final d = (i - center).abs() / maxDist;
      final fall = math.pow(1.0 - d, 1.6).toDouble();
      final localBass = (a.bass * fall).clamp(0.0, 1.0);

      // hue shifts slightly per LED for a moving rainbow feel.
      // Narrower spread when a tint is selected so the strip stays in family.
      final spread = tintHue >= 0 ? 0.04 : 0.18;
      final h = (_hue + (i / n) * spread) % 1.0;
      final v = (brightness * (0.55 + 0.45 * fall) + localBass * 0.5)
          .clamp(0.0, 1.0);

      final rgb = _hsvToRgb(h, saturation, v);
      out[i * 3] = rgb[0];
      out[i * 3 + 1] = rgb[1];
      out[i * 3 + 2] = rgb[2];
    }
    return out;
  }

  static List<int> _hsvToRgb(double h, double s, double v) {
    final i = (h * 6).floor();
    final f = h * 6 - i;
    final p = v * (1 - s);
    final q = v * (1 - f * s);
    final t = v * (1 - (1 - f) * s);
    double r, g, b;
    switch (i % 6) {
      case 0: r = v; g = t; b = p; break;
      case 1: r = q; g = v; b = p; break;
      case 2: r = p; g = v; b = t; break;
      case 3: r = p; g = q; b = v; break;
      case 4: r = t; g = p; b = v; break;
      default: r = v; g = p; b = q; break;
    }
    return [
      (r * 255).round().clamp(0, 255),
      (g * 255).round().clamp(0, 255),
      (b * 255).round().clamp(0, 255),
    ];
  }
}
