import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/audio_capture.dart';
import '../audio/visualizer.dart';
import '../data/settings.dart';
import '../wled/wled_http.dart';
import '../wled/wled_udp.dart';

enum SyncMode { off, audio }

class AppState extends ChangeNotifier {
  AppSettings settings = AppSettings();
  WledInfo info = WledInfo.offline;
  WledState wled = WledState.initial;

  SyncMode mode = SyncMode.off;
  AudioLevel lastLevel = AudioLevel.silent;
  String? lastError;
  bool busy = false;

  late WledClient _http;
  final _udp = WledUdp();
  final _audio = AudioCapture();
  late Visualizer _viz;
  StreamSubscription<AudioLevel>? _audioSub;

  Future<void> init() async {
    settings = await AppSettings.load();
    _http = WledClient(ip: settings.wledIp, port: settings.httpPort);
    _viz = Visualizer(ledCount: settings.ledCount)
      ..beatGain = settings.beatGain
      ..hueDrift = settings.hueDrift
      ..warmth = settings.warmth;
    notifyListeners();
    unawaited(refreshDevice());
  }

  Future<void> refreshDevice() async {
    try {
      _http.ip = settings.wledIp;
      _http.port = settings.httpPort;
      info = await _http.info();
      if (info.online) {
        wled = await _http.getState();
        if (info.ledCount > 0) {
          settings.ledCount = info.ledCount;
          _viz.ledCount = info.ledCount;
        }
      }
      lastError = null;
    } catch (e) {
      info = WledInfo.offline;
      lastError = e.toString();
    }
    notifyListeners();
  }

  Future<void> saveSettings() async {
    await settings.save();
    _http.ip = settings.wledIp;
    _http.port = settings.httpPort;
    _viz.ledCount = settings.ledCount;
    _viz.beatGain = settings.beatGain;
    _viz.hueDrift = settings.hueDrift;
    _viz.warmth = settings.warmth;
    notifyListeners();
  }

  // ---- Manual controls ----
  Future<void> setPower(bool on) async {
    wled = wled.copyWith(on: on);
    notifyListeners();
    try {
      await _http.setPower(on);
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> setBrightness(int bri) async {
    wled = wled.copyWith(brightness: bri);
    notifyListeners();
    try {
      await _http.setBrightness(bri);
    } catch (e) {
      lastError = e.toString();
    }
  }

  Future<void> setColor(List<int> rgb) async {
    wled = wled.copyWith(primaryRgb: rgb);
    notifyListeners();
    try {
      await _http.setColor(rgb);
    } catch (e) {
      lastError = e.toString();
    }
  }

  Future<void> setSpeed(int v) async {
    wled = wled.copyWith(speed: v);
    notifyListeners();
    try {
      await _http.setSpeedIntensity(v, wled.intensity);
    } catch (_) {}
  }

  Future<void> setIntensity(int v) async {
    wled = wled.copyWith(intensity: v);
    notifyListeners();
    try {
      await _http.setSpeedIntensity(wled.speed, v);
    } catch (_) {}
  }

  Future<void> applyPreset({
    required int fx,
    required int palette,
    required int speed,
    required int intensity,
    List<int>? color,
  }) async {
    busy = true;
    notifyListeners();
    try {
      if (color != null) await _http.setColor(color);
      await _http.setEffect(fx,
          speed: speed, intensity: intensity, palette: palette);
      wled = wled.copyWith(
        on: true,
        effect: fx,
        palette: palette,
        speed: speed,
        intensity: intensity,
        primaryRgb: color ?? wled.primaryRgb,
      );
    } catch (e) {
      lastError = e.toString();
    }
    busy = false;
    notifyListeners();
  }

  // ---- Audio sync ----
  Future<bool> startAudioSync() async {
    if (mode == SyncMode.audio) return true;
    await _udp.connect(settings.wledIp, port: settings.udpPort);
    final ok = await _audio.start();
    if (!ok) {
      await _udp.close();
      lastError = 'Audio capture permission denied';
      notifyListeners();
      return false;
    }
    _viz.reset();
    _audioSub = _audio.stream.listen(_onAudio);
    mode = SyncMode.audio;
    notifyListeners();
    return true;
  }

  Future<void> stopAudioSync() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _audio.stop();
    // blackout final frame
    final blank = Uint8List(settings.ledCount * 3);
    _udp.sendDrgb(blank, waitSeconds: 1);
    await _udp.close();
    mode = SyncMode.off;
    lastLevel = AudioLevel.silent;
    notifyListeners();
  }

  void _onAudio(AudioLevel a) {
    lastLevel = a;
    final strip = _viz.render(a);
    _zeroSkips(strip);
    _udp.sendDrgb(strip);
    notifyListeners();
  }

  void _zeroSkips(Uint8List strip) {
    final n = settings.ledCount;
    final s = settings.skipStart.clamp(0, n);
    final e = settings.skipEnd.clamp(0, n - s);
    for (var i = 0; i < s; i++) {
      strip[i * 3] = 0; strip[i * 3 + 1] = 0; strip[i * 3 + 2] = 0;
    }
    for (var i = n - e; i < n; i++) {
      strip[i * 3] = 0; strip[i * 3 + 1] = 0; strip[i * 3 + 2] = 0;
    }
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _audio.dispose();
    _udp.close();
    super.dispose();
  }
}
