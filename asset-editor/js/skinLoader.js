// Parses a skin's layout.cfg into the same shape src/view/uSkinLoader.pas
// builds (TSkinModeMeta / TViewLayout), with the same strict validation
// rules: a missing key falls back to a default, but a key that IS present
// with a value that fails to parse throws -- see uSkinLoader.pas's own
// ReadStrict* helpers and their comment for why ("previously only the
// required Mode fields were checked this way").
//
// Deliberately independent of asset-editor/js/cfgModel.js's line-preserving
// CfgDoc: that model exists for format-preserving GUI->text writes, this one
// exists to read the *meaning* of a cfg for rendering/preview. Both parse
// the same INI dialect but for different purposes.
//
// Classic UMD script (no ES-module import/export), matching cfgModel.js --
// see that file's own header comment for why (Chromium blocks module
// scripts under file://).

(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.SkinLoader = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {

class SkinFormatError extends Error {
  constructor(path, section, key, raw) {
    super(`${path}: [${section}] ${key}=${raw} is not a valid value`);
    this.path = path;
    this.section = section;
    this.key = key;
    this.raw = raw;
  }
}

// A plain INI reader (case-insensitive section/key lookup, first value wins
// on duplicate keys) -- just enough of TMemIniFile's behavior for this
// loader's purposes. Line-preserving edits belong to CfgDoc, not here.
class IniFile {
  constructor(text) {
    this.sections = new Map(); // lower(name) -> Map<lower(key), value>
    let current = null;
    const lines = text.split(/\r\n|\n/);
    for (const raw of lines) {
      const line = raw.trim();
      if (line === '' || line.startsWith(';')) continue;
      const secMatch = /^\[(.+?)\]$/.exec(line);
      if (secMatch) {
        const name = secMatch[1].toLowerCase();
        current = this.sections.get(name);
        if (!current) {
          current = new Map();
          this.sections.set(name, current);
        }
        continue;
      }
      const eq = line.indexOf('=');
      if (eq < 0 || !current) continue;
      const key = line.slice(0, eq).trim().toLowerCase();
      const value = line.slice(eq + 1).trim();
      if (!current.has(key)) current.set(key, value);
    }
  }

  readString(section, key, def) {
    const sec = this.sections.get(section.toLowerCase());
    if (!sec) return def;
    const v = sec.get(key.toLowerCase());
    return v === undefined ? def : v;
  }

  readInteger(section, key, def) {
    const raw = this.readString(section, key, '');
    if (raw === '') return def;
    const n = parseInt(raw, 10);
    return Number.isNaN(n) ? def : n;
  }
}

function isHexChar(c) {
  return /[0-9A-Fa-f]/.test(c);
}

// Mirrors uSkinLoader.pas's TryParseColor: "#RRGGBB" or a Delphi "clXxx"
// constant name. The Delphi TColor constants actually reachable via
// StringToColor are the named ones VCL registers (clBlack, clWhite, clRed,
// ...); skins only ever use a small, fixed set of these in practice, so a
// lookup table covers what StringToColor would resolve rather than
// reimplementing the whole VCL identifier-to-TColor table.
const CL_COLORS = {
  clblack: '#000000', clmaroon: '#800000', clgreen: '#008000', clolive: '#808000',
  clnavy: '#000080', clpurple: '#800080', clteal: '#008080', clgray: '#808080',
  clgrey: '#808080', clsilver: '#C0C0C0', clred: '#FF0000', cllime: '#00FF00',
  clyellow: '#FFFF00', clblue: '#0000FF', clfuchsia: '#FF00FF', claqua: '#00FFFF',
  clwhite: '#FFFFFF', clmoneygreen: '#C0DCC0', clskyblue: '#A6CAF0', clcream: '#FFFBF0',
  clmedgray: '#A0A0A4',
};

function tryParseColor(raw) {
  const v = raw.trim();
  if (v.length === 7 && v[0] === '#' &&
      [1, 2, 3, 4, 5, 6].every((i) => isHexChar(v[i]))) {
    return { r: parseInt(v.slice(1, 3), 16), g: parseInt(v.slice(3, 5), 16), b: parseInt(v.slice(5, 7), 16) };
  }
  const named = CL_COLORS[v.toLowerCase()];
  if (named) {
    return { r: parseInt(named.slice(1, 3), 16), g: parseInt(named.slice(3, 5), 16), b: parseInt(named.slice(5, 7), 16) };
  }
  return null;
}

function colorToCss(c) {
  const h = (n) => n.toString(16).padStart(2, '0');
  return `#${h(c.r)}${h(c.g)}${h(c.b)}`;
}

class SkinReader {
  constructor(path, ini) {
    this.path = path;
    this.ini = ini;
  }

  err(section, key, raw) {
    return new SkinFormatError(this.path, section, key, raw);
  }

  readStrictInt(section, key, def) {
    const raw = this.ini.readString(section, key, '').trim();
    if (raw === '') return def;
    if (!/^[+-]?\d+$/.test(raw)) throw this.err(section, key, raw);
    return parseInt(raw, 10);
  }

  readStrictBool(section, key, def) {
    const raw = this.ini.readString(section, key, '').trim();
    if (raw === '') return def;
    const v = raw.toLowerCase();
    if (v === '1' || v === 'true' || v === 'yes' || v === 'on') return true;
    if (v === '0' || v === 'false' || v === 'no' || v === 'off') return false;
    throw this.err(section, key, raw);
  }

  readStrictColor(section, key, def) {
    const raw = this.ini.readString(section, key, '').trim();
    if (raw === '') return def;
    const c = tryParseColor(raw);
    if (!c) throw this.err(section, key, raw);
    return c;
  }

  // Mirrors ReadSprite (uSkinLoader.pas:151-175).
  readSprite(section) {
    const fileName = this.ini.readString(section, 'File', '').trim();
    if (fileName === '') return null;
    const x = this.readStrictInt(section, 'X', 0);
    const y = this.readStrictInt(section, 'Y', 0);
    const frames = this.readStrictInt(section, 'Frames', 1);
    if (frames < 1) throw this.err(section, 'Frames', String(frames));
    const hasMask = this.ini.readString(section, 'MaskColor', '').trim() !== '';
    const transparent = this.readStrictBool(section, 'Transparent', hasMask);
    let maskColor = { r: 0, g: 0, b: 0 };
    if (transparent) {
      maskColor = this.readStrictColor(section, 'MaskColor', maskColor);
    } else if (hasMask) {
      this.readStrictColor(section, 'MaskColor', maskColor); // validate even though unused
    }
    return { fileName, x, y, frames, transparent, maskColor };
  }

  // Mirrors ReadMeterSprite (uSkinLoader.pas:181-202): meter-kind parts
  // additionally require Kind=/Strength= when defined.
  readMeterSprite(section) {
    const sprite = this.readSprite(section);
    if (!sprite) return null;
    const kindRaw = this.ini.readString(section, 'Kind', '').trim();
    const strengthRaw = this.ini.readString(section, 'Strength', '').trim();
    if (kindRaw === '' || strengthRaw === '') {
      throw new SkinFormatError(this.path, section, 'Kind/Strength', '(missing)');
    }
    const kind = kindRaw.toLowerCase();
    if (kind !== 'bar' && kind !== 'peak' && kind !== 'vu') throw this.err(section, 'Kind', kindRaw);
    sprite.ballisticKind = kind;
    sprite.ballisticStrength = this.readStrictInt(section, 'Strength', 0);
    if (sprite.ballisticStrength < 0 || sprite.ballisticStrength > 100) {
      throw this.err(section, 'Strength', strengthRaw);
    }
    return sprite;
  }

  // Mirrors ReadDigitValue (uSkinLoader.pas:204-240).
  readDigitValue(section) {
    const enabled = this.readStrictBool(section, 'ValSW', false);
    const styleRaw = this.ini.readString(section, 'ValStyle', 'bitmap').trim().toLowerCase();
    const style = styleRaw === 'system' ? 'system' : 'bitmap';
    const x = this.readStrictInt(section, 'ValX', 0);
    const y = this.readStrictInt(section, 'ValY', 0);
    const digits = this.readStrictInt(section, 'ValB', 3);
    if (digits < 1) throw this.err(section, 'ValB', String(digits));
    const fillZero = this.readStrictBool(section, 'ValFZ', false);

    const fontName = this.ini.readString(section, 'ValFont', '').trim();
    const fontSize = this.readStrictInt(section, 'ValFontSize', 9);
    if (fontSize < 1) throw this.err(section, 'ValFontSize', String(fontSize));
    const color = this.readStrictColor(section, 'ValColor', { r: 0, g: 0, b: 0 });
    const bold = this.readStrictBool(section, 'ValBold', false);

    const bitmapFile = this.ini.readString(section, 'ValFontFile', '').trim();
    if (enabled && style === 'bitmap' && bitmapFile === '') {
      throw new SkinFormatError(this.path, section, 'ValFontFile', '(required when ValSW=1 and ValStyle=bitmap)');
    }
    const fontMaskRaw = this.ini.readString(section, 'ValFontMaskColor', '').trim();
    const fontTransparent = fontMaskRaw !== '';
    const fontMaskColor = fontTransparent
      ? this.readStrictColor(section, 'ValFontMaskColor', { r: 0, g: 0, b: 0 })
      : { r: 0, g: 0, b: 0 };

    return {
      enabled, style, x, y, digits, fillZero,
      fontName, fontSize, color, bold,
      bitmapFile, fontMaskColor, fontTransparent,
    };
  }

  // Mirrors ReadPartSections (uSkinLoader.pas:248-275).
  readPartSections(suffix) {
    const layout = {};
    layout.cpu = this.readMeterSprite('Cpu' + suffix);
    layout.mem = this.readMeterSprite('Mem' + suffix);
    layout.swap = this.readMeterSprite('Swap' + suffix);
    layout.diskReadMeter = this.readMeterSprite('DiskReadMeter' + suffix);
    layout.diskWriteMeter = this.readMeterSprite('DiskWriteMeter' + suffix);
    layout.diskIoMeter = this.readMeterSprite('DiskIoMeter' + suffix);
    layout.netInMeter = this.readMeterSprite('NetInMeter' + suffix);
    layout.netOutMeter = this.readMeterSprite('NetOutMeter' + suffix);
    layout.netIoMeter = this.readMeterSprite('NetIoMeter' + suffix);
    layout.audio = this.readMeterSprite('Audio' + suffix);
    layout.audioL = this.readMeterSprite('AudioL' + suffix);
    layout.audioR = this.readMeterSprite('AudioR' + suffix);

    layout.ping = this.readSprite('Ping' + suffix);
    layout.diskRead = this.readSprite('DiskRead' + suffix);
    layout.diskWrite = this.readSprite('DiskWrite' + suffix);
    layout.diskRW = this.readSprite('DiskRW' + suffix);
    layout.netIn = this.readSprite('NetIn' + suffix);
    layout.netOut = this.readSprite('NetOut' + suffix);
    layout.netActivity = this.readSprite('NetActivity' + suffix);
    layout.netTotal = this.readSprite('NetTotal' + suffix);

    layout.cpuVal = this.readDigitValue('Cpu' + suffix);
    layout.memVal = this.readDigitValue('Mem' + suffix);
    layout.swapVal = this.readDigitValue('Swap' + suffix);
    return layout;
  }

  // Mirrors ReadGraphLane/ReadGraph (uSkinLoader.pas:277-322). Kept for
  // parsing completeness (so a skin with [GraphFull] still validates), even
  // though this milestone's renderer doesn't draw graphs yet.
  readGraphLane(key, colorKey, defaultColor) {
    const raw = this.ini.readString('GraphFull', key, '').trim();
    if (raw === '') return { enabled: false };
    const parts = raw.split(',');
    const nums = parts.map((p) => p.trim());
    if (nums.length !== 4 || !nums.every((n) => /^[+-]?\d+$/.test(n))) {
      throw this.err('GraphFull', key, raw);
    }
    const [x, y, w, h] = nums.map((n) => parseInt(n, 10));
    if (w <= 0 || h <= 0) throw this.err('GraphFull', key, raw);
    return { enabled: true, x, y, w, h, color: this.readStrictColor('GraphFull', colorKey, defaultColor) };
  }

  readGraph() {
    const styleRaw = this.ini.readString('GraphFull', 'Style', '').trim().toLowerCase();
    const style = styleRaw === 'bar' ? 'bar' : 'line';
    const black = { r: 0, g: 0, b: 0 };
    const graph = {
      style,
      cpu: this.readGraphLane('Cpu', 'CpuColor', black),
      mem: this.readGraphLane('Mem', 'MemColor', black),
      swap: this.readGraphLane('Swap', 'SwapColor', black),
      diskRead: this.readGraphLane('DiskRead', 'DiskReadColor', black),
      diskWrite: this.readGraphLane('DiskWrite', 'DiskWriteColor', black),
      netIn: this.readGraphLane('NetIn', 'NetInColor', black),
      netOut: this.readGraphLane('NetOut', 'NetOutColor', black),
    };
    graph.enabled = [graph.cpu, graph.mem, graph.swap, graph.diskRead, graph.diskWrite, graph.netIn, graph.netOut]
      .some((l) => l.enabled);
    return graph;
  }
}

// Mirrors LoadSkinLayout (uSkinLoader.pas:324-384). `folderName` stands in
// for the Delphi version's ExtractFileName(ExtractFilePath(path)) fallback.
function loadSkin(path, text, folderName) {
  const ini = new IniFile(text);
  const r = new SkinReader(path, ini);

  const id = ini.readString('General', 'Id', folderName).trim() || folderName;
  const caption = ini.readString('General', 'Caption', id).trim() || id;
  const order = r.readStrictInt('General', 'Order', 100);
  const isDefault = r.readStrictBool('General', 'Default', false);

  const compact = {
    modeId: id,
    transparent: r.readStrictBool('GeneralCompact', 'Transparent', true),
    maskColor: r.readStrictColor('GeneralCompact', 'MaskColor', { r: 0, g: 0, b: 0 }),
    bgFile: ini.readString('GeneralCompact', 'Bg', '').trim(),
    width: ini.readInteger('GeneralCompact', 'Width', 0),
    height: ini.readInteger('GeneralCompact', 'Height', 0),
  };
  if (compact.width <= 0 || compact.height <= 0 || compact.bgFile === '') {
    throw new Error(`${path}: [GeneralCompact] is incomplete (Width/Height/Bg all required)`);
  }
  Object.assign(compact, r.readPartSections('Compact'));

  const fullBg = ini.readString('GeneralFull', 'Bg', '').trim();
  const fullW = ini.readInteger('GeneralFull', 'Width', 0);
  const fullH = ini.readInteger('GeneralFull', 'Height', 0);
  const hasFull = fullBg !== '' && fullW > 0 && fullH > 0;

  let full = null;
  if (hasFull) {
    full = {
      modeId: id,
      width: fullW,
      height: fullH,
      bgFile: fullBg,
      transparent: r.readStrictBool('GeneralFull', 'Transparent', true),
      maskColor: r.readStrictColor('GeneralFull', 'MaskColor', { r: 0, g: 0, b: 0 }),
      graph: r.readGraph(),
    };
    Object.assign(full, r.readPartSections('Full'));
  }

  return { id, caption, order, isDefault, hasFull, compact, full };
}

return { loadSkin, tryParseColor, colorToCss, SkinFormatError, IniFile };

});
