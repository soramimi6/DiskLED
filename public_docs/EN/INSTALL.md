# Install and distribution

[日本語](../INSTALL.md)

## Requirements

| Item | Requirement |
|------|-------------|
| OS | Windows 10 / Windows 11 (64-bit) |
| Privileges | Standard user (no administrator required) |
| Display | Per-Monitor V2. The gadget uses 0.5-step scale (125% looks like 150%). The dashboard follows real DPI. Options use VCL Scaled |
| Network | ICMP echo must work for Ping; firewall blocks appear as timeout |

## Distribution forms

| Use | Form | Example file |
|-----|------|--------------|
| Portals / general release | **Installer** (primary) | `DiskLED_Setup_3.1.0.exe` |
| Advanced / trial | **Portable zip** | `DiskLED-3.1.0-portable.zip` |

No adware or bundled third-party software.

## Installer (recommended)

### Install

1. Run `DiskLED_Setup_3.1.0.exe` (no administrator rights required)
2. Default install location is `%LocalAppData%\Programs\DiskLED`
3. A Start menu entry is always created
4. **Desktop shortcut** and **start when I log on** are optional wizard tasks (**both default off**)
5. Optionally leave “Launch DiskLED” checked at the end
6. User documentation is installed in the `public_docs` folder (Japanese plus `EN`)

### Uninstall

1. Open Windows Settings → Apps → Installed apps (or Apps & features) and select **DiskLED**
2. Choose Uninstall

Uninstall does **not** delete `DiskLED.ini` (next to the exe, or under `%AppData%\DiskLED\`). Delete it manually if you want a clean slate. A Run-key startup entry created by the installer (if you opted in) is removed by the uninstaller.

## Portable zip

1. Extract `DiskLED-3.1.0-portable.zip` to any folder
2. Run `DiskLED.exe` from that folder (keep bundled `assets`, `styles`, `LICENSE.txt`, and `public_docs`)
3. To remove, quit DiskLED and delete the folder (including any local `DiskLED.ini`)

## Packaging (developers)

Delphi Community Edition cannot compile from the command line. Build **Win64 / Release** in the IDE first so `Win64\Release\DiskLED.exe` exists. Canonical user docs live at repo-root `public_docs\` (copied into `dist\DiskLED\public_docs\` when staging).

| Step | Command (from repo root) |
|------|--------------------------|
| Stage only (`dist\DiskLED\`) | `.\tools\stage-dist.ps1` |
| Portable zip | `.\tools\make-portable.ps1` |
| Installer (needs [Inno Setup 6](https://jrsoftware.org/isinfo.php)) | `.\tools\make-installer.ps1` |

Use `-Config Debug` only if you lack a Release build (Release is preferred for distribution).
