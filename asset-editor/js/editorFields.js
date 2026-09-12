// Declares which keys each layout.cfg section kind exposes to the GUI
// editor, and what widget/type each key should use. This is the field
// list side of the "GUI edits <-> layout.cfg text" sync spec in
// docs/PLANNED-3.2.0.md item 6: it doesn't parse or write anything itself
// (asset-editor/js/skinLoader.js reads meaning, cfgModel.js's CfgDoc writes
// format-preserving text) -- it only says which keys exist for a given
// section name, mirroring src/view/uSkinLoader.pas's own per-part key sets
// (ReadSprite/ReadMeterSprite/ReadDigitValue/ReadGraphLane).
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
  { key: 'File', label: 'Image file', type: 'text' },
  { key: 'X', label: 'X', type: 'int' },
  { key: 'Y', label: 'Y', type: 'int' },
  { key: 'Frames', label: 'Frames', type: 'int' },
  { key: 'Transparent', label: 'Transparent', type: 'bool' },
  { key: 'MaskColor', label: 'Mask color', type: 'color' },
];

const BALLISTIC_FIELDS = [
  { key: 'Kind', label: 'Ballistic kind', type: 'enum', options: ['bar', 'peak', 'vu'] },
  { key: 'Strength', label: 'Ballistic strength (0-100)', type: 'int' },
];

const DIGIT_FIELDS = [
  { key: 'ValSW', label: 'Digit readout enabled', type: 'bool' },
  { key: 'ValStyle', label: 'Digit style', type: 'enum', options: ['bitmap', 'system'] },
  { key: 'ValX', label: 'Digit X', type: 'int' },
  { key: 'ValY', label: 'Digit Y', type: 'int' },
  { key: 'ValB', label: 'Digit count', type: 'int' },
  { key: 'ValFZ', label: 'Zero-fill', type: 'bool' },
  { key: 'ValFontFile', label: 'Bitmap font file (style=bitmap)', type: 'text' },
  { key: 'ValFontMaskColor', label: 'Bitmap font mask color (blank = opaque)', type: 'color' },
  { key: 'ValFont', label: 'System font name (style=system)', type: 'text' },
  { key: 'ValFontSize', label: 'System font size', type: 'int' },
  { key: 'ValColor', label: 'System font color', type: 'color' },
  { key: 'ValBold', label: 'System font bold', type: 'bool' },
];

const GENERAL_FIELDS = [
  { key: 'Id', label: 'Id', type: 'text' },
  { key: 'Caption', label: 'Caption', type: 'text' },
  { key: 'Order', label: 'Order', type: 'int' },
  { key: 'Default', label: 'Default skin', type: 'bool' },
];

const MODE_FIELDS = [
  { key: 'Width', label: 'Width', type: 'int' },
  { key: 'Height', label: 'Height', type: 'int' },
  { key: 'Bg', label: 'Background image file', type: 'text' },
  { key: 'Transparent', label: 'Transparent', type: 'bool' },
  { key: 'MaskColor', label: 'Mask color', type: 'color' },
];

// [GraphFull]: Style plus one "X,Y,W,H" + Color pair per lane. The combined
// coordinate string is edited as one text field, matching ReadGraphLane's
// own "X,Y,W,H" parsing (uSkinLoader.pas:277-300) rather than 4 separate
// int fields, since the four numbers have no meaning split apart.
const GRAPH_LANE_KEYS = ['Cpu', 'Mem', 'Swap', 'DiskRead', 'DiskWrite', 'NetIn', 'NetOut'];

function graphFields() {
  const fields = [{ key: 'Style', label: 'Style', type: 'enum', options: ['line', 'bar'] }];
  for (const lane of GRAPH_LANE_KEYS) {
    fields.push({ key: lane, label: `${lane} (X,Y,W,H — blank = disabled)`, type: 'text' });
    fields.push({ key: `${lane}Color`, label: `${lane} color`, type: 'color' });
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

// All section names a fresh part could be added as, grouped for a
// "new section" picker -- suffix-less; the caller appends Compact/Full.
const KNOWN_PART_BASES = [...new Set([...METER_BASES, ...SPRITE_BASES])];

return { describeSection, KNOWN_PART_BASES };

});
