# Usage

[日本語](../USAGE.md)

## Start and exit

1. Run `DiskLED.exe` from the install folder (or portable folder)
2. The meter window appears on the desktop
3. To quit: **right-click** the window → **Exit** (Japanese UI: **終了**)

- Only one instance is allowed. A second launch brings the existing window forward and exits
- Prefer the Exit menu over killing the process in Task Manager
- A normal exit rewrites startup registration to match the current Options setting (including the exe path if the folder moved)

## Window controls

| Action | Effect |
|--------|--------|
| Left-drag | Move the window |
| Hover | Tooltip with version, CPU / MEM / SWP, Disk / Net I/O, and Ping (target and RTT). Updates about once per second |
| Left double-click | Compact ⇄ full (Original / Metalic; no-op on Crystal / Info Bar) |
| Right-click | Popup menu |

The window is a tool window and usually does not appear on the taskbar (resident-gadget style).

## Right-click menu (current implementation)

| Item | Effect |
|------|--------|
| Original / Crystal / Metalic / Info Bar | Switch display mode (exclusive) |
| Compact / コンパクト | Compact view (always available) |
| Full / フル | Full view (enabled only when the mode defines full layout) |
| Dashboard / ダッシュボード | Separate window with left and right columns. Remembers position, size, and maximized state. Reopens on next launch if it was open at exit |
| Refresh Ping / Ping 更新 | Send one Ping immediately |
| Options / オプション | Always-on-top, startup, check for a new version at startup, fps, graph rate, network speed response (linear / log), Ping settings |
| View DiskLED 3.x.x release info / 新しい DiskLED 3.x.x の情報を見る | Shown above Exit only when a newer stable release exists. Click opens that GitHub release page (stays until you install it). The tray balloon is once per version |
| Exit / 終了 | Quit the app |

Menu captions follow the OS UI language (**English by default**; Japanese only when OS UI is Japanese). A tray icon shows that DiskLED is running (same right-click menu; double-click brings the window forward). Hovering the tray shows the same tooltip as the window (version, usage, I/O, Ping). There is no taskbar button.

## Reading the display

- **Meters** — CPU / memory / SWAP usage. Rise is snappy; fall has a short coast (varies by display mode)
- **LEDs** — disk R/W and network activity (Original: separate In / Out; Crystal and others may also show a combined activity LED). Info Bar has no activity LEDs; throughput is shown as horizontal LED bars
- **Speed bars** — instantaneous throughput. Disk is auto-sense linear; network is linear or logarithmic in Options (same rise/fall ballistics as meters)
- **Ping** — four-level frame/lamp (look varies by mode)
- **Volume** — Info Bar only: playback peak L / R as horizontal LED bars (separate from the dashboard power subsection)

Layouts follow each display mode’s art. Original / Metalic full mode draws history graphs from **normalized measured values** (peak within each graph-update interval; not the meter’s coasting display). Original uses bars; Metalic uses a line. Switching network speed between linear and logarithmic clears the graph, because the scale changes.

## Dashboard (3.1.0)

Open **Dashboard** from the right-click menu. Region names:

```
DISKLED HUD (header)
+ Left column
| + CPU / memory / SWAP / disk / network sections
|     donut graph (about 5 times per second) | history graph (about 5 minutes, updated every second while open)
+ Right column
  + CPU subsection — name, cores (C/T), clock (current and max when they differ), user/kernel
  + Memory subsection — RAM stacked bar (in use / standby / free), SWAP usage and commit
  + Power subsection — left card: source (AC / battery), charge, remaining time (field names stay visible on AC; — when unknown). Right card: horizontal playback L / R segmented bars (left to right; green 0–70%, yellow 70–90%, red 90–100%; fast rise, slower fall) and one line of output device name underneath (ellipsis if it does not fit; — when unknown)
  + Disk queue — queue length, combined active time across drives, read/write IOPS
  + Ping — latest RTT/target plus a time / target / RTT / status history (up to 5 rows, newest first)
```

- The disk section combines read (outer ring) and write (inner ring); both history traces are solid lines, distinguished by color and the legend. Network in/out is the same
- Numbers in the donut update once per second. Only the rings and volume bars follow about 5 times per second
- CPU / memory / SWAP history graphs fill under the line with a lighter wash of the line color. Disk / network are lines only, because the traces overlap
- Close (×) hides it (history stays in memory). Position, size, and maximized state are kept even after close. If it was still open at exit, the next launch restores that state (stored as 96 dpi DIP). History is cleared on app restart
- CPU package temperature is not shown (not available reliably without admin/vendor APIs)
- Matching row heights across columns (CPU / memory / SWAP↔power / disk↔disk queue / network↔Ping). Laid out for a single screen with no scrolling. Resizable window
- Colors follow Windows app mode (light / dark). Changing the OS setting updates an already-open dashboard. Light colors are provisional
- Appears on the taskbar (the gadget itself still does not)
- Turning Ping off in Options makes the tooltip say “off”. The dashboard Ping subsection keeps the last history and does not send new probes

## Options

Right-click **Options** (Japanese UI: **オプション**). Confirm with **Apply** (Cancel discards).

| Item | Effect |
|------|--------|
| Always on top | Gadget window only (on by default). Does not apply to the dashboard |
| Run at Windows startup | Writes the Run key on Apply and on a normal exit |
| Check for a new version at startup | One GitHub Latest lookup after launch (on by default). Off skips the request and hides the menu item |
| Refresh rate (fps) | 10 / 15 (default) / 20. No redraw while sprite frames stay the same |
| Graph update (Hz) | 0.5 / 1 (default) / 2 for Original / Metalic **full-view** history. Dashboard history is always 1 second |
| Network speed response | Linear (link speed = 100%, default) or logarithmic. Switching clears gadget and dashboard network history |
| Enable Ping | Off stops periodic ICMP |
| Use default gateway | Host field is read-only when on |
| Ping host | Default `mg6.jp` (when gateway is off) |
| Interval | Seconds. **Minimum and default 300** (5 minutes) |
| Ping level thresholds | Fair / Slow / Timeout (ms). Fair &lt; Slow &lt; Timeout. Reset button restores 200 / 500 / 1000 |

## Settings file

Settings are normally saved as `DiskLED.ini` next to the executable. If that location is not writable (e.g. Program Files), `%AppData%\DiskLED\DiskLED.ini` is used. Edit the file only while the app is not running. Dashboard position and size are stored as 96 dpi DIP; maximized state is a separate key. Bounds are converted to physical pixels for the current monitor DPI on load.
