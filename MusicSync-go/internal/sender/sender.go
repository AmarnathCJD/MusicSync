package sender

import (
	"context"
	"fmt"
	"math"
	"math/rand"
	"net"
	"sync"
	"time"

	"musicsync/internal/settings"
	"musicsync/internal/strip"
)

type Sender struct {
	mu       sync.RWMutex
	target   []strip.RGB
	current  []strip.RGB
	settings settings.Settings
	conn     *net.UDPConn
	addr     *net.UDPAddr

	previewMu     sync.Mutex
	previewLatest []strip.RGB
}

func New(s settings.Settings) (*Sender, error) {
	snd := &Sender{
		settings: s,
		target:   strip.New(s.LEDCount),
		current:  strip.New(s.LEDCount),
	}
	if err := snd.dial(); err != nil {
		return nil, err
	}
	return snd, nil
}

func (s *Sender) dial() error {
	addr, err := net.ResolveUDPAddr("udp", fmt.Sprintf("%s:%d", s.settings.WLEDIP, s.settings.Port))
	if err != nil {
		return err
	}
	conn, err := net.DialUDP("udp", nil, addr)
	if err != nil {
		return err
	}
	s.addr = addr
	s.conn = conn
	return nil
}

func (s *Sender) UpdateSettings(cfg settings.Settings) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	reconnect := cfg.WLEDIP != s.settings.WLEDIP || cfg.Port != s.settings.Port
	resize := cfg.LEDCount != s.settings.LEDCount
	s.settings = cfg
	if resize {
		s.target = strip.New(cfg.LEDCount)
		s.current = strip.New(cfg.LEDCount)
	}
	if reconnect {
		if s.conn != nil {
			s.conn.Close()
		}
		return s.dial()
	}
	return nil
}

func (s *Sender) Push(frame []strip.RGB) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(frame) != len(s.target) {
		return
	}
	copy(s.target, frame)
}

func (s *Sender) PushZero() {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.target {
		s.target[i] = strip.RGB{}
	}
}

// Snapshot returns the current settings the sender is running with. Runners
// call this each tick so live slider changes take effect without restarting.
func (s *Sender) Snapshot() settings.Settings {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.settings
}

func (s *Sender) PreviewSnapshot() []strip.RGB {
	s.previewMu.Lock()
	defer s.previewMu.Unlock()
	if s.previewLatest == nil {
		return nil
	}
	out := make([]strip.RGB, len(s.previewLatest))
	copy(out, s.previewLatest)
	return out
}

func (s *Sender) setPreview(frame []strip.RGB) {
	s.previewMu.Lock()
	defer s.previewMu.Unlock()
	if s.previewLatest == nil || len(s.previewLatest) != len(frame) {
		s.previewLatest = make([]strip.RGB, len(frame))
	}
	copy(s.previewLatest, frame)
}

func (s *Sender) Run(ctx context.Context) {
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	packet := make([]byte, 0, 2+3*256)

	for {
		s.mu.RLock()
		fps := s.settings.SendFPS
		followSec := s.settings.FollowMs / 1000.0
		skipStart := s.settings.SkipStart
		skipEnd := s.settings.SkipEnd
		dither := s.settings.Video.TemporalDither
		n := len(s.target)
		s.mu.RUnlock()

		if fps <= 0 {
			fps = 60
		}
		if followSec <= 0 {
			followSec = 0.05
		}
		followRate := float32(1.0 - math.Exp(-1.0/(float64(fps)*followSec)))
		interval := time.Second / time.Duration(fps)
		t0 := time.Now()

		s.mu.RLock()
		for i := 0; i < n; i++ {
			s.current[i].R += (s.target[i].R - s.current[i].R) * followRate
			s.current[i].G += (s.target[i].G - s.current[i].G) * followRate
			s.current[i].B += (s.target[i].B - s.current[i].B) * followRate
		}
		s.mu.RUnlock()

		packet = packet[:0]
		packet = append(packet, 2, 255)

		s.mu.RLock()
		for i := 0; i < n; i++ {
			if i < skipStart || i >= n-skipEnd {
				packet = append(packet, 0, 0, 0)
				continue
			}
			r, g, b := s.current[i].R, s.current[i].G, s.current[i].B
			if dither {
				r += rng.Float32()
				g += rng.Float32()
				b += rng.Float32()
			} else {
				r += 0.5
				g += 0.5
				b += 0.5
			}
			packet = append(packet, byteClamp(r), byteClamp(g), byteClamp(b))
		}
		s.mu.RUnlock()

		if s.conn != nil {
			_, _ = s.conn.Write(packet)
		}

		if n > 0 {
			snapshot := make([]strip.RGB, n)
			s.mu.RLock()
			copy(snapshot, s.current)
			s.mu.RUnlock()
			s.setPreview(snapshot)
		}

		dt := time.Since(t0)
		if dt < interval {
			select {
			case <-ctx.Done():
				return
			case <-time.After(interval - dt):
			}
		} else if ctx.Err() != nil {
			return
		}
	}
}

func (s *Sender) Blink() error {
	if s.conn == nil {
		return fmt.Errorf("no connection")
	}
	s.mu.RLock()
	n := len(s.target)
	skipStart := s.settings.SkipStart
	skipEnd := s.settings.SkipEnd
	s.mu.RUnlock()

	packet := make([]byte, 0, 2+3*n)
	packet = append(packet, 2, 255)
	for i := 0; i < n; i++ {
		if i < skipStart || i >= n-skipEnd {
			packet = append(packet, 0, 0, 0)
			continue
		}
		packet = append(packet, 255, 255, 255)
	}
	_, err := s.conn.Write(packet)
	return err
}

func (s *Sender) Close() {
	if s.conn != nil {
		s.conn.Close()
	}
}

func byteClamp(v float32) byte {
	x := int(v)
	if x < 0 {
		return 0
	}
	if x > 255 {
		return 255
	}
	return byte(x)
}
