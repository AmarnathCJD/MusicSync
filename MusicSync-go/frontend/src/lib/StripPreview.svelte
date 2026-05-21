<script>
  export let leds = [];
</script>

<script context="module">
  function chunks(arr, n) {
    const out = [];
    for (let i = 0; i + n - 1 < arr.length; i += n) {
      out.push(arr.slice(i, i + n));
    }
    return out;
  }
</script>

<figure class="plate">
  <div class="frame">
    <div class="bar">
      {#each chunks(leds, 3) as [r, g, b]}
        <div class="led" style="background: rgb({r}, {g}, {b})"></div>
      {/each}
      {#if !leds.length}
        <div class="empty">— awaiting signal —</div>
      {/if}
    </div>
  </div>
  <figcaption>
    <span class="cap-num">fig. 1</span>
    <span class="cap-italic">live capture of the lower strip, full length, no scaling.</span>
  </figcaption>
</figure>

<style>
  .plate {
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .frame {
    padding: 8px;
    background: var(--paper-2);
    border: 1px solid var(--rule);
    /* tiny inner shadow for printed-plate feel — no neon glow */
    box-shadow: inset 0 0 0 1px rgba(28,26,22,0.05);
  }
  .bar {
    display: flex;
    gap: 1px;
    height: 32px;
    background: #1c1a16;
    padding: 3px;
    overflow: hidden;
    position: relative;
  }
  .led {
    flex: 1;
    transition: background 80ms linear;
  }
  .empty {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #c8bea8;
    font-family: var(--serif-italic);
    font-style: italic;
    font-size: 14px;
    letter-spacing: 0.04em;
  }
  figcaption {
    display: flex;
    gap: 8px;
    align-items: baseline;
    color: var(--ink-mid);
    font-size: 12.5px;
  }
  .cap-num {
    font-family: var(--mono);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    font-size: 11px;
    font-weight: 500;
    color: var(--oxblood);
  }
  .cap-italic {
    font-family: var(--serif-italic);
    font-style: italic;
    color: var(--ink-soft);
  }
</style>
