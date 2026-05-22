<p align="center">
  <img src="assets/logo.png" width="160" alt="MusicSync"/>
</p>

<h1 align="center">MusicSync</h1>

<p align="center">
  Drive WLED from what you're <b>hearing</b> and what you're <b>seeing</b>.<br/>
  <sub>Audio-reactive + display-reactive LED sync, phone and desktop.</sub>
</p>

---

Most WLED helpers stop at "send a color over HTTP." MusicSync goes further:
the host computes every LED in real time and streams the strip frame-by-frame
over **DRGB UDP**. The built-in WLED effects are bypassed entirely — what
you see on the strip is whatever the app rendered locally that millisecond,
driven by either your speakers or your screen.

Two implementations, same protocol, same WLED on the other end (Android + Windows)

## Screenshots

### Android

<p>
  <img src="assets/p1.jpg" width="22%"/>
  <img src="assets/p2.jpg" width="22%"/>
  <img src="assets/p3.jpg" width="22%"/>
  <img src="assets/p4.jpg" width="22%"/>
</p>

### Desktop (Windows)

<p>
  <img src="assets/w1.png" width="46%"/>
  <img src="assets/w2.png" width="46%"/>
</p>

## What's actually interesting here

- **Two reactive sources, one transport.** Audio mode runs an FFT on the
  host and drives bass / mid / high band energies + beat detection into the
  per-LED renderer. Display mode (desktop) captures your monitor, samples
  vertical columns weighted toward the bottom of the frame, processes them
  through a saturation → gamma → highlight chain, and streams the result as
  an ambilight. Both pipelines end at the same DRGB UDP socket.
- **Presets are not WLED presets.** WLED's `fx` catalogue varies between
  firmware builds and rarely matches the *name* on a tile. Heartbeat that
  doesn't thump, Embers and Inferno that share one fx and only diverge by
  speed — that whole class of problem. The Android app renders every preset
  in Dart (`android/lib/src/render/`) and streams DRGB at ~30fps. The tile
  named *Heartbeat* runs a lub-dub envelope; *Fire* has a directional flame
  with a hot base and cooler tip; *Lightning* sits dark and flashes on a
  seeded timeline.
- **System audio without external loopback hardware.** Android via
  `MediaProjection` + `AudioPlaybackCaptureConfiguration`; Windows via WASAPI
  loopback through `malgo`. Both run a 1024-point Hann-windowed radix-2 FFT
  on the host and emit bass / mid / high band energies plus a beat flag.
- **Mic mode that doesn't ask for the mic at launch.** Android requests
  `RECORD_AUDIO` *lazily*, only when you actually tap "Start mic sync."
  Most apps grab it on startup; this one doesn't.
- **WLED realtime override, handled properly.** DRGB packets put WLED into
  `live` mode for `waitSeconds`, which blocks every HTTP write. The Android
  client (`wled_http.dart`) sends `live: false` on every mutation and pins
  segment id 0 so multi-segment configs don't silently drop writes. Stopping
  any stream sends a `waitSeconds: 0` packet so the strip leaves realtime
  immediately, not 2 seconds later.
- **Foreground service keeps presets alive when the phone is locked.** Same
  service used by audio capture; just started in idle mode with no
  AudioRecord, so the UDP socket and frame timer survive backgrounding.

## Running

Each component has its own README with platform-specific setup:

- **[android/README.md](android/README.md)** — Flutter, Android 10+, plus WLED's
  *Sync Interfaces* → realtime UDP toggle.
- **[desktop/README.md](desktop/README.md)** — Go, Node, WebView2, Wails CLI,
  and a C compiler (CGo is required by `malgo` for loopback).

Both look for WLED on the same LAN. Set the strip's IP once in the app.
UDP port `21324`, HTTP port `80` — WLED's defaults.

## Layout

```
.
├── android/        Flutter mobile app
├── desktop/        Wails (Go + Svelte) Windows app
└── assets/         Icons + screenshots used by this README
```
