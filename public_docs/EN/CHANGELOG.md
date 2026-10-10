# Changelog

[日本語](../CHANGELOG.md)

Newest first. User-facing summary only; implementation detail lives in `docs/DESIGN.md`.

## 3.3.0

**If you are updating from 3.2.0 or earlier**: "View Trace Route" has been removed from the right-click menu. The route now lives on the dashboard's "Ping / Route" tab (clicking the Ping box on the Overview page also opens it). "Window Only / Window + Tray LED / Tray LED Only" moved from the right-click menu to the General tab in Options, and "Display Scale" moved to the Display tab.

Update for DiskLED 3.x on Windows 10 / 11 (64-bit).

- **Added pages to the dashboard**. Tabs under the header (or Ctrl+Tab) switch between Overview, Processes, and Ping / Route
  - **Processes**: lists the top processes by CPU usage, memory used, and I/O in three columns (processes with the same name are combined into one row). Also shows window title, company, user, commit, handle and thread counts, and executable path; hover an entry for more. Refreshes every 3 / 5 / 10 seconds, or can be stopped
  - **Ping / Route**: a waterfall showing which segments of the path the round trip to the target is spent in, with each hop's RTT (min–max), loss, jitter, and change from last time. Automatic measurement every 1 / 5 / 10 minutes or stopped (default: stopped), plus "Measure now". Measures only while the page is showing. Turning on "Show network operators" looks up each hop's operator from an external DNS service (off by default). When the Ping target has only an IPv6 address, the route is measured over IPv6
- **Per-drive tray LEDs**. Shows a tray icon for each drive chosen in Options (C:, D:, …), identified by the letter at the icon's lower right and its tooltip. Can be shown together with the all-drives LED
- **Added yellow to the tray LED colors, and disk and network can now use different colors**
- **Network LEDs now flicker like an access lamp**. While traffic continues, they go dark for a moment whenever the transfer rate drops (in the tray and in display modes that have network LEDs)
- **The dashboard header now shows the PC's uptime and cumulative disk (read / write) and network (received / sent) totals**
- **Measured values now match Task Manager**
  - Fixed network rates and totals coming out several times too high because filter drivers attached to network adapters were counted as extra adapters
  - Network rates are now shown in bits (Kbps / Mbps / Gbps)
  - CPU usage now uses the same basis as Task Manager (processor utility, which accounts for clock speed). The CPU clock now shows the actual running clock (it used to show an average of base clocks)
  - SWAP is now page file usage (it used to show the commit charge). Shows "—" where the value cannot be read
  - The dashboard's memory "Standby" is now Windows' standby list
  - Fixed link speeds such as 10 Gbps being capped at 4.29 Gbps
  - Disk queue, IOPS, active time and latency, and the dashboard's disk and network rates are now one-second averages
- Tidied up the right-click menu. "Window Only / Window + Tray LED / Tray LED Only" moved to the General tab in Options and "Display Scale" to the Display tab
- The Options dialog now always uses the standard Windows look (it no longer follows light/dark mode)
- Fixed the dashboard flickering over Remote Desktop
- Fixed the black outline around the numbers inside the dashboard donuts standing out in light mode
- Unified wording across the UI

## 3.2.0

Update for DiskLED 3.x on Windows 10 / 11 (64-bit).

- **Manual display scale for the gadget itself**. Added a "Display scale" submenu to the right-click menu: the default stays Automatic (follows screen DPI), and 100% / 150% / 200% can now be chosen as well (the dashboard is unaffected and always follows the real DPI)
- **Manual UI language selection** in Options (Auto / Japanese / English). Takes effect on the next launch
- **Added GPU usage to the dashboard**, sharing the CPU card (outer ring = CPU, inner ring = GPU, two history lines). On multi-GPU systems, shows the busiest GPU's usage
- **Reworked the task tray**. The display menu is now a 3-way choice of "Window only / Window + tray LED / Tray LED only", so the tray LED can stay lit while the window is also shown. The tray LED color can now be green, blue, or red. Disk and network activity can be shown at the same time as two separate tray icons
- **Added a browser-based skin editor, "Asset Editor"** (bundled in `asset-editor/`). In the browser, you can edit `layout.cfg` while previewing it. You can create and tweak your own display modes. See the bundled `SKIN_GUIDE.md` for usage
- **Added a full view to the "Info Bar" display mode**. Full shows what the old compact view used to (CPU/memory/SWAP bars, disk/network speed bars, Ping, volume bars); compact was redesigned to a slimmer layout (narrower width) with a CPU bar, Ping, volume bars, and simple disk/network activity LEDs in place of the speed bars
- Fixed a bug where, at high display scales (200% etc.), the dashboard window couldn't be resized down to fit the screen
- Adjusted the "Vintage" display mode's tick marks and labels, and changed its full view's volume meter from mono to stereo (L / R)
- Reorganized the Options dialog into four tabs and made its colors follow Windows' light/dark app mode
- Improved the dashboard power card's remaining time to show units

## 3.1.2

**If you use the Microsoft Store version**: "Run at Windows startup" now works correctly. Previously, turning it on did not actually register the app. Please turn it off and back on once to pick up the fix.

Update for DiskLED 3.x on Windows 10 / 11 (64-bit).

- **Fixed startup registration on the Microsoft Store build.** Turning on "Run at Windows startup" previously had no real effect, so the app never launched at logon. Switched to the `windows.startupTask` mechanism. If it has been disabled from outside the app (Windows Startup Apps settings or policy), Options now shows that state
- **Added a new display mode, "Vintage."** An analog VU-meter style skin. Compact shows 5 meters (CPU / MEM / DiskIO / NetIO / SND); full shows 8 (CPU / MEM / SWP / DiskRead / DiskWrite / NetIn / NetOut / SND). Disk and Net meters include an activity lamp
- Fixed the dashboard window getting stuck off-screen after a monitor configuration change (e.g. removing a secondary monitor)
- Fixed the View Trace Route window's text overlapping and columns overflowing at high DPI (150% and above)
- The hover/tray tooltip now also shows the Microsoft Store edition (`(Store)`); shortened the I/O labels (Disk I/O → Disk, Net I/O → Net)
- Unified the behavior when a `layout.cfg` or image asset is broken: instead of a possible startup crash or an app left running with a half-drawn display, it now shows a clear error and exits
- Distribution: `DiskLED_Setup_3.1.2.exe` and `DiskLED-3.1.2-portable.zip`

## 3.1.1

**If you use the Microsoft Store version**: Starting with 3.1.1, the Store build no longer checks GitHub for updates at startup — updates arrive automatically through the Store. Please do not additionally install the GitHub installer or zip on top of it; running both can cause duplicate instances and conflicting settings.

Update for DiskLED 3.x on Windows 10 / 11 (64-bit).

- **Added a "task tray" display size.** The right-click display-size menu is now an exclusive 3-way choice: Compact / Full / Task Tray. Choosing Task Tray hides the main window and turns the notification-area icon itself into a disk-activity LED (Read/Write combined, on/off). Double-click restores the last Compact/Full size. The right-click menu is the same regardless of display size
- **Ping results now open in a dedicated window** (replaces the old "Refresh Ping" item). Shows each hop's route (TTL, IP, hostname, RTT) top-down like Tracert, with asynchronous hostname resolution. Also shows hop count, total time, and the last measured time
- **Added disk latency** (average response time, ms) to the dashboard. Shown as a big number next to Queue on the Disk Info card (— when unavailable)
- Raised the dashboard's minimum size to 1000×900 (96 dpi DIP)
- The Microsoft Store build no longer checks GitHub for updates at startup (updates come through the Store instead; the matching Options item is hidden too)
- Refreshed the app icon
- Fixed the hover tooltip showing across screen edges and monitor boundaries, and flickering at some positions
- Added **Reset Position** to the right-click menu, so a main window stuck off-screen can be recovered from the tray icon's right-click menu
- Fixed the main window being pulled back to the primary monitor on restart when it had been left on a secondary monitor
- Fixed the startup update-check menu item briefly showing stale state left over from a previous session
- Distribution: `DiskLED_Setup_3.1.1.exe` and `DiskLED-3.1.1-portable.zip`

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
- One GitHub Releases Latest check at startup. A newer stable release gets a tray balloon once per version, and a right-click item above Exit (**View DiskLED 3.x.x release info**) until you install it. Click opens that release page (no download or self-update; can be turned off in Options)
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
