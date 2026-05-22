package strip

import "math"

type RGB struct {
	R, G, B float32
}

func New(n int) []RGB { return make([]RGB, n) }

func Clear(s []RGB) {
	for i := range s {
		s[i] = RGB{}
	}
}

func Mirror(s []RGB) {
	for i, j := 0, len(s)-1; i < j; i, j = i+1, j-1 {
		s[i], s[j] = s[j], s[i]
	}
}

func Saturate(s []RGB, amount float32) {
	for i, c := range s {
		mn := minF(c.R, minF(c.G, c.B))
		s[i].R = mn + (c.R-mn)*amount
		s[i].G = mn + (c.G-mn)*amount
		s[i].B = mn + (c.B-mn)*amount
	}
}

func Gamma(s []RGB, g float32) {
	gg := float64(g)
	for i, c := range s {
		s[i].R = float32(math.Pow(clamp01(float64(c.R)/255), gg) * 255)
		s[i].G = float32(math.Pow(clamp01(float64(c.G)/255), gg) * 255)
		s[i].B = float32(math.Pow(clamp01(float64(c.B)/255), gg) * 255)
	}
}

func Highlight(s []RGB, gain, threshold float32) {
	t := threshold * 255
	for i, c := range s {
		luma := 0.299*c.R + 0.587*c.G + 0.114*c.B
		if luma > t {
			s[i].R *= gain
			s[i].G *= gain
			s[i].B *= gain
		}
	}
}

func BlackKnee(s []RGB, floor, knee float32) {
	span := knee - floor
	if span <= 0 {
		span = 1
	}
	for i, c := range s {
		mx := maxF(c.R, maxF(c.G, c.B))
		fade := (mx - floor) / span
		if fade < 0 {
			fade = 0
		}
		if fade > 1 {
			fade = 1
		}
		s[i].R *= fade
		s[i].G *= fade
		s[i].B *= fade
	}
}

func Clamp(s []RGB) {
	for i, c := range s {
		s[i].R = clamp255f(c.R)
		s[i].G = clamp255f(c.G)
		s[i].B = clamp255f(c.B)
	}
}

func Copy(dst, src []RGB) {
	n := len(src)
	if len(dst) < n {
		n = len(dst)
	}
	copy(dst[:n], src[:n])
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

func clamp255f(v float32) float32 {
	if v < 0 {
		return 0
	}
	if v > 255 {
		return 255
	}
	return v
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
