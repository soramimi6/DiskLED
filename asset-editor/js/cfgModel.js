// Line-preserving layout.cfg model: parse into a line array plus a
// section/key -> line-number index, and write back by touching only the
// lines that actually changed. This is the foundational piece PLANNED-3.2.0
// item 6 flags as the biggest uncertainty ("テキスト<->GUI同期はフォーマット
// 保持"); see asset-editor/spike-roundtrip.cjs for the proof this file exists
// to support: a single GUI value change must turn into a single changed
// text line against the project's own real layout.cfg files.
//
// Plain classic script (no ES-module `import`/`export`) so index.html can
// load it via <script src="js/cfgModel.js"></script> and still work when the
// page is opened directly from disk (file://) -- Chromium blocks module
// script loading under file://, but a classic script has no such
// restriction. A tiny UMD wrapper also lets spike-roundtrip.cjs `require()`
// it under Node for fast command-line re-checks during development.

(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.CfgDoc = factory().CfgDoc;
  }
})(typeof self !== 'undefined' ? self : this, function () {

const SECTION_RE = /^\s*\[(.+?)\]\s*$/;
// Captures: 1) everything up to and including '=' (leading whitespace, key,
// spacing around '='), 2) the value, 3) trailing whitespace/comment to keep
// untouched. DiskLED's own layout.cfg files don't currently use inline
// trailing comments (Delphi's TMemIniFile treats the rest of the line as
// the value), but preserving an optional ';'-led comment here is cheap and
// matches the plan's "行末コメント保持" requirement defensively.
const KEY_RE = /^(\s*([^=\s][^=]*?)\s*=\s*)([^;]*?)(\s*(?:;.*)?)$/;
// A whole line that is (optionally indented) a comment. KEY_RE's key group
// ([^=\s][^=]*?) doesn't exclude a leading ';', so a comment containing its
// own '=' (e.g. "; ... 1px = 1 sample ...") would otherwise be misread as a
// key -- every KEY_RE match site below checks this first.
const COMMENT_LINE_RE = /^\s*;/;

class CfgDoc {
  constructor(text) {
    // Split on \r\n or \n, remember which line ending the file actually
    // uses so a round-trip on an unmodified line reproduces it byte-for-byte.
    this.eol = text.includes('\r\n') ? '\r\n' : '\n';
    this.lines = text.split(/\r\n|\n/);
    this._rebuildIndex();
  }

  _rebuildIndex() {
    // sections: ordered array of {name, headerLine, keys: Map<key, line>, endLine}
    // endLine = index of the last line belonging to this section (before the
    // next section header or EOF) -- where a new key gets inserted.
    this.sections = [];
    let current = null;
    for (let i = 0; i < this.lines.length; i++) {
      const line = this.lines[i];
      const secMatch = SECTION_RE.exec(line);
      if (secMatch) {
        current = { name: secMatch[1], headerLine: i, keys: new Map(), endLine: i };
        this.sections.push(current);
        continue;
      }
      if (current) {
        current.endLine = i;
      }
      const keyMatch = COMMENT_LINE_RE.test(line) ? null : KEY_RE.exec(line);
      if (keyMatch && current) {
        const key = keyMatch[2];
        // First occurrence wins for lookups; a duplicate is a validation
        // error at a higher layer, not something the line model resolves.
        if (!current.keys.has(key)) {
          current.keys.set(key, i);
        }
      }
    }
  }

  findSection(name) {
    return this.sections.find((s) => s.name.toLowerCase() === name.toLowerCase());
  }

  getValue(sectionName, key) {
    const section = this.findSection(sectionName);
    if (!section || !section.keys.has(key)) return undefined;
    const line = this.lines[section.keys.get(key)];
    const m = KEY_RE.exec(line);
    return m ? m[3] : undefined;
  }

  // Sets Section/Key to newValue, touching the minimum number of lines:
  // - key exists: rewrite just that line (keep indent/comment).
  // - section exists, key doesn't: insert "Key=Value" right after the
  //   section's last line.
  // - section doesn't exist: append a blank line, "[Section]", "Key=Value"
  //   at end of file.
  setValue(sectionName, key, newValue) {
    let section = this.findSection(sectionName);
    if (!section) {
      if (this.lines.length > 0 && this.lines[this.lines.length - 1] !== '') {
        this.lines.push('');
      }
      this.lines.push(`[${sectionName}]`);
      this.lines.push(`${key}=${newValue}`);
      this._rebuildIndex();
      return;
    }
    if (section.keys.has(key)) {
      const lineNo = section.keys.get(key);
      const m = KEY_RE.exec(this.lines[lineNo]);
      if (m) {
        this.lines[lineNo] = `${m[1]}${newValue}${m[4]}`;
      } else {
        // Shouldn't happen (the index only records lines that matched
        // KEY_RE), but fall back to a plain rewrite rather than throw.
        this.lines[lineNo] = `${key}=${newValue}`;
      }
      this._rebuildIndex();
      return;
    }
    // Section exists, key doesn't: insert right after the section's last
    // recorded line (its header if it has no keys yet).
    const insertAt = section.endLine + 1;
    this.lines.splice(insertAt, 0, `${key}=${newValue}`);
    this._rebuildIndex();
  }

  // Appends a new, empty section (just its header line) at EOF, blank-line
  // separated -- the same "section doesn't exist" placement setValue uses,
  // just without requiring an initial key. No-op if the section is already
  // there. Used by the asset-editor's "Active" checkbox: checking a section
  // that isn't in the file yet adds it with nothing in it, ready for the
  // GUI fields to fill in (which themselves call setValue as usual).
  addSection(sectionName) {
    if (this.findSection(sectionName)) return;
    if (this.lines.length > 0 && this.lines[this.lines.length - 1] !== '') {
      this.lines.push('');
    }
    this.lines.push(`[${sectionName}]`);
    this._rebuildIndex();
  }

  // Removes a section's header line and every line through its recorded
  // endLine (its own content plus any blank separator line before the next
  // section or EOF) -- the inverse of addSection, and the other half of the
  // "Active" checkbox. No-op if the section isn't present.
  removeSection(sectionName) {
    const section = this.findSection(sectionName);
    if (!section) return;
    this.lines.splice(section.headerLine, section.endLine - section.headerLine + 1);
    this._rebuildIndex();
  }

  // Every distinct key actually present in a section, one entry per key
  // (first-occurrence casing) regardless of how many times it repeats --
  // pair with findDuplicateKeys to also see which of these repeat. Used by
  // the asset-editor GUI to spot keys it has no field for ("unknown key").
  sectionKeys(sectionName) {
    const section = this.findSection(sectionName);
    if (!section) return [];
    const seenLower = new Set();
    const result = [];
    for (let i = section.headerLine + 1; i <= section.endLine; i++) {
      const line = this.lines[i];
      if (COMMENT_LINE_RE.test(line)) continue;
      const m = KEY_RE.exec(line);
      if (!m) continue;
      const lower = m[2].toLowerCase();
      if (seenLower.has(lower)) continue;
      seenLower.add(lower);
      result.push(m[2]);
    }
    return result;
  }

  // Key names that appear more than once within a section. The constructor
  // comment already notes why this isn't resolved by the section/key index
  // itself (that index only ever records the first occurrence's line, for
  // lookups) -- detecting a duplicate is a validation-layer concern the
  // asset-editor GUI surfaces as a warning; CfgDoc never removes or merges
  // one on its own.
  findDuplicateKeys(sectionName) {
    const section = this.findSection(sectionName);
    if (!section) return [];
    const counts = new Map(); // lower(key) -> { key: firstCasing, count }
    for (let i = section.headerLine + 1; i <= section.endLine; i++) {
      const line = this.lines[i];
      if (COMMENT_LINE_RE.test(line)) continue;
      const m = KEY_RE.exec(line);
      if (!m) continue;
      const lower = m[2].toLowerCase();
      const entry = counts.get(lower);
      if (entry) entry.count++;
      else counts.set(lower, { key: m[2], count: 1 });
    }
    return [...counts.values()].filter((e) => e.count > 1).map((e) => e.key);
  }

  toText() {
    return this.lines.join(this.eol);
  }
}

return { CfgDoc };

});
