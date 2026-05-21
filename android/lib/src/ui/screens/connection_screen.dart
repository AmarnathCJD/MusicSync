import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../widgets/section_card.dart';

class ConnectionScreen extends StatefulWidget {
  final AppState state;
  const ConnectionScreen({super.key, required this.state});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  late TextEditingController _ip;
  late TextEditingController _httpPort;
  late TextEditingController _udpPort;
  late TextEditingController _led;
  late TextEditingController _skipS;
  late TextEditingController _skipE;

  @override
  void initState() {
    super.initState();
    final s = widget.state.settings;
    _ip = TextEditingController(text: s.wledIp);
    _httpPort = TextEditingController(text: s.httpPort.toString());
    _udpPort = TextEditingController(text: s.udpPort.toString());
    _led = TextEditingController(text: s.ledCount.toString());
    _skipS = TextEditingController(text: s.skipStart.toString());
    _skipE = TextEditingController(text: s.skipEnd.toString());
  }

  @override
  void dispose() {
    _ip.dispose();
    _httpPort.dispose();
    _udpPort.dispose();
    _led.dispose();
    _skipS.dispose();
    _skipE.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final s = widget.state.settings;
    s.wledIp = _ip.text.trim();
    s.httpPort = int.tryParse(_httpPort.text) ?? 80;
    s.udpPort = int.tryParse(_udpPort.text) ?? 21324;
    s.ledCount = int.tryParse(_led.text) ?? 60;
    s.skipStart = int.tryParse(_skipS.text) ?? 0;
    s.skipEnd = int.tryParse(_skipE.text) ?? 0;
    await widget.state.saveSettings();
    await widget.state.refreshDevice();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.state.info.online
            ? 'Connected to ${widget.state.info.name}'
            : 'Saved (offline)'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    return ListView(
      children: [
        SectionCard(
          icon: Icons.router,
          title: 'WLED device',
          trailing: _statusChip(st),
          child: Column(
            children: [
              TextField(
                controller: _ip,
                decoration: const InputDecoration(
                  labelText: 'IP address',
                  hintText: '192.168.x.x',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _httpPort,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'HTTP port'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _udpPort,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'UDP port'),
                  ),
                ),
              ]),
            ],
          ),
        ),
        SectionCard(
          icon: Icons.linear_scale,
          title: 'Strip layout',
          child: Column(
            children: [
              TextField(
                controller: _led,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'LED count'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _skipS,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Skip start LEDs'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _skipE,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Skip end LEDs'),
                  ),
                ),
              ]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: FilledButton.icon(
            onPressed: _apply,
            icon: const Icon(Icons.check),
            label: const Text('Save & connect'),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(AppState st) {
    final online = st.info.online;
    return Chip(
      side: BorderSide(color: (online ? Colors.greenAccent : Colors.redAccent).withOpacity(0.4)),
      label: Text(online ? 'online' : 'offline'),
      avatar: CircleAvatar(
        backgroundColor: online ? Colors.greenAccent : Colors.redAccent,
        radius: 6,
      ),
    );
  }
}
