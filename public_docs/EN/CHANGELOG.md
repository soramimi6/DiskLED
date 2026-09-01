# Changelog

[日本語](../CHANGELOG.md)

Newest first. User-facing summary only; implementation detail lives in `docs/DESIGN.md`.

## 3.1.0

Update for DiskLED 3.x on Windows 10 / 11 (64-bit).

- **High DPI**: Per-Monitor V2. The gadget uses 0.5-step scale (1× / 1.5× / 2×…; 125% looks like 1.5×). The dashboard follows real DPI (`Dpi/96`). Options use VCL Scaled
- **Dashboard**: Open from the right-click menu as a separate window. The left column has sections for CPU / memory / SWAP / disk / network (donut plus history; disk and network use a double donut, overlaid lines, and a Read/Write or In/Out color legend). The right column has CPU details, memory amounts (in-use / standby / free bar and SWAP commit), power (left card: power info, right card: horizontal L / R volume segment bars that light left to right, plus the output device name), disk queue (including combined active time), and Ping (latest plus up to 5 history rows)
- Dashboard colors follow Windows app light/dark mode (updates while the window is open). While visible, left-column donuts and the volume bars on the right of the power subsection update about 5 times per second; numbers, history graphs, and the rest of the right column stay at once per second. History is in memory only (cleared on restart). If the window was open at exit, the next launch opens it again. Position, size, and maximized state are restored (96 dpi DIP). CPU / memory / SWAP history fills under the line with a lighter wash (disk / network stay unfilled because the traces overlap)
- Default dashboard size is now 960×720, minimum 800×600 (96 dpi DIP), so it fits smaller screens more easily
- Playback L / R peaks are collected internally, plus a mono equivalent (max of all channels). Shown as horizontal L / R bars (left to right) and one line of output device name (ellipsis if needed) on the right card of the power subsection (no waveform or recording)
- Left-column donut center values are about 1.5× as large, with a black outline on CPU / memory / SWAP / disk / network
- Fixed the gadget sticking to a screen edge after snapping, so it can be dragged away again
- Display mode **Info Bar** added (531×16, compact only). CPU / memory / SWAP / disk read·write / network in·out / playback volume L / R as horizontal LED bars (no activity LEDs)
- Display modes (`layout.cfg`) can define gadget volume meters `Audio` / `AudioL` / `AudioR` (0–100%). Bundled **Info Bar** uses L / R bars; Original / Crystal / Metalic do not
- Options dialog auto-scales on high DPI
- Distribution: `DiskLED_Setup_3.1.0.exe` and `DiskLED-3.1.0-portable.zip`

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
