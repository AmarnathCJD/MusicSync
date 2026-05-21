import 'dart:convert';

import 'package:http/http.dart' as http;

class WledInfo {
  final String name;
  final String version;
  final int ledCount;
  final bool online;

  const WledInfo({
    required this.name,
    required this.version,
    required this.ledCount,
    required this.online,
  });

  static const offline = WledInfo(name: '-', version: '-', ledCount: 0, online: false);
}

class WledState {
  final bool on;
  final int brightness;
  final List<int> primaryRgb;
  final int effect;
  final int palette;
  final int speed;
  final int intensity;

  const WledState({
    required this.on,
    required this.brightness,
    required this.primaryRgb,
    required this.effect,
    required this.palette,
    required this.speed,
    required this.intensity,
  });

  WledState copyWith({
    bool? on,
    int? brightness,
    List<int>? primaryRgb,
    int? effect,
    int? palette,
    int? speed,
    int? intensity,
  }) =>
      WledState(
        on: on ?? this.on,
        brightness: brightness ?? this.brightness,
        primaryRgb: primaryRgb ?? this.primaryRgb,
        effect: effect ?? this.effect,
        palette: palette ?? this.palette,
        speed: speed ?? this.speed,
        intensity: intensity ?? this.intensity,
      );

  static const initial = WledState(
    on: false,
    brightness: 128,
    primaryRgb: [255, 120, 40],
    effect: 0,
    palette: 0,
    speed: 128,
    intensity: 128,
  );
}

class WledClient {
  WledClient({required this.ip, this.port = 80});

  String ip;
  int port;

  Uri _u(String path) => Uri.parse('http://$ip:$port$path');

  Future<WledInfo> info() async {
    try {
      final r = await http
          .get(_u('/json/info'))
          .timeout(const Duration(seconds: 3));
      if (r.statusCode != 200) return WledInfo.offline;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return WledInfo(
        name: (j['name'] ?? 'WLED').toString(),
        version: (j['ver'] ?? '?').toString(),
        ledCount: (j['leds']?['count'] as num?)?.toInt() ?? 0,
        online: true,
      );
    } catch (_) {
      return WledInfo.offline;
    }
  }

  Future<WledState> getState() async {
    final r = await http
        .get(_u('/json/state'))
        .timeout(const Duration(seconds: 3));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final seg = (j['seg'] as List?)?.cast<Map<String, dynamic>>().first ??
        <String, dynamic>{};
    final col = (seg['col'] as List?)?.cast<List>().first ?? const [255, 120, 40];
    return WledState(
      on: (j['on'] as bool?) ?? false,
      brightness: (j['bri'] as num?)?.toInt() ?? 128,
      primaryRgb: col.take(3).map((e) => (e as num).toInt()).toList(),
      effect: (seg['fx'] as num?)?.toInt() ?? 0,
      palette: (seg['pal'] as num?)?.toInt() ?? 0,
      speed: (seg['sx'] as num?)?.toInt() ?? 128,
      intensity: (seg['ix'] as num?)?.toInt() ?? 128,
    );
  }

  Future<void> setPower(bool on) =>
      _postState({'on': on});

  Future<void> setBrightness(int bri) =>
      _postState({'bri': bri.clamp(0, 255)});

  Future<void> setColor(List<int> rgb) =>
      _postState({
        'seg': [
          {
            'col': [rgb, [0, 0, 0], [0, 0, 0]],
          }
        ],
      });

  Future<void> setEffect(int fx, {int? speed, int? intensity, int? palette}) {
    final seg = <String, dynamic>{'fx': fx};
    if (speed != null) seg['sx'] = speed.clamp(0, 255);
    if (intensity != null) seg['ix'] = intensity.clamp(0, 255);
    if (palette != null) seg['pal'] = palette.clamp(0, 70);
    return _postState({
      'on': true,
      'seg': [seg],
    });
  }

  Future<void> setSpeedIntensity(int speed, int intensity) =>
      _postState({
        'seg': [
          {
            'sx': speed.clamp(0, 255),
            'ix': intensity.clamp(0, 255),
          }
        ],
      });

  Future<void> setPalette(int pal) =>
      _postState({
        'seg': [
          {'pal': pal.clamp(0, 70)},
        ],
      });

  /// Switch WLED into realtime-DRGB mode (turns built-in effects off so UDP packets render).
  Future<void> enableLiveOverride() =>
      _postState({'on': true, 'live': true});

  Future<void> _postState(Map<String, dynamic> body) async {
    await http
        .post(
          _u('/json/state'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 3));
  }
}
