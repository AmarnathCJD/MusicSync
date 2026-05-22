# MusicSync — Desktop (Windows)

Wails (Go + Svelte) app that drives a WLED strip from your speakers or your
screen, streamed frame-by-frame over DRGB UDP.

## Modes

- **Audio** — WASAPI loopback via `malgo`, 1024-pt Hann FFT, bass / mid /
  high band energies + beat detection feed an HSV palette.
- **Video** — monitor capture sampled along vertical columns, weighted
  toward the bottom of the frame; saturation → gamma → highlight chain;
  ambilight-style output.

Only one mode runs at a time. Both feed the same 144Hz sender (exponential
follow + temporal dither) which emits DRGB packets to WLED.

## Requirements

- Go 1.22+
- Node.js LTS (for the Svelte build)
- WebView2 runtime (preinstalled on Win11; Win10 needs the Evergreen runtime)
- A C compiler — CGo is required by `malgo`. Easiest:
  `winget install BrechtSanders.WinLibs.POSIX.UCRT.MSVCRT`
- Wails CLI: `go install github.com/wailsapp/wails/v2/cmd/wails@latest`
- WLED on the same LAN with Realtime UDP enabled (port `21324`)

## Build

```powershell
go mod tidy
cd frontend && npm install && cd ..
wails dev          # hot-reload dev window
wails build        # produces build/bin/MusicSync.exe
```

## Notes

- Settings persist to `%AppData%\MusicSync\settings.json`, autosaved 250ms
  after each change.
- Audio mode is silent until something is actually playing — WASAPI
  loopback delivers nothing when the output device is idle.
- Switching modes cancels the running goroutine and starts the new one;
  **Off** sends a zero frame and stops everything.

## Layout

```
desktop/
├── main.go, app.go            Wails entry + JS bindings
├── internal/
│   ├── settings/              JSON persistence
│   ├── strip/                 RGB strip type
│   ├── sender/                144Hz follow + dither + UDP DRGB
│   ├── audio/                 malgo loopback → FFT → strip
│   └── video/                 screen capture → sample → process
└── frontend/src/              Svelte UI (App.svelte, lib/, style.css)
```
