#!/usr/bin/env python3
"""Maakt pixel-art portretten van de echte teamfoto's in assets/personen/.

Het gezicht wordt uitgesneden, verkleind naar 32x40 en teruggebracht tot een
beperkt palet, zodat het bij de rest van de pixel-art past.
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageEnhance

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "personen")
OUT = os.path.join(ROOT, "assets", "sprites", "portraits")
W, H = 32, 40
COLORS = 24


def make(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    side = int(min(w, h) * 0.86)
    left = (w - side) // 2
    top = int(h * 0.02)
    im = im.crop((left, top, left + side, min(h, top + int(side * H / W))))
    im = im.resize((W, H), Image.LANCZOS)
    im = ImageEnhance.Color(im).enhance(1.25)
    im = ImageEnhance.Contrast(im).enhance(1.15)
    return im.quantize(colors=COLORS, method=Image.MEDIANCUT).convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for f in sorted(os.listdir(SRC)):
        if not f.endswith(".png"):
            continue
        name = os.path.splitext(f)[0]
        make(os.path.join(SRC, f)).save(os.path.join(OUT, f"{name}.png"))
        made.append(name)
    print(f"portretten ({W}x{H}, {COLORS} kleuren):", ", ".join(made))
    sheet = Image.new("RGB", (W * len(made), H), (20, 20, 26))
    for i, n in enumerate(made):
        sheet.paste(Image.open(os.path.join(OUT, f"{n}.png")), (i * W, 0))
    sheet.resize((W * len(made) * 5, H * 5), Image.NEAREST).save("/tmp/portretten.png")


if __name__ == "__main__":
    main()
