import 'package:flutter/material.dart';

import 'src/state/app_state.dart';
import 'src/ui/home_shell.dart';
import 'src/ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MusicSyncApp());
}

class MusicSyncApp extends StatefulWidget {
  const MusicSyncApp({super.key});

  @override
  State<MusicSyncApp> createState() => _MusicSyncAppState();
}

class _MusicSyncAppState extends State<MusicSyncApp> {
  final AppState _state = AppState();

  @override
  void initState() {
    super.initState();
    _state.init();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MusicSync',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AnimatedBuilder(
        animation: _state,
        builder: (_, __) => HomeShell(state: _state),
      ),
    );
  }
}
