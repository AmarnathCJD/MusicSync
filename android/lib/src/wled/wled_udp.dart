import 'dart:io';
import 'dart:typed_data';

class WledUdp {
  RawDatagramSocket? _sock;
  InternetAddress? _addr;
  int _port = 21324;

  Future<void> connect(String ip, {int port = 21324}) async {
    await close();
    _addr = InternetAddress(ip);
    _port = port;
    _sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  }

  bool get isOpen => _sock != null && _addr != null;

  /// strip is RGB triples 0..255, length = ledCount * 3
  void sendDrgb(Uint8List strip, {int waitSeconds = 2}) {
    final s = _sock;
    final a = _addr;
    if (s == null || a == null) return;
    final pkt = Uint8List(2 + strip.length);
    pkt[0] = 2; // DRGB
    pkt[1] = waitSeconds.clamp(0, 255); // timeout in seconds
    pkt.setRange(2, pkt.length, strip);
    try {
      s.send(pkt, a, _port);
    } catch (_) {}
  }

  Future<void> close() async {
    _sock?.close();
    _sock = null;
    _addr = null;
  }
}
