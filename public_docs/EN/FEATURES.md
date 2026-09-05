# Features

[日本語](../FEATURES.md)

## What it can do

- Usage meters for **CPU, physical memory, and SWAP** (page file equivalent); rise is snappy, fall coasts
- **Disk** read/write LEDs and speed bars (sum of all physical disks)
- **Network** in/out LEDs and speed bars (sum of real NICs; VPN/loopback-style adapters are excluded when possible)
- **Ping** shown in four levels (OK / fair / slow / timeout)
- **Display modes**: Original / Crystal / Metalic / Info Bar
- Original / Metalic full view includes history graphs (**measured values**, peak in each update interval; not the meter coast). Original uses bars; Metalic uses a line. Switching network linear/log clears the graph. Crystal and Info Bar stay compact-only
- **Always-on-top** and drag-to-move
- Hover the window (or tray) for a tooltip with **version, usage, Disk/Net I/O, and Ping (target and RTT)**
- **Single instance** (a second launch focuses the existing window and exits)
- **Tray**, **startup registration** (applied when Options is confirmed and on exit), and **INI settings**
- **Installer** (per-user, uninstallable) and portable zip (see [INSTALL.md](INSTALL.md))
- **Dashboard** (3.1.0): separate window with a left column (donuts and history; disk/network include a color legend) and a right column (CPU details, memory amounts, power (left card: power info, right card: horizontal L / R volume bars and output device name), disk info (queue, latency, IOPS), Ping history) on one screen (right-click menu). Donuts and volume bars update about 5 times per second; numbers and history stay at 1 Hz. Colors follow Windows app light/dark mode. If it was open at exit, the next launch opens it again. Position, size, and maximized state persist across runs
- **High DPI** (3.1.0): Per-Monitor V2. Gadget uses 0.5-step scale (1× / 1.5× / 2×…); dashboard follows real DPI; Options use VCL Scaled
- **New version notice** (3.1.0): one GitHub Releases Latest check at startup. A newer stable release gets a tray balloon once per version, and a right-click item above Exit (**View DiskLED 3.x.x release info**) until you install it. Click opens that release page in the browser (no download or self-update; can be turned off in Options; not performed at all on the Microsoft Store build, which updates through the Store instead)
- **View Trace Route** (3.1.1): opens a dedicated window from the right-click menu showing the route to the target hop by hop (TTL, IP, hostname, RTT). Hostname lookups run asynchronously
- **Task Tray** (3.1.1): a third display size alongside Compact and Full. Hides the gadget window and turns the notification-area icon into a disk-activity LED

## Display modes

Built-in looks only. User-installed legacy skins (`.dla`) are not supported.

| Mode | Origin | Approx. size | Transparent window |
|------|----------------------|--------------|--------------------|
| **Original** | System Analog Meter II (sam2) compact | 240×34 | Yes |
| **Crystal** | Mac OS X–style (MacX) | 192×14 | Yes |
| **Metalic** | xsrv SkinS | 256×24 | No (rectangular) |
| **Info Bar** | New for DiskLED 3 | 531×16 | No (rectangular) |

- Original uses full background `Original_FullBase.png` with `[ModeFull]` / `[Graph]` (left double-click toggles). Network LEDs are separate In / Out. 64-frame analog meters. History graphs are bars
- Crystal has no full layout (compact only). CPU / memory level bars use 32 frames
- Metalic uses `Metalic_FullBase.bmp` plus graphs (left double-click toggles). History graphs are a line
- Info Bar has no full layout (compact only). CPU / memory / SWAP / disk read·write / network in·out / playback volume L / R are horizontal LED bars (21 frames). No activity LEDs

## Monitoring model

| Target | Behavior |
|--------|----------|
| Disk | Aggregate I/O for the whole system (like the chassis HDD lamp). Per-drive selection is out of scope for v1 |
| Network | Sum of real NICs. Pinning one NIC is out of scope for v1 |
| Speed range | Net: link speed, linear (default) or logarithmic (Options). Disk: measured auto-sense, always linear. No manual range UI in v1 |
| Ping | Default host `mg6.jp`, or the default gateway from Options. Can be turned off. Interval minimum and default **5 minutes**. Right-click **View Trace Route** (Japanese UI: **Ping 結果表示**) for an immediate probe alongside the route (Tracert) |

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
