#!/usr/bin/env python3
"""Builds the app icon set from docs/icon/dockorate-icon.png.

The source artwork fills its whole canvas, so it is shrunk onto Apple's macOS
icon grid (an 824 pt body centred on 1024, with a soft drop shadow) to sit the
same size as other Dock icons. Needs Pillow: python3 -m pip install pillow
Run from anywhere: python3 scripts/make-icon.py
"""
import json, os
from PIL import Image, ImageFilter

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
src = Image.open(os.path.join(root, "docs/icon/dockorate-icon.png")).convert("RGBA")
out = os.path.join(root, "FallDock/Assets.xcassets/AppIcon.appiconset")

CANVAS, BODY = 1024, 824
body = src.resize((BODY, BODY), Image.LANCZOS)
off = (CANVAS - BODY) // 2

shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
alpha = body.getchannel("A").point(lambda a: a * 0.30)
shadow.paste((0, 0, 0, 255), (off, off + 12), alpha)
shadow = shadow.filter(ImageFilter.GaussianBlur(14))

icon = Image.alpha_composite(shadow, Image.new("RGBA", (CANVAS, CANVAS)))
icon.alpha_composite(body, (off, off))

with open(os.path.join(out, "Contents.json")) as f:
    images = json.load(f)["images"]
for entry in images:
    pt = int(entry["size"].split("x")[0])
    px = pt * int(entry["scale"].rstrip("x"))
    icon.resize((px, px), Image.LANCZOS).save(os.path.join(out, entry["filename"]))
print("Wrote", len(images), "icon sizes to", out)
