# Features

[日本語](../FEATURES.md)

## What v1 / MVP includes

- Usage meters for **CPU, physical memory, and SWAP** (page file equivalent); rise is snappy, fall coasts
- **Disk** read/write LEDs and speed bars (sum of all physical disks)
- **Network** in/out LEDs and speed bars (sum of real NICs; VPN/loopback-style adapters are excluded when possible)
- **Ping** shown in four levels (OK / fair / slow / timeout)
- **Display modes**: Original / Crystal / Metalic
- Original / Metalic full view includes history graphs (**measured values**, peak in each update interval; not the meter coast)
- **Always-on-top** and drag-to-move
- Hover the window (or tray) for a tooltip with **version, usage, Disk/Net I/O, and Ping (target and RTT)**
- **Single instance** (a second launch focuses the existing window and exits)
- **Tray**, **startup registration**, and **INI settings**
- **Installer** (per-user, uninstallable) and portable zip (see [INSTALL.md](INSTALL.md))

## Display modes

Built-in looks only. User-installed legacy skins (`.dla`) are not supported.

| Mode | Origin (legacy skin) | Approx. size | Transparent window |
|------|----------------------|--------------|--------------------|
| **Original** | System Analog Meter II (sam2) compact | 240×34 | Yes |
| **Crystal** | Mac OS X–style (MacX) | 192×14 | Yes |
| **Metalic** | xsrv SkinS | 256×24 | No (rectangular) |

- Original uses full background `Original_FullBase.png` with `[ModeFull]` / `[Graph]` (left double-click toggles). Network LEDs are separate In / Out
- Crystal has no full layout (compact only)
- Metalic uses `Metalic_FullBase.bmp` plus graphs (left double-click toggles)

## Monitoring model

| Target | Behavior |
|--------|----------|
| Disk | Aggregate I/O for the whole system (like the chassis HDD lamp). Per-drive selection is out of scope for v1 |
| Network | Sum of real NICs. Pinning one NIC is out of scope for v1 |
| Speed range | Device caps, then measured auto-sense (no manual range UI in v1) |
| Ping | Default host `mg6.jp`, or auto default gateway (toggle planned in options). Interval minimum and default **5 minutes**. Right-click **Refresh Ping** (Japanese UI: **Ping 更新**) for an immediate probe |

### Ping levels (default thresholds)

| Display | Condition (default) |
|---------|---------------------|
| OK | 0 ≤ RTT &lt; 200 ms |
| Fair | 200 ≤ RTT &lt; 500 ms |
| Slow | 500 ≤ RTT &lt; 1000 ms |
| Timeout | Failure, or ≥ 1000 ms |

Thresholds are designed to be editable in options (see CHANGELOG / DESIGN for status).

## Not in v1

Some 2.x features are intentionally omitted. See [NOTES.md](NOTES.md).
