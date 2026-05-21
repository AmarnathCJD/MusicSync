import socket
import numpy as np
import soundcard as sc
import colorsys

WLED_IP = "10.158.240.95"
PORT = 21324
LED_COUNT = 60
SAMPLE_RATE = 44100
FRAMES = 512

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

speaker = sc.default_speaker()
loopback = sc.get_microphone(id=str(speaker.name), include_loopback=True)

phase = 0.0
center = 0.5
smoothed_level = 0.0
bass_baseline = 0.0
peak = 1e-6
palette_shift = 0.0

freqs = np.fft.rfftfreq(FRAMES, d=1.0 / SAMPLE_RATE)
bass_mask = (freqs >= 20) & (freqs <= 200)
mid_mask = (freqs > 200) & (freqs <= 2000)
high_mask = (freqs > 2000) & (freqs <= 8000)
window = np.hanning(FRAMES)


def shape_color(hue, brightness, energy):
    sat = 0.78 + 0.18 * energy
    val = brightness ** 0.65
    r, g, b = colorsys.hsv_to_rgb(hue % 1.0, sat, val)
    r = r ** 0.9
    g = g ** 1.0
    b = b ** 1.1
    return int(r * 255), int(g * 255), int(b * 255)


with loopback.recorder(samplerate=SAMPLE_RATE, blocksize=FRAMES) as mic:
    while True:
        data = mic.record(numframes=FRAMES)
        mono = data.mean(axis=1)

        spectrum = np.abs(np.fft.rfft(mono * window))
        bass = spectrum[bass_mask].mean()
        mid = spectrum[mid_mask].mean()
        high = spectrum[high_mask].mean()

        level = bass + mid + high
        peak = max(peak * 0.9995, level, 1e-6)
        norm_level = level / peak

        smoothed_level = 0.35 * smoothed_level + 0.65 * norm_level

        bass_norm = bass / peak
        bass_baseline = 0.92 * bass_baseline + 0.08 * bass_norm
        beat = max(0.0, bass_norm - bass_baseline)

        brightness = min(1.0, smoothed_level * 0.55 + beat * 3.0)
        brightness = max(0.04, brightness)

        phase += 0.0015 + smoothed_level * 0.02
        center = (center + 0.001 + beat * 0.05) % 1.0

        palette_shift = 0.97 * palette_shift + 0.03 * (high / (peak + 1e-6))
        base_hue = phase + palette_shift * 0.35

        hue_spread = 0.12 + min(0.35, smoothed_level * 0.4)

        packet = bytearray([2, 255])
        for i in range(LED_COUNT):
            pos = i / LED_COUNT
            dist = abs(pos - center)
            dist = min(dist, 1.0 - dist)
            falloff = 1.0 - dist * 0.6

            hue = base_hue + (pos - 0.5) * hue_spread
            led_brightness = brightness * (0.7 + 0.3 * falloff)

            r, g, b = shape_color(hue, led_brightness, smoothed_level)
            packet.extend([r, g, b])

        sock.sendto(packet, (WLED_IP, PORT))
