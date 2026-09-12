// Line-preserving layout.cfg model: parse into a line array plus a
// section/key -> line-number index, and write back by touching only the
// lines that actually changed. This is the foundational piece PLANNED-3.2.0
// item 6 flags as the biggest uncertainty ("テキスト<->GUI同期はフォーマット
// 保持"); see asset-editor/spike-roundtrip.mjs for the proof this file exists
// to support: a single GUI value change must turn into a single changed
// text line against the project's own real layout.cfg files.
//
// Plain ES module, no build step, runs unmodified under Node (for the spike
// script) and in a <script type="module"> browser context.

const SECTION_RE = /^\s*\[(.+?)\]\s*$/;
// Captures: 1) everything up to and including '=' (leading whitespace, key,
// spacing around '='), 2) the value, 3) trailing whitespace/comment to keep
// untouched. DiskLED's own layout.cfg files don't currently use inline
// trailing comments (Delphi's TMemIniFile treats the rest of the line as
// the value), but preserving an optional ';'-led comment here is cheap and
// matches the plan's "行末コメント保持" requirement defensively.
const KEY_RE = /^(\s*([^=\s][^=]*?)\s*=\s*)([^;]*?)(\s*(?:;.*)?)$/;

export class CfgDoc {
  constructor(text) {
    // Split on \r\n or \n, remember which line ending the file actually
    // uses so a round-trip on an unmodified line reproduces it byte-for-byte.
    this.eol = text.includes('\r\n') ? '\r\n' : '\n';
    this.lines = text.split(/\r\n|\n/);
    // A trailing split artifact ("") from a final newline is kept as a real
    // line only if the source had one; track that so join() doesn't add or
    // drop a trailing newline that wasn't there.
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
      const keyMatch = KEY_RE.exec(line);
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
      } else if (this.lines.length === 0) {
        // nothing to pad
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

  toText() {
    return this.lines.join(this.eol);
  }
}
