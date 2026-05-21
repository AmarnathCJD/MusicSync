import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  String wledIp;
  int httpPort;
  int udpPort;
  int ledCount;
  int skipStart;
  int skipEnd;

  // visualizer
  double beatGain;
  double hueDrift;
  double warmth;

  AppSettings({
    this.wledIp = '10.158.240.95',
    this.httpPort = 80,
    this.udpPort = 21324,
    this.ledCount = 60,
    this.skipStart = 8,
    this.skipEnd = 3,
    this.beatGain = 0.55,
    this.hueDrift = 0.015,
    this.warmth = 0.05,
  });

  static const _kIp = 'wled_ip';
  static const _kHttp = 'wled_http_port';
  static const _kUdp = 'wled_udp_port';
  static const _kLed = 'led_count';
  static const _kSkipS = 'skip_start';
  static const _kSkipE = 'skip_end';
  static const _kBeat = 'beat_gain';
  static const _kHue = 'hue_drift';
  static const _kWarm = 'warmth';

  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      wledIp: p.getString(_kIp) ?? '10.158.240.95',
      httpPort: p.getInt(_kHttp) ?? 80,
      udpPort: p.getInt(_kUdp) ?? 21324,
      ledCount: p.getInt(_kLed) ?? 60,
      skipStart: p.getInt(_kSkipS) ?? 8,
      skipEnd: p.getInt(_kSkipE) ?? 3,
      beatGain: p.getDouble(_kBeat) ?? 0.55,
      hueDrift: p.getDouble(_kHue) ?? 0.015,
      warmth: p.getDouble(_kWarm) ?? 0.05,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kIp, wledIp);
    await p.setInt(_kHttp, httpPort);
    await p.setInt(_kUdp, udpPort);
    await p.setInt(_kLed, ledCount);
    await p.setInt(_kSkipS, skipStart);
    await p.setInt(_kSkipE, skipEnd);
    await p.setDouble(_kBeat, beatGain);
    await p.setDouble(_kHue, hueDrift);
    await p.setDouble(_kWarm, warmth);
  }
}
