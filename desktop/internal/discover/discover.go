// Package discover finds WLED instances on the LAN via mDNS.
//
// WLED advertises itself as `_wled._tcp.local`. We query that service type
// and return whatever resolves within the timeout window.
package discover

import (
	"context"
	"net"
	"time"

	"github.com/hashicorp/mdns"
)

type Device struct {
	Name string `json:"name"`
	IP   string `json:"ip"`
	Port int    `json:"port"`
}

// Find queries the LAN for WLED devices. Blocks for up to `timeout`.
func Find(ctx context.Context, timeout time.Duration) []Device {
	entries := make(chan *mdns.ServiceEntry, 16)
	results := make([]Device, 0)
	seen := make(map[string]struct{})

	done := make(chan struct{})
	go func() {
		for e := range entries {
			ip := pickIP(e)
			if ip == "" {
				continue
			}
			key := ip
			if _, dup := seen[key]; dup {
				continue
			}
			seen[key] = struct{}{}
			name := e.Name
			if e.Host != "" {
				name = trimDot(e.Host)
			}
			results = append(results, Device{
				Name: name,
				IP:   ip,
				Port: e.Port,
			})
		}
		close(done)
	}()

	params := mdns.DefaultParams("_wled._tcp")
	params.Entries = entries
	params.Timeout = timeout
	params.DisableIPv6 = true

	_ = mdns.Query(params)
	close(entries)
	<-done
	return results
}

func pickIP(e *mdns.ServiceEntry) string {
	if e.AddrV4 != nil && !e.AddrV4.IsUnspecified() {
		return e.AddrV4.String()
	}
	if ip := net.ParseIP(e.Addr.String()); ip != nil && ip.To4() != nil {
		return ip.String()
	}
	return ""
}

func trimDot(s string) string {
	for len(s) > 0 && s[len(s)-1] == '.' {
		s = s[:len(s)-1]
	}
	return s
}

var _ = context.Canceled
