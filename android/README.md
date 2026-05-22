# MusicSync — Android

Flutter app that controls your WLED strip from a phone, with locally-rendered
animated presets and audio-reactive sync streamed over DRGB UDP.

## Modes

- **Controls** — power, brightness, color picker, speed/intensity. Live HTTP.
- **Effects** — 26 hand-written animations rendered in Dart and streamed at
  ~30fps. WLED's built-in `fx` is bypassed entirely.
- **Audio sync** — system audio (`MediaProjection`) or mic input. 1024-pt
  Hann-windowed FFT on the Kotlin side; bass / mid / high + beat drive the
  visualizer. Optional hue tint to lock the strip to one color family.

## Requirements

- Android 10+ (API 29 for `AudioPlaybackCaptureConfiguration`)
- Flutter 3.22+
- WLED on the same LAN with **Realtime UDP** enabled (Settings → Sync
  Interfaces, port `21324`)

## Build

```bash
cd android
flutter pub get
flutter run --release
```

## Notes

- System-audio capture goes through Android's screen-capture consent flow —
  there's no public loopback API. The app reads only audio; no video is
  recorded.
- Mic permission is requested **lazily**, the first time you tap *Start mic
  sync* — never at launch.
- Presets and audio sync are mutually exclusive (one UDP stream at a time).
  Background-safe via a foreground service.

## Layout

```
lib/src/
├── audio/      audio_capture.dart, visualizer.dart
├── render/     preset_anim.dart, preset_renderer.dart, anim_registry.dart
├── wled/       wled_http.dart, wled_udp.dart
├── state/      app_state.dart
├── data/       settings.dart, presets.dart
└── ui/         screens/, widgets/

android/app/src/main/kotlin/com/musicsync/app/
├── MainActivity.kt        MethodChannel + EventChannel
├── AudioBus.kt            service ↔ Flutter bridge
└── AudioCaptureService.kt foreground service + FFT
```
