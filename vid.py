import socket
import threading
import time
import numpy as np
import mss

WLED_IP = "10.158.240.95"
PORT = 21324
LED_COUNT = 60
SKIP_LEDS_START = 8
SKIP_LEDS_END = 3

MONITOR_INDEX = 1
DOWNSCALE_WIDTH = 240

CAPTURE_FPS = 60
SEND_FPS = 144

VERTICAL_BIAS = 0.5
MIRROR = True

SATURATION = 1.4
GAMMA = 0.85
HIGHLIGHT_GAIN = 1.2
HIGHLIGHT_AT = 0.65
BLACK_FLOOR = 12
BLACK_KNEE = 28

BLACK_BAR_CUTOFF = 0.04

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

target_strip = np.zeros((LED_COUNT, 3), dtype=np.float32)
target_lock = threading.Lock()
stop_event = threading.Event()


def crop_black_bars(frame):
    luma = frame.mean(axis=2)
    rows = np.where(luma.mean(axis=1) / 255.0 > BLACK_BAR_CUTOFF)[0]
    cols = np.where(luma.mean(axis=0) / 255.0 > BLACK_BAR_CUTOFF)[0]
    if len(rows) < 10 or len(cols) < 10:
        return frame
    return frame[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]


def sample_strip(img, count):
    h, w, _ = img.shape
    img = img.astype(np.float32)
    row_weights = np.linspace(1.0 - VERTICAL_BIAS, 1.0, h)
    row_weights /= row_weights.sum()
    weighted = (img * row_weights[:, None, None]).sum(axis=0)

    col_w = w / count
    out = np.zeros((count, 3), dtype=np.float32)
    for i in range(count):
        x0 = int(i * col_w)
        x1 = max(x0 + 1, int((i + 1) * col_w))
        out[i] = weighted[x0:x1].mean(axis=0)

    if MIRROR:
        out = out[::-1]
    return out


def process_colors(rgb):
    rgb = rgb / 255.0
    mn = rgb.min(axis=1, keepdims=True)
    rgb = mn + (rgb - mn) * SATURATION
    rgb = np.clip(rgb, 0.0, 1.0)
    rgb = rgb ** GAMMA

    luma = 0.299 * rgb[:, 0] + 0.587 * rgb[:, 1] + 0.114 * rgb[:, 2]
    boost = np.where(luma > HIGHLIGHT_AT, HIGHLIGHT_GAIN, 1.0)[:, None]
    rgb = np.clip(rgb * boost, 0.0, 1.0) * 255.0

    mx = rgb.max(axis=1)
    fade = np.clip((mx - BLACK_FLOOR) / (BLACK_KNEE - BLACK_FLOOR), 0.0, 1.0)
    rgb = rgb * fade[:, None]
    return rgb


def capture_loop():
    capture_interval = 1.0 / CAPTURE_FPS
    with mss.mss() as sct:
        monitor = sct.monitors[MONITOR_INDEX]
        target_w = DOWNSCALE_WIDTH
        target_h = max(1, int(monitor["height"] * DOWNSCALE_WIDTH / monitor["width"]))
        active_count = LED_COUNT - SKIP_LEDS_START - SKIP_LEDS_END

        while not stop_event.is_set():
            t0 = time.perf_counter()

            shot = np.array(sct.grab(monitor))
            frame = shot[..., :3][..., ::-1]
            h, w, _ = frame.shape
            ys = np.linspace(0, h - 1, target_h).astype(np.int32)
            xs = np.linspace(0, w - 1, target_w).astype(np.int32)
            small = frame[ys][:, xs]

            cropped = crop_black_bars(small)
            active = sample_strip(cropped, active_count)
            processed = process_colors(active)

            full = np.zeros((LED_COUNT, 3), dtype=np.float32)
            full[SKIP_LEDS_START:LED_COUNT - SKIP_LEDS_END] = processed

            with target_lock:
                global target_strip
                target_strip = full

            dt = time.perf_counter() - t0
            if dt < capture_interval:
                time.sleep(capture_interval - dt)


def send_loop():
    send_interval = 1.0 / SEND_FPS
    current = np.zeros((LED_COUNT, 3), dtype=np.float32)
    follow_rate = 1.0 - np.exp(-1.0 / (SEND_FPS * 0.05))

    while not stop_event.is_set():
        t0 = time.perf_counter()

        with target_lock:
            target = target_strip

        current += (target - current) * follow_rate

        out = current.copy()
        noise = np.random.random(out.shape).astype(np.float32)
        out_int = np.clip(np.floor(out + noise), 0, 255).astype(np.uint8)

        packet = bytearray([2, 255])
        packet.extend(out_int.tobytes())
        sock.sendto(packet, (WLED_IP, PORT))

        dt = time.perf_counter() - t0
        if dt < send_interval:
            time.sleep(send_interval - dt)


def main():
    cap = threading.Thread(target=capture_loop, daemon=True)
    snd = threading.Thread(target=send_loop, daemon=True)
    cap.start()
    snd.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        stop_event.set()
        cap.join(timeout=1)
        snd.join(timeout=1)


if __name__ == "__main__":
    main()
