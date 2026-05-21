# MusicSync

Single-binary ambient LED sync for WLED. Combines audio-reactive (FFT loopback) and video-reactive (screen capture) modes into one app with a Wails + Svelte GUI.

## Prerequisites

You already have Go installed. You also need:

- A C compiler (CGo is required by `malgo` for audio loopback):
  ```powershell
  winget install -e --id BrechtSanders.WinLibs.POSIX.UCRT.MSVCRT
  ```
  Restart your terminal after installing so `gcc` is on PATH.

- Node.js (for the Svelte frontend build):
  ```powershell
  winget install OpenJS.NodeJS.LTS
  ```

- WebView2 runtime — preinstalled on Windows 11. If on Windows 10, install from https://developer.microsoft.com/microsoft-edge/webview2/

- Wails CLI:
  ```powershell
  go install github.com/wailsapp/wails/v2/cmd/wails@latest
  wails doctor
  ```
  `wails doctor` should report no errors. Fix anything red before continuing.

## First run

From this directory:

```powershell
go mod tidy
cd frontend
npm install
cd ..
wails dev
```

`wails dev` opens a window with hot reload. The Go binary embeds the built frontend at `frontend/dist`, so `wails dev` writes there during dev.

## Production build

```powershell
wails build
```

Produces `build/bin/MusicSync.exe`. Single file, no Python runtime required, distributable.

## Configuration

Settings persist to `%AppData%\MusicSync\settings.json`. The GUI auto-saves 250ms after each change. Defaults are tuned to the existing Python scripts in this repo.

## Quickstart

1. Open the app. The **WLED Connection** card shows IP / port / LED count.
2. Set your WLED IP (default `10.158.240.95`). LED count, skip-start / skip-end.
3. Click **Test Connection (Blink)** — the strip should flash white once. If it doesn't, fix the IP/port or check that WLED has UDP realtime enabled on port 21324.
4. Click **Audio** or **Video** to start that mode. Adjust sliders live; changes apply within ~250ms.
5. **Off** stops both modes and sends a zero frame.

## Modes

### Audio (loopback FFT)
Captures the system audio mix via WASAPI loopback. 1024-sample windows, Hann-windowed FFT, splits into bass (20–200 Hz), mid (200–2000 Hz), high (2000–8000 Hz). Drives an HSV palette with a bass-baseline beat detector. Sliders: beat gain, hue drift, brightness, saturation.

### Video (screen capture)
Captures the chosen monitor at the configured FPS. Downsamples, optionally crops black bars, samples vertical columns weighted toward the bottom of the frame (for strips mounted below the screen), mirrors for wall-bounce setups. Color processing: saturation stretch → gamma → highlight boost → soft black-knee. Sliders cover all of these plus capture FPS and downscale width.

## Architecture

```
audio.Runner ──┐
               ├─→ sender (144Hz interpolator + dither) ──→ UDP DRGB ──→ WLED
video.Runner ──┘
```

Both modes write to a shared `Sender` running at the configured Send FPS. The sender does exponential follow toward the latest target, temporal dithering for sub-LSB smoothness, applies skip-LED zeroing, and emits a DRGB packet (`[2, 255, r, g, b, ...]`).

Only one mode is active at a time; switching modes cancels the current goroutine and starts the new one.

## Troubleshooting

- **Audio mode silent / no reaction**: Make sure something is *playing*. WASAPI loopback delivers nothing when the device is idle. Try the system audio test.
- **Video mode shows wrong monitor**: change the **Monitor** dropdown in the Video panel.
- **Strip shows only one color**: WLED may be configured for a different realtime protocol. In WLED → Settings → Sync Interfaces, ensure Realtime UDP is enabled on port 21324, and the segment covers all LEDs.
- **`gcc` not found** during `wails build`: install winlibs (see Prerequisites) and restart your terminal.
- **`wails dev` reports embedding error**: ensure `frontend/dist/` exists. It does in this repo; if you cleaned it, run `cd frontend && npm run build`.

## File layout

```
MusicSync-go/
├── main.go                          Wails entry
├── app.go                           Bindings: GetSettings/SaveSettings/SetMode/...
├── internal/
│   ├── settings/   settings.go      JSON persistence + defaults
│   ├── strip/      strip.go         []RGB type + helpers
│   ├── sender/     sender.go        144Hz follow + dither + UDP DRGB
│   ├── audio/      runner.go        malgo loopback → FFT → strip
│   └── video/      runner.go        screen capture → sample → process
└── frontend/
    ├── src/App.svelte               Main UI
    ├── src/lib/                     Slider, StripPreview, VUMeter
    └── src/style.css                Dark theme
```
