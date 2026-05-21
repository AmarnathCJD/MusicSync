<script>
  export let bass = 0;
  export let mid = 0;
  export let high = 0;

  function clamp01(v) { return Math.max(0, Math.min(1, v)); }
</script>

<div class="vu">
  <div class="row">
    <span class="lbl">bass</span>
    <span class="track">
      <span class="fill bass" style="width: {clamp01(bass) * 100}%"></span>
    </span>
    <span class="num">{(clamp01(bass) * 100).toFixed(0).padStart(3, '0')}</span>
  </div>
  <div class="row">
    <span class="lbl">mid</span>
    <span class="track">
      <span class="fill mid" style="width: {clamp01(mid) * 100}%"></span>
    </span>
    <span class="num">{(clamp01(mid) * 100).toFixed(0).padStart(3, '0')}</span>
  </div>
  <div class="row">
    <span class="lbl">high</span>
    <span class="track">
      <span class="fill high" style="width: {clamp01(high) * 100}%"></span>
    </span>
    <span class="num">{(clamp01(high) * 100).toFixed(0).padStart(3, '0')}</span>
  </div>
</div>

<style>
  .vu {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .row {
    display: grid;
    grid-template-columns: 56px 1fr 44px;
    align-items: center;
    gap: 12px;
  }
  .lbl {
    font-family: var(--serif-italic);
    font-style: italic;
    font-size: 15px;
    color: var(--ink);
  }
  .track {
    position: relative;
    height: 14px;
    background: var(--paper-2);
    border: 1px solid var(--rule);
    overflow: hidden;
    min-width: 0;
  }
  .fill {
    display: block;
    height: 100%;
    transition: width 80ms linear;
  }
  /* Warm, readable accent colors — clearly distinct, never near-black. */
  .fill.bass { background: #c44a3f; }   /* terracotta red */
  .fill.mid  { background: #b8862b; }   /* warm ochre */
  .fill.high { background: #5e7a3a; }   /* sage green */
  .num {
    font-family: var(--mono);
    font-size: 12.5px;
    color: var(--ink);
    font-weight: 500;
    text-align: right;
    font-variant-numeric: tabular-nums;
  }
</style>
