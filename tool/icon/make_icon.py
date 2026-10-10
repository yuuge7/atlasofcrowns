"""Draws the launcher icon: a brass crown over a globe's meridians, on baize.

    python tool/icon/make_icon.py

Writes, under android/app/src/main/res/mipmap-*/, ic_launcher.png (the whole
icon, for launchers before Android 8) and ic_launcher_foreground.png (the
artwork alone, which the adaptive icon lays over @color/atlas_baize).
"""
import math
import os

from PIL import Image, ImageDraw

BAIZE = (31, 61, 54)
BAIZE_DEEP = (20, 41, 36)
BRASS = (200, 162, 74)
BRASS_BRIGHT = (230, 200, 119)
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

S = 1024
art = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(art)

# Globe: one circle with meridians and parallels, like an atlas frontispiece.
cx, cy, r = S / 2, S * 0.54, S * 0.37
d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=BAIZE_DEEP, outline=BRASS, width=14)
for k in (0.36, 0.72):
    d.ellipse([cx - r * k, cy - r, cx + r * k, cy + r], outline=BRASS, width=7)
d.line([cx, cy - r, cx, cy + r], fill=BRASS, width=7)
for k in (-0.5, 0.0, 0.5):
    half = math.sqrt(1 - k * k) * r
    d.line([cx - half, cy + r * k, cx + half, cy + r * k], fill=BRASS, width=7)

# Crown: three points over a band, sitting across the globe.
w, top, base = S * 0.56, S * 0.30, S * 0.63
left, right = cx - w / 2, cx + w / 2
points = [
    (left, base), (left - S * 0.02, top + S * 0.07), (cx - w * 0.25, top + S * 0.17),
    (cx, top), (cx + w * 0.25, top + S * 0.17), (right + S * 0.02, top + S * 0.07), (right, base),
]
d.polygon(points, fill=BRASS_BRIGHT, outline=BAIZE_DEEP, width=12)
d.rectangle([left, base - S * 0.015, right, base + S * 0.085], fill=BRASS, outline=BAIZE_DEEP, width=12)
for px, py in (points[1], points[3], points[5]):
    d.ellipse([px - 30, py - 30, px + 30, py + 30], fill=BRASS_BRIGHT, outline=BAIZE_DEEP, width=10)

img = Image.new("RGBA", (S, S), BAIZE + (255,))
img.alpha_composite(art)

# The adaptive foreground is 108dp of which only the middle 66dp is always
# visible, so the artwork is shrunk into that safe zone.
inner = int(S * 0.62)
foreground = Image.new("RGBA", (S, S), (0, 0, 0, 0))
foreground.alpha_composite(art.resize((inner, inner), Image.LANCZOS), ((S - inner) // 2, (S - inner) // 2))

root = os.path.join(os.path.dirname(__file__), "..", "..", "android", "app", "src", "main", "res")
for name, size in SIZES.items():
    folder = os.path.join(root, f"mipmap-{name}")
    img.convert("RGB").resize((size, size), Image.LANCZOS).save(os.path.join(folder, "ic_launcher.png"))
    side = size * 108 // 48
    foreground.resize((side, side), Image.LANCZOS).save(os.path.join(folder, "ic_launcher_foreground.png"))
print("icon written")
