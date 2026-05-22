import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/audio_capture.dart';
import '../audio/visualizer.dart';
import '../data/presets.dart';
import '../data/settings.dart';
import '../render/anim_registry.dart';
import '../render/preset_renderer.dart';
import '../wled/wled_http.dart';
import '../wled/wled_udp.dart';

enum SyncMode { off, audio, mic, preset }

class AppState extends ChangeNotifier {
  AppSettings settings = AppSettings();
  WledInfo info = WledInfo.offline;
  WledState wled = WledState.initial;

  SyncMode mode = SyncMode.off;
  AudioLevel lastLevel = AudioLevel.silent;
  String? lastError;
  bool busy = false;

  /// The currently-active locally-rendered preset, or null. Used by the
  /// effects screen to highlight a tile via identity.
  EffectPreset? currentPreset;

  late WledClient _http;
  WledClient get http => _http;
  final _udp = WledUdp();
  final _audio = AudioCapture();
  late Visualizer _viz;
  late PresetRenderer _preset;
  StreamSubscription<AudioLevel>? _audioSub;

  Future<void> init() async {
    settings = await AppSettings.load();
    _http = WledClient(ip: settings.wledIp, port: settings.httpPort);
    _applyBounds();
    _viz = Visualizer(ledCount: settings.ledCount)
      ..beatGain = settings.beatGain
      ..hueDrift = settings.hueDrift
      ..warmth = settings.warmth
      ..tintHue = settings.audioTintHue;
    _preset = PresetRenderer(_udp)
      ..applyBounds(
        leds: settings.ledCount,
        skipStart: settings.skipStart,
        skipEnd: settings.skipEnd,
      );
    notifyListeners();
    unawaited(refreshDevice());
  }

  void _applyBounds() {
    final n = settings.ledCount;
    final s = settings.skipStart.clamp(0, n);
    final e = settings.skipEnd.clamp(0, n - s);
    _http.applyBounds(start: s, stop: n - e);
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
          _applyBounds();
          _preset.applyBounds(
            leds: info.ledCount,
            skipStart: settings.skipStart,
            skipEnd: settings.skipEnd,
          );
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
    _applyBounds();
    _viz.ledCount = settings.ledCount;
    _viz.beatGain = settings.beatGain;
    _viz.hueDrift = settings.hueDrift;
    _viz.warmth = settings.warmth;
    _viz.tintHue = settings.audioTintHue;
    _preset.applyBounds(
      leds: settings.ledCount,
      skipStart: settings.skipStart,
      skipEnd: settings.skipEnd,
    );
    notifyListeners();
  }

  // ---- Manual controls ----
  Future<void> setPower(bool on) async {
    // Manual power flip kills any preset stream.
    if (mode == SyncMode.preset) await stopPreset();
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
    if (mode == SyncMode.preset) await stopPreset();
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

  // ---- Preset rendering (local DRGB stream) ----
  Future<void> applyPreset(EffectPreset p) async {
    if (p.off) {
      if (mode == SyncMode.preset) await stopPreset();
      currentPreset = null;
      await setPower(false);
      notifyListeners();
      return;
    }
    // Stop any running audio sync first (mutual exclusion).
    if (mode == SyncMode.audio || mode == SyncMode.mic) {
      await stopAudioSync();
    }
    final anim = animFor(p.animId);
    if (anim == null) {
      lastError = 'Unknown animation: ${p.animId}';
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    try {
      // Make sure UDP socket is open.
      await _udp.connect(settings.wledIp, port: settings.udpPort);
      // Ask Android to keep us alive in the background.
      await _audio.startIdleForeground();
      // Power on the strip so a wakeful state is visible immediately.
      if (!wled.on) {
        try { await _http.setPower(true); } catch (_) {}
        wled = wled.copyWith(on: true);
      }
      _preset.applyBounds(
        leds: settings.ledCount,
        skipStart: settings.skipStart,
        skipEnd: settings.skipEnd,
      );
      _preset.start(anim);
      mode = SyncMode.preset;
      currentPreset = p;
    } catch (e) {
      lastError = e.toString();
    }
    busy = false;
    notifyListeners();
  }

  Future<void> stopPreset() async {
    if (mode != SyncMode.preset) return;
    _preset.stop();
    // Same recovery sequence as stopAudioSync: leave realtime mode and
    // restore the prior visible state.
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      await _http.disableLiveOverride();
      if (wled.on) {
        await _http.setPower(true);
        await _http.setBrightness(wled.brightness);
      }
    } catch (_) {}
    await _udp.close();
    // Tear down the idle foreground service.
    await _audio.stop();
    mode = SyncMode.off;
    currentPreset = null;
    notifyListeners();
  }

  // ---- Audio sync ----
  Future<bool> startAudioSync() async {
    if (mode == SyncMode.audio) return true;
    if (mode == SyncMode.preset) await stopPreset();
    if (mode == SyncMode.mic) await stopAudioSync();
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

  /// Start mic-input audio sync. Lazily requests RECORD_AUDIO permission so
  /// the user is only prompted the first time they tap "Start mic sync".
  Future<bool> startMicSync() async {
    if (mode == SyncMode.mic) return true;
    if (mode == SyncMode.preset) await stopPreset();
    if (mode == SyncMode.audio) await stopAudioSync();
    await _udp.connect(settings.wledIp, port: settings.udpPort);
    final ok = await _audio.startMic();
    if (!ok) {
      await _udp.close();
      lastError = 'Microphone permission denied';
      notifyListeners();
      return false;
    }
    _viz.reset();
    _audioSub = _audio.stream.listen(_onAudio);
    mode = SyncMode.mic;
    notifyListeners();
    return true;
  }

  Future<void> stopAudioSync() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _audio.stop();
    // Send a DRGB packet with waitSeconds:0 so WLED leaves realtime override
    // immediately instead of holding the strip for another 1–2 seconds.
    final blank = Uint8List(settings.ledCount * 3);
    _udp.sendDrgb(blank, waitSeconds: 0);
    await _udp.close();
    // Give WLED a moment to drop out of live mode, then explicitly clear it
    // via HTTP and re-apply the last known visible state.
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      await _http.disableLiveOverride();
      if (wled.on) {
        await _http.setPower(true);
        await _http.setBrightness(wled.brightness);
      }
    } catch (_) {}
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
    _preset.stop();
    _udp.close();
    super.dispose();
  }
}
