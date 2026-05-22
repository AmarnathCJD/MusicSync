package video

import (
	"context"
	"fmt"
	"image"
	"math"
	"time"

	"github.com/kbinani/screenshot"

	"musicsync/internal/sender"
	"musicsync/internal/settings"
	"musicsync/internal/strip"
)

type Runner struct {
	initial settings.Settings
	sender  *sender.Sender
}

func New(s settings.Settings, snd *sender.Sender) *Runner {
	return &Runner{initial: s, sender: snd}
}

// live pulls the latest settings from the sender so slider changes take
// effect without restarting the video mode.
func (r *Runner) live() settings.Settings {
	if r.sender == nil {
		return r.initial
	}
	return r.sender.Snapshot()
}

type MonitorInfo struct {
	Index  int    `json:"index"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
	Label  string `json:"label"`
}

func ListMonitors() []MonitorInfo {
	n := screenshot.NumActiveDisplays()
	out := make([]MonitorInfo, 0, n)
	for i := 0; i < n; i++ {
		b := screenshot.GetDisplayBounds(i)
		label := fmt.Sprintf("Display %d (%dx%d)", i+1, b.Dx(), b.Dy())
		if i == 0 {
			label = "Primary " + label
		}
		out = append(out, MonitorInfo{
			Index:  i,
			Width:  b.Dx(),
			Height: b.Dy(),
			Label:  label,
		})
	}
	return out
}

func (r *Runner) Run(ctx context.Context) error {
	n := screenshot.NumActiveDisplays()
	if n == 0 {
		return fmt.Errorf("no displays detected")
	}
	idx := r.initial.Video.MonitorIndex
	if idx < 0 || idx >= n {
		idx = 0
	}
	bounds := screenshot.GetDisplayBounds(idx)

	captureFPS := r.initial.Video.CaptureFPS
	if captureFPS <= 0 {
		captureFPS = 60
	}
	interval := time.Second / time.Duration(captureFPS)

	for {
		t0 := time.Now()

		img, err := screenshot.CaptureRect(bounds)
		if err == nil {
			out := r.processFrame(img)
			r.sender.Push(out)
		}

		dt := time.Since(t0)
		wait := interval - dt
		if wait < 0 {
			wait = 0
		}
		select {
		case <-ctx.Done():
			r.sender.PushZero()
			return nil
		case <-time.After(wait):
		}
	}
}

func (r *Runner) processFrame(img *image.RGBA) []strip.RGB {
	live := r.live()
	cfg := live.Video

	srcW := img.Bounds().Dx()
	srcH := img.Bounds().Dy()
	if srcW == 0 || srcH == 0 {
		return strip.New(live.LEDCount)
	}

	targetW := cfg.DownscaleWidth
	if targetW <= 0 {
		targetW = 320
	}
	if targetW > srcW {
		targetW = srcW
	}
	targetH := int(float64(srcH) * float64(targetW) / float64(srcW))
	if targetH < 1 {
		targetH = 1
	}

	pix := downsample(img, targetW, targetH)

	pix = cropBlackBars(pix, targetW, targetH, cfg.BlackBarCutoff)
	cw := len(pix[0]) / 3
	ch := len(pix)

	active := live.LEDCount - live.SkipStart - live.SkipEnd
	if active < 1 {
		active = 1
	}
	sample := sampleColumns(pix, cw, ch, active, cfg.VerticalBias)

	if cfg.Mirror {
		for i, j := 0, len(sample)-1; i < j; i, j = i+1, j-1 {
			sample[i], sample[j] = sample[j], sample[i]
		}
	}

	processed := punchColors(sample, cfg)

	out := strip.New(live.LEDCount)
	for i, c := range processed {
		out[live.SkipStart+i] = c
	}
	return out
}

func downsample(img *image.RGBA, w, h int) [][]byte {
	bounds := img.Bounds()
	srcW := bounds.Dx()
	srcH := bounds.Dy()

	rows := make([][]byte, h)
	for y := 0; y < h; y++ {
		srcY := y * srcH / h
		row := make([]byte, w*3)
		for x := 0; x < w; x++ {
			srcX := x * srcW / w
			off := img.PixOffset(bounds.Min.X+srcX, bounds.Min.Y+srcY)
			row[x*3+0] = img.Pix[off+0]
			row[x*3+1] = img.Pix[off+1]
			row[x*3+2] = img.Pix[off+2]
		}
		rows[y] = row
	}
	return rows
}

func cropBlackBars(rows [][]byte, w, h int, cutoff float64) [][]byte {
	if cutoff <= 0 || h < 20 || w < 20 {
		return rows
	}
	thresh := cutoff * 255

	rowBright := make([]float64, h)
	colBright := make([]float64, w)
	for y, row := range rows {
		s := 0.0
		for x := 0; x < w; x++ {
			lum := 0.299*float64(row[x*3+0]) + 0.587*float64(row[x*3+1]) + 0.114*float64(row[x*3+2])
			s += lum
			colBright[x] += lum
		}
		rowBright[y] = s / float64(w)
	}
	for x := range colBright {
		colBright[x] /= float64(h)
	}

	r0, r1 := -1, -1
	for y, b := range rowBright {
		if b > thresh {
			if r0 < 0 {
				r0 = y
			}
			r1 = y
		}
	}
	c0, c1 := -1, -1
	for x, b := range colBright {
		if b > thresh {
			if c0 < 0 {
				c0 = x
			}
			c1 = x
		}
	}
	if r0 < 0 || c0 < 0 || r1-r0 < 10 || c1-c0 < 10 {
		return rows
	}

	out := make([][]byte, r1-r0+1)
	for i := r0; i <= r1; i++ {
		out[i-r0] = rows[i][c0*3 : (c1+1)*3]
	}
	return out
}

func sampleColumns(rows [][]byte, w, h int, count int, verticalBias float64) []strip.RGB {
	if count < 1 {
		count = 1
	}
	rowWeights := make([]float64, h)
	wSum := 0.0
	for y := 0; y < h; y++ {
		t := float64(y) / float64(maxInt(h-1, 1))
		v := (1.0 - verticalBias) + verticalBias*t
		rowWeights[y] = v
		wSum += v
	}
	if wSum > 0 {
		for i := range rowWeights {
			rowWeights[i] /= wSum
		}
	}

	weighted := make([][3]float64, w)
	for y, row := range rows {
		wf := rowWeights[y]
		for x := 0; x < w; x++ {
			weighted[x][0] += float64(row[x*3+0]) * wf
			weighted[x][1] += float64(row[x*3+1]) * wf
			weighted[x][2] += float64(row[x*3+2]) * wf
		}
	}

	out := make([]strip.RGB, count)
	colW := float64(w) / float64(count)
	for i := 0; i < count; i++ {
		x0 := int(float64(i) * colW)
		x1 := int(float64(i+1) * colW)
		if x1 <= x0 {
			x1 = x0 + 1
		}
		if x1 > w {
			x1 = w
		}
		var r, g, b float64
		n := float64(x1 - x0)
		for x := x0; x < x1; x++ {
			r += weighted[x][0]
			g += weighted[x][1]
			b += weighted[x][2]
		}
		out[i] = strip.RGB{
			R: float32(r / n),
			G: float32(g / n),
			B: float32(b / n),
		}
	}
	return out
}

func punchColors(s []strip.RGB, cfg settings.VideoSettings) []strip.RGB {
	out := make([]strip.RGB, len(s))
	copy(out, s)

	sat := float32(cfg.Saturation)
	gamma := cfg.Gamma
	hg := float32(cfg.HighlightGain)
	ht := float32(cfg.HighlightAt) * 255

	floor := float32(cfg.BlackFloor)
	knee := float32(cfg.BlackKnee)
	span := knee - floor
	if span <= 0 {
		span = 1
	}

	for i, c := range out {
		mn := minF(c.R, minF(c.G, c.B))
		out[i].R = mn + (c.R-mn)*sat
		out[i].G = mn + (c.G-mn)*sat
		out[i].B = mn + (c.B-mn)*sat

		if out[i].R > 255 {
			out[i].R = 255
		}
		if out[i].G > 255 {
			out[i].G = 255
		}
		if out[i].B > 255 {
			out[i].B = 255
		}

		if gamma > 0 && gamma != 1.0 {
			out[i].R = float32(math.Pow(float64(out[i].R/255), gamma) * 255)
			out[i].G = float32(math.Pow(float64(out[i].G/255), gamma) * 255)
			out[i].B = float32(math.Pow(float64(out[i].B/255), gamma) * 255)
		}

		luma := 0.299*out[i].R + 0.587*out[i].G + 0.114*out[i].B
		if luma > ht {
			out[i].R *= hg
			out[i].G *= hg
			out[i].B *= hg
		}

		mx := maxF(out[i].R, maxF(out[i].G, out[i].B))
		fade := (mx - floor) / span
		if fade < 0 {
			fade = 0
		}
		if fade > 1 {
			fade = 1
		}
		out[i].R *= fade
		out[i].G *= fade
		out[i].B *= fade

		if out[i].R > 255 {
			out[i].R = 255
		}
		if out[i].G > 255 {
			out[i].G = 255
		}
		if out[i].B > 255 {
			out[i].B = 255
		}
	}
	return out
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}
func minF(a, b float32) float32 {
	if a < b {
		return a
	}
	return b
}
func maxF(a, b float32) float32 {
	if a > b {
		return a
	}
	return b
}
