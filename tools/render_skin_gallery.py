"""Render static sample images of every bundled DiskLED skin (compact and
full, where available) straight from the real assets/<id>/layout.cfg and PNG
files, mirroring asset-editor/js/renderer.js's compositing rules. Dev-only
tool (not part of the release payload -- see tools/stage-dist.ps1's copy
list). Re-run after any bundled skin's look or meter set changes, then
update public_docs/SKIN_GALLERY.md (JA+EN) if the description text needs
adjusting too.

Output: public_docs/images/skins/<id>-<mode>.png, 3x nearest-neighbor
upscaled for legibility, composited onto a light checkerboard so
transparent skins are distinguishable from opaque ones.
"""
import configparser
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
OUT = os.path.join(ROOT, "public_docs", "images", "skins")
os.makedirs(OUT, exist_ok=True)

DEMO_STATE = {
    "cpu": 0.5, "mem": 0.4, "swap": 0.2,
    "diskRead": 0.3, "diskWrite": 0.3,
    "netIn": 0.3, "netOut": 0.3,
    "audio": 0.4, "audioL": 0.4, "audioR": 0.4,
    "diskReadOn": True, "diskWriteOn": False,
    "netInOn": True, "netOutOn": False,
    "pingLevel": 3,
}
DEMO_STATE["diskIo"] = max(DEMO_STATE["diskRead"], DEMO_STATE["diskWrite"])
DEMO_STATE["netIo"] = max(DEMO_STATE["netIn"], DEMO_STATE["netOut"])
DEMO_STATE["diskRWOn"] = DEMO_STATE["diskReadOn"] or DEMO_STATE["diskWriteOn"]
DEMO_STATE["netActivityOn"] = DEMO_STATE["netInOn"] or DEMO_STATE["netOutOn"]

# part name -> state key (meters), or None for LED/ping parts handled separately
METER_PARTS = {
    "Cpu": "cpu", "Mem": "mem", "Swap": "swap",
    "DiskReadMeter": "diskRead", "DiskWriteMeter": "diskWrite",
    "NetInMeter": "netIn", "NetOutMeter": "netOut",
    "DiskIoMeter": "diskIo", "NetIoMeter": "netIo",
    "Audio": "audio", "AudioL": "audioL", "AudioR": "audioR",
}
LED_PARTS = {
    "DiskRead": "diskReadOn", "DiskWrite": "diskWriteOn",
    "NetIn": "netInOn", "NetOut": "netOutOn",
    "DiskRW": "diskRWOn", "NetActivity": "netActivityOn", "NetTotal": "netActivityOn",
}
ALL_PART_BASES = list(METER_PARTS) + list(LED_PARTS) + ["Ping"]


def load_ini(path):
    cp = configparser.ConfigParser()
    cp.optionxform = str
    cp.read(path, encoding="utf-8")
    return cp


def hexcolor(s):
    s = s.strip().lstrip("#")
    return tuple(int(s[i:i+2], 16) for i in (0, 2, 4))


def image_cache():
    cache = {}
    def get(folder, filename):
        key = (folder, filename.lower())
        if key not in cache:
            # case-insensitive file lookup
            actual = None
            for f in os.listdir(folder):
                if f.lower() == filename.lower():
                    actual = f
                    break
            if actual is None:
                cache[key] = None
            else:
                cache[key] = Image.open(os.path.join(folder, actual)).convert("RGBA")
        return cache[key]
    return get


def flag(section, key, default):
    """Mirrors uSkinLoader's ReadStrictBool: blank/absent reads as `default`;
    1/true/yes/on and 0/false/no/off are the accepted spellings."""
    v = (section.get(key) or "").strip().lower()
    if v in ("1", "true", "yes", "on"):
        return True
    if v in ("0", "false", "no", "off"):
        return False
    return default


def sprite_transparent(sprite):
    """A sprite with a MaskColor but no Transparent key is transparent
    (uSkinLoader: Transparent defaults to HasMask)."""
    has_mask = bool((sprite.get("MaskColor") or "").strip())
    return flag(sprite, "Transparent", has_mask) and has_mask


def keyed(img, mask_rgb):
    if mask_rgb is None:
        return img
    arr = img.copy()
    px = arr.load()
    w, h = arr.size
    mr, mg, mb = mask_rgb
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r == mr and g == mg and b == mb:
                px[x, y] = (r, g, b, 0)
    return arr


def draw_strip(canvas, get_img, folder, sprite, value):
    fname = sprite.get("File")
    if not fname:
        return
    frames = int(sprite.get("Frames", "0"))
    if frames <= 0:
        return
    img = get_img(folder, fname)
    if img is None:
        return
    fh = img.height // frames
    if fh <= 0:
        return
    f = round(max(0.0, min(1.0, value)) * (frames - 1))
    f = max(0, min(frames - 1, f))
    frame = img.crop((0, f * fh, img.width, (f + 1) * fh))
    if sprite_transparent(sprite):
        frame = keyed(frame, hexcolor(sprite["MaskColor"]))
    canvas.alpha_composite(frame, (int(sprite["X"]), int(sprite["Y"])))


def draw_ping(canvas, get_img, folder, sprite, level):
    fname = sprite.get("File")
    if not fname:
        return
    frames = int(sprite.get("Frames", "0"))
    img = get_img(folder, fname)
    if img is None or frames <= 0:
        return
    fh = img.height // frames
    level = max(0, min(frames - 1, level))
    frame = img.crop((0, level * fh, img.width, (level + 1) * fh))
    if sprite_transparent(sprite):
        frame = keyed(frame, hexcolor(sprite["MaskColor"]))
    canvas.alpha_composite(frame, (int(sprite["X"]), int(sprite["Y"])))


def render(skin_id, mode):
    folder = os.path.join(ASSETS, skin_id)
    cfg = load_ini(os.path.join(folder, "layout.cfg"))
    gen_sec = "General" + mode
    if not cfg.has_section(gen_sec):
        return None
    g = cfg[gen_sec]
    w, h = int(g["Width"]), int(g["Height"])
    get_img = image_cache()
    bg = get_img(folder, g["Bg"])
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    if bg is not None:
        canvas.alpha_composite(bg.convert("RGBA"), (0, 0))

    for base in ALL_PART_BASES:
        sec = base + mode
        if not cfg.has_section(sec):
            continue
        sprite = dict(cfg[sec])
        if base == "Ping":
            draw_ping(canvas, get_img, folder, sprite, DEMO_STATE["pingLevel"])
        elif base in METER_PARTS:
            draw_strip(canvas, get_img, folder, sprite, DEMO_STATE[METER_PARTS[base]])
        elif base in LED_PARTS:
            val = 1.0 if DEMO_STATE[LED_PARTS[base]] else 0.0
            draw_strip(canvas, get_img, folder, sprite, val)

    if flag(g, "Transparent", True) and g.get("MaskColor"):
        canvas = keyed(canvas, hexcolor(g["MaskColor"]))

    return canvas


def flatten_on_checker(img, cell=6):
    w, h = img.size
    bg = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    c1, c2 = (235, 235, 235, 255), (214, 214, 214, 255)
    px = bg.load()
    for y in range(h):
        for x in range(w):
            px[x, y] = c1 if ((x // cell) + (y // cell)) % 2 == 0 else c2
    bg.alpha_composite(img)
    return bg.convert("RGB")


SKINS = [
    ("original", ["Compact", "Full"]),
    ("crystal", ["Compact"]),
    ("metalic", ["Compact", "Full"]),
    ("infobar", ["Compact", "Full"]),
    ("vintage", ["Compact", "Full"]),
]

for skin_id, modes in SKINS:
    for mode in modes:
        img = render(skin_id, mode)
        if img is None:
            print(f"skip {skin_id} {mode} (no section)")
            continue
        flat = flatten_on_checker(img)
        out_path = os.path.join(OUT, f"{skin_id}-{mode.lower()}.png")
        # 3x nearest-neighbor upscale for legibility in docs
        big = flat.resize((flat.width * 3, flat.height * 3), Image.NEAREST)
        big.save(out_path)
        print("wrote", out_path, big.size)
