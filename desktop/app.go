package main

import (
	"context"
	"fmt"
	"sync"
	"time"

	wruntime "github.com/wailsapp/wails/v2/pkg/runtime"

	"musicsync/internal/audio"
	"musicsync/internal/discover"
	"musicsync/internal/sender"
	"musicsync/internal/settings"
	"musicsync/internal/strip"
	"musicsync/internal/video"
)

type App struct {
	ctx context.Context

	mu       sync.Mutex
	cfg      settings.Settings
	sender   *sender.Sender
	senderCh context.CancelFunc
	senderWg sync.WaitGroup

	mode       string
	modeCancel context.CancelFunc
	modeWg     sync.WaitGroup

	audioRunner *audio.Runner
}

func NewApp() *App {
	return &App{mode: "off"}
}

func (a *App) OnStartup(ctx context.Context) {
	a.ctx = ctx

	cfg, err := settings.Load()
	if err != nil {
		wruntime.LogErrorf(ctx, "settings load: %v", err)
	}
	a.cfg = cfg

	snd, err := sender.New(cfg)
	if err != nil {
		wruntime.LogErrorf(ctx, "sender init: %v", err)
		return
	}
	a.sender = snd

	sCtx, sCancel := context.WithCancel(context.Background())
	a.senderCh = sCancel
	a.senderWg.Add(1)
	go func() {
		defer a.senderWg.Done()
		a.sender.Run(sCtx)
	}()

	go a.emitLoop()

	if cfg.Mode == "audio" || cfg.Mode == "video" {
		_ = a.SetMode(cfg.Mode)
	}
}

func (a *App) OnShutdown(ctx context.Context) {
	a.stopMode()
	if a.senderCh != nil {
		a.senderCh()
	}
	a.senderWg.Wait()
	if a.sender != nil {
		a.sender.Close()
	}
}

func (a *App) emitLoop() {
	tick := time.NewTicker(50 * time.Millisecond)
	defer tick.Stop()
	for {
		select {
		case <-a.ctx.Done():
			return
		case <-tick.C:
			if a.sender == nil {
				continue
			}
			preview := a.sender.PreviewSnapshot()
			if preview != nil {
				flat := make([]int, 0, len(preview)*3)
				for _, c := range preview {
					flat = append(flat, clamp255(int(c.R)), clamp255(int(c.G)), clamp255(int(c.B)))
				}
				wruntime.EventsEmit(a.ctx, "strip-update", flat)
			}
			a.mu.Lock()
			runner := a.audioRunner
			mode := a.mode
			a.mu.Unlock()
			if mode == "audio" && runner != nil {
				lvl := runner.Level()
				wruntime.EventsEmit(a.ctx, "audio-level", map[string]float64{
					"bass": clamp01(lvl.Bass),
					"mid":  clamp01(lvl.Mid),
					"high": clamp01(lvl.High),
				})
			}
			wruntime.EventsEmit(a.ctx, "status", map[string]interface{}{
				"mode": mode,
				"fps":  a.cfg.SendFPS,
			})
		}
	}
}

func (a *App) GetSettings() settings.Settings {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.cfg
}

func (a *App) SaveSettings(s settings.Settings) error {
	a.mu.Lock()
	a.cfg = s
	a.mu.Unlock()
	if a.sender != nil {
		if err := a.sender.UpdateSettings(s); err != nil {
			return err
		}
	}
	return settings.Save(s)
}

func (a *App) GetMode() string {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.mode
}

func (a *App) SetMode(mode string) error {
	a.stopMode()

	a.mu.Lock()
	a.mode = mode
	a.cfg.Mode = mode
	cfg := a.cfg
	a.mu.Unlock()

	_ = settings.Save(cfg)

	if mode == "off" {
		if a.sender != nil {
			a.sender.PushZero()
		}
		return nil
	}
	if a.sender == nil {
		return fmt.Errorf("sender not ready")
	}

	mCtx, mCancel := context.WithCancel(context.Background())
	a.mu.Lock()
	a.modeCancel = mCancel
	a.mu.Unlock()

	switch mode {
	case "audio":
		ar := audio.New(cfg, a.sender)
		a.mu.Lock()
		a.audioRunner = ar
		a.mu.Unlock()
		a.modeWg.Add(1)
		go func() {
			defer a.modeWg.Done()
			if err := ar.Run(mCtx); err != nil {
				wruntime.LogErrorf(a.ctx, "audio runner: %v", err)
			}
		}()
	case "video":
		vr := video.New(cfg, a.sender)
		a.modeWg.Add(1)
		go func() {
			defer a.modeWg.Done()
			if err := vr.Run(mCtx); err != nil {
				wruntime.LogErrorf(a.ctx, "video runner: %v", err)
			}
		}()
	default:
		return fmt.Errorf("unknown mode: %s", mode)
	}
	return nil
}

func (a *App) stopMode() {
	a.mu.Lock()
	cancel := a.modeCancel
	a.modeCancel = nil
	a.audioRunner = nil
	a.mu.Unlock()
	if cancel != nil {
		cancel()
	}
	a.modeWg.Wait()
}

func (a *App) TestConnection() error {
	if a.sender == nil {
		return fmt.Errorf("sender not ready")
	}
	return a.sender.Blink()
}

func (a *App) GetMonitors() []video.MonitorInfo {
	return video.ListMonitors()
}

func (a *App) DiscoverDevices() []discover.Device {
	return discover.Find(a.ctx, 3*time.Second)
}

// ResetAudio replaces audio settings with defaults, preserves everything else,
// persists, applies, and returns the resulting Settings so the UI can rebind.
func (a *App) ResetAudio() (settings.Settings, error) {
	a.mu.Lock()
	a.cfg.Audio = settings.AudioDefaults()
	cfg := a.cfg
	a.mu.Unlock()
	return cfg, a.applyAndSave(cfg)
}

func (a *App) ResetVideo() (settings.Settings, error) {
	a.mu.Lock()
	a.cfg.Video = settings.VideoDefaults()
	cfg := a.cfg
	a.mu.Unlock()
	return cfg, a.applyAndSave(cfg)
}

// ResetAll restores every setting to defaults except for the IP (keeps the
// user's WLED address so they don't have to retype it). Pass true to also
// reset the IP.
func (a *App) ResetAll(resetIP bool) (settings.Settings, error) {
	a.mu.Lock()
	oldIP := a.cfg.WLEDIP
	a.cfg = settings.Defaults()
	if !resetIP {
		a.cfg.WLEDIP = oldIP
	}
	a.cfg.Mode = a.mode
	cfg := a.cfg
	a.mu.Unlock()
	return cfg, a.applyAndSave(cfg)
}

func (a *App) GetDefaults() settings.Settings {
	return settings.Defaults()
}

// GetAudioPresets returns the named presets the UI can apply.
func (a *App) GetAudioPresets() []settings.AudioPreset {
	return settings.AudioPresets()
}

// ApplyAudioPreset overwrites the audio knobs from a named preset, keeping
// palette/mono hue and device-level fields. Returns the merged Settings.
func (a *App) ApplyAudioPreset(id string) (settings.Settings, error) {
	a.mu.Lock()
	a.cfg.Audio = settings.ApplyAudioPreset(a.cfg.Audio, id)
	cfg := a.cfg
	a.mu.Unlock()
	return cfg, a.applyAndSave(cfg)
}

func (a *App) applyAndSave(s settings.Settings) error {
	if a.sender != nil {
		if err := a.sender.UpdateSettings(s); err != nil {
			return err
		}
	}
	return settings.Save(s)
}

func clamp255(v int) int {
	if v < 0 {
		return 0
	}
	if v > 255 {
		return 255
	}
	return v
}

func clamp01(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 1
	}
	return v
}

var _ = strip.New
