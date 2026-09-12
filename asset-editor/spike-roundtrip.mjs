// PLANNED-3.2.0 item 6 spike: prove "GUI 1 value change -> text diff of
// exactly 1 line" against the project's own 5 real layout.cfg files, before
// any editor UI is built on top of CfgDoc. Run with: node spike-roundtrip.mjs
//
// Not a unit test framework -- a standalone proof script, matching the
// plan's own framing ("スパイクは最初に証明する").

import { readFileSync } from 'node:fs';
import { CfgDoc } from './js/cfgModel.js';

const skins = ['crystal', 'infobar', 'metalic', 'original', 'vintage'];
// One representative edit per skin: an existing GeneralCompact key every
// skin defines (per assets/LAYOUT.md), changed to a new value.
const edit = { section: 'GeneralCompact', key: 'Width', newValue: '999' };

let allOk = true;

function diffLines(before, after) {
  const max = Math.max(before.length, after.length);
  const changed = [];
  for (let i = 0; i < max; i++) {
    if (before[i] !== after[i]) changed.push({ line: i, before: before[i], after: after[i] });
  }
  return changed;
}

for (const skin of skins) {
  const path = `../assets/${skin}/layout.cfg`;
  const original = readFileSync(new URL(path, import.meta.url), 'utf8');
  const doc = new CfgDoc(original);

  const before = doc.getValue(edit.section, edit.key);
  if (before === undefined) {
    console.log(`[${skin}] FAIL: ${edit.section}/${edit.key} not found`);
    allOk = false;
    continue;
  }

  const beforeLines = original.split(/\r\n|\n/);
  doc.setValue(edit.section, edit.key, edit.newValue);
  const afterText = doc.toText();
  const afterLines = afterText.split(/\r\n|\n/);

  const changed = diffLines(beforeLines, afterLines);
  const readBack = doc.getValue(edit.section, edit.key);
  const roundTripOk = readBack === edit.newValue;
  const oneLineOk = changed.length === 1;
  const eolPreserved = afterText.endsWith('\r\n') === original.endsWith('\r\n') ||
    (!original.includes('\r\n') && !afterText.includes('\r\n'));

  const status = roundTripOk && oneLineOk && eolPreserved ? 'OK' : 'FAIL';
  if (status === 'FAIL') allOk = false;
  console.log(
    `[${skin}] ${status}  ${edit.section}/${edit.key}: '${before}' -> '${readBack}'` +
      `  (lines changed: ${changed.length}, eol preserved: ${eolPreserved})`
  );
  if (status === 'FAIL' || process.argv.includes('--verbose')) {
    for (const c of changed) {
      console.log(`    line ${c.line}: '${c.before}' -> '${c.after}'`);
    }
  }
}

// Second pass: prove the "key doesn't exist yet" insert path, and the
// "section doesn't exist" append path, against one real file without
// mutating what's already there.
{
  const skin = 'original';
  const path = `../assets/${skin}/layout.cfg`;
  const original = readFileSync(new URL(path, import.meta.url), 'utf8');
  const doc = new CfgDoc(original);
  const beforeLines = original.split(/\r\n|\n/);

  doc.setValue('GeneralCompact', 'BrandNewKey', 'hello');
  const afterInsertKey = doc.toText().split(/\r\n|\n/);
  const insertDelta = afterInsertKey.length - beforeLines.length;
  console.log(
    `[${skin}] new-key-in-existing-section: ${insertDelta === 1 ? 'OK' : 'FAIL'}` +
      ` (+${insertDelta} line, value=${doc.getValue('GeneralCompact', 'BrandNewKey')})`
  );

  doc.setValue('BrandNewSection', 'Foo', 'bar');
  const afterNewSection = doc.toText().split(/\r\n|\n/);
  // Exactly one blank line separates the new section from whatever came
  // before (the file may or may not have already ended on a blank line),
  // followed by the header and the key -- check content, not a fixed line
  // count, since that depends on whether the source already ended blank.
  const tail = afterNewSection.slice(-3);
  const sectionOk =
    tail[0] === '' && tail[1] === '[BrandNewSection]' && tail[2] === 'Foo=bar';
  console.log(
    `[${skin}] new-section-at-eof: ${sectionOk ? 'OK' : 'FAIL'}` +
      ` (tail=${JSON.stringify(tail)}, value=${doc.getValue('BrandNewSection', 'Foo')})`
  );
  if (insertDelta !== 1 || !sectionOk) allOk = false;
}

console.log(allOk ? '\nAll round-trip checks passed.' : '\nSome checks FAILED.');
process.exit(allOk ? 0 : 1);
