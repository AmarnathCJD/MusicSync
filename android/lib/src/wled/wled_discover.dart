import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

class DiscoveredWled {
  final String name;
  final String ip;
  final int port;
  DiscoveredWled(this.name, this.ip, this.port);
}

/// Discover WLED instances on the LAN.
///
/// WLED advertises itself over mDNS as `_wled._tcp.local`. We resolve PTR ->
/// SRV -> A records to get the hostname/IP/port. Listening is bounded by
/// [timeout]; the first IP-resolved hit per service is reported.
Future<List<DiscoveredWled>> discoverWled({
  Duration timeout = const Duration(seconds: 3),
}) async {
  final client = MDnsClient(rawDatagramSocketFactory: (host, port,
          {bool? reuseAddress, bool? reusePort, int? ttl}) =>
      RawDatagramSocket.bind(host, port,
          reuseAddress: true, reusePort: false, ttl: ttl ?? 255));

  final results = <String, DiscoveredWled>{};
  try {
    await client.start();
    const serviceType = '_wled._tcp.local';

    await for (final ptr in client
        .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(serviceType))
        .timeout(timeout, onTimeout: (s) => s.close())) {
      await for (final srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName))) {
        await for (final ip in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target))) {
          final name = ptr.domainName.split('.').first;
          results.putIfAbsent(
              srv.target, () => DiscoveredWled(name, ip.address.address, srv.port));
        }
      }
    }
  } catch (_) {
    // Multicast may be blocked on some networks; return whatever we have.
  } finally {
    client.stop();
  }
  return results.values.toList();
}
