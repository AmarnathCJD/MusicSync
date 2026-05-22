package settings

import (
	"encoding/json"
	"os"
	"path/filepath"
)

type AudioSettings struct {
	SampleRate    int     `json:"sample_rate"`
	Frames        int     `json:"frames"`
	BeatGain      float64 `json:"beat_gain"`
	HueDrift      float64 `json:"hue_drift"`
	Brightness    float64 `json:"brightness"`
	Saturation    float64 `json:"saturation"`
	Smoothing     float64 `json:"smoothing"`      // 0=snap, 1=slow molasses
	BeatThreshold float64 `json:"beat_threshold"` // bass-baseline gap for a beat
	SilenceFloor  float64 `json:"silence_floor"`  // abs energy below this → idle
	BassFalloff   float64 `json:"bass_falloff"`   // 0=flat, 2=tight center pulse
	HueSpread     float64 `json:"hue_spread"`     // 0=mono, 0.5=wide rainbow
	Gamma         float64 `json:"gamma"`          // perceived brightness curve
	CenterMotion  float64 `json:"center_motion"`  // 0=pinned middle, 1=wanders
	Palette       string  `json:"palette"`        // rainbow | warm | cool | mono | sunset | aurora
	MonoHue       float64 `json:"mono_hue"`       // 0..360, used only when palette=="mono"
}

type VideoSettings struct {
	MonitorIndex   int     `json:"monitor_index"`
	DownscaleWidth int     `json:"downscale_width"`
	CaptureFPS     int     `json:"capture_fps"`
	VerticalBias   float64 `json:"vertical_bias"`
	Mirror         bool    `json:"mirror"`
	Saturation     float64 `json:"saturation"`
	Gamma          float64 `json:"gamma"`
	HighlightGain  float64 `json:"highlight_gain"`
	HighlightAt    float64 `json:"highlight_at"`
	BlackFloor     int     `json:"black_floor"`
	BlackKnee      int     `json:"black_knee"`
	BlackBarCutoff float64 `json:"black_bar_cutoff"`
	TemporalDither bool    `json:"temporal_dither"`
}

type Settings struct {
	WLEDIP    string        `json:"wled_ip"`
	Port      int           `json:"port"`
	LEDCount  int           `json:"led_count"`
	SkipStart int           `json:"skip_start"`
	SkipEnd   int           `json:"skip_end"`
	SendFPS   int           `json:"send_fps"`
	FollowMs  float64       `json:"follow_ms"`
	Mode      string        `json:"mode"`
	Audio     AudioSettings `json:"audio"`
	Video     VideoSettings `json:"video"`
}

func Defaults() Settings {
	return Settings{
		WLEDIP:    "10.158.240.95",
		Port:      21324,
		LEDCount:  60,
		SkipStart: 8,
		SkipEnd:   3,
		SendFPS:   144,
		FollowMs:  50,
		Mode:      "off",
		Audio: AudioSettings{
			SampleRate:    44100,
			Frames:        1024,
			BeatGain:      2.5,
			HueDrift:      0.015,
			Brightness:    1.0,
			Saturation:    0.88,
			Smoothing:     0.35,
			BeatThreshold: 0.12,
			SilenceFloor:  0.0008,
			BassFalloff:   1.0,
			HueSpread:     0.18,
			Gamma:         0.85,
			CenterMotion:  0.5,
			Palette:       "rainbow",
			MonoHue:       0,
		},
		Video: VideoSettings{
			MonitorIndex:   0,
			DownscaleWidth: 320,
			CaptureFPS:     60,
			VerticalBias:   0.5,
			Mirror:         true,
			Saturation:     1.4,
			Gamma:          0.85,
			HighlightGain:  1.2,
			HighlightAt:    0.65,
			BlackFloor:     12,
			BlackKnee:      28,
			BlackBarCutoff: 0.04,
			TemporalDither: true,
		},
	}
}

// AudioDefaults returns just the audio defaults. Used by "reset audio" UI.
func AudioDefaults() AudioSettings { return Defaults().Audio }

// VideoDefaults returns just the video defaults.
func VideoDefaults() VideoSettings { return Defaults().Video }

// AudioPreset describes a named one-click configuration the UI can apply
// without making the user understand every knob.
type AudioPreset struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Blurb string `json:"blurb"`
}

// AudioPresets is the list shown in the UI. The actual values are produced
// by ApplyAudioPreset so a preset can carry policy (e.g. "match palette to
// whatever the user already chose") rather than just static numbers.
func AudioPresets() []AudioPreset {
	return []AudioPreset{
		{ID: "chill",     Name: "Chill",     Blurb: "slow, calm, lounge"},
		{ID: "party",     Name: "Party",     Blurb: "punchy beats, full color"},
		{ID: "cinematic", Name: "Cinematic", Blurb: "moody, wide swings"},
		{ID: "strobe",    Name: "Strobe",    Blurb: "fast, snappy, bright"},
		{ID: "ambient",   Name: "Ambient",   Blurb: "barely there, soft glow"},
	}
}

// ApplyAudioPreset returns a copy of `a` with knob values overwritten by
// the named preset. SampleRate/Frames are preserved (those are device-level,
// not creative choices). Palette + MonoHue are preserved so the user's
// color taste survives a preset swap.
func ApplyAudioPreset(a AudioSettings, id string) AudioSettings {
	out := a // keep SampleRate, Frames, Palette, MonoHue
	switch id {
	case "chill":
		out.BeatGain = 1.4
		out.HueDrift = 0.008
		out.Brightness = 0.85
		out.Saturation = 0.78
		out.Smoothing = 0.65
		out.BeatThreshold = 0.18
		out.SilenceFloor = 0.0008
		out.BassFalloff = 0.4
		out.HueSpread = 0.35
		out.Gamma = 0.9
		out.CenterMotion = 0.15
	case "party":
		out.BeatGain = 3.5
		out.HueDrift = 0.025
		out.Brightness = 1.15
		out.Saturation = 0.95
		out.Smoothing = 0.25
		out.BeatThreshold = 0.10
		out.SilenceFloor = 0.0008
		out.BassFalloff = 1.4
		out.HueSpread = 0.7
		out.Gamma = 0.8
		out.CenterMotion = 0.7
	case "cinematic":
		out.BeatGain = 2.2
		out.HueDrift = 0.012
		out.Brightness = 1.0
		out.Saturation = 0.85
		out.Smoothing = 0.55
		out.BeatThreshold = 0.14
		out.SilenceFloor = 0.0008
		out.BassFalloff = 1.8
		out.HueSpread = 0.5
		out.Gamma = 0.75
		out.CenterMotion = 0.4
	case "strobe":
		out.BeatGain = 5.0
		out.HueDrift = 0.04
		out.Brightness = 1.3
		out.Saturation = 1.0
		out.Smoothing = 0.05
		out.BeatThreshold = 0.08
		out.SilenceFloor = 0.0008
		out.BassFalloff = 0.6
		out.HueSpread = 0.6
		out.Gamma = 0.7
		out.CenterMotion = 0.9
	case "ambient":
		out.BeatGain = 0.8
		out.HueDrift = 0.005
		out.Brightness = 0.6
		out.Saturation = 0.65
		out.Smoothing = 0.8
		out.BeatThreshold = 0.22
		out.SilenceFloor = 0.0008
		out.BassFalloff = 0.2
		out.HueSpread = 0.25
		out.Gamma = 1.0
		out.CenterMotion = 0.05
	default:
		// unknown id — return defaults but keep Palette/MonoHue/SR/Frames.
		d := AudioDefaults()
		d.SampleRate = a.SampleRate
		d.Frames = a.Frames
		d.Palette = a.Palette
		d.MonoHue = a.MonoHue
		return d
	}
	return out
}

func configPath() (string, error) {
	dir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	full := filepath.Join(dir, "MusicSync")
	if err := os.MkdirAll(full, 0755); err != nil {
		return "", err
	}
	return filepath.Join(full, "settings.json"), nil
}

func Load() (Settings, error) {
	path, err := configPath()
	if err != nil {
		return Defaults(), err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return Defaults(), nil
		}
		return Defaults(), err
	}
	s := Defaults()
	if err := json.Unmarshal(data, &s); err != nil {
		return Defaults(), err
	}
	// Backfill any unset audio fields with defaults so old config files still work.
	d := Defaults().Audio
	if s.Audio.Smoothing == 0 {
		s.Audio.Smoothing = d.Smoothing
	}
	if s.Audio.BeatThreshold == 0 {
		s.Audio.BeatThreshold = d.BeatThreshold
	}
	if s.Audio.SilenceFloor == 0 {
		s.Audio.SilenceFloor = d.SilenceFloor
	}
	if s.Audio.BassFalloff == 0 {
		s.Audio.BassFalloff = d.BassFalloff
	}
	if s.Audio.HueSpread == 0 {
		s.Audio.HueSpread = d.HueSpread
	}
	if s.Audio.Gamma == 0 {
		s.Audio.Gamma = d.Gamma
	}
	if s.Audio.Palette == "" {
		s.Audio.Palette = d.Palette
	}
	return s, nil
}

func Save(s Settings) error {
	path, err := configPath()
	if err != nil {
		return err
	}
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}
