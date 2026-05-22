import 'dart:math' as math;
import 'dart:typed_data';

import 'anim_utils.dart';

/// One frame of a preset animation.
///
/// Implementations fill [out] (length n*3, RGB triples) for time [tSec]
/// since the renderer started. Implementations should be stateless across
/// renders where possible — for stateful effects (sparks, flickers,
/// twinkles), use [tSec] + per-LED hashing so the result is deterministic
/// and reproducible regardless of frame rate.
abstract class PresetAnim {
  String get id;
  void render(double tSec, Uint8List out, int n);
}

// ============================================================
// Cinematic / atmospheric
// ============================================================

class PacificaAnim implements PresetAnim {
  @override
  String get id => 'pacifica';

  @override
  void render(double t, Uint8List out, int n) {
    // Three slow sine layers blended; deep teal → navy gradient.
    const deep = [0, 18, 48];
    const mid = [0, 80, 130];
    const crest = [60, 200, 220];
    for (var i = 0; i < n; i++) {
      final x = i / n;
      final a = math.sin(x * 6.0 + t * 0.7);
      final b = math.sin(x * 11.0 - t * 0.4);
      final c = math.sin(x * 17.0 + t * 1.1);
      final v = ((a + b + c) / 3.0 + 1.0) * 0.5; // 0..1
      final col = gradient([0.0, 0.55, 1.0], [deep, mid, crest], v);
      writeRgb(out, i, col[0], col[1], col[2]);
    }
  }
}

class AuroraAnim implements PresetAnim {
  @override
  String get id => 'aurora';

  @override
  void render(double t, Uint8List out, int n) {
    for (var i = 0; i < n; i++) {
      final x = i / n;
      // two slow moving bands
      final a = math.sin(x * 3.0 + t * 0.5);
      final b = math.sin(x * 7.0 - t * 0.3 + 1.7);
      final band = (a * 0.6 + b * 0.4 + 1.0) * 0.5; // 0..1
      // hue green→cyan→violet
      final h = 0.30 + band * 0.45; // 0.30..0.75
      final v = 0.25 + 0.55 * band;
      hsvToRgb(h, 0.85, v, out, i);
    }
  }
}

class NebulaAnim implements PresetAnim {
  @override
  String get id => 'nebula';

  @override
  void render(double t, Uint8List out, int n) {
    for (var i = 0; i < n; i++) {
      final x = i / n;
      final a = math.sin(x * 4.0 + t * 0.6);
      final b = math.sin(x * 9.0 - t * 0.2);
      final v = (a + b + 2) / 4.0;
      // magenta-cyan band shift
      final h = 0.78 + 0.18 * math.sin(t * 0.1 + x * 2.0);
      hsvToRgb(h % 1.0, 0.9, 0.35 + 0.55 * v, out, i);
    }
  }
}

class GalaxyAnim implements PresetAnim {
  @override
  String get id => 'galaxy';

  @override
  void render(double t, Uint8List out, int n) {
    // Indigo base + per-LED sparse twinkles.
    for (var i = 0; i < n; i++) {
      // base
      var r = 8, g = 4, b = 30;
      // twinkle: each LED has its own phase via hash, blinks slowly.
      final phase = noise1D(i.toDouble() * 0.13, seed: 7) * 12.0;
      final s = math.sin(t * 1.2 + phase);
      if (s > 0.92) {
        final k = ((s - 0.92) / 0.08).clamp(0.0, 1.0);
        final w = (255 * k).round();
        r = (r + w).clamp(0, 255);
        g = (g + w).clamp(0, 255);
        b = (b + w).clamp(0, 255);
      }
      writeRgb(out, i, r, g, b);
    }
  }
}

// ============================================================
// Fire family
// ============================================================

class EmbersAnim implements PresetAnim {
  @override
  String get id => 'embers';

  @override
  void render(double t, Uint8List out, int n) {
    // Per-LED dim warm base modulated by slow noise + occasional brighter spark.
    for (var i = 0; i < n; i++) {
      final base = 0.25 + 0.35 * noise1D(i * 0.4 + t * 0.6, seed: 11);
      final spark = noise1D(i * 1.7 + t * 1.3, seed: 23);
      final hot = spark > 0.92 ? (spark - 0.92) * 10.0 : 0.0;
      final v = (base + hot * 0.6).clamp(0.0, 1.0);
      // warm: 100% R, ~30% G, 0% B, with hot pushing toward yellow
      final r = (255 * v).round();
      final g = (90 * v + 60 * hot).round().clamp(0, 255);
      final b = (10 * hot).round().clamp(0, 255);
      writeRgb(out, i, r, g, b);
    }
  }
}

class FireAnim implements PresetAnim {
  @override
  String get id => 'fire';

  @override
  void render(double t, Uint8List out, int n) {
    // Per-LED flame model with directional bias: base of the strip (i=0)
    // burns hotter than the tip. Middle ground between Embers and Inferno.
    for (var i = 0; i < n; i++) {
      // Hotter near the base, cooler near the tip.
      final pos = 1.0 - (i / n); // 1 at base → 0 at tip
      final heat = 0.55 + 0.30 * pos;
      final base = heat * (0.65 + 0.35 * noise1D(i * 0.5 + t * 1.1, seed: 17));
      final spark = noise1D(i * 1.9 + t * 2.0, seed: 29);
      final hot = spark > 0.84 ? (spark - 0.84) * 6.0 : 0.0;
      final v = (base + hot * 0.55 * pos).clamp(0.0, 1.0);
      final r = (255 * v).round();
      final g = (115 * v + 80 * hot * pos).round().clamp(0, 255);
      final b = (20 * hot * pos).round().clamp(0, 255);
      writeRgb(out, i, r, g, b);
    }
  }
}

class InfernoAnim implements PresetAnim {
  @override
  String get id => 'inferno';

  @override
  void render(double t, Uint8List out, int n) {
    // Faster, brighter, more chaotic flames.
    for (var i = 0; i < n; i++) {
      final base = 0.55 + 0.35 * noise1D(i * 0.6 + t * 1.6, seed: 31);
      final spark = noise1D(i * 2.3 + t * 3.0, seed: 47);
      final hot = spark > 0.78 ? (spark - 0.78) * 4.5 : 0.0;
      final v = (base + hot * 0.7).clamp(0.0, 1.0);
      final r = (255 * v).round();
      final g = (140 * v + 100 * hot).round().clamp(0, 255);
      final b = (35 * hot).round().clamp(0, 255);
      writeRgb(out, i, r, g, b);
    }
  }
}

class CandleAnim implements PresetAnim {
  @override
  String get id => 'candle';

  @override
  void render(double t, Uint8List out, int n) {
    // Whole-strip flicker around warm orange.
    final flicker = 0.7 + 0.30 * noise1D(t * 6.0, seed: 5);
    final r = (255 * flicker).round();
    final g = (90 * flicker).round();
    final b = (15 * flicker).round();
    for (var i = 0; i < n; i++) {
      writeRgb(out, i, r, g, b);
    }
  }
}

class CandelabraAnim implements PresetAnim {
  @override
  String get id => 'candelabra';

  @override
  void render(double t, Uint8List out, int n) {
    // Each LED flickers independently.
    for (var i = 0; i < n; i++) {
      final flicker = 0.55 + 0.40 * noise1D(t * 5.0 + i * 1.3, seed: 9);
      final r = (255 * flicker).round();
      final g = (95 * flicker).round();
      final b = (18 * flicker).round();
      writeRgb(out, i, r, g, b);
    }
  }
}

// ============================================================
// Day cycle
// ============================================================

class SunriseAnim implements PresetAnim {
  @override
  String get id => 'sunrise';

  @override
  void render(double t, Uint8List out, int n) {
    // 25-second cycle: deep red → orange → yellow → white → loop.
    const period = 25.0;
    final f = (t % period) / period;
    // stages
    const c0 = [40, 0, 0];      // deep red
    const c1 = [255, 60, 0];    // orange
    const c2 = [255, 200, 40];  // yellow
    const c3 = [255, 245, 220]; // warm white
    final col = gradient(
        [0.0, 0.35, 0.7, 1.0], [c0, c1, c2, c3], f);
    for (var i = 0; i < n; i++) {
      writeRgb(out, i, col[0], col[1], col[2]);
    }
  }
}

class SunsetAnim implements PresetAnim {
  @override
  String get id => 'sunset';

  @override
  void render(double t, Uint8List out, int n) {
    // Reverse-ish journey, longer dwell in warm tones.
    const period = 28.0;
    final f = (t % period) / period;
    const c0 = [255, 230, 160]; // late afternoon
    const c1 = [255, 130, 30];  // orange
    const c2 = [200, 30, 90];   // magenta horizon
    const c3 = [25, 10, 60];    // deep blue night
    final col = gradient(
        [0.0, 0.4, 0.75, 1.0], [c0, c1, c2, c3], f);
    for (var i = 0; i < n; i++) {
      writeRgb(out, i, col[0], col[1], col[2]);
    }
  }
}

class MoonlightAnim implements PresetAnim {
  @override
  String get id => 'moonlight';

  @override
  void render(double t, Uint8List out, int n) {
    // Slow breathe between cool dim and cool slightly-brighter.
    final v = 0.35 + 0.18 * math.sin(t * 0.6); // ~10s breath
    final r = (180 * v).round();
    final g = (200 * v).round();
    final b = (255 * v).round();
    for (var i = 0; i < n; i++) {
      writeRgb(out, i, r, g, b);
    }
  }
}

// ============================================================
// Cold / winter
// ============================================================

class SnowfallAnim implements PresetAnim {
  @override
  String get id => 'snowfall';

  @override
  void render(double t, Uint8List out, int n) {
    // Cool blue base + drifting white twinkles per-LED.
    for (var i = 0; i < n; i++) {
      // base: dim cool blue
      var r = 20, g = 40, b = 90;
      // twinkle drifting "down" the strip
      final phase = (i / n) * 6.0 + t * 1.4;
      final tw = noise1D(phase + i * 0.07, seed: 41);
      if (tw > 0.85) {
        final k = ((tw - 0.85) / 0.15);
        r = (r + 220 * k).round().clamp(0, 255);
        g = (g + 215 * k).round().clamp(0, 255);
        b = (b + 165 * k).round().clamp(0, 255);
      }
      writeRgb(out, i, r, g, b);
    }
  }
}

class FrostbiteAnim implements PresetAnim {
  @override
  String get id => 'frostbite';

  @override
  void render(double t, Uint8List out, int n) {
    // Cyan base + sharper, faster shimmer.
    for (var i = 0; i < n; i++) {
      var r = 0, g = 80, b = 110;
      final phase = i * 0.3 + t * 3.5;
      final shimmer = noise1D(phase, seed: 53);
      if (shimmer > 0.78) {
        final k = (shimmer - 0.78) / 0.22;
        r = (200 * k).round().clamp(0, 255);
        g = (g + 175 * k).round().clamp(0, 255);
        b = (b + 145 * k).round().clamp(0, 255);
      }
      writeRgb(out, i, r, g, b);
    }
  }
}

// ============================================================
// Vibe / texture
// ============================================================

class LavaLampAnim implements PresetAnim {
  @override
  String get id => 'lava';

  @override
  void render(double t, Uint8List out, int n) {
    // 3 large smooth bumps drifting slowly along the strip.
    for (var i = 0; i < n; i++) {
      final x = i / n;
      double m = 0;
      m += math.exp(-math.pow((x - (0.5 + 0.35 * math.sin(t * 0.20))) * 4, 2));
      m += math.exp(-math.pow((x - (0.5 + 0.40 * math.sin(t * 0.13 + 2.0))) * 4, 2));
      m += math.exp(-math.pow((x - (0.5 + 0.30 * math.sin(t * 0.27 + 4.1))) * 4, 2));
      m = m.clamp(0.0, 1.2);
      // hue between orange (0.07) and magenta (0.90)
      final h = (0.05 + 0.85 * (m / 1.2)) % 1.0;
      hsvToRgb(h, 0.95, 0.35 + 0.55 * (m / 1.2), out, i);
    }
  }
}

class TropicsAnim implements PresetAnim {
  @override
  String get id => 'tropics';

  @override
  void render(double t, Uint8List out, int n) {
    // Cyan / yellow / coral wave drift.
    const cyan = [0, 200, 220];
    const yellow = [255, 220, 60];
    const coral = [255, 110, 70];
    for (var i = 0; i < n; i++) {
      final x = i / n;
      final v = (math.sin(x * 5.0 + t * 0.9) + 1) * 0.5;
      List<int> col;
      if (v < 0.5) {
        col = lerpRgb(cyan, yellow, v / 0.5);
      } else {
        col = lerpRgb(yellow, coral, (v - 0.5) / 0.5);
      }
      writeRgb(out, i, col[0], col[1], col[2]);
    }
  }
}

class RainforestAnim implements PresetAnim {
  @override
  String get id => 'rainforest';

  @override
  void render(double t, Uint8List out, int n) {
    // Deep green base with soft yellow-green dappled patches.
    for (var i = 0; i < n; i++) {
      final patch = noise1D(i * 0.18 + t * 0.4, seed: 67);
      final r = (30 + 120 * patch).round().clamp(0, 255);
      final g = (100 + 130 * patch).round().clamp(0, 255);
      final b = (10 + 30 * patch).round().clamp(0, 255);
      writeRgb(out, i, r, g, b);
    }
  }
}

class VaporAnim implements PresetAnim {
  @override
  String get id => 'vapor';

  @override
  void render(double t, Uint8List out, int n) {
    // Pastel plasma: pink/cyan/violet wash.
    for (var i = 0; i < n; i++) {
      final x = i / n;
      final a = math.sin(x * 4.0 + t * 0.7);
      final b = math.sin(x * 9.0 - t * 0.4 + 2.0);
      final c = math.sin(x * 13.0 + t * 0.3 + 4.0);
      final v = (a + b + c) / 3.0; // -1..1
      final h = (0.75 + 0.20 * v) % 1.0; // around magenta
      hsvToRgb(h, 0.45, 0.55 + 0.25 * (v + 1) / 2, out, i);
    }
  }
}

class PlasmaAnim implements PresetAnim {
  @override
  String get id => 'plasma';

  @override
  void render(double t, Uint8List out, int n) {
    for (var i = 0; i < n; i++) {
      final x = i / n;
      final a = math.sin(x * 6.0 + t * 1.5);
      final b = math.sin(x * 13.0 - t * 1.1 + 1.7);
      final c = math.sin(x * 21.0 + t * 0.9 + 3.5);
      final v = (a + b + c) / 3.0;
      final h = (0.78 + 0.22 * v) % 1.0;
      hsvToRgb(h, 0.95, 0.45 + 0.45 * (v + 1) / 2, out, i);
    }
  }
}

// ============================================================
// High-energy
// ============================================================

class CyberpunkAnim implements PresetAnim {
  @override
  String get id => 'cyberpunk';

  @override
  void render(double t, Uint8List out, int n) {
    // Hot-pink + cyan ribbons chasing along the strip.
    for (var i = 0; i < n; i++) {
      final x = i / n;
      // square-ish ribbon by thresholding a sin wave
      final s = math.sin(x * 12.0 - t * 4.0);
      if (s > 0.2) {
        // pink ribbon, sharper edges
        final k = ((s - 0.2) / 0.8).clamp(0.0, 1.0);
        writeRgb(out, i, (255 * k).round(), (20 * k).round(),
            (120 * k).round());
      } else if (s < -0.2) {
        // cyan ribbon
        final k = ((-s - 0.2) / 0.8).clamp(0.0, 1.0);
        writeRgb(out, i, 0, (220 * k).round(), (255 * k).round());
      } else {
        writeRgb(out, i, 10, 0, 20);
      }
    }
  }
}

class LightningAnim implements PresetAnim {
  @override
  String get id => 'lightning';

  @override
  void render(double t, Uint8List out, int n) {
    // Mostly dark.
    final dim = (12 + 8 * math.sin(t * 0.6)).round();
    for (var i = 0; i < n; i++) {
      writeRgb(out, i, dim, dim, (dim * 1.4).round().clamp(0, 255));
    }
    // Bucket time into ~3s windows; deterministic flash inside the window.
    final window = (t / 2.8).floor();
    final phase = t - window * 2.8;
    final flashAt = 0.4 + 2.0 * noise1D(window.toDouble(), seed: 73);
    final dt = phase - flashAt;
    if (dt > 0 && dt < 0.12) {
      // primary flash
      final k = 1.0 - (dt / 0.12);
      final w = (255 * k).round();
      for (var i = 0; i < n; i++) {
        writeRgb(out, i, w, w, w);
      }
    } else if (dt > 0.18 && dt < 0.26) {
      // secondary smaller flash
      final k = 1.0 - ((dt - 0.18) / 0.08);
      final w = (180 * k).round();
      for (var i = 0; i < n; i++) {
        writeRgb(out, i, w, w, w);
      }
    }
  }
}

class PoliceAnim implements PresetAnim {
  @override
  String get id => 'police';

  @override
  void render(double t, Uint8List out, int n) {
    // Alternate red/blue halves every 250ms.
    final phase = ((t * 4).floor() % 2);
    final left = phase == 0 ? const [255, 0, 0] : const [0, 0, 255];
    final right = phase == 0 ? const [0, 0, 255] : const [255, 0, 0];
    final mid = n ~/ 2;
    for (var i = 0; i < n; i++) {
      final c = i < mid ? left : right;
      writeRgb(out, i, c[0], c[1], c[2]);
    }
  }
}

// ============================================================
// Living things
// ============================================================

class HeartbeatAnim implements PresetAnim {
  @override
  String get id => 'heartbeat';

  // ~60 bpm cardiac rhythm: lub (short, bright), short gap, dub (short,
  // slightly dimmer), then long rest. Whole cycle = 1.0s.
  @override
  void render(double t, Uint8List out, int n) {
    final p = t % 1.0;
    double env;
    if (p < 0.08) {
      env = math.sin(p / 0.08 * math.pi); // lub
      env = env * 1.0;
    } else if (p < 0.20) {
      env = 0.18; // tiny dip between
    } else if (p < 0.30) {
      env = math.sin((p - 0.20) / 0.10 * math.pi) * 0.75; // dub
    } else {
      env = 0.15; // rest with faint glow
    }
    final v = env.clamp(0.0, 1.0);
    final r = (40 + 215 * v).round().clamp(0, 255);
    final g = (4 * v).round().clamp(0, 255);
    final b = (8 * v).round().clamp(0, 255);
    for (var i = 0; i < n; i++) {
      writeRgb(out, i, r, g, b);
    }
  }
}

class BreatheAnim implements PresetAnim {
  @override
  String get id => 'breathe';

  @override
  void render(double t, Uint8List out, int n) {
    // 4s sin breath, cyan family.
    final v = 0.20 + 0.60 * (math.sin(t * math.pi / 2) * 0.5 + 0.5);
    final r = (40 * v).round();
    final g = (180 * v).round();
    final b = (220 * v).round();
    for (var i = 0; i < n; i++) {
      writeRgb(out, i, r, g, b);
    }
  }
}

// ============================================================
// Classic
// ============================================================

class RainbowAnim implements PresetAnim {
  @override
  String get id => 'rainbow';

  @override
  void render(double t, Uint8List out, int n) {
    for (var i = 0; i < n; i++) {
      final h = (i / n + t * 0.10) % 1.0;
      hsvToRgb(h, 1.0, 0.9, out, i);
    }
  }
}

class CandyAnim implements PresetAnim {
  @override
  String get id => 'candy';

  @override
  void render(double t, Uint8List out, int n) {
    // Slower pastel sweep, lower saturation, gentler value.
    for (var i = 0; i < n; i++) {
      final h = (i / n * 0.6 + t * 0.04) % 1.0;
      hsvToRgb(h, 0.45, 0.85, out, i);
    }
  }
}
