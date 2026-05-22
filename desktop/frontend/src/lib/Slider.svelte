<script>
  export let label = '';
  export let value = 0;
  export let min = 0;
  export let max = 1;
  export let step = 0.01;
  export let precision = 2;
  export let format = (v) => Number(v).toFixed(precision);

  $: pct = ((value - min) / (max - min)) * 100;
</script>

<div class="slider">
  <div class="head">
    <span class="label">{label}</span>
    <span class="value">{format(value)}</span>
  </div>
  <div class="track-wrap">
    <div class="fill" style="width:{Math.max(0, Math.min(100, pct))}%"></div>
    <input type="range" bind:value {min} {max} {step} />
  </div>
  <div class="scale">
    <span>{format(min)}</span>
    <span>{format(max)}</span>
  </div>
</div>

<style>
  .slider {
    display: flex;
    flex-direction: column;
    gap: 6px;
    min-width: 0;
  }
  .head {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
  }
  .label {
    color: var(--ink);
    font-family: var(--serif-display);
    font-size: 14px;
    font-weight: 500;
    letter-spacing: 0.01em;
  }
  .value {
    color: var(--oxblood);
    font-family: var(--mono);
    font-size: 13px;
    font-weight: 500;
    font-variant-numeric: tabular-nums;
  }
  .track-wrap {
    position: relative;
    height: 14px;
    display: flex;
    align-items: center;
  }
  .fill {
    position: absolute;
    left: 0;
    top: 50%;
    transform: translateY(-50%);
    height: 2px;
    background: var(--ink);
    pointer-events: none;
  }
  .scale {
    display: flex;
    justify-content: space-between;
    font-family: var(--mono);
    font-size: 11px;
    color: var(--ink-mid);
  }
</style>
