# Making Your Own Skin

[日本語](../SKIN_GUIDE.md)

A guide to creating and customizing DiskLED's look (a "display mode", or "skin"). Editing is done with the bundled browser tool **Asset Editor**.

## 1. What a skin is

- One `assets/<id>/` folder corresponds to one display mode (e.g. Original, Crystal)
- Each folder contains a `layout.cfg` (settings file) and its image files
- Any subfolder of `assets/` that has a `layout.cfg` is automatically picked up as a display mode at startup — no rebuild needed
- **Compact and Full displays are completely independent.** Nothing is inherited between them (more on this below)

## 2. Opening Asset Editor

1. Double-click `asset-editor/index.html` (it opens in your browser — it looks a bit nicer with an internet connection, but works fine without one)
2. Click **Load asset folder…** and pick the folder of the skin you want to edit — the folder that directly contains its `layout.cfg`. You can also **drag and drop** that folder onto the page instead
3. Picking a parent folder (like `assets/` itself) won't load anything — pick the **one asset's own folder**
4. To start a brand-new skin from scratch, create an empty folder and put a minimal `layout.cfg` in it first (see the template in section 3), then load it

Asset Editor works the same whether the folder is inside this repository or anywhere else on your computer (My Documents, a USB drive, ...).

## 3. A minimal `layout.cfg`

```ini
[General]
Id=myskin
Caption=My Skin

[GeneralCompact]
Width=200
Height=32
Transparent=1
MaskColor=#FF00FF
Bg=MyBase.png
```

`Width`, `Height`, and `Bg` are all required for a valid skin. Put the image named in `Bg` in the same folder.

## 4. The screen layout

| Area | Contents |
|---|---|
| Header | Load a folder, switch the editor's own display language (EN/JA) |
| Preview (top) | The actual look. Compact/Full toggle, display scale (x1/x2/x5) |
| Sections (left) | Every part this skin could use. Ones already in use show normally; unused ones show dimmed with a checkbox |
| Field editor (center) | Edit the selected section's contents as a GUI form. Hover any field for an explanation |
| layout.cfg (right) | The raw text editor (with syntax coloring), always in sync with the GUI. **Copy** copies the whole text; **Save** writes it out |
| Test values & diagnostics (bottom) | Manually set CPU/memory/etc. values to see the preview react, and self-check layout.cfg's consistency |

Changing a value in the GUI rewrites only that line in the text; editing the text directly re-parses after a short pause and updates the GUI and preview. Either direction works.

## 5. Basic workflow

1. Prepare your skin's images (background, meter sprite sheets, ...) and put them in a folder
2. Load that folder in Asset Editor
3. Under **General**, set `Id` and `Caption`
4. Under **Compact > Mode** (`GeneralCompact`), set `Width`, `Height`, `Transparent`, `MaskColor`, and `Bg`. After setting `Bg`, click **Auto-fit to background image** to fill Width/Height from the image's actual pixel size
5. Check the parts you want to use (e.g. `Cpu`) to enable them, then set `File` (image), `X`/`Y` (position), `Frames` (frame count), and so on
6. Use the Test values sliders/LEDs at the bottom to sweep through values and check the preview
7. To also add a Full display, check **Full > Mode** (`GeneralFull`) and set it up the same way (Full becomes active once `Width`/`Height`/`Bg` are all set)
8. Click **Save** to write `layout.cfg`. In a browser that supports it, you can pick the save location directly; otherwise (the common case when opened via `file://`) the file downloads and you move it into the original folder yourself
9. Place the finished folder under DiskLED's `assets/` folder and pick it from the right-click menu's display mode list to check it for real

## 6. Compact and Full are independent

**Nothing is inherited between Compact and Full.** Every setting except the tray is split into its own section per mode.

| Section | Contents | Present? |
|---|---|---|
| `General` | Mode-wide info (Id, Caption, ...) | Always one |
| `GeneralCompact` (Compact > Mode) | The Compact window definition (size, background, transparency) | Required |
| `GeneralFull` (Full > Mode) | The Full window definition. **Without this, the mode is Compact-only** | Optional |
| `GraphFull` (Full > Graph) | The history graph, Full only | Optional |
| Each part (`CpuCompact`/`CpuFull`, etc.) | Image, position, response behavior, digit readout | Independent per part, per Compact/Full |

- If only one of a pair exists, that part simply doesn't exist in the other mode (e.g. defining only `DiskIoMeterCompact` means it never shows in Full)
- To show the same part in both displays, **write both sections with the same content** (in Asset Editor, check and edit each one separately — they're distinct sections)

## 7. Transparency (color keying)

| Target | Where | What it does |
|---|---|---|
| The whole window's outline | `Transparent`/`MaskColor` in `GeneralCompact`/`GeneralFull` | Pixels of that exact color become transparent for the whole window, showing the desktop through. `Transparent=0` gives a plain rectangular window |
| Each part (meters, LEDs, Ping, digit readout) | That part's own `Transparent`/`MaskColor` | Only that part's own image is color-keyed, independent of the window's own transparency |

Asset Editor's preview shows the window's transparent area as a checkerboard pattern.

## 8. Kinds of parts

Parts come in `<name>Compact`/`<name>Full` pairs (e.g. `CpuCompact`/`CpuFull`). The section list groups them under "Meters" and "LEDs & Ping".

**Meter-kind parts** (need `File`/`X`/`Y`/`Frames`/`Transparent`/`MaskColor`, plus `Kind`/`Strength` are required):
`Cpu` `Mem` `Swap` `DiskReadMeter` `DiskWriteMeter` `DiskIoMeter` `NetInMeter` `NetOutMeter` `NetIoMeter` `Audio` `AudioL` `AudioR`

**LED/Ping-kind parts** (just `File`/`X`/`Y`/`Frames`/`Transparent`/`MaskColor`):
`Ping` `DiskRead` `DiskWrite` `DiskRW` `NetIn` `NetOut` `NetActivity` `NetTotal`

- `DiskRW` lights up on either disk read or write activity
- `NetTotal` lights up on either network in or out activity (same condition as `NetActivity`)
- `DiskIoMeter`/`NetIoMeter` are combined meters showing whichever of read/write (or in/out) is larger
- `Ping` needs 4 frames (Timeout → Slow → Fair → Normal, in that order)
- Images are expected as a vertical strip (low value at the top, high value at the bottom)

## 9. Meter response (Ballistic)

Meter-kind parts state how they respond to a changing value via `Kind` and `Strength` (0-100) — both required.

| Kind | Typical use | Rise | Fall |
|---|---|---|---|
| `vu` | A needle meter with many frames | Exponential, fairly fast | About 0.8s full-scale |
| `bar` | A coarse LED bar | Exponential, moderate | About 0.5s full-scale |
| `peak` | Spike (instantaneous peak) display | Exponential, fastest | About 1.3s full-scale |

Note that Asset Editor's own preview maps the value straight to a frame and doesn't reproduce this response animation itself — set `Kind`/`Strength` as a guide for how it will actually look in the real app.

## 10. Digit readout (percentage overlay)

Only the `Cpu`/`Mem`/`Swap` parts can also show their usage as a number, overlaid on the part. Enable it with `ValSW=1` in the same section.

- **bitmap** (default): each part specifies its own font sheet image (11 frames across: 0-9 and a blank). There's no shared mode-wide font
- **system**: draws with an OS font (name, size, color, bold)

## 11. History graph (Full only)

`GraphFull` (Full > Graph) draws CPU/memory/disk/network trends, Full display only. Each lane's position and size is given as `X,Y,W,H`, plus its own color. Choose line (`line`) or bar (`bar`) style. Asset Editor's preview lets you watch a lane actually scroll by moving the Test values sliders.

## 12. Reading warnings and errors

Asset Editor flags mistakes as you go.

| What you see | What it means | What to do |
|---|---|---|
| A red-outlined input | The file named in `File`/`Bg` wasn't found in the loaded folder | Check the spelling, or add the image to the folder |
| A yellow warning box (unknown key) | A key in that section isn't one the GUI recognizes (possibly a typo) | Check the key name. If it's intentional, it's kept as-is and doesn't block anything |
| A red warning box (duplicate key) | The same key appears more than once in that section | Remove the extra line in the text editor on the right |
| The error box on the right | layout.cfg itself can't be parsed (a missing required field, a malformed number or color, ...) | The message names the file/section/key/value. GUI editing is disabled until it's fixed, but the text pane stays editable |

## 13. If something isn't working

- **Check all fields** in "Test values & diagnostics" round-trips every section and field currently loaded, to confirm the text/GUI sync is behaving correctly across the board
- To undo a change you're trying out, either edit the text back by hand, or reload the page before saving (unsaved changes are discarded)
- If something isn't showing up, first check whether that part's section is actually checked (Active) in the tree
