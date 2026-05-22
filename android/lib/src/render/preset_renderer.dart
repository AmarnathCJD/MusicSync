import 'dart:async';
import 'dart:typed_data';

import '../wled/wled_udp.dart';
import 'preset_anim.dart';

/// Streams locally-rendered preset frames over DRGB UDP to WLED.
///
/// Frame rate: ~30fps (33ms). Each frame allocates a fresh strip buffer,
/// calls the active [PresetAnim] to fill it, zeroes the skip ranges, and
/// sends a DRGB packet with waitSeconds=2 (matches audio sync).
class PresetRenderer {
  PresetRenderer(this._udp);

  final WledUdp _udp;
  Timer? _timer;
  PresetAnim? _anim;
  DateTime _startedAt = DateTime.now();

  int ledCount = 60;
  int skipStart = 0;
  int skipEnd = 0;

  bool get running => _timer != null;
  PresetAnim? get current => _anim;

  void applyBounds({required int leds, required int skipStart, required int skipEnd}) {
    ledCount = leds;
    final s = skipStart.clamp(0, leds);
    final e = skipEnd.clamp(0, leds - s);
    this.skipStart = s;
    this.skipEnd = e;
  }

  void start(PresetAnim anim) {
    _anim = anim;
    _startedAt = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
    _tick(); // emit first frame immediately
  }

  void _tick() {
    final anim = _anim;
    if (anim == null) return;
    final t = DateTime.now().difference(_startedAt).inMicroseconds / 1e6;
    final strip = Uint8List(ledCount * 3);
    anim.render(t, strip, ledCount);
    _zeroSkips(strip);
    _udp.sendDrgb(strip);
  }

  void _zeroSkips(Uint8List strip) {
    for (var i = 0; i < skipStart; i++) {
      strip[i * 3] = 0; strip[i * 3 + 1] = 0; strip[i * 3 + 2] = 0;
    }
    for (var i = ledCount - skipEnd; i < ledCount; i++) {
      strip[i * 3] = 0; strip[i * 3 + 1] = 0; strip[i * 3 + 2] = 0;
    }
  }

  /// Stop the timer and send one waitSeconds=0 packet so WLED leaves
  /// realtime override immediately.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _anim = null;
    final blank = Uint8List(ledCount * 3);
    _udp.sendDrgb(blank, waitSeconds: 0);
  }
}
