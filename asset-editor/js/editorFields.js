// Declares which keys each layout.cfg section kind exposes to the GUI
// editor, and what widget/type each key should use. This is the field
// list side of the "GUI edits <-> layout.cfg text" sync spec in
// docs/PLANNED-3.2.0.md item 6: it doesn't parse or write anything itself
// (asset-editor/js/skinLoader.js reads meaning, cfgModel.js's CfgDoc writes
// format-preserving text) -- it only says which keys exist for a given
// section name, mirroring src/view/uSkinLoader.pas's own per-part key sets
// (ReadSprite/ReadMeterSprite/ReadDigitValue/ReadGraphLane).
//
// `label`/`hint` are i18n keys (looked up via index.html's STRINGS/t()),
// not literal text -- this module has no UI language of its own. `options`
// arrays are the opposite: literal values written into layout.cfg itself
// (Kind=bar/peak/vu, ValStyle=bitmap/system, Style=line/bar), so they must
// never be translated.
//
// Classic UMD script, no ES-module import/export -- see cfgModel.js's header
// comment for why (Chromium blocks module scripts under file://).

(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.EditorFields = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {

// Field types: 'text', 'int', 'bool', 'color', 'enum' (needs `options`).
const SPRITE_FIELDS = [
  { key: 'File', label: 'field.file', hint: 'hint.file', type: 'text', fileRef: true },
  { key: 'X', label: 'field.x', hint: 'hint.x', type: 'int' },
  { key: 'Y', label: 'field.y', hint: 'hint.y', type: 'int' },
  { key: 'Frames', label: 'field.frames', hint: 'hint.frames', type: 'int' },
  { key: 'Transparent', label: 'field.transparent', hint: 'hint.transparent', type: 'bool' },
  { key: 'MaskColor', label: 'field.maskColor', hint: 'hint.maskColor', type: 'color' },
];

const BALLISTIC_FIELDS = [
  { key: 'Kind', label: 'field.ballisticKind', hint: 'hint.ballisticKind', type: 'enum', options: ['bar', 'peak', 'vu'] },
  { key: 'Strength', label: 'field.ballisticStrength', hint: 'hint.ballisticStrength', type: 'int' },
];

const DIGIT_FIELDS = [
  { key: 'ValSW', label: 'field.digitEnabled', hint: 'hint.digitEnabled', type: 'bool' },
  { key: 'ValStyle', label: 'field.digitStyle', hint: 'hint.digitStyle', type: 'enum', options: ['bitmap', 'system'] },
  { key: 'ValX', label: 'field.digitX', hint: 'hint.digitX', type: 'int' },
  { key: 'ValY', label: 'field.digitY', hint: 'hint.digitY', type: 'int' },
  { key: 'ValB', label: 'field.digitCount', hint: 'hint.digitCount', type: 'int' },
  { key: 'ValFZ', label: 'field.zeroFill', hint: 'hint.zeroFill', type: 'bool' },
  { key: 'ValFontFile', label: 'field.bitmapFontFile', hint: 'hint.bitmapFontFile', type: 'text', fileRef: true },
  { key: 'ValFontMaskColor', label: 'field.bitmapFontMaskColor', hint: 'hint.bitmapFontMaskColor', type: 'color' },
  { key: 'ValFont', label: 'field.systemFontName', hint: 'hint.systemFontName', type: 'text' },
  { key: 'ValFontSize', label: 'field.systemFontSize', hint: 'hint.systemFontSize', type: 'int' },
  { key: 'ValColor', label: 'field.systemFontColor', hint: 'hint.systemFontColor', type: 'color' },
  { key: 'ValBold', label: 'field.systemFontBold', hint: 'hint.systemFontBold', type: 'bool' },
];

const GENERAL_FIELDS = [
  { key: 'Id', label: 'field.id', hint: 'hint.id', type: 'text' },
  { key: 'Caption', label: 'field.caption', hint: 'hint.caption', type: 'text' },
  { key: 'Order', label: 'field.order', hint: 'hint.order', type: 'int' },
  { key: 'Default', label: 'field.defaultSkin', hint: 'hint.defaultSkin', type: 'bool' },
];

const MODE_FIELDS = [
  { key: 'Width', label: 'field.width', hint: 'hint.width', type: 'int' },
  { key: 'Height', label: 'field.height', hint: 'hint.height', type: 'int' },
  { key: 'Bg', label: 'field.bg', hint: 'hint.bg', type: 'text', fileRef: true },
  { key: 'Transparent', label: 'field.transparent', hint: 'hint.transparentMode', type: 'bool' },
  { key: 'MaskColor', label: 'field.maskColor', hint: 'hint.maskColorMode', type: 'color' },
];

// [GraphFull]: Style plus one "X,Y,W,H" + Color pair per lane. The combined
// coordinate string is edited as one text field, matching ReadGraphLane's
// own "X,Y,W,H" parsing (uSkinLoader.pas:277-300) rather than 4 separate
// int fields, since the four numbers have no meaning split apart. `lane`
// carries the raw lane name (Cpu/Mem/...) for the caller to interpolate
// into the translated label (e.g. "{lane} (X,Y,W,H — blank = disabled)").
const GRAPH_LANE_KEYS = ['Cpu', 'Mem', 'Swap', 'DiskRead', 'DiskWrite', 'NetIn', 'NetOut'];

function graphFields() {
  const fields = [{ key: 'Style', label: 'field.graphStyle', hint: 'hint.graphStyle', type: 'enum', options: ['line', 'bar'] }];
  for (const lane of GRAPH_LANE_KEYS) {
    fields.push({ key: lane, label: 'field.graphLaneCoord', hint: 'hint.graphLaneCoord', lane, type: 'text' });
    fields.push({ key: `${lane}Color`, label: 'field.graphLaneColor', hint: 'hint.graphLaneColor', lane, type: 'color' });
  }
  return fields;
}

// Section base names that carry meter-kind sprite fields (File/X/Y/Frames/
// Transparent/MaskColor + Kind/Strength) -- mirrors ReadPartSections'
// ReadMeterSprite calls (uSkinLoader.pas:250-261).
const METER_BASES = [
  'Cpu', 'Mem', 'Swap', 'DiskReadMeter', 'DiskWriteMeter', 'DiskIoMeter',
  'NetInMeter', 'NetOutMeter', 'NetIoMeter', 'Audio', 'AudioL', 'AudioR',
];
// Plain sprite (LED/ping) bases -- ReadSprite calls (uSkinLoader.pas:263-270).
const SPRITE_BASES = [
  'Ping', 'DiskRead', 'DiskWrite', 'DiskRW', 'NetIn', 'NetOut', 'NetActivity', 'NetTotal',
];
// These three also carry the section's ValSW/... digit-readout keys
// (ReadDigitValue is called on 'Cpu'+suffix/'Mem'+suffix/'Swap'+suffix, the
// same section as their meter sprite -- uSkinLoader.pas:272-274).
const DIGIT_BASES = ['Cpu', 'Mem', 'Swap'];

function stripSuffix(name) {
  if (name.endsWith('Compact')) return { base: name.slice(0, -'Compact'.length), suffix: 'Compact' };
  if (name.endsWith('Full')) return { base: name.slice(0, -'Full'.length), suffix: 'Full' };
  return { base: name, suffix: '' };
}

// Returns { kind, fields } describing the given section name's editable
// keys, or null if this section isn't one the GUI editor recognizes (the
// text pane remains the only way to edit it -- see uSkinLoader.pas's own
// comment that an omitted section simply means "unused").
function describeSection(name) {
  if (name === 'General') return { kind: 'general', fields: GENERAL_FIELDS };
  if (name === 'GeneralCompact' || name === 'GeneralFull') return { kind: 'mode', fields: MODE_FIELDS };
  if (name === 'GraphFull') return { kind: 'graph', fields: graphFields() };

  const { base, suffix } = stripSuffix(name);
  if (suffix === '') return null;

  if (METER_BASES.includes(base)) {
    const fields = [...SPRITE_FIELDS, ...BALLISTIC_FIELDS];
    if (DIGIT_BASES.includes(base)) fields.push(...DIGIT_FIELDS);
    return { kind: 'meter', fields };
  }
  if (SPRITE_BASES.includes(base)) {
    return { kind: 'sprite', fields: SPRITE_FIELDS };
  }
  return null;
}

return { describeSection, METER_BASES, SPRITE_BASES };

});
