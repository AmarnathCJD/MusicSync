import 'dart:async';

import 'package:flutter/services.dart';

class AudioLevel {
  final double bass;
  final double mid;
  final double high;
  final double level;
  final bool beat;

  const AudioLevel({
    required this.bass,
    required this.mid,
    required this.high,
    required this.level,
    required this.beat,
  });

  static const silent = AudioLevel(
    bass: 0, mid: 0, high: 0, level: 0, beat: false,
  );

  factory AudioLevel.fromMap(Map<dynamic, dynamic> m) => AudioLevel(
        bass: (m['bass'] as num?)?.toDouble() ?? 0,
        mid: (m['mid'] as num?)?.toDouble() ?? 0,
        high: (m['high'] as num?)?.toDouble() ?? 0,
        level: (m['level'] as num?)?.toDouble() ?? 0,
        beat: (m['beat'] as bool?) ?? false,
      );
}

class AudioCapture {
  static const _method = MethodChannel('musicsync/audio');
  static const _events = EventChannel('musicsync/audio/events');

  StreamSubscription? _sub;
  final _controller = StreamController<AudioLevel>.broadcast();
  bool _running = false;

  Stream<AudioLevel> get stream => _controller.stream;
  bool get isRunning => _running;

  Future<bool> start() async {
    if (_running) return true;
    final ok = await _method.invokeMethod<bool>('requestCapture') ?? false;
    if (!ok) return false;
    _sub ??= _events.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        _controller.add(AudioLevel.fromMap(event));
      }
    }, onError: (e) {
      // surfaced to UI via stream errors if needed
    });
    _running = true;
    return true;
  }

  Future<void> stop() async {
    if (!_running) return;
    await _method.invokeMethod('stopCapture');
    _running = false;
    _controller.add(AudioLevel.silent);
  }

  Future<void> dispose() async {
    await stop();
    await _sub?.cancel();
    await _controller.close();
  }
}
