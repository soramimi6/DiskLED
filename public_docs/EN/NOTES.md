# Notes and differences from 2.x

[日本語](../NOTES.md)

## Disclaimer

The author accepts no liability for any damage arising from use of this software. Use it at your own risk.

## Operational notes

- **Ping** sends ICMP to an external host (default `mg6.jp`) or the gateway. If security software or a firewall blocks ICMP, the UI stays on timeout (accepted as normal)
- **Disk / network** are aggregates. Per-drive or per-NIC views are not in v1
- Virtual-adapter filtering is heuristic; LED behavior may vary by environment
- High DPI (e.g. above 125%) may blur or mis-position the UI (v1 assumes 100%)
- Motion is roughly **10–20 fps** (default 15). The window is not redrawn while sprite frames stay the same
- The list of real NICs is refreshed every few seconds. After a VPN connect/disconnect, LEDs may lag or linger briefly

## Changes from DiskLED 2.x

| Topic | 2.x | 3.x (this series) |
|-------|-----|-------------------|
| Target OS | 95–XP era, etc. | Windows 10 / 11 |
| Skins | User `.dla` packs, etc. | Bundled modes only (`layout.cfg`) |
| History graphs | sam2 full, etc. | Full view on Original / Metalic (double-click). Crystal stays compact |
| Sound | Yes | **Not supported** |
| Floating | Yes | **Not supported** |
| SSTP | Yes | **Not supported** |
| Multiple instances | Sometimes allowed | **Single instance only** |
| Language | Resource-dependent | **OS UI–driven (English by default; Japanese only when OS UI is Japanese)** |

## What we do not do

- No ads; no silently installing other software
- No collection/sending of personal data as a product purpose
- No regular outbound traffic other than Ping (Ping target is designed to be configurable)
