import 'dart:math' as math;
import 'dart:typed_data';

/// Writes one LED's RGB at index [i] into [out].
void writeRgb(Uint8List out, int i, int r, int g, int b) {
  out[i * 3] = r.clamp(0, 255);
  out[i * 3 + 1] = g.clamp(0, 255);
  out[i * 3 + 2] = b.clamp(0, 255);
}

/// HSV → RGB. h/s/v all in [0, 1].
void hsvToRgb(double h, double s, double v, Uint8List out, int i) {
  final hh = (h % 1.0 + 1.0) % 1.0;
  final ix = (hh * 6).floor();
  final f = hh * 6 - ix;
  final p = v * (1 - s);
  final q = v * (1 - f * s);
  final t = v * (1 - (1 - f) * s);
  double r, g, b;
  switch (ix % 6) {
    case 0: r = v; g = t; b = p; break;
    case 1: r = q; g = v; b = p; break;
    case 2: r = p; g = v; b = t; break;
    case 3: r = p; g = q; b = v; break;
    case 4: r = t; g = p; b = v; break;
    default: r = v; g = p; b = q; break;
  }
  writeRgb(out, i,
      (r * 255).round(), (g * 255).round(), (b * 255).round());
}

/// Linear blend between two RGB triples. f in [0, 1].
List<int> lerpRgb(List<int> a, List<int> b, double f) {
  final fc = f.clamp(0.0, 1.0);
  return [
    (a[0] + (b[0] - a[0]) * fc).round().clamp(0, 255),
    (a[1] + (b[1] - a[1]) * fc).round().clamp(0, 255),
    (a[2] + (b[2] - a[2]) * fc).round().clamp(0, 255),
  ];
}

/// Multi-stop gradient. Stops in [0,1] ascending.
List<int> gradient(List<double> stops, List<List<int>> colors, double f) {
  if (f <= stops.first) return colors.first;
  if (f >= stops.last) return colors.last;
  for (var i = 1; i < stops.length; i++) {
    if (f <= stops[i]) {
      final t = (f - stops[i - 1]) / (stops[i] - stops[i - 1]);
      return lerpRgb(colors[i - 1], colors[i], t);
    }
  }
  return colors.last;
}

/// Smoothstep, Ken Perlin's variant.
double smoothstep(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double clamp01(double v) => v.clamp(0.0, 1.0);

/// Deterministic 1D value noise: smooth scalar field over [x], stable
/// across frames for a given seed.
double noise1D(double x, {int seed = 0}) {
  final i = x.floor();
  final f = x - i;
  final a = _hash(i, seed);
  final b = _hash(i + 1, seed);
  final t = f * f * (3 - 2 * f);
  return a + (b - a) * t;
}

/// Hash int → [0, 1).
double _hash(int x, int seed) {
  var h = (x * 374761393) ^ (seed * 668265263);
  h = (h ^ (h >> 13)) * 1274126177;
  h = h ^ (h >> 16);
  return ((h & 0x7fffffff) / 0x7fffffff);
}

/// Scaled-and-saturated brightness multiplier; clamps and applies gamma 2.2-ish
/// for a more pleasing eye response on the strip.
int gamma(double v) {
  final c = v.clamp(0.0, 1.0);
  return (math.pow(c, 1.6) * 255).round().clamp(0, 255);
}
