# Changelog

[日本語](../CHANGELOG.md)

Newest first. User-facing summary only; implementation detail lives in `docs/DESIGN.md`.

## 3.0.1 — in progress

- Lighter idle load: the window redraws only when sprite frames change (collectors still follow display fps)
- Original full-view history graphs are bars; Metalic stays a line

## 3.0.0 — MVP

First DiskLED 3.x release for Windows 10 / 11 (64-bit). Rebuild of the classic 2.x line.

- Resident meters for CPU / memory / SWAP / disk / network / Ping
- Display modes: Original / Crystal / Metalic (full/compact + history graphs on Original and Metalic)
- Original: separate Net In / Out LEDs (Crystal / Metalic may also use a combined activity LED)
- Single instance, always-on-top, tray, startup, Options, `DiskLED.ini`
- Per-user installer (`DiskLED_Setup_3.0.0.exe`) and portable zip
- UI: English by default; Japanese when the OS UI is Japanese
- No adware or bundled third-party software

---

## Legacy series

The 3.x version line is counted independently from 2.x.
