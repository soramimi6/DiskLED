// Port of src/metrics/uHistoryBuffer.pas: a fixed-width ring buffer where
// 1 pixel = 1 sample, zero-filled and always full, index 0 = oldest. Kept as
// its own module (mirroring the Delphi unit split) rather than folded into
// renderer.js, since it's buffer/state bookkeeping, not drawing.
//
// Classic UMD script, no ES-module import/export -- see cfgModel.js's header
// comment for why (Chromium blocks module scripts under file://).

(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.HistoryBuffer = factory().HistoryBuffer;
  }
})(typeof self !== 'undefined' ? self : this, function () {

function clamp01(v) {
  if (v < 0) return 0;
  if (v > 1) return 1;
  return v;
}

function zeroSample() {
  return { cpu: 0, mem: 0, swap: 0, diskRead: 0, diskWrite: 0, netIn: 0, netOut: 0 };
}

class HistoryBuffer {
  constructor(capacity) {
    this.capacity = Math.max(1, capacity | 0);
    this.samples = Array.from({ length: this.capacity }, zeroSample);
    this.head = 0;
  }

  clear() {
    this.samples = Array.from({ length: this.capacity }, zeroSample);
    this.head = 0;
  }

  // Mirrors THistoryBuffer.Push: clamps every lane to 0..1 on the way in.
  push(sample) {
    const s = {
      cpu: clamp01(sample.cpu), mem: clamp01(sample.mem), swap: clamp01(sample.swap),
      diskRead: clamp01(sample.diskRead), diskWrite: clamp01(sample.diskWrite),
      netIn: clamp01(sample.netIn), netOut: clamp01(sample.netOut),
    };
    this.samples[this.head] = s;
    this.head = (this.head + 1) % this.capacity;
  }

  // Index 0 = oldest, capacity-1 = newest.
  sampleChronological(index) {
    if (index < 0 || index >= this.capacity) return zeroSample();
    return this.samples[(this.head + index) % this.capacity];
  }
}

return { HistoryBuffer, zeroSample };

});
