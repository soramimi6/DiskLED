// Canvas port of the display engine's non-ballistic, non-graph drawing:
// src/view/uMeterRenderer.pas (StripFrame/DrawBackground/DrawMeters) and
// src/view/uDigitRenderer.pas (DrawPercent). Graph preview (uGraphRenderer.pas)
// is a separate, later milestone -- see docs/PLANNED-3.2.0.md item 6's own
// staged estimate, which lists it apart from "meter/LED/digit + compact/full".
//
// Color-key transparency (Delphi's TransparentBlt with a MaskColor) is
// reproduced by recoloring exact mask-color pixels to alpha=0 on an offscreen
// canvas, cached per (image, maskColor) pair since it's a pure function of
// the two.
//
// Classic UMD script, no ES-module import/export -- see cfgModel.js's header
// comment for why (Chromium blocks module scripts under file://).

(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.SkinRenderer = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {

function clamp01(v) {
  if (v < 0) return 0;
  if (v > 1) return 1;
  return v;
}

// Mirrors TMeterRenderer.StripFrame (uMeterRenderer.pas:54-63).
function stripFrame(sprite, value) {
  if (!sprite || !sprite.fileName || sprite.frames <= 0) return 0;
  let f = Math.round(clamp01(value) * (sprite.frames - 1));
  if (f < 0) f = 0;
  if (f > sprite.frames - 1) f = sprite.frames - 1;
  return f;
}

// Returns a canvas with `maskColor` pixels made fully transparent, cached on
// the source image itself keyed by the color so repeated frames of the same
// sprite sheet only pay the pixel scan once.
function keyedCanvas(image, maskColor) {
  if (!maskColor) return image;
  image.__maskCache = image.__maskCache || new Map();
  const key = `${maskColor.r},${maskColor.g},${maskColor.b}`;
  let cached = image.__maskCache.get(key);
  if (cached) return cached;

  const canvas = document.createElement('canvas');
  canvas.width = image.naturalWidth || image.width;
  canvas.height = image.naturalHeight || image.height;
  const ctx = canvas.getContext('2d');
  ctx.drawImage(image, 0, 0);
  const imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const d = imgData.data;
  for (let i = 0; i < d.length; i += 4) {
    if (d[i] === maskColor.r && d[i + 1] === maskColor.g && d[i + 2] === maskColor.b) {
      d[i + 3] = 0;
    }
  }
  ctx.putImageData(imgData, 0, 0);
  image.__maskCache.set(key, canvas);
  return canvas;
}

// `images` is a Map<lowercased fileName, HTMLImageElement>. Missing images
// (not yet imported into the skin folder) are silently skipped, same as
// Delphi's AAssets.Graphic would only be reached for a part that has a
// non-empty File= -- the "image not imported" case is a validation warning
// handled elsewhere, not a render-time error.
function image(images, fileName) {
  return images.get(fileName.toLowerCase()) || null;
}

// Mirrors the DrawStrip local proc (uMeterRenderer.pas:140-167) shared by
// meters and LEDs (an LED is just a 2-frame strip drawn at value 0.0/1.0).
function drawStrip(ctx, images, sprite, value) {
  if (!sprite || !sprite.fileName || sprite.frames <= 0) return;
  const img = image(images, sprite.fileName);
  if (!img) return;
  const naturalH = img.naturalHeight || img.height;
  const frameH = Math.floor(naturalH / sprite.frames);
  if (frameH <= 0) return;

  const frame = stripFrame(sprite, value);
  const srcY = frame * frameH;
  const w = img.naturalWidth || img.width;
  const source = sprite.transparent ? keyedCanvas(img, sprite.maskColor) : img;
  ctx.drawImage(source, 0, srcY, w, frameH, sprite.x, sprite.y, w, frameH);
}

function drawLed(ctx, images, sprite, on) {
  drawStrip(ctx, images, sprite, on ? 1.0 : 0.0);
}

// Mirrors DrawPing (uMeterRenderer.pas:178-210): frame = ordinal of
// TPingLevel (Timeout=0, Slow=1, Fair=2, Normal=3), not a value-driven strip.
function drawPing(ctx, images, sprite, pingLevelIndex) {
  if (!sprite || !sprite.fileName || sprite.frames <= 0) return;
  const img = image(images, sprite.fileName);
  if (!img) return;
  const naturalH = img.naturalHeight || img.height;
  const frameH = Math.floor(naturalH / sprite.frames);
  if (frameH <= 0) return;

  let frame = pingLevelIndex;
  if (frame < 0) frame = 0;
  if (frame > sprite.frames - 1) frame = sprite.frames - 1;
  const srcY = frame * frameH;
  const w = img.naturalWidth || img.width;
  const source = sprite.transparent ? keyedCanvas(img, sprite.maskColor) : img;
  ctx.drawImage(source, 0, srcY, w, frameH, sprite.x, sprite.y, w, frameH);
}

const FONT_GLYPHS = 11; // 0..9 + space, mirrors uDigitRenderer.pas's CFontGlyphs

// Mirrors FormatPercentText (uDigitRenderer.pas:29-63).
function formatPercentText(percent, digits, fillZero) {
  let p = Math.max(0, Math.min(100, Math.round(percent)));
  let s = String(p);
  if (s.length > digits) s = s.slice(s.length - digits);
  if (fillZero) {
    while (s.length < digits) s = '0' + s;
  } else {
    while (s.length < digits) s = ' ' + s;
  }
  return s;
}

// Mirrors DrawBitmapDigits (uDigitRenderer.pas:65-106).
function drawBitmapDigits(ctx, images, val, text) {
  if (!val.bitmapFile) return;
  const fontImg = image(images, val.bitmapFile);
  if (!fontImg) return;
  const w = fontImg.naturalWidth || fontImg.width;
  const h = fontImg.naturalHeight || fontImg.height;
  const glyphW = Math.floor(w / FONT_GLYPHS);
  const glyphH = h;
  if (glyphW <= 0 || glyphH <= 0) return;

  const source = val.fontTransparent ? keyedCanvas(fontImg, val.fontMaskColor) : fontImg;
  let destX = val.x;
  for (const ch of text) {
    let glyphIndex;
    if (ch === ' ') glyphIndex = 10;
    else if (ch >= '0' && ch <= '9') glyphIndex = ch.charCodeAt(0) - 48;
    else glyphIndex = 10;
    ctx.drawImage(source, glyphIndex * glyphW, 0, glyphW, glyphH, destX, val.y, glyphW, glyphH);
    destX += glyphW;
  }
}

// Mirrors DrawSystemDigits (uDigitRenderer.pas:108-133).
function drawSystemDigits(ctx, val, text) {
  if (!val.fontName || !val.fontName.trim()) return;
  const weight = val.bold ? 'bold ' : '';
  ctx.font = `${weight}${val.fontSize * 1.333}px "${val.fontName}", sans-serif`;
  ctx.fillStyle = `rgb(${val.color.r},${val.color.g},${val.color.b})`;
  ctx.textBaseline = 'top';
  ctx.fillText(text, val.x, val.y);
}

// Mirrors TDigitRenderer.DrawPercent (uDigitRenderer.pas:135-153).
function drawPercent(ctx, images, val, value01) {
  if (!val.enabled) return;
  const percent = Math.round(clamp01(value01) * 100);
  const text = formatPercentText(percent, val.digits, val.fillZero);
  if (val.style === 'bitmap') drawBitmapDigits(ctx, images, val, text);
  else drawSystemDigits(ctx, val, text);
}

// Mirrors TMeterRenderer.DrawBackground: the background bitmap is blitted
// as-is (no per-part transparency) -- the window's overall MaskColor cutout
// is applied separately, by renderFrame below, over the whole composited
// frame, mirroring TransparentColor/TransparentColorValue at the VCL form
// level (src/uMainForm.pas:864-866) rather than per-sprite.
function drawBackground(ctx, images, layout) {
  const img = image(images, layout.bgFile);
  if (!img) return;
  ctx.drawImage(img, 0, 0);
}

// Mirrors TMeterRenderer.DrawMeters (uMeterRenderer.pas:212-242).
function drawMeters(ctx, images, layout, state) {
  drawStrip(ctx, images, layout.cpu, state.cpu);
  drawStrip(ctx, images, layout.mem, state.mem);
  drawStrip(ctx, images, layout.swap, state.swap);

  drawStrip(ctx, images, layout.diskReadMeter, state.diskRead);
  drawStrip(ctx, images, layout.diskWriteMeter, state.diskWrite);
  drawStrip(ctx, images, layout.diskIoMeter, state.diskIo);
  drawStrip(ctx, images, layout.netInMeter, state.netIn);
  drawStrip(ctx, images, layout.netOutMeter, state.netOut);
  drawStrip(ctx, images, layout.netIoMeter, state.netIo);
  drawStrip(ctx, images, layout.audio, state.audio);
  drawStrip(ctx, images, layout.audioL, state.audioL);
  drawStrip(ctx, images, layout.audioR, state.audioR);

  drawLed(ctx, images, layout.diskRead, state.diskReadOn);
  drawLed(ctx, images, layout.diskWrite, state.diskWriteOn);
  drawLed(ctx, images, layout.diskRW, state.diskRWOn);
  drawLed(ctx, images, layout.netActivity, state.netActivityOn);
  drawLed(ctx, images, layout.netIn, state.netInOn);
  drawLed(ctx, images, layout.netOut, state.netOutOn);
  drawLed(ctx, images, layout.netTotal, state.netActivityOn);

  drawPing(ctx, images, layout.ping, state.pingLevel);

  drawPercent(ctx, images, layout.cpuVal, state.cpu);
  drawPercent(ctx, images, layout.memVal, state.mem);
  drawPercent(ctx, images, layout.swapVal, state.swap);
}

const GRAPH_LANES = ['cpu', 'mem', 'swap', 'diskRead', 'diskWrite', 'netIn', 'netOut'];

// Mirrors GraphMaxWidth (uLayoutTypes.pas:115-132): widest enabled lane,
// used to size the history buffer the graph reads from.
function graphMaxWidth(graph) {
  let max = 0;
  for (const key of GRAPH_LANES) {
    const lane = graph[key];
    if (lane.enabled && lane.w > max) max = lane.w;
  }
  return max;
}

// Mirrors TGraphRenderer.Draw's DrawLane local proc (uGraphRenderer.pas:45-98).
function drawGraphLane(ctx, graph, lane, key, history) {
  if (!lane.enabled || lane.w < 1 || lane.h < 1 || !history) return;
  const cap = history.capacity;
  if (cap < 1) return;

  const w = Math.min(lane.w, cap);
  const start = cap - w;
  const left = lane.x, top = lane.y, bottom = lane.y + lane.h;
  const color = `rgb(${lane.color.r},${lane.color.g},${lane.color.b})`;

  if (graph.style === 'bar') {
    ctx.fillStyle = color;
    for (let i = 0; i < w; i++) {
      const v = clamp01(history.sampleChronological(start + i)[key]);
      const y = Math.round(v * lane.h);
      if (y < 1) continue;
      ctx.fillRect(left + i, bottom - y, 1, y);
    }
  } else {
    ctx.strokeStyle = color;
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (let i = 0; i < w; i++) {
      const v = clamp01(history.sampleChronological(start + i)[key]);
      const x = left + i + 0.5;
      const y = bottom - 1 - Math.round(v * (lane.h - 1)) + 0.5;
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
  }
}

// Mirrors TGraphRenderer.Draw (uGraphRenderer.pas:28-110). `history` is a
// HistoryBuffer (asset-editor/js/historyBuffer.js); its lane keys
// (cpu/mem/swap/diskRead/diskWrite/netIn/netOut) match TLaneKind 1:1.
function drawGraph(ctx, graph, history) {
  if (!graph || !graph.enabled) return;
  drawGraphLane(ctx, graph, graph.cpu, 'cpu', history);
  drawGraphLane(ctx, graph, graph.mem, 'mem', history);
  drawGraphLane(ctx, graph, graph.swap, 'swap', history);
  drawGraphLane(ctx, graph, graph.diskRead, 'diskRead', history);
  drawGraphLane(ctx, graph, graph.diskWrite, 'diskWrite', history);
  drawGraphLane(ctx, graph, graph.netIn, 'netIn', history);
  drawGraphLane(ctx, graph, graph.netOut, 'netOut', history);
}

// Renders one full frame: background, then meters/LEDs/digits, then the
// graph (Full layouts only, when history is supplied), then the
// window-level color-key cutout (see drawBackground's comment) so the
// caller's canvas shows exactly what the real transparent gadget window
// would show through to the desktop -- painted here as a checkerboard.
function renderFrame(canvas, images, layout, state, history) {
  canvas.width = layout.width;
  canvas.height = layout.height;
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  drawBackground(ctx, images, layout);
  drawMeters(ctx, images, layout, state);
  if (layout.graph) drawGraph(ctx, layout.graph, history);

  if (layout.transparent) {
    const imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const d = imgData.data;
    const m = layout.maskColor;
    for (let i = 0; i < d.length; i += 4) {
      if (d[i] === m.r && d[i + 1] === m.g && d[i + 2] === m.b) d[i + 3] = 0;
    }
    ctx.putImageData(imgData, 0, 0);
  }
}

return { clamp01, stripFrame, renderFrame, formatPercentText, graphMaxWidth };

});
