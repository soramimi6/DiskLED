# Changelog

[日本語](../CHANGELOG.md)

Newest first. User-facing summary only; implementation detail lives in `docs/DESIGN.md`.

## 3.0.1

Update for DiskLED 3.x on Windows 10 / 11 (64-bit).

- Lighter idle load: the window redraws only when sprite frames change (collectors still follow display fps)
- Meter follow: per-mode profiles in `layout.cfg` `[Ballistic]` (vu / bar / peak)
- Original: separate Net In / Out LEDs; 64-frame analog meters; full-view history graphs are bars
- Crystal: CPU / memory level bars upsampled to 32 frames (smoother follow)
- Metalic: full-view history graphs stay a line (unchanged)
- Network speed response can be linear (default) or logarithmic in Options; disk stays auto-sense linear. Switching the scale clears the history graph
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
