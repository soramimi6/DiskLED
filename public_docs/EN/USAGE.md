# Usage

[日本語](../USAGE.md)

## Start and exit

1. Choose DiskLED from the Start menu to launch it. For the portable edition, run `DiskLED.exe` from its folder
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
| Left double-click | Compact ⇄ full (Original / Metalic / Vintage / Info Bar; no-op on Crystal) |
| Right-click | Popup menu |

The window is a tool window and usually does not appear on the taskbar (resident-gadget style).

## Right-click menu (current implementation)

| Item | Effect |
|------|--------|
| Original / Crystal / Metalic / Info Bar / Vintage | Switch display mode (exclusive) |
| Compact / コンパクト | Compact view (always available) |
| Full / フル | Full view (enabled only when the mode defines full layout) |
| Reset Position / 位置をリセット | Move the main window back on-screen and bring it forward. Recovery for a window stuck off-screen; also works while the tray LED only is showing, restoring the window |
| Dashboard / ダッシュボード | Separate window with three pages: Overview, Processes, and Ping / Route. Remembers position, size, and maximized state. Reopens on next launch if it was open at exit |
| Options / オプション | Always-on-top, startup, UI language, check for a new version at startup, display mode (window / tray LED), fps, graph rate, network speed response (linear / log), display scale, tray LED color/info/per-drive, Ping settings. Four tabs: General / Display / Tray LED / Ping & Network |
| View DiskLED 3.x.x release info / 新しい DiskLED 3.x.x の情報を見る | Shown above Exit only when a newer stable release exists. Click opens that GitHub release page (stays until you install it). The tray balloon is once per version |
| Exit / 終了 | Quit the app |

Menu captions follow the OS UI language (**English by default**; Japanese only when OS UI is Japanese — or fix either one from Options' Language setting). The right-click menu is the same from the tray icon and from the window, regardless of display state (Compact/Full, Window Only/Window + Tray LED/Tray LED Only). Hovering the tray shows the same tooltip as the window (version, usage, I/O, Ping).

In 3.3.0, Window Only / Window + Tray LED / Tray LED Only moved to the **General** tab in Options, and Display Scale moved to the **Display** tab. View Trace Route was removed and replaced by the dashboard's **Ping / Route** page (see [Ping / Route page](#ping--route-page)).

## Task Tray

**Display mode** on the **General** tab in Options (**Window Only / Window + Tray LED / Tray LED Only**) chooses the main window's visibility and the tray LED, independent of the Compact/Full size.

- **Window Only** (default): shows only the main window; the tray LED stays off
- **Window + Tray LED**: shows the main window while the notification-area icon also lights up as a disk/network activity LED
- **Tray LED Only**: hides the main window (the app keeps running) and lights up only the notification-area icon as an LED
- **Click** the tray icon to open the dashboard. **Double-click** it to show the main window (this also leaves Tray LED Only)
- The right-click menu is the same in every state; Options and the dashboard can be opened from it
- The dashboard is independent of this state: if it was open, it stays open even with only the tray LED showing
- The network LED flickers like an access lamp: while traffic continues, it goes dark for a moment whenever the transfer rate drops
- Storing the icon in the notification area's "hidden icons" tray hides the blinking too (a Windows limitation) — pin it somewhere always visible instead

### Tray LED settings (Options)

Set these on the **Tray LED** tab in Options.

| Item | Effect |
|------|--------|
| Tray LED color | Green / Blue / Red / Yellow, chosen separately for disk and network |
| Tray LED info | Independent Disk / Network checkboxes. **Both can be on at once**, which shows two tray icons (one per metric). Both cannot be off at the same time |
| Per-drive LEDs | Shows a tray icon for each checked drive (C:, D:, …). Tell them apart by the letter at the icon's lower right and the tooltip (read / write rate over the last second). A drive that is not connected can be checked in advance and appears once it is connected. Optical drives cannot be chosen |
| Also show the total LED | Keeps the all-drives disk LED while per-drive LEDs are chosen (on by default) |

## Reading the display

- **Meters** — CPU / memory / SWAP usage. Rise is snappy; fall has a short coast (varies by display mode)
- **LEDs** — disk R/W and network activity (Original: separate In / Out; Crystal and others may also show a combined activity LED). Network LEDs go dark for a moment whenever the transfer rate drops, even while traffic continues. Info Bar's full view has no activity LEDs (throughput is shown as horizontal LED bars instead), but its compact view does show activity LEDs (green = read/in, red = write/out)
- **Speed bars** — instantaneous throughput. Disk is auto-sense linear; network is linear or logarithmic in Options (same rise/fall ballistics as meters)
- **Ping** — four-level frame/lamp (look varies by mode)
- **Volume** — Info Bar only: playback peak L / R as horizontal LED bars (separate from the dashboard power subsection)

Layouts follow each display mode’s art. Original / Metalic full mode draws history graphs from **normalized measured values** (peak within each graph-update interval; not the meter’s coasting display). Original uses bars; Metalic uses a line. Switching network speed between linear and logarithmic clears the graph, because the scale changes.

## Dashboard (3.1.0)

Open **Dashboard** from the right-click menu (or click the tray icon).

The tabs under the header switch between three pages: **Overview**, **Processes**, and **Ping / Route** (Ctrl+Tab / Ctrl+Shift+Tab also work). The dashboard always opens on Overview. The right side of the header shows the PC's uptime and the cumulative disk (read / write) and network (received / sent) totals (3.3.0).

### Overview page

Region names:

```
DISKLED HUD (header)
+ Left column
| + CPU (shares its card with GPU) / memory / SWAP / disk / network sections
|     donut graph (about 5 times per second) | history graph (about 5 minutes, updated every second while open)
+ Right column
  + CPU subsection — name, cores (C/T), clock (current and base when they differ; base only while the current clock is unknown), user/kernel
  + Memory subsection — RAM stacked bar (in use / standby / free), SWAP (page file) usage and commit
  + Power subsection — left card: source (AC / battery), charge, remaining time (field names stay visible on AC; — when unknown). Right card: horizontal playback L / R segmented bars (left to right; green 0–70%, yellow 70–90%, red 90–100%; fast rise, slower fall) and one line of output device name underneath (ellipsis if it does not fit; — when unknown)
  + Disk info — big numbers for queue length and latency (average response time, ms; — when unavailable) side by side, combined active time across drives, read/write IOPS
  + Ping — latest RTT/target plus a time / target / RTT / status history (up to 5 rows, newest first). Click to go to the Ping / Route page
```

- The CPU section's outer ring is CPU and inner ring is GPU (two history lines, distinguished by the legend). On multi-GPU systems, shows the busiest GPU's usage
- The disk section combines read (outer ring) and write (inner ring); both history traces are solid lines, distinguished by color and the legend. Network in/out is the same
- Numbers in the donut update once per second. Only the rings and volume bars follow about 5 times per second. CPU is the average over the last second (on Task Manager's basis), and so are the disk and network rates. Network rates are in bits (Kbps / Mbps / Gbps)
- SWAP is page file usage. Shows — where it cannot be read
- CPU / memory / SWAP history graphs fill under the line with a lighter wash of the line color. Disk / network are lines only, because the traces overlap
- Close (×) hides it (history stays in memory). Position, size, and maximized state are kept even after close. If it was still open at exit, the next launch restores that state (stored as 96 dpi DIP). History is cleared on app restart
- CPU package temperature is not shown (not available reliably without admin/vendor APIs)
- Matching row heights across columns (CPU / memory / SWAP↔power / disk↔disk info / network↔Ping). Laid out for a single screen with no scrolling. Resizable window
- Colors follow Windows app mode (light / dark). Changing the OS setting updates an already-open dashboard. Light colors are provisional
- Appears on the taskbar (the gadget itself still does not)
- Turning Ping off in Options makes the tooltip say “off”. The dashboard Ping subsection keeps the last history and does not send new probes

### Processes page

Lists the processes using the most CPU, memory, and I/O in three columns, left to right (3.3.0).

- Processes with the same name are combined into one row, with the count after the name (e.g. `chrome (12)`)
- Each entry has four lines: icon, name and value; window title (or description / product name) and company; user, commit, handle count and thread count; and executable path. Hover an entry for more, including version, 64-bit / 32-bit and copyright
- CPU is the share of the whole CPU; memory is the amount used (private working set) and its share of physical memory; I/O is the read and write rates. I/O counts all reads and writes to files, the network and devices, so it does not match Task Manager's Disk column
- Processes DiskLED cannot open, such as system processes and processes running as administrator, show "Details not available" and the default icon
- Making the window taller shows more entries
- Choose the refresh interval (3 / 5 / 10 seconds) at the right end of the tab row. **Stop** freezes the current list. The interval is remembered (Stop is not)
- Collection runs only while this page is showing

### Ping / Route page

Shows which segments of the path the round trip to the target is spent in (3.3.0; replaces the View Trace Route window of 3.2.0 and earlier). The target is the same as the Ping setting.

- The top shows the target, hop count, round trip and measurement time, a bar splitting the round trip by segment, and a waterfall of the hops (a bar per segment and a min–max line). A gray dashed line is the router's own reply delay, which is not delay along the path
- The list at the bottom shows, per hop: host name (IP), class (LAN / CGNAT / global and so on), reply type, loss, segment delay, RTT (min–max), jitter, and change from the last measurement. Hover a row for details; scroll with the mouse wheel when it does not fit
- Each measurement sends three probes to every hop and compares their medians
- Measurement runs only while this page is showing. It measures once when the page opens; choose automatic measurement (1 / 5 / 10 minutes, Stop by default) at the right end of the tab row. **Measure now** measures again at any time
- Turning on **Show network operators** in the tab row looks up the operator of each global-address hop (e.g. `Example Corp. (AS64500)`) from an external DNS service (off by default; see [NOTES.md](NOTES.md) for where the query goes and what is sent)
- When the Ping target has only an IPv6 address, the route is measured over IPv6

## Options

Right-click **Options** (Japanese UI: **オプション**). Confirm with **Apply** (Cancel discards). Four tabs: **General / Display / Tray LED / Ping & Network**. The window uses the standard Windows look and does not follow light/dark mode (3.3.0).

### General

| Item | Effect |
|------|--------|
| Always on top | Gadget window only (on by default). Does not apply to the dashboard |
| Run at Windows startup | Starts at logon. The GitHub edition writes the Run key on Apply and on a normal exit. The Microsoft Store edition uses Windows' startup task mechanism (`windows.startupTask`); if it has been disabled from outside the app (Windows Startup Apps settings or policy), the checkbox becomes read-only and shows that state |
| Check for a new version at startup | One GitHub Latest lookup after launch (on by default). Off skips the request and hides the menu item. Not shown on the Microsoft Store build, which updates automatically via the Store. **Do not run the Store edition and the GitHub edition (installer/zip) side by side** |
| Language | Auto (default) / Japanese / English. **Takes effect on the next launch** |
| Display mode | Window Only (default) / Window + Tray LED / Tray LED Only. See [Task Tray](#task-tray) |

### Display

| Item | Effect |
|------|--------|
| Refresh rate (fps) | 10 / 15 (default) / 20. No redraw while sprite frames stay the same |
| Graph update (Hz) | 0.5 / 1 (default) / 2 for Original / Metalic **full-view** history. Dashboard history is always 1 second |
| Network speed response | Linear (link speed = 100%, default) or logarithmic. Switching clears gadget and dashboard network history |
| Display scale | Auto (default; follows screen DPI) / 100% / 150% / 200%. Only affects the gadget's own zoom; the dashboard is unaffected |

### Tray LED

| Item | Effect |
|------|--------|
| Tray LED color | Green (default) / Blue / Red / Yellow, chosen on separate rows for disk and network |
| Tray LED info | Independent Disk / Network checkboxes. Both can be on at once (shows two tray icons). Both cannot be off at the same time |
| Per-drive LEDs | Pick the drives that get their own tray LED from the drive list. Drives that are not connected are marked "(not connected)" |
| Also show the total LED | Keeps the all-drives LED while per-drive LEDs are chosen (on by default) |

### Ping & Network

| Item | Effect |
|------|--------|
| Enable Ping | Off stops periodic ICMP |
| Use default gateway | Host field is read-only when on |
| Ping host | Default `mg6.jp` (when gateway is off) |
| Interval | Seconds. **Minimum and default 300** (5 minutes) |
| Ping level thresholds | Fair / Slow / Timeout (ms). Fair &lt; Slow &lt; Timeout. Reset button restores 200 / 500 / 1000 |

## Settings file

Settings are normally saved as `DiskLED.ini` next to the executable. If that location is not writable (e.g. Program Files), `%AppData%\DiskLED\DiskLED.ini` is used. Edit the file only while the app is not running. Dashboard position and size are stored as 96 dpi DIP; maximized state is a separate key. Bounds are converted to physical pixels for the current monitor DPI on load.
