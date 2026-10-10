# Notes and differences from 2.x

[日本語](../NOTES.md)

## Disclaimer

The author accepts no liability for any damage arising from use of this software. Use it at your own risk.

## Operational notes

- **Ping** sends ICMP to an external host (default `mg6.jp`) or the gateway. It can be turned off in Options. If security software or a firewall blocks ICMP, the UI stays on timeout (accepted as normal)
- **Disk / network** are aggregates on the gadget and the dashboard. There is no way to view only a specific NIC. For disks, the tray LEDs can also be shown per drive (3.3.0)
- **Per-drive tray LEDs** (3.3.0): fixed drives and removable drives such as USB are supported. Optical drives cannot be chosen because Windows reports no activity for them. Network drives and drives mapped with `subst` do not appear in the list. On Windows 11, new tray icons may go into the "hidden icons" area — pin them if needed
- Virtual-adapter filtering is heuristic; LED behavior may vary by environment
- High DPI: since 3.1.0 the process is **Per-Monitor V2**. The gadget's display scale uses 0.5 steps, so it may not match the OS percentage (**125% looks like 150%**). Skin bitmaps can look a bit soft when enlarged. The dashboard follows real DPI. If a dashboard size saved by an earlier build is too large, resize it once
- Motion is roughly **10–20 fps** (default 15). To reduce load, the window is not redrawn while the visible frames stay the same
- The list of real NICs is refreshed every few seconds. After a VPN connect/disconnect, LEDs may lag or linger briefly
- The dashboard CPU subsection does **not** show advanced information such as temperature. User-mode Windows APIs do not provide CPU information reliably
- Since 3.3.0, the dashboard RAM bar’s Standby segment is Windows’ standby list (Task Manager’s “Cached” is this plus the modified pages)
- **SWAP** is page file usage since 3.3.0 (3.2.0 and earlier showed the commit charge). Where performance counters are unavailable, the dashboard and tooltip show —; the gadget’s digit readout stays at 0
- **CPU usage and clock** use Task Manager’s basis since 3.3.0: usage is processor utility, which accounts for clock speed (it rises with turbo), and the clock is the actual running clock
- The dashboard’s **uptime** (3.3.0) is the time since Windows started, the same as Task Manager’s Up time. With Fast Startup enabled, shutting down and powering on does not reset it (a restart does). The **totals** for disk and network count since Windows started and can go back when a network adapter is disconnected and reconnected
- On the dashboard’s **Processes** page (3.3.0), details such as user name and path are not available for system processes or processes running as administrator. I/O counts all reads and writes to files, the network and devices, so it does not match Task Manager’s Disk column
- Dashboard colors follow Windows app light/dark mode. The gadget display modes (Original / Crystal / Metalic / Info Bar / Vintage) stay skin-based and do not follow OS light/dark. Since 3.3.0 the Options dialog always uses the standard Windows look and does not follow light/dark
- **GPU usage** (3.2.0, sharing the dashboard's CPU card): on multi-GPU systems, shows the busiest GPU's usage. Falls back to 0 on systems without a GPU counter (older Windows, RDP sessions, etc.)
- The app reads **L / R peaks** (0–1) of the mix sent to the playback device, locally, and also keeps a mono equivalent (max of all metering channels). It does not keep or send waveforms or recordings. Horizontal L / R bars (left to right) and the default playback device name (local display only) appear on the right card of the dashboard power subsection. Peaks are 0 when another app has exclusive mode. With no playback device, peaks are 0 and the name is —
- **Task tray** (3.1.1; reworked in 3.2.0 into a 3-way "Window Only / Window + Tray LED / Tray LED Only" choice): storing the icon in the notification area's "hidden icons" tray also hides the tray LED blinking (a Windows limitation) — we recommend pinning it (by your own action) somewhere always visible. The tray icon's position and order (main area vs. overflow) is managed by the Windows shell; DiskLED has no control over it
- **Ping / Route** page (3.3.0): measures only while the page is showing, sending three ICMP probes to each hop. Segment delays are estimates from each hop's replies. Routers along the way may answer late; that part is drawn as a gray dashed line
- **Network operator names** (Ping / Route page, off by default): when on, the IP address of each global-address hop on the route is looked up through Windows DNS at Team Cymru's DNS service (`origin.asn.cymru.com`, `origin6.asn.cymru.com`, `asn.cymru.com`). LAN and CGNAT addresses are not sent. Nothing is sent while it is off. Routers at operator boundaries or exchange points may show the neighboring operator's name
- **Microsoft Store edition** (3.1.1): Does not check GitHub for updates at startup (updates arrive automatically via the Store). Do not also install the GitHub installer or portable zip — having both can cause duplicate running instances and conflicting `DiskLED.ini` settings. If switching from the GitHub edition to the Store edition, uninstall the GitHub edition first (or delete the portable folder) before installing the Store edition. "Run at Windows startup" works correctly via Windows' startup task mechanism starting in 3.1.2 (in 3.1.1 and earlier, turning it on did not actually register the app). If it has been disabled from outside the app, Options shows that state

## Changes from DiskLED 2.x

| Topic | 2.x | 3.x (this series) |
|-------|-----|-------------------|
| Target OS | 95–XP era, etc. | Windows 10 / 11 |
| Skins | User `.dla` packs, etc. | Bundled modes only (`layout.cfg`). Since 3.2.0, the bundled browser tool "Asset Editor" lets you author your own display modes in the same format (see [SKIN_GUIDE.md](SKIN_GUIDE.md)) |
| History graphs | sam2 full, etc. | Full view on Original / Metalic (double-click). Crystal stays compact-only; Info Bar and Vintage have a full view but no history graph |
| Sound | Yes | Right card of the dashboard power subsection (horizontal L / R and output name). Gadget meters via `layout.cfg` `Audio` / `AudioL` / `AudioR` (bundled Info Bar uses L / R) |
| Floating | Yes | **Not supported** |
| SSTP | Yes | **Not supported** |
| Multiple instances | Sometimes allowed | **Single instance only** |
| Language | Resource-dependent | **OS UI–driven by default (English; Japanese only when OS UI is Japanese). Since 3.2.0, can also be fixed to Auto / Japanese / English from Options (takes effect on next launch)** |

## What we do not do

- No ads; no silently installing other software
- No collection/sending of personal data as a product purpose
- The only regular outbound traffic is **Ping** (target and on/off in Options) and **one GitHub Releases Latest lookup at startup** (new-version check; can be turned off). No personal data is sent besides the app version in the User-Agent
- The dashboard's **Ping / Route** page sends ICMP along the route to the Ping target only while it is showing. Global IP addresses on the route are looked up at an external DNS service only when **network operator names** are turned on (see Operational notes above)
- No microphone. No audio data other than the playback-mix L / R / mono-equivalent peak numbers
