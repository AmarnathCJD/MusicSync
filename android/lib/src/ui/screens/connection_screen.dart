import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../wled/wled_http.dart';
import '../theme.dart';
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
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      children: [
        _Hero(info: st.info, online: st.info.online),
        SectionCard(
          title: 'Endpoint',
          caption: 'WLED device on your local network',
          child: Column(
            children: [
              _Field(label: 'IP address', controller: _ip, hint: '192.168.x.x'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'HTTP port',
                      controller: _httpPort,
                      numeric: true,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Field(
                      label: 'UDP port',
                      controller: _udpPort,
                      numeric: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Strip layout',
          caption: 'Physical mapping of your LED strip',
          child: Column(
            children: [
              _Field(label: 'LED count', controller: _led, numeric: true),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Skip start',
                      controller: _skipS,
                      numeric: true,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Field(
                      label: 'Skip end',
                      controller: _skipE,
                      numeric: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: _ApplyButton(onTap: _apply),
        ),
        if (st.http.lastRequest.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LAST HTTP CALL',
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 1.6,
                    color: AppTones.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '→ ${st.http.lastRequest}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTones.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '← ${st.http.lastResponse}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTones.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final WledInfo info;
  final bool online;

  const _Hero({required this.info, required this.online});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: online
                ? [AppTones.bloom, AppTones.bg2]
                : [AppTones.bg2, AppTones.bg1],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: online
                              ? AppTones.positive
                              : AppTones.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        online ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                          color: online
                              ? Colors.white
                              : Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              online ? info.name : 'Not connected',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: Colors.white.withOpacity(online ? 0.95 : 0.55),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(label: 'FIRMWARE', value: online ? info.version : '—'),
                const SizedBox(width: 28),
                _Stat(
                    label: 'LEDS',
                    value: online ? info.ledCount.toString() : '—'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.55),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool numeric;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.numeric = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 1.4,
            color: AppTones.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: numeric ? TextInputType.number : TextInputType.url,
          decoration: InputDecoration(hintText: hint),
          style: const TextStyle(
            fontSize: 15,
            color: AppTones.textPrimary,
            fontWeight: FontWeight.w500,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ApplyButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ApplyButton({required this.onTap});

  @override
  State<_ApplyButton> createState() => _ApplyButtonState();
}

class _ApplyButtonState extends State<_ApplyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _pressed ? AppTones.accentDim : AppTones.accent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_rounded, size: 18, color: AppTones.bg0),
            SizedBox(width: 8),
            Text(
              'Save & connect',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTones.bg0,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
