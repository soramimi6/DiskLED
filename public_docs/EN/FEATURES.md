# Features

[日本語](../FEATURES.md)

## What it can do

- Usage meters for **CPU, physical memory, and SWAP** (page file equivalent); rise is snappy, fall coasts
- **Disk** read/write LEDs and speed bars (sum of all physical disks)
- **Network** in/out LEDs and speed bars (sum of real NICs; VPN/loopback-style adapters are excluded when possible)
- **Ping** shown in four levels (OK / fair / slow / timeout)
- **Display modes**: Original / Crystal / Metalic / Info Bar / Vintage
- Original / Metalic full view includes history graphs (**measured values**, peak in each update interval; not the meter coast). Original uses bars; Metalic uses a line. Switching network linear/log clears the graph. Crystal stays compact-only. Info Bar and Vintage have a full view but no history graph
- **Always-on-top** and drag-to-move
- Hover the window (or tray) for a tooltip with **version, usage, Disk/Net I/O, and Ping (target and RTT)**
- **Single instance** (a second launch focuses the existing window and exits)
- **Tray**, **startup registration** (applied when Options is confirmed; the GitHub edition also rewrites it on a normal exit; the Microsoft Store edition uses Windows' startup task mechanism), and **INI settings**
- **Installer** (per-user, uninstallable) and portable zip (see [INSTALL.md](INSTALL.md))
- **Dashboard** (3.1.0): separate window with a left column (donuts and history; disk/network include a color legend) and a right column (CPU details, memory amounts, power (left card: power info, right card: horizontal L / R volume bars and output device name), disk info (queue, latency, IOPS), Ping history) on one screen (right-click menu). Donuts and volume bars update about 5 times per second; numbers and history stay at 1 Hz. Colors follow Windows app light/dark mode. If it was open at exit, the next launch opens it again. Position, size, and maximized state persist across runs
- **High DPI** (3.1.0): Per-Monitor V2. Gadget uses 0.5-step scale (1× / 1.5× / 2×…); dashboard follows real DPI; Options use VCL Scaled
- **New version notice** (3.1.0): one GitHub Releases Latest check at startup. A newer stable release gets a tray balloon once per version, and a right-click item above Exit (**View DiskLED 3.x.x release info**) until you install it. Click opens that release page in the browser (no download or self-update; can be turned off in Options; not performed at all on the Microsoft Store build, which updates through the Store instead)
- **Ping / Route** (added as a separate window in 3.1.1; became a dashboard page in 3.3.0): a waterfall showing which segments of the path the round trip to the target is spent in, plus each hop's RTT (min–max), loss, jitter, and change from last time. Measures only while the page is showing. Optional network operator names (off by default) and IPv6-only targets are supported
- **Task Tray** (3.1.1): a third display size alongside Compact and Full. Hides the gadget window and turns the notification-area icon into a disk-activity LED
- **Display mode "Vintage"** (3.1.2; full volume meter became stereo in 3.2.0): an analog VU-meter style skin. Compact shows 5 meters (CPU / MEM / DiskIO / NetIO / SND); full shows 9 (CPU / MEM / SWP / DiskRead / DiskWrite / NetIn / NetOut / L / R stereo volume). Disk and Net meters include an activity lamp
- **Display scale** (3.2.0; moved from the right-click menu to Options in 3.3.0): pick the gadget's own zoom level on the Display tab in Options. Default is Automatic (follows screen DPI); can also be fixed at 100% / 150% / 200% (the dashboard is unaffected and always follows the real DPI)
- **UI language** (3.2.0): choose the UI language in Options — Auto (default) / Japanese / English. Takes effect on the next launch
- **GPU usage on the dashboard** (3.2.0): shares the CPU card (outer ring = CPU, inner ring = GPU, two history lines). On multi-GPU systems, shows the busiest GPU's usage
- **Reworked task tray** (3.2.0): display is a 3-way choice of "Window Only / Window + Tray LED / Tray LED Only", so the tray LED can stay lit while the window is also shown (moved to the General tab in Options in 3.3.0). Disk and network activity can be shown at the same time as two separate tray icons
- **Tray LED color** (3.2.0; yellow added in 3.3.0): green, blue, red, or yellow. Since 3.3.0, disk and network can use different colors
- **Per-drive tray LEDs** (3.3.0): a tray icon for each chosen drive (C:, D:, …), identified by the letter at the icon's lower right and its tooltip. Can be shown together with the all-drives LED
- **Network LED flicker** (3.3.0): while traffic continues, network LEDs go dark for a moment whenever the transfer rate drops, like an access lamp (in the tray and in display modes that have network LEDs)
- **Dashboard pages** (3.3.0): tabs switch between Overview, Processes, and Ping / Route. The Processes page lists the top processes by CPU usage, memory used, and I/O, along with window title, company, user and more
- **Uptime and totals** (3.3.0): the dashboard header shows the PC's uptime and cumulative disk (read / write) and network (received / sent) totals
- **Asset Editor** (3.2.0): a browser-based skin editor bundled in `asset-editor/`. Its text and GUI editors for `layout.cfg` stay in sync in real time, with a live preview matching the real app's look, for creating and tweaking your own display modes. See [SKIN_GUIDE.md](SKIN_GUIDE.md)
- **Reworked Options dialog** (3.2.0): reorganized into four tabs (General / Display / Tray LED / Ping & Network). Since 3.3.0 it always uses the standard Windows look (it does not follow light/dark mode)

## Display modes

Built-in looks only. User-installed legacy skins (`.dla`) are not supported.

| Mode | Origin | Approx. size | Transparent window |
|------|----------------------|--------------|--------------------|
| **Original** | System Analog Meter II (sam2) compact | 240×34 | Yes |
| **Crystal** | Mac OS X–style (MacX) | 192×14 | Yes |
| **Metalic** | xsrv SkinS | 256×24 | No (rectangular) |
| **Info Bar** | New for DiskLED 3 | 285×16 (full 531×16) | No (rectangular) |
| **Vintage** | New for DiskLED 3 | 232×32 (full 416×32) | Yes |

- Original uses full background `Original_FullBase.png` with `[ModeFull]` / `[Graph]` (left double-click toggles). Network LEDs are separate In / Out. 64-frame analog meters. History graphs are bars
- Crystal has no full layout (compact only). CPU / memory level bars use 32 frames
- Metalic uses `Metalic_FullBase.bmp` plus graphs (left double-click toggles). History graphs are a line
- Info Bar's compact and full views are both centered on horizontal LED bars, toggled by left double-click (full added in 3.2.0). Full shows CPU / memory / SWAP / disk read·write / network in·out / playback volume L / R, all as horizontal LED bars (21 frames), with no activity LEDs. Compact trims that down to a CPU bar, Ping, and playback volume L / R bars, plus 2-frame activity LEDs for disk read·write and network in·out (green = read/in, red = write/out)
- Vintage is an analog (moving-coil) VU-meter style. Compact shows 5 meters (CPU / MEM / DiskIO / NetIO / SND); full shows 9 (CPU / MEM / SWP / DiskRead / DiskWrite / NetIn / NetOut / L / R stereo volume), toggled by left double-click. DiskIO / NetIO needles show the larger of read/write (in/out). Disk- and Net-family meters include an activity lamp. No history graph

## Monitoring model

| Target | Behavior |
|--------|----------|
| Disk | Aggregate I/O for the whole system (like the chassis HDD lamp). Tray LEDs can also be shown per drive (C: and so on; 3.3.0) |
| Network | Sum of real NICs. Pinning one NIC is out of scope for v1 |
| Speed range | Net: link speed, linear (default) or logarithmic (Options). Disk: measured auto-sense, always linear. No manual range UI in v1 |
| Ping | Default host `mg6.jp`, or the default gateway from Options. Can be turned off. Interval minimum and default **5 minutes**. The route is measured only while the dashboard's **Ping / Route** page (Japanese UI: **Ping/経路**) is showing |

### Ping levels (default thresholds)

| Display | Condition (default) |
|---------|---------------------|
| OK | 0 ≤ RTT &lt; 200 ms |
| Fair | 200 ≤ RTT &lt; 500 ms |
| Slow | 500 ≤ RTT &lt; 1000 ms |
| Timeout | Failure, or ≥ 1000 ms |

Thresholds can be changed in Options under Ping level thresholds (Fair &lt; Slow &lt; Timeout; a reset-to-defaults button is included).

## Not in v1

Some 2.x features are intentionally omitted. See [NOTES.md](NOTES.md).
