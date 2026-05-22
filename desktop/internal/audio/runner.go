package audio

import (
	"context"
	"fmt"
	"math"
	"sync"
	"sync/atomic"
	"time"
	"unsafe"

	"github.com/gen2brain/malgo"
	"gonum.org/v1/gonum/dsp/fourier"

	"musicsync/internal/sender"
	"musicsync/internal/settings"
	"musicsync/internal/strip"
)

type Runner struct {
	initial settings.Settings
	sender  *sender.Sender

	mu       sync.Mutex
	ringBuf  []float32
	ringPos  int
	ringFull bool
	frames   int

	actualSampleRate float64
	fftState         *runtimeFFT

	peak         float64
	smoothLevel  float64
	bassBaseline float64
	phase        float64
	center       float64
	paletteShift float64
	silenceFade  float64 // 1 = full music, 0 = full silence

	lastLevel atomic.Value
}

type LevelSnapshot struct {
	Bass float64
	Mid  float64
	High float64
}

func New(s settings.Settings, snd *sender.Sender) *Runner {
	return &Runner{
		initial: s,
		sender:  snd,
		frames:  s.Audio.Frames,
		ringBuf: make([]float32, s.Audio.Frames),
		peak:    1e-6,
	}
}

// live pulls the latest settings from the sender so slider changes take
// effect without restarting the audio mode. Falls back to the snapshot
// captured at construction time if the sender ever loses them.
func (r *Runner) live() settings.Settings {
	if r.sender == nil {
		return r.initial
	}
	return r.sender.Snapshot()
}

func (r *Runner) Level() LevelSnapshot {
	v := r.lastLevel.Load()
	if v == nil {
		return LevelSnapshot{}
	}
	return v.(LevelSnapshot)
}

func (r *Runner) Run(ctx context.Context) error {
	mctx, err := malgo.InitContext(nil, malgo.ContextConfig{}, func(msg string) {})
	if err != nil {
		return fmt.Errorf("malgo init: %w", err)
	}
	defer func() {
		_ = mctx.Uninit()
		mctx.Free()
	}()

	deviceConfig := malgo.DefaultDeviceConfig(malgo.Loopback)
	deviceConfig.Capture.Format = malgo.FormatF32
	deviceConfig.Capture.Channels = 2
	deviceConfig.SampleRate = uint32(r.initial.Audio.SampleRate)
	deviceConfig.Alsa.NoMMap = 1

	captureCallback := func(_ []byte, inSamples []byte, frameCount uint32) {
		samples := unsafe.Slice((*float32)(unsafe.Pointer(&inSamples[0])), int(frameCount)*int(deviceConfig.Capture.Channels))
		channels := int(deviceConfig.Capture.Channels)
		r.ingest(samples, channels)
	}

	callbacks := malgo.DeviceCallbacks{
		Data: captureCallback,
	}

	device, err := malgo.InitDevice(mctx.Context, deviceConfig, callbacks)
	if err != nil {
		return fmt.Errorf("malgo init device: %w", err)
	}
	defer device.Uninit()

	if err := device.Start(); err != nil {
		return fmt.Errorf("malgo start: %w", err)
	}
	defer device.Stop()

	r.actualSampleRate = float64(deviceConfig.SampleRate)
	r.buildFFT()

	tick := time.NewTicker(16 * time.Millisecond)
	defer tick.Stop()
	for {
		select {
		case <-ctx.Done():
			r.sender.PushZero()
			return nil
		case <-tick.C:
			r.process()
		}
	}
}

func (r *Runner) ingest(samples []float32, channels int) {
	r.mu.Lock()
	defer r.mu.Unlock()
	for i := 0; i+channels-1 < len(samples); i += channels {
		mono := samples[i]
		if channels > 1 {
			mono = (samples[i] + samples[i+1]) * 0.5
		}
		r.ringBuf[r.ringPos] = mono
		r.ringPos++
		if r.ringPos >= len(r.ringBuf) {
			r.ringPos = 0
			r.ringFull = true
		}
	}
}

var (
	bassMask = [2]float64{20, 200}
	midMask  = [2]float64{200, 2000}
	highMask = [2]float64{2000, 8000}
)

type runtimeFFT struct {
	fft        *fourier.FFT
	window     []float64
	freqs      []float64
	bassIdx    []int
	midIdx     []int
	highIdx    []int
	inBuf      []float64
}

func (r *Runner) buildFFT() {
	if r.fftState != nil && r.fftState.fft != nil && r.fftState.fft.Len() == r.frames {
		return
	}
	st := &runtimeFFT{
		fft:    fourier.NewFFT(r.frames),
		window: make([]float64, r.frames),
		inBuf:  make([]float64, r.frames),
	}
	for i := 0; i < r.frames; i++ {
		st.window[i] = 0.5 * (1 - math.Cos(2*math.Pi*float64(i)/float64(r.frames-1)))
	}
	sr := r.actualSampleRate
	if sr <= 0 {
		sr = float64(r.initial.Audio.SampleRate)
	}
	binCount := r.frames/2 + 1
	st.freqs = make([]float64, binCount)
	for i := 0; i < binCount; i++ {
		st.freqs[i] = float64(i) * sr / float64(r.frames)
	}
	for i, f := range st.freqs {
		if f >= bassMask[0] && f <= bassMask[1] {
			st.bassIdx = append(st.bassIdx, i)
		}
		if f > midMask[0] && f <= midMask[1] {
			st.midIdx = append(st.midIdx, i)
		}
		if f > highMask[0] && f <= highMask[1] {
			st.highIdx = append(st.highIdx, i)
		}
	}
	r.fftState = st
}

func (r *Runner) process() {
	r.mu.Lock()
	if !r.ringFull && r.ringPos < r.frames {
		r.mu.Unlock()
		return
	}
	if r.fftState == nil {
		r.mu.Unlock()
		return
	}
	st := r.fftState
	for i := 0; i < r.frames; i++ {
		idx := (r.ringPos + i) % len(r.ringBuf)
		st.inBuf[i] = float64(r.ringBuf[idx]) * st.window[i]
	}
	r.mu.Unlock()

	coeffs := st.fft.Coefficients(nil, st.inBuf)
	mag := func(idxs []int) float64 {
		if len(idxs) == 0 {
			return 0
		}
		sum := 0.0
		for _, i := range idxs {
			sum += complexAbs(coeffs[i])
		}
		return sum / float64(len(idxs))
	}
	bass := mag(st.bassIdx)
	mid := mag(st.midIdx)
	high := mag(st.highIdx)
	level := bass + mid + high

	cfg := r.live()
	a := cfg.Audio

	// Absolute-energy silence gate. The previous code normalized against a
	// decaying peak, which meant ambient noise / DC bias still produced a
	// non-zero `normLevel` and the strip kept glowing during idle.
	silenceFloor := a.SilenceFloor
	if silenceFloor <= 0 {
		silenceFloor = 0.0008
	}
	silenceOpen := silenceFloor * 3.125 // ~hysteresis band
	if level <= silenceFloor {
		r.silenceFade -= 0.08
	} else if level >= silenceOpen {
		r.silenceFade += 0.15
	}
	if r.silenceFade < 0 {
		r.silenceFade = 0
	} else if r.silenceFade > 1 {
		r.silenceFade = 1
	}

	// Only let the peak track real signal. Floor it at silenceOpen so a quiet
	// room can't keep normalizing trace amounts of noise up to "full".
	target := level
	if target < silenceOpen {
		target = silenceOpen
	}
	if target > r.peak {
		r.peak = target
	} else {
		r.peak = 0.9995*r.peak + 0.0005*target
	}
	if r.peak < silenceOpen {
		r.peak = silenceOpen
	}

	normLevel := level / r.peak
	if r.silenceFade <= 0 {
		normLevel = 0
	}
	smoothing := clamp(a.Smoothing, 0, 0.95)
	r.smoothLevel = smoothing*r.smoothLevel + (1-smoothing)*normLevel

	bassNorm := bass / r.peak
	r.bassBaseline = 0.92*r.bassBaseline + 0.08*bassNorm
	beatStrength := bassNorm - r.bassBaseline
	beatThresh := a.BeatThreshold
	if beatThresh <= 0 {
		beatThresh = 0.12
	}
	beat := 0.0
	if r.silenceFade > 0 && beatStrength > beatThresh {
		beat = beatStrength - beatThresh
	}

	r.lastLevel.Store(LevelSnapshot{
		Bass: bassNorm * r.silenceFade,
		Mid:  (mid / r.peak) * r.silenceFade,
		High: (high / r.peak) * r.silenceFade,
	})

	r.phase += a.HueDrift + r.smoothLevel*0.02
	if r.phase > 1e6 || r.phase < -1e6 {
		r.phase = math.Mod(r.phase, 1.0)
	}
	centerMotion := clamp(a.CenterMotion, 0, 1)
	if centerMotion > 0 {
		r.center = math.Mod(r.center+0.001*centerMotion+beat*0.05*centerMotion, 1.0)
	} else {
		r.center = 0.5
	}
	r.paletteShift = 0.97*r.paletteShift + 0.03*(high/(r.peak+1e-6))

	brightness := r.smoothLevel*0.55 + beat*a.BeatGain
	if brightness > 1 {
		brightness = 1
	}
	if brightness < 0 {
		brightness = 0
	}
	brightness *= a.Brightness * r.silenceFade

	paletteBase, paletteWindow := paletteParams(a.Palette)
	if a.Palette == "mono" {
		// MonoHue is in degrees (0..360) — convert to 0..1.
		paletteBase = math.Mod(a.MonoHue/360.0, 1.0)
		if paletteBase < 0 {
			paletteBase += 1
		}
	}
	hueSpread := clamp(a.HueSpread, 0, 1) * paletteWindow
	// For constrained palettes (window < 1) we don't want r.phase to march the
	// hue around the entire wheel — that would defeat picking a palette at all.
	// Drift oscillates inside ±half-window of the base hue instead. Rainbow
	// (window == 1) keeps the original free-running behavior.
	var baseHue float64
	if paletteWindow >= 0.999 {
		baseHue = paletteBase + r.phase + r.paletteShift*0.35
	} else if paletteWindow <= 1e-6 {
		// "mono" — pin the hue entirely, no drift, no shift
		baseHue = paletteBase
	} else {
		osc := math.Sin(r.phase*2*math.Pi) * 0.5 * paletteWindow
		shift := (r.paletteShift - 0.5) * 0.25 * paletteWindow
		baseHue = paletteBase + osc + shift
	}

	gamma := a.Gamma
	if gamma <= 0 {
		gamma = 0.85
	}
	falloffPower := clamp(a.BassFalloff, 0, 3)

	n := cfg.LEDCount
	out := strip.New(n)
	if r.silenceFade <= 0 || brightness <= 0 {
		r.sender.Push(out) // all zeros — sender will interpolate down to black
		return
	}
	for i := 0; i < n; i++ {
		pos := float64(i) / float64(n)
		dist := math.Abs(pos - r.center)
		if d := 1.0 - dist; d < dist {
			dist = d
		}
		// Bass falloff: 0 = flat strip, 1 = gentle pulse, 2+ = tight center pulse.
		var falloff float64
		if falloffPower <= 0 {
			falloff = 1.0
		} else {
			falloff = math.Pow(1.0-dist*0.6, 1.0+falloffPower)
		}
		hue := math.Mod(baseHue+(pos-0.5)*hueSpread, 1.0)
		if hue < 0 {
			hue += 1
		}
		val := brightness * (0.7 + 0.3*falloff)
		sat := a.Saturation + 0.12*r.smoothLevel
		if sat > 1 {
			sat = 1
		}
		rF, gF, bF := hsvToRGB(hue, sat, math.Pow(val, gamma))
		out[i] = strip.RGB{
			R: float32(rF * 255),
			G: float32(gF * 255),
			B: float32(bF * 255),
		}
	}
	r.sender.Push(out)
}

// paletteParams returns the base hue and the spread window (fraction of the
// color wheel) for a named palette. Spread window of 1.0 = whole wheel.
func paletteParams(name string) (base, window float64) {
	switch name {
	case "warm":
		return 0.02, 0.18 // red → orange → yellow
	case "cool":
		return 0.50, 0.20 // cyan → blue → indigo
	case "mono":
		return 0.0, 0.0 // pinned, no hue spread
	case "sunset":
		return 0.92, 0.22 // pink → red → orange
	case "aurora":
		return 0.30, 0.28 // green → teal → blue
	case "forest":
		return 0.25, 0.16 // greens
	default: // rainbow
		return 0.0, 1.0
	}
}

func complexAbs(c complex128) float64 {
	return math.Hypot(real(c), imag(c))
}

func hsvToRGB(h, s, v float64) (float64, float64, float64) {
	if s <= 0 {
		return v, v, v
	}
	h = math.Mod(h, 1)
	if h < 0 {
		h += 1
	}
	h6 := h * 6
	i := math.Floor(h6)
	f := h6 - i
	p := v * (1 - s)
	q := v * (1 - s*f)
	t := v * (1 - s*(1-f))
	switch int(i) % 6 {
	case 0:
		return v, t, p
	case 1:
		return q, v, p
	case 2:
		return p, v, t
	case 3:
		return p, q, v
	case 4:
		return t, p, v
	default:
		return v, p, q
	}
}

func clamp(v, lo, hi float64) float64 {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
