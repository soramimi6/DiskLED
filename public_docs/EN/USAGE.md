# Usage

[日本語](../USAGE.md)

## Start and exit

1. Run `DiskLED.exe` from the install folder (or portable folder)
2. The meter window appears on the desktop
3. To quit: **right-click** the window → **Exit** (Japanese UI: **終了**)

- Only one instance is allowed. A second launch brings the existing window forward and exits
- Prefer the Exit menu over killing the process in Task Manager

## Window controls

| Action | Effect |
|--------|--------|
| Left-drag | Move the window |
| Hover | Tooltip with version, CPU / MEM / SWP, Disk / Net I/O, and Ping (target and RTT). Updates about once per second |
| Left double-click | Compact ⇄ full (Original / Metalic; no-op on Crystal) |
| Right-click | Popup menu |

The window is a tool window and usually does not appear on the taskbar (resident-gadget style).

## Right-click menu (current implementation)

| Item | Effect |
|------|--------|
| Original / Crystal / Metalic | Switch display mode (exclusive) |
| Compact / コンパクト | Compact view (always available) |
| Full / フル | Full view (enabled only when the mode defines full layout) |
| Refresh Ping / Ping 更新 | Send one Ping immediately |
| Options / オプション | Always-on-top, startup, fps, graph rate, network speed response (linear / log), Ping settings |
| Exit / 終了 | Quit the app |

Menu captions follow the OS UI language (**English by default**; Japanese only when OS UI is Japanese). A tray icon shows that DiskLED is running (same right-click menu; double-click brings the window forward). Hovering the tray shows the same tooltip as the window (version, usage, I/O, Ping). There is no taskbar button.

## Reading the display

- **Meters** — CPU / memory / SWAP usage. Rise is snappy; fall has a short coast (varies by display mode)
- **LEDs** — disk R/W and network activity (Original: separate In / Out; Crystal and others may also show a combined activity LED)
- **Speed bars** — instantaneous throughput. Disk is auto-sense linear; network is linear or logarithmic in Options (same rise/fall ballistics as meters)
- **Ping** — four-level frame/lamp (look varies by mode)

Layouts follow legacy skins. Original / Metalic full mode draws history graphs from **normalized measured values** (peak within each graph-update interval; not the meter’s coasting display). Original uses bars; Metalic uses a line. Switching network speed between linear and logarithmic clears the graph, because the scale changes.

## Settings file

Settings are normally saved as `DiskLED.ini` next to the executable. If that location is not writable (e.g. Program Files), `%AppData%\DiskLED\DiskLED.ini` is used. Edit the file only while the app is not running.
