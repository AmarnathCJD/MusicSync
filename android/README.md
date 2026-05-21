# MusicSync (Android)

A Flutter app to control your WLED strip from your phone, with **real-time
system-audio reactive LEDs**. No external mic — the app captures the audio
playing on your device (music apps, YouTube, games) via Android's
`MediaProjection` + `AudioPlaybackCaptureConfiguration` API.

## Features

- **Controls**: power, master brightness, primary color picker, effect speed
  & intensity sliders, all hitting the WLED JSON API live.
- **Curated effect grid**: Fire, Snowfall, Aurora, Ocean, Lava Lamp, Forest,
  Sunset, Rainbow, Lightning, Plasma, Candy, Galaxy — each preset bundles
  a WLED built-in effect + palette + speed + intensity.
- **Audio sync**: captures system audio, runs an FFT on-device (1024-sample
  Hann-windowed radix-2 FFT in native Kotlin), extracts bass / mid / high
  band energies, detects beats, and streams DRGB UDP packets to WLED at
  ~50ms cadence with center-pulse falloff, HSV palette rotation and beat
  highlight. Mirrors the visualization model from the desktop `main.py`.
- **Per-strip layout settings**: LED count, skip first/last N LEDs (for the
  strip-behind-laptop "skip the glue" case), HTTP + UDP ports, IP.
- **Settings persisted** via `shared_preferences`.

## Requirements

- Android 10+ (API 29) — `AudioPlaybackCaptureConfiguration` is API 29+.
- Flutter 3.22+.
- WLED-flashed controller on the same Wi-Fi network, with **realtime UDP
  (DRGB) enabled** in WLED's *Sync Interfaces* settings.

## First-time build

```bash
cd android
flutter pub get
flutter run --release
```

If you don't have a launcher icon yet, Flutter will fall back to the
default. To add one, run `flutter pub add flutter_launcher_icons` and
configure it, or drop your own PNGs into
`android/app/src/main/res/mipmap-*`.

## How audio capture works on Android

There is **no public "loopback audio" API** on Android. To capture the
audio playing in other apps the OS forces you through the screen-capture
consent flow — that's just how Android exposes it. When you tap **Start
sync**, you'll see a system dialog ("MusicSync will start capturing
everything that's displayed on your screen"). Accept it. The app does
**not** record video or store anything; it only routes the audio stream
into the visualizer.

Caveats:
- An app can opt-out of being captured (rare for music apps; common for
  DRM-protected video). If you start sync and the strip stays dark, the
  source app is opted out.
- The OS shows a persistent notification while capture is active — that's
  required for foreground media-projection services on Android 10+.

## WLED setup

In WLED's web UI:
1. *Config → WiFi setup* — note the IP.
2. *Config → Sync Interfaces* → enable **Realtime UDP**, port **21324**.
3. *Config → LED preferences* — set your LED count.

In the MusicSync app, go to the **Device** tab, enter the IP, hit save.
The LED count auto-syncs from WLED's `/json/info`.

## Project layout

```
android/
├── lib/
│   ├── main.dart
│   └── src/
│       ├── audio/         -- audio_capture.dart, visualizer.dart
│       ├── wled/          -- wled_http.dart, wled_udp.dart
│       ├── state/         -- app_state.dart
│       ├── data/          -- settings.dart, presets.dart
│       └── ui/
│           ├── home_shell.dart
│           ├── screens/   -- controls, effects, audio_sync, connection
│           └── widgets/   -- section_card, vu_meter
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml
│       └── kotlin/com/musicsync/app/
│           ├── MainActivity.kt        -- MethodChannel + EventChannel
│           ├── AudioBus.kt            -- service ↔ Flutter bridge
│           └── AudioCaptureService.kt -- foreground service + FFT
└── pubspec.yaml
```

## Troubleshooting

- **Strip stays dark in audio sync** — check that WLED Realtime UDP is on
  and you accepted the screen-capture prompt. Also confirm the IP in the
  *Device* tab is reachable (the status dot turns green when
  `/json/info` responds).
- **Effects from the grid don't apply** — make sure the device is online
  (green dot top-right). Some WLED builds disable effects on segments;
  the app sends a single-segment update so this should just work on
  stock WLED.
- **Capture stops by itself** — Android may kill the foreground service
  under aggressive battery saving. Whitelist the app in your battery
  settings.
