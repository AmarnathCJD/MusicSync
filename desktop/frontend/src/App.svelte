<script>
  import { onMount, onDestroy } from 'svelte';
  import Slider from './lib/Slider.svelte';
  import StripPreview from './lib/StripPreview.svelte';
  import VUMeter from './lib/VUMeter.svelte';

  let settings = null;
  let mode = 'off';
  // `view` is the selected tab in the UI. `mode` is the runtime state of the
  // backend (off / audio / video). They diverge when the user opens the
  // config tab while audio/video is still running.
  let view = 'off';
  let leds = [];
  let level = { bass: 0, mid: 0, high: 0 };
  let monitors = [];
  let status = '';
  let presets = [];
  let showAdvanced = false;

  // Theme: 'workshop' (dark graphite, default) | 'almanac' (paper editorial)
  let theme = 'workshop';
  function applyTheme(t) {
    theme = t;
    document.documentElement.setAttribute('data-theme', t);
    try { localStorage.setItem('musicsync-theme', t); } catch (_) {}
  }
  function toggleTheme() {
    applyTheme(theme === 'workshop' ? 'almanac' : 'workshop');
  }

  // "Reactivity" is the user-facing inverse of `smoothing`. 0=calm, 1=snappy.
  // It two-way-binds to a Slider; whenever it changes we mirror back to
  // settings.audio.smoothing. After any external write to settings.audio
  // (preset apply, reset, initial load) the caller invokes syncReactivity().
  let reactivity = 0.65;
  let lastReactivity = -1;
  function syncReactivity() {
    if (!settings) return;
    reactivity = 1 - (settings.audio?.smoothing ?? 0.35);
    lastReactivity = reactivity;
  }
  $: if (settings && reactivity !== lastReactivity) {
    lastReactivity = reactivity;
    settings.audio.smoothing = 1 - reactivity;
  }

  async function applyPreset(id, name) {
    suppressSave = true;
    try {
      const next = await window.go.main.App.ApplyAudioPreset(id);
      settings = next;
      syncReactivity();
      status = `preset · ${name.toLowerCase()}`;
      setTimeout(() => { if (status.startsWith('preset · ')) status = ''; }, 1800);
    } catch (e) { status = 'preset failed'; }
    finally { setTimeout(() => suppressSave = false, 0); }
  }

  let scanning = false;
  let discovered = [];
  async function scanDevices() {
    scanning = true;
    discovered = [];
    try {
      const r = await window.go.main.App.DiscoverDevices();
      discovered = r || [];
      if (!discovered.length) status = 'no WLED found';
      setTimeout(() => { if (status === 'no WLED found') status = ''; }, 2200);
    } catch (e) { status = 'scan failed'; }
    finally { scanning = false; }
  }
  function pickDiscovered(d) {
    if (!settings) return;
    settings.wled_ip = d.ip;
    discovered = [];
    status = `set ip · ${d.ip}`;
    setTimeout(() => { if (status === `set ip · ${d.ip}`) status = ''; }, 1800);
  }

  let saveTimer = null;
  let suppressSave = false;
  function scheduleSave() {
    if (!settings || suppressSave) return;
    if (saveTimer) clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      window.go.main.App.SaveSettings(settings).catch(e => console.error(e));
    }, 250);
  }
  $: if (settings) scheduleSave();

  async function resetAudio() {
    suppressSave = true;
    try {
      const next = await window.go.main.App.ResetAudio();
      settings = next;
      syncReactivity();
      status = 'audio reset to defaults';
      setTimeout(() => { if (status === 'audio reset to defaults') status = ''; }, 1800);
    } catch (e) { status = 'reset failed'; }
    finally { setTimeout(() => suppressSave = false, 0); }
  }

  async function resetVideo() {
    suppressSave = true;
    try {
      const next = await window.go.main.App.ResetVideo();
      settings = next;
      status = 'video reset to defaults';
      setTimeout(() => { if (status === 'video reset to defaults') status = ''; }, 1800);
    } catch (e) { status = 'reset failed'; }
    finally { setTimeout(() => suppressSave = false, 0); }
  }

  async function resetAll() {
    if (!confirm('Reset everything except WLED IP to defaults?')) return;
    suppressSave = true;
    try {
      const next = await window.go.main.App.ResetAll(false);
      settings = next;
      syncReactivity();
      status = 'all reset to defaults';
      setTimeout(() => { if (status === 'all reset to defaults') status = ''; }, 1800);
    } catch (e) { status = 'reset failed'; }
    finally { setTimeout(() => suppressSave = false, 0); }
  }

  async function reloadMonitors() {
    monitors = await window.go.main.App.GetMonitors();
  }

  async function setMode(m) {
    mode = m;
    try {
      await window.go.main.App.SetMode(m);
      status = `→ ${m}`;
      setTimeout(() => { if (status === `→ ${m}`) status = ''; }, 1400);
    } catch (e) { status = 'error: ' + e; }
  }

  // Tab click: config switches the view only; off/audio/video also drive
  // the backend mode so the runtime state matches what's on screen.
  async function selectTab(t) {
    view = t;
    if (t !== 'config') {
      await setMode(t);
    }
  }

  async function testConnection() {
    try {
      await window.go.main.App.TestConnection();
      status = 'blink sent';
      setTimeout(() => { if (status === 'blink sent') status = ''; }, 1800);
    } catch (e) { status = 'connect failed'; }
  }

  let stripUnsub, levelUnsub, statusUnsub;
  onMount(async () => {
    let saved = 'workshop';
    try { saved = localStorage.getItem('musicsync-theme') || 'workshop'; } catch (_) {}
    applyTheme(saved === 'almanac' ? 'almanac' : 'workshop');

    settings = await window.go.main.App.GetSettings();
    syncReactivity();
    mode = await window.go.main.App.GetMode();
    view = mode;
    await reloadMonitors();
    try { presets = await window.go.main.App.GetAudioPresets(); } catch (e) { presets = []; }
    stripUnsub  = window.runtime.EventsOn('strip-update', (flat) => leds  = flat);
    levelUnsub  = window.runtime.EventsOn('audio-level', (lvl)  => level = lvl);
    statusUnsub = window.runtime.EventsOn('status',      (s)    => mode  = s.mode);
  });
  onDestroy(() => {
    stripUnsub && stripUnsub();
    levelUnsub && levelUnsub();
    statusUnsub && statusUnsub();
  });

  const modeBlurb = {
    off:   'silent. the strip sleeps.',
    audio: 'system playback drives color and pulse.',
    video: 'screen edges paint the wall behind.',
  };

  // mono palette helpers — translate between hue (0..360) and the #rrggbb the
  // <input type="color"> picker speaks. Saturation/value pinned so the picker
  // surfaces a clean hue ring rather than letting the user dim to black.
  function hueToHex(hue) {
    const h = (((Number(hue) || 0) % 360) + 360) % 360;
    const s = 1, v = 1;
    const c = v * s;
    const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
    const m = v - c;
    let r = 0, g = 0, b = 0;
    if      (h < 60)  { r = c; g = x; }
    else if (h < 120) { r = x; g = c; }
    else if (h < 180) { g = c; b = x; }
    else if (h < 240) { g = x; b = c; }
    else if (h < 300) { r = x; b = c; }
    else              { r = c; b = x; }
    const to = (n) => Math.round((n + m) * 255).toString(16).padStart(2, '0');
    return '#' + to(r) + to(g) + to(b);
  }
  function hexToHue(hex) {
    const m = /^#?([\da-f]{2})([\da-f]{2})([\da-f]{2})$/i.exec(hex);
    if (!m) return 0;
    const r = parseInt(m[1], 16) / 255;
    const g = parseInt(m[2], 16) / 255;
    const b = parseInt(m[3], 16) / 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b);
    const d = max - min;
    if (d === 0) return 0;
    let h;
    if      (max === r) h = ((g - b) / d) % 6;
    else if (max === g) h = (b - r) / d + 2;
    else                h = (r - g) / d + 4;
    h *= 60;
    if (h < 0) h += 360;
    return Math.round(h);
  }
</script>

<div class="root">
  <header>
    <div class="masthead">
      <div class="masthead-left">
        <span class="ornament">❦</span>
        <div class="title-stack">
          <h1>Music<span class="amp italic-serif">·</span>Sync</h1>
        </div>
      </div>
      <div class="masthead-right">
        <div class="theme-toggle" role="group" aria-label="Theme">
          <button
            class="theme-opt"
            class:active={theme === 'workshop'}
            on:click={() => applyTheme('workshop')}
            title="Dark graphite — desktop tooling"
          >workshop</button>
          <button
            class="theme-opt"
            class:active={theme === 'almanac'}
            on:click={() => applyTheme('almanac')}
            title="Paper noir — editorial"
          >almanac</button>
        </div>
        <div class="dateline mono">
          <span class="dateline-row"><span class="dateline-k">vol.</span><span>I</span></span>
          <span class="dateline-row"><span class="dateline-k">no.</span><span>01</span></span>
          <span class="dateline-row"><span class="dateline-k">prs.</span><span>{mode}</span></span>
        </div>
      </div>
    </div>
    <div class="ruler">
      <span class="ruler-thick"></span>
      <span class="ruler-thin"></span>
    </div>
    <nav class="tabs">
      {#each ['config','off','audio','video'] as t}
        <button class="tab" class:active={view === t} on:click={() => selectTab(t)}>
          <span class="tab-num mono">{({config:'⚙',off:'00',audio:'01',video:'02'})[t]}</span>
          <span class="tab-name">{t}</span>
        </button>
      {/each}
    </nav>
  </header>

  {#if settings}
    <div class="strip-pin">
      <div class="strip-pin-head">
        <span class="chap-no">STRIP</span>
        <span class="strip-pin-title">Preview</span>
        <span class="dotted-rule"></span>
        <span class="aside">{settings.led_count} px · live</span>
      </div>
      <StripPreview {leds} />
    </div>

    <main>
      {#if view === 'config'}
        <section class="chapter">
          <div class="chapter-head">
            <span class="chap-no">CFG</span>
            <h2>Device</h2>
            <span class="dotted-rule"></span>
            <button class="sm ghost" on:click={scanDevices} disabled={scanning}>
              {scanning ? 'scanning…' : 'scan network'}
            </button>
            <button class="sm ghost" on:click={resetAll}>reset everything</button>
            <button class="primary sm" on:click={testConnection}>Blink</button>
          </div>
          {#if discovered.length}
            <div class="discovered">
              {#each discovered as d}
                <button class="disc-row" on:click={() => pickDiscovered(d)}>
                  <span class="disc-dot"></span>
                  <span class="disc-name">{d.name}</span>
                  <span class="disc-ip mono">{d.ip}</span>
                </button>
              {/each}
            </div>
          {/if}
          <div class="fields-grid">
            <label class="field"><span>IP</span><input type="text" bind:value={settings.wled_ip} /></label>
            <label class="field"><span>Port</span><input type="number" bind:value={settings.port} /></label>
            <label class="field"><span>LEDs</span><input type="number" bind:value={settings.led_count} /></label>
            <label class="field"><span>Skip start</span><input type="number" bind:value={settings.skip_start} /></label>
            <label class="field"><span>Skip end</span><input type="number" bind:value={settings.skip_end} /></label>
            <label class="field"><span>Send fps</span><input type="number" bind:value={settings.send_fps} /></label>
            <label class="field"><span>Follow ms</span><input type="number" bind:value={settings.follow_ms} /></label>
          </div>
        </section>
      {/if}

      {#if view === 'off'}
        <section class="chapter">
          <div class="chapter-head">
            <span class="chap-no">00</span>
            <h2>Off</h2>
            <span class="dotted-rule"></span>
          </div>
          <p class="hint">Strip is idle. Switch to <strong>audio</strong> or <strong>video</strong> to drive it.</p>
        </section>
      {/if}

      {#if view === 'audio'}
        <section class="chapter">
          <div class="chapter-head">
            <span class="chap-no">02</span>
            <h2>Audio sync</h2>
            <span class="dotted-rule"></span>
            <button class="sm ghost" on:click={resetAudio}>reset audio</button>
          </div>

          {#if presets.length}
            <div class="subhead">
              <span class="sub-no mono">a.</span>
              <span class="sub-title">Presets</span>
              <span class="sub-rule"></span>
            </div>
            <div class="presets-row">
              {#each presets as p}
                <button
                  class="preset"
                  on:click={() => applyPreset(p.id, p.name)}
                  title={p.blurb}
                >
                  <span class="preset-name">{p.name}</span>
                  <span class="preset-blurb">{p.blurb}</span>
                </button>
              {/each}
            </div>
            <p class="hint">Applies all dials below. Palette and hue are kept.</p>
          {/if}

          <div class="subhead">
            <span class="sub-no mono">b.</span>
            <span class="sub-title">Color</span>
            <span class="sub-rule"></span>
          </div>
          <div class="palette-block">
            <div class="fields-grid">
              <label class="field span-2">
                <span>Palette</span>
                <select bind:value={settings.audio.palette}>
                  <option value="rainbow">rainbow — full wheel</option>
                  <option value="warm">warm — red / orange / amber</option>
                  <option value="cool">cool — cyan / blue / indigo</option>
                  <option value="sunset">sunset — pink / red / orange</option>
                  <option value="aurora">aurora — green / teal / blue</option>
                  <option value="forest">forest — greens</option>
                  <option value="mono">mono — single hue, no spread</option>
                </select>
              </label>
              {#if settings.audio.palette === 'mono'}
                <label class="field mono-pick">
                  <span>Hue</span>
                  <div class="mono-pick-row">
                    <span
                      class="swatch"
                      style="background: hsl({settings.audio.mono_hue ?? 0}, 80%, 50%)"
                      aria-hidden="true"
                    ></span>
                    <input
                      type="color"
                      value={hueToHex(settings.audio.mono_hue ?? 0)}
                      on:input={(e) => settings.audio.mono_hue = hexToHue(e.currentTarget.value)}
                      title="pick a base hue"
                    />
                    <input
                      type="number"
                      min="0"
                      max="360"
                      step="1"
                      bind:value={settings.audio.mono_hue}
                      class="hue-num"
                    />
                    <span class="hue-unit mono">°</span>
                  </div>
                </label>
              {/if}
            </div>
          </div>
          <div class="sliders-grid">
            <Slider label="Color variety"  bind:value={settings.audio.hue_spread}  min={0}   max={1}    step={0.02}  precision={2} />
            <Slider label="Color motion"   bind:value={settings.audio.hue_drift}   min={0}   max={0.08} step={0.001} precision={3} />
            <Slider label="Color richness" bind:value={settings.audio.saturation}  min={0.4} max={1}    step={0.02}  precision={2} />
            <Slider label="Brightness"     bind:value={settings.audio.brightness}  min={0.1} max={1.5}  step={0.05}  precision={2} />
          </div>

          <div class="subhead">
            <span class="sub-no mono">c.</span>
            <span class="sub-title">Beat &amp; feel</span>
            <span class="sub-rule"></span>
          </div>
          <div class="sliders-grid">
            <Slider label="Beat punch"     bind:value={settings.audio.beat_gain}     min={0.5} max={6}   step={0.1}  precision={1} />
            <Slider label="Reactivity"     bind:value={reactivity}                    min={0.05} max={1}  step={0.02} precision={2} />
            <Slider label="Center pulse"   bind:value={settings.audio.bass_falloff}  min={0}   max={3}   step={0.05} precision={2} />
            <Slider label="Pulse drift"    bind:value={settings.audio.center_motion} min={0}   max={1}   step={0.02} precision={2} />
          </div>

          <details class="advanced" bind:open={showAdvanced}>
            <summary>
              <span class="adv-marker mono">{showAdvanced ? '−' : '+'}</span>
              <span class="adv-title">Advanced</span>
            </summary>
            <div class="sliders-grid adv-grid">
              <Slider label="Gamma"          bind:value={settings.audio.gamma}          min={0.4}    max={1.4}  step={0.02}   precision={2} />
              <Slider label="Beat threshold" bind:value={settings.audio.beat_threshold} min={0.02}   max={0.4}  step={0.005}  precision={3} />
              <Slider label="Silence floor"  bind:value={settings.audio.silence_floor}  min={0.0001} max={0.01} step={0.0001} precision={4} />
            </div>
          </details>

          <div class="vu-wrap">
            <VUMeter bass={level.bass} mid={level.mid} high={level.high} />
          </div>
        </section>
      {/if}

      {#if view === 'video'}
        <section class="chapter">
          <div class="chapter-head">
            <span class="chap-no">02</span>
            <h2>Video sync</h2>
            <span class="dotted-rule"></span>
            <button class="sm ghost" on:click={resetVideo}>reset video</button>
          </div>
          <div class="fields-grid">
            <label class="field span-2">
              <span>Monitor</span>
              <select bind:value={settings.video.monitor_index}>
                {#each monitors as m}
                  <option value={m.index}>{m.label}</option>
                {/each}
              </select>
            </label>
            <label class="field check"><span>Mirror</span><input type="checkbox" bind:checked={settings.video.mirror} /></label>
            <label class="field check"><span>Dither</span><input type="checkbox" bind:checked={settings.video.temporal_dither} /></label>
          </div>
          <div class="sliders-grid">
            <Slider label="Saturation"      bind:value={settings.video.saturation}        min={0.8} max={2.2} step={0.05}  precision={2} />
            <Slider label="Gamma"           bind:value={settings.video.gamma}             min={0.5} max={1.5} step={0.02}  precision={2} />
            <Slider label="Vertical bias"   bind:value={settings.video.vertical_bias}     min={0}   max={1}   step={0.02}  precision={2} />
            <Slider label="Highlight gain"  bind:value={settings.video.highlight_gain}    min={1}   max={1.8} step={0.02}  precision={2} />
            <Slider label="Highlight at"    bind:value={settings.video.highlight_at}      min={0.3} max={0.95} step={0.02} precision={2} />
            <Slider label="Capture fps"     bind:value={settings.video.capture_fps}       min={15}  max={144} step={1}     precision={0} />
            <Slider label="Downscale w"     bind:value={settings.video.downscale_width}   min={120} max={640} step={10}    precision={0} />
            <Slider label="Black bar cut"   bind:value={settings.video.black_bar_cutoff}  min={0}   max={0.2} step={0.005} precision={3} />
            <Slider label="Black floor"     bind:value={settings.video.black_floor}       min={0}   max={60}  step={1}     precision={0} />
            <Slider label="Black knee"      bind:value={settings.video.black_knee}        min={0}   max={120} step={1}     precision={0} />
          </div>
        </section>
      {/if}

    </main>

    <footer>
      <span class="foot-mark">●</span>
      <span class="foot-cap">{mode === 'off' ? 'idle' : mode + ' mode'}</span>
      <span class="rule-v"></span>
      <span class="mono small">{settings.send_fps} fps</span>
      <span class="rule-v"></span>
      <span class="mono small">follow {settings.follow_ms}ms</span>
      {#if status}
        <span class="rule-v"></span>
        <span class="small">{status}</span>
      {/if}
      <span class="spacer"></span>
    </footer>
  {:else}
    <div class="loading italic-serif">Setting type…</div>
  {/if}
</div>

<style>
  .root {
    display: flex;
    flex-direction: column;
    height: 100vh;
    min-width: 0;
  }

  /* ----------------------- masthead ----------------------- */
  header {
    flex-shrink: 0;
    padding: 20px 28px 10px;
    background:
      linear-gradient(to bottom, rgba(110,31,31,0.045), transparent 60%),
      var(--paper);
    border-bottom: 1px solid var(--rule);
    position: relative;
  }
  header::before {
    /* decorative corner marker — like a printer's registration mark */
    content: "";
    position: absolute;
    top: 8px;
    left: 8px;
    width: 10px;
    height: 10px;
    border-top: 1.5px solid var(--oxblood);
    border-left: 1.5px solid var(--oxblood);
  }
  header::after {
    content: "";
    position: absolute;
    top: 8px;
    right: 8px;
    width: 10px;
    height: 10px;
    border-top: 1.5px solid var(--oxblood);
    border-right: 1.5px solid var(--oxblood);
  }
  .masthead {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 14px;
    flex-wrap: wrap;
  }
  .masthead-left {
    display: flex;
    align-items: flex-start;
    gap: 14px;
  }
  .title-stack {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .masthead h1 {
    font-family: var(--serif-display);
    font-weight: 700;
    font-size: 34px;
    letter-spacing: -0.025em;
    line-height: 0.95;
    color: var(--ink);
    font-variation-settings: "SOFT" 50, "WONK" 1;
  }
  .amp {
    color: var(--oxblood);
    font-weight: 400;
    margin: 0 1px;
    font-size: 0.85em;
    position: relative;
    top: -2px;
  }
  .subtitle {
    color: var(--ink-mid);
    font-size: 14.5px;
    letter-spacing: 0.02em;
    padding-left: 1px;
  }
  .ornament {
    color: var(--oxblood);
    font-size: 22px;
    line-height: 1;
    margin-top: 4px;
  }
  .dateline {
    display: flex;
    flex-direction: column;
    gap: 1px;
    font-size: 10.5px;
    text-align: right;
    color: var(--ink-mid);
    border-left: 1px solid var(--rule);
    padding-left: 10px;
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }
  .dateline-row {
    display: flex;
    gap: 8px;
    justify-content: flex-end;
  }
  .dateline-k {
    color: var(--ink-faint);
  }

  .ruler {
    margin: 14px 0 12px;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .ruler-thick { height: 2px; background: var(--ink); }
  .ruler-thin  { height: 0; border-bottom: 1px solid var(--rule); }

  /* ----------------------- tab nav ----------------------- */
  .tabs {
    display: flex;
    align-items: baseline;
    gap: 14px;
    flex-wrap: wrap;
  }
  .tabs-label {
    color: var(--ink-mid);
    font-size: 13px;
  }
  .tab {
    border: none;
    background: transparent;
    color: var(--ink-soft);
    padding: 2px 8px 4px;
    display: inline-flex;
    align-items: baseline;
    gap: 7px;
    font-family: var(--serif-display);
    font-size: 14px;
    text-transform: lowercase;
    letter-spacing: 0.02em;
    border: 1px solid transparent;
    border-bottom: 2px solid transparent;
    transition: color 0.15s, border-color 0.15s, background 0.15s;
    border-radius: 0;
  }
  .tab:hover {
    background: var(--paper-2);
    color: var(--ink);
    border-color: var(--rule);
    border-bottom-color: var(--ink);
  }
  .tab.active {
    color: var(--oxblood);
    border-bottom-color: var(--oxblood);
    font-weight: 600;
    background: transparent;
  }
  .tab.active::before {
    content: "❦";
    color: var(--oxblood);
    margin-right: 2px;
    font-size: 11px;
  }
  .tab-num {
    font-size: 11px;
    color: var(--ink-mid);
    letter-spacing: 0.05em;
  }
  .tab.active .tab-num { color: var(--oxblood); }
  .tab-name {
    font-size: 16px;
  }
  .tab-blurb {
    color: var(--ink-mid);
    font-size: 14px;
    margin-left: auto;
    font-style: italic;
    border-left: 1px solid var(--rule);
    padding-left: 12px;
  }

  /* ----------------------- pinned strip ----------------------- */
  .strip-pin {
    flex-shrink: 0;
    padding: 14px 28px 12px;
    background:
      linear-gradient(to bottom, var(--paper) 0%, var(--paper) 80%, rgba(28,26,22,0.04) 100%),
      var(--paper);
    border-bottom: 1px solid var(--rule);
    box-shadow: 0 4px 6px -4px rgba(28, 26, 22, 0.12);
    position: relative;
    z-index: 2;
  }
  .strip-pin-head {
    display: flex;
    align-items: baseline;
    gap: 12px;
    margin-bottom: 8px;
  }
  .strip-pin-title {
    font-family: var(--serif-display);
    font-size: 15px;
    font-weight: 600;
    color: var(--ink);
    letter-spacing: -0.005em;
  }

  /* ----------------------- main scroll ----------------------- */
  main {
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
    padding: 22px 28px 8px;
    display: flex;
    flex-direction: column;
    gap: 28px;
    min-width: 0;
  }

  /* ----------------------- chapter ----------------------- */
  .chapter {
    min-width: 0;
    padding-left: 38px;
    position: relative;
  }
  .chapter::before {
    /* spine: thick rule + thin rule, like a hand-bound book */
    content: "";
    position: absolute;
    left: 0;
    top: 6px;
    bottom: 6px;
    width: 1px;
    background: var(--ink);
  }
  .chapter::after {
    content: "";
    position: absolute;
    left: 4px;
    top: 6px;
    bottom: 6px;
    width: 1px;
    background: var(--paper-3);
  }
  .chapter-head {
    display: flex;
    align-items: baseline;
    gap: 12px;
    margin-bottom: 18px;
    flex-wrap: wrap;
    position: relative;
  }
  .chap-no {
    color: var(--paper);
    background: var(--oxblood);
    font-size: 10.5px;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    padding: 3px 8px 3px 9px;
    font-weight: 600;
    line-height: 1;
    align-self: center;
    position: relative;
    /* tag / banderole — diagonal cut on the right */
    clip-path: polygon(0 0, 100% 0, calc(100% - 6px) 50%, 100% 100%, 0 100%);
    padding-right: 14px;
  }
  .chapter-head h2 {
    font-size: 24px;
    font-weight: 600;
    color: var(--ink);
    letter-spacing: -0.015em;
    font-variation-settings: "SOFT" 30;
  }
  .chapter-head h2::first-letter {
    /* subtle drop initial — only first letter, oxblood */
    color: var(--oxblood);
    font-style: italic;
    font-family: var(--serif-italic);
    font-size: 1.1em;
    padding-right: 1px;
  }
  .dotted-rule {
    flex: 1;
    height: 0;
    border-bottom: 1px dotted var(--rule);
    min-width: 30px;
    position: relative;
    top: -3px;
  }
  .aside {
    color: var(--ink-mid);
    font-size: 14px;
    white-space: nowrap;
  }

  /* subheads inside a chapter — lettered subsections */
  .subhead {
    display: flex;
    align-items: baseline;
    gap: 10px;
    margin: 22px 0 12px;
  }
  .subhead:first-of-type { margin-top: 6px; }
  .sub-no {
    color: var(--oxblood);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.05em;
    font-style: italic;
    font-family: var(--serif-italic);
    font-size: 14px;
  }
  .sub-title {
    font-family: var(--serif-display);
    font-size: 14.5px;
    color: var(--ink);
    text-transform: lowercase;
    font-variant: small-caps;
    letter-spacing: 0.08em;
    font-weight: 600;
  }
  .sub-rule {
    flex: 1;
    height: 0;
    border-bottom: 1px solid var(--paper-3);
    min-width: 30px;
    position: relative;
    top: -3px;
  }
  .sub-rule::after {
    content: "❦";
    position: absolute;
    right: 0;
    top: -9px;
    color: var(--paper-3);
    font-size: 11px;
    background: var(--paper);
    padding: 0 4px;
  }

  button.ghost {
    background: transparent;
    border: 1px solid var(--rule);
    color: var(--ink-mid);
    font-family: var(--serif-italic);
    font-style: italic;
    font-size: 11.5px;
    text-transform: none;
    letter-spacing: 0;
    font-weight: 400;
  }
  button.ghost:hover {
    background: var(--paper-2);
    color: var(--ink);
    border-color: var(--ink);
  }

  /* ----------------------- discovered devices ----------------------- */
  .discovered {
    display: flex;
    flex-direction: column;
    gap: 4px;
    margin: 6px 0 14px;
  }
  .disc-row {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 7px 10px;
    border: 1px solid var(--rule);
    background: var(--paper);
    cursor: pointer;
    font-size: 13px;
    color: var(--ink);
    text-align: left;
  }
  .disc-row:hover {
    background: var(--paper-2);
    border-color: var(--ink);
  }
  .disc-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: var(--oxblood);
    flex-shrink: 0;
  }
  .disc-name { flex: 1; }
  .disc-ip {
    font-size: 12px;
    color: var(--ink-mid);
  }
  :global([data-theme="workshop"]) .disc-row {
    background: var(--panel);
    border-color: var(--panel-edge);
    color: var(--ink);
  }
  :global([data-theme="workshop"]) .disc-row:hover {
    background: var(--hover);
    border-color: var(--panel-edge-2);
  }
  :global([data-theme="workshop"]) .disc-dot { background: var(--accent); }

  /* ----------------------- grids ----------------------- */
  .fields-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
    gap: 14px 22px;
  }
  .sliders-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 18px 28px;
  }

  .field {
    display: flex;
    flex-direction: column;
    gap: 4px;
    min-width: 0;
  }
  .field > span {
    color: var(--ink-soft);
    font-size: 12.5px;
    font-variant: small-caps;
    letter-spacing: 0.08em;
    font-family: var(--serif-display);
    font-weight: 600;
  }
  .field > span::after {
    content: " .";
    color: var(--oxblood);
    font-weight: 700;
  }
  .field.span-2 { grid-column: span 2; }
  .field.check {
    flex-direction: row;
    align-items: baseline;
    justify-content: flex-start;
    gap: 10px;
    border-bottom: 1px solid var(--rule);
    padding-bottom: 4px;
  }
  .field.check > span { padding-bottom: 0; }

  /* ----------------------- presets row ----------------------- */
  .presets-row {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
    gap: 10px;
    margin-bottom: 10px;
  }
  .preset {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 2px;
    padding: 9px 12px 10px;
    border: 1px solid var(--rule);
    background: var(--paper);
    text-align: left;
    cursor: pointer;
    transition: background 0.15s, border-color 0.15s, transform 0.05s;
    position: relative;
  }
  .preset::before {
    /* corner tick — like a printed catalog card */
    content: "";
    position: absolute;
    top: 0;
    left: 0;
    width: 7px;
    height: 7px;
    border-top: 1.5px solid var(--oxblood);
    border-left: 1.5px solid var(--oxblood);
  }
  .preset:hover {
    background: var(--paper-2);
    border-color: var(--ink);
    color: var(--ink);
  }
  .preset:active { transform: translateY(1px); }
  .preset-name {
    font-family: var(--serif-display);
    font-size: 15px;
    font-weight: 600;
    color: var(--ink);
    text-transform: lowercase;
    letter-spacing: 0.01em;
  }
  .preset-blurb {
    font-size: 12px;
    color: var(--ink-mid);
    line-height: 1.25;
  }
  .hint {
    color: var(--ink-mid);
    font-size: 13px;
    margin: 6px 0 8px;
  }

  /* ----------------------- advanced fold ----------------------- */
  .advanced {
    margin-top: 22px;
    border-top: 1px dotted var(--paper-3);
    padding-top: 14px;
  }
  .advanced summary {
    list-style: none;
    cursor: pointer;
    display: flex;
    align-items: baseline;
    gap: 10px;
    user-select: none;
    padding: 4px 0;
  }
  .advanced summary::-webkit-details-marker { display: none; }
  .adv-marker {
    color: var(--oxblood);
    font-size: 14px;
    font-weight: 600;
    width: 12px;
    display: inline-block;
    text-align: center;
  }
  .adv-title {
    font-family: var(--serif-display);
    font-size: 14.5px;
    color: var(--ink);
    font-variant: small-caps;
    letter-spacing: 0.08em;
    font-weight: 600;
  }
  .adv-hint {
    color: var(--ink-mid);
    font-size: 13px;
  }
  .adv-grid {
    margin-top: 14px;
    padding-left: 22px;
    border-left: 1px solid var(--paper-3);
  }

  /* ----------------------- palette block ----------------------- */
  .palette-block {
    padding-bottom: 18px;
    margin-bottom: 6px;
    border-bottom: 1px dotted var(--paper-3);
  }
  .mono-pick { min-width: 0; }
  .mono-pick-row {
    display: flex;
    align-items: center;
    gap: 8px;
    padding-top: 2px;
  }
  .mono-pick-row .swatch {
    width: 22px;
    height: 22px;
    border: 1px solid var(--ink);
    flex-shrink: 0;
    box-shadow: inset 0 0 0 1px rgba(243, 237, 225, 0.6);
  }
  .mono-pick-row input[type="color"] {
    appearance: none;
    -webkit-appearance: none;
    width: 28px;
    height: 22px;
    padding: 0;
    border: 1px solid var(--rule);
    background: transparent;
    cursor: pointer;
  }
  .mono-pick-row input[type="color"]::-webkit-color-swatch-wrapper { padding: 1px; }
  .mono-pick-row input[type="color"]::-webkit-color-swatch { border: none; }
  .mono-pick-row .hue-num {
    width: 48px;
    text-align: right;
  }
  .hue-unit {
    color: var(--ink-mid);
    font-size: 12px;
  }

  /* ----------------------- vu ----------------------- */
  .vu-wrap {
    margin-top: 18px;
    padding-top: 14px;
    border-top: 1px dotted var(--rule);
  }

  /* ----------------------- footer ----------------------- */
  footer {
    display: flex;
    align-items: baseline;
    gap: 12px;
    padding: 12px 28px 10px;
    border-top: 2px solid var(--ink);
    background:
      linear-gradient(to top, rgba(28,26,22,0.04), transparent 70%),
      var(--paper);
    flex-shrink: 0;
    font-family: var(--sans);
    font-size: 12.5px;
    color: var(--ink-soft);
    position: relative;
  }
  footer::before {
    content: "";
    position: absolute;
    top: -4px;
    left: 0;
    right: 0;
    height: 1px;
    background: var(--rule);
  }
  .foot-mark {
    color: var(--oxblood);
    font-size: 9px;
    line-height: 1;
    position: relative;
    top: -1px;
  }
  .foot-cap {
    color: var(--ink);
    text-transform: lowercase;
    letter-spacing: 0.02em;
  }
  .rule-v {
    width: 1px;
    height: 11px;
    background: var(--rule);
    align-self: center;
  }
  .small { font-size: 12px; color: var(--ink-mid); }
  .spacer { flex: 1; }
  .colophon { color: var(--ink-mid); font-size: 12.5px; }

  button.sm {
    padding: 4px 10px;
    font-size: 10.5px;
  }

  .loading {
    padding: 40px;
    color: var(--ink-mid);
    font-size: 18px;
  }

  /* ----------------------- theme toggle (both themes) ----------------------- */
  .theme-toggle {
    display: inline-flex;
    border: 1px solid var(--panel-edge);
    border-radius: var(--radius);
    overflow: hidden;
    margin-right: 10px;
    align-self: center;
  }
  .theme-opt {
    border: none;
    background: transparent;
    color: var(--ink-mid);
    padding: 4px 10px;
    font-family: var(--ui);
    font-size: 11px;
    letter-spacing: 0.06em;
    text-transform: lowercase;
    cursor: pointer;
    border-radius: 0;
    transition: background 0.12s, color 0.12s;
  }
  .theme-opt + .theme-opt { border-left: 1px solid var(--panel-edge); }
  .theme-opt:hover { color: var(--ink); background: var(--hover, transparent); }
  .theme-opt.active {
    background: var(--accent-soft);
    color: var(--accent);
    font-weight: 600;
  }

  /* =================================================================
     WORKSHOP THEME — recolor only. Almanac's layout, typography,
     spines, banderoles, drop caps, dotted rules all stay. Just paint
     the editorial structure in graphite + amber instead of paper + oxblood.
     ================================================================= */

  /* header gradient — swap paper wash for graphite wash */
  :global([data-theme="workshop"]) header {
    background:
      linear-gradient(to bottom, rgba(210,149,107,0.05), transparent 60%),
      var(--bg);
    border-bottom: 1px solid var(--panel-edge);
  }
  :global([data-theme="workshop"]) header::before { border-top-color: var(--accent); border-left-color: var(--accent); }
  :global([data-theme="workshop"]) header::after  { border-top-color: var(--accent); border-right-color: var(--accent); }

  :global([data-theme="workshop"]) .ornament { color: var(--accent); }
  :global([data-theme="workshop"]) .amp { color: var(--accent); }
  :global([data-theme="workshop"]) .dateline { border-left-color: var(--panel-edge); }

  :global([data-theme="workshop"]) .ruler-thick { background: var(--ink); }
  :global([data-theme="workshop"]) .ruler-thin  { border-bottom-color: var(--panel-edge); }

  /* tabs — keep editorial form, recolor */
  :global([data-theme="workshop"]) .tab:hover {
    background: var(--hover);
    color: var(--ink);
    border-color: var(--panel-edge);
    border-bottom-color: var(--ink);
  }
  :global([data-theme="workshop"]) .tab.active {
    color: var(--accent);
    border-bottom-color: var(--accent);
    background: transparent;
  }
  :global([data-theme="workshop"]) .tab.active::before { color: var(--accent); }
  :global([data-theme="workshop"]) .tab.active .tab-num { color: var(--accent); }
  :global([data-theme="workshop"]) .tab-blurb { border-left-color: var(--panel-edge); }

  /* pinned strip — graphite wash instead of paper */
  :global([data-theme="workshop"]) .strip-pin {
    background:
      linear-gradient(to bottom, var(--bg-2) 0%, var(--bg-2) 80%, rgba(0,0,0,0.18) 100%),
      var(--bg-2);
    border-bottom: 1px solid var(--panel-edge);
    box-shadow: 0 4px 6px -4px rgba(0, 0, 0, 0.4);
  }

  /* chapter spine — graphite double rule */
  :global([data-theme="workshop"]) .chapter::before { background: var(--ink); }
  :global([data-theme="workshop"]) .chapter::after  { background: var(--panel-edge-2); }

  /* banderole — amber on graphite */
  :global([data-theme="workshop"]) .chap-no {
    background: var(--accent);
    color: var(--accent-ink);
  }

  :global([data-theme="workshop"]) .chapter-head h2::first-letter {
    color: var(--accent);
  }

  :global([data-theme="workshop"]) .dotted-rule { border-bottom-color: var(--panel-edge); }

  /* subsection rules */
  :global([data-theme="workshop"]) .sub-no { color: var(--accent); }
  :global([data-theme="workshop"]) .sub-rule { border-bottom-color: var(--panel-edge); }
  :global([data-theme="workshop"]) .sub-rule::after {
    color: var(--panel-edge-2);
    background: var(--bg);
  }

  /* field labels — drop the oxblood accent dot, use amber */
  :global([data-theme="workshop"]) .field > span::after { color: var(--accent); }
  :global([data-theme="workshop"]) .field.check { border-bottom-color: var(--panel-edge); }

  /* ghost button */
  :global([data-theme="workshop"]) button.ghost {
    border-color: var(--panel-edge);
    color: var(--ink-mid);
  }
  :global([data-theme="workshop"]) button.ghost:hover {
    background: var(--hover);
    color: var(--ink);
    border-color: var(--panel-edge-2);
  }

  /* presets */
  :global([data-theme="workshop"]) .preset {
    background: var(--panel);
    border-color: var(--panel-edge);
  }
  :global([data-theme="workshop"]) .preset::before {
    border-top-color: var(--accent);
    border-left-color: var(--accent);
  }
  :global([data-theme="workshop"]) .preset:hover {
    background: var(--hover);
    border-color: var(--panel-edge-2);
  }

  /* advanced fold */
  :global([data-theme="workshop"]) .advanced { border-top-color: var(--panel-edge); }
  :global([data-theme="workshop"]) .adv-marker { color: var(--accent); }
  :global([data-theme="workshop"]) .adv-grid { border-left-color: var(--panel-edge); }

  /* palette block divider */
  :global([data-theme="workshop"]) .palette-block { border-bottom-color: var(--panel-edge); }
  :global([data-theme="workshop"]) .mono-pick-row .swatch {
    border-color: var(--ink);
    box-shadow: inset 0 0 0 1px rgba(255,255,255,0.08);
  }

  /* vu wrap */
  :global([data-theme="workshop"]) .vu-wrap { border-top-color: var(--panel-edge); }

  /* footer — graphite version of the editorial footer */
  :global([data-theme="workshop"]) footer {
    border-top: 2px solid var(--ink);
    background:
      linear-gradient(to top, rgba(0,0,0,0.25), transparent 70%),
      var(--bg);
    color: var(--ink-soft);
  }
  :global([data-theme="workshop"]) footer::before { background: var(--panel-edge); }
  :global([data-theme="workshop"]) .foot-mark { color: var(--ok); }
  :global([data-theme="workshop"]) .rule-v { background: var(--panel-edge); }
</style>
