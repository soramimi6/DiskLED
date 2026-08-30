# Changelog

[日本語](../CHANGELOG.md)

Newest first. User-facing summary only; implementation detail lives in `docs/DESIGN.md`.

## 3.1.0

Update for DiskLED 3.x on Windows 10 / 11 (64-bit).

- **High DPI**: Per-Monitor V2. The gadget uses 0.5-step scale (1× / 1.5× / 2×…; 125% looks like 1.5×). The dashboard follows real DPI (`Dpi/96`). Options use VCL Scaled
- **Dashboard**: Open from the right-click menu as a separate window. The left column has sections for CPU / memory / SWAP / disk / network (donut plus history; disk and network use a double donut, overlaid lines, and a Read/Write or In/Out color legend). The right column has CPU details, memory amounts (in-use / standby / free bar and SWAP commit), power (battery field names stay visible on AC), disk queue (including combined active time), and Ping (latest plus up to 5 history rows)
- Dashboard colors follow Windows app light/dark mode (updates while the window is open). While visible, left-column donuts update about 5 times per second; numbers, history graphs, and the right column stay at once per second. History is in memory only (cleared on restart). CPU / memory / SWAP history fills under the line with a lighter wash (disk / network stay unfilled because the traces overlap)
- Fixed network aggregate speed staying at zero
- Options dialog auto-scales on high DPI

## 3.0.1

Update for DiskLED 3.x on Windows 10 / 11 (64-bit).

- Lighter idle load: the window redraws only when sprite frames change (collectors still follow display fps)
- Meter follow: per-mode profiles in `layout.cfg` `[Ballistic]` (vu / bar / peak)
- Original: separate Net In / Out LEDs; 64-frame analog meters; full-view history graphs are bars
- Crystal: CPU / memory level bars upsampled to 32 frames (smoother follow)
- Metalic: full-view history graphs stay a line (unchanged)
- Network speed response can be linear (default) or logarithmic in Options; disk stays auto-sense linear. Switching the scale clears the history graph
- On exit, startup registration is updated to match the current setting (including rewriting the exe path after a move)
- Distribution: `DiskLED_Setup_3.0.1.exe` and `DiskLED-3.0.1-portable.zip`

## 3.0.0 — MVP

First DiskLED 3.x release for Windows 10 / 11 (64-bit). Rebuild of the classic 2.x line.

- Resident meters for CPU / memory / SWAP / disk / network / Ping
- Display modes: Original / Crystal / Metalic (full/compact + history graphs on Original and Metalic)
- Single instance, always-on-top, tray, startup, Options, `DiskLED.ini`
- Per-user installer (`DiskLED_Setup_3.0.0.exe`) and portable zip
- UI: English by default; Japanese when the OS UI is Japanese
- No adware or bundled third-party software

---

## Legacy series

The 3.x version line is counted independently from 2.x.
