#!/usr/bin/env python3
"""Genereert de herkleurbare personage-spritesheets.

Huid, haar en shirt zijn sleutelkleuren die de game runtime vervangt, zodat
alle collega's uit een handvol sheets komen. Per uiterlijk-variant (baard,
bril, krullen, lang haar, hoodie, overhemd) is er een eigen sheet.

Layout: 5 kolommen (idle + 4 loopframes) x 4 rijen (down, up, left, right)
Frame  : 16 x 24, voeten op de onderrand.
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw

FW, FH = 16, 24
COLS, ROWS = 5, 4
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))

SKIN    = (255, 0, 0, 255);   SKIN_S  = (170, 0, 0, 255)
HAIR    = (0, 255, 0, 255);   HAIR_S  = (0, 170, 0, 255)
SHIRT   = (0, 0, 255, 255);   SHIRT_S = (0, 0, 170, 255)
OUT_C   = (26, 24, 32, 255)
PANTS   = (52, 56, 78, 255)
SHOES   = (30, 28, 36, 255)
EYE     = (28, 26, 34, 255)
GLASS   = (38, 36, 44, 255)
LENS    = (196, 214, 228, 255)

VARIANTS = {
    "plain":   set(),
    "beard":   {"beard"},
    "glasses": {"glasses"},
    "curly":   {"beard", "curly"},
    "long":    {"long"},
    "hoodie":  {"hoodie"},
    "buttons": {"buttons"},
}


def clothing(d, feat, direction, bob):
    """Kledingdetails over de romp heen. Alleen sleutelkleuren en de omlijning,
    zodat de runtime-herkleuring blijft werken."""
    if "hoodie" in feat:
        # kap ligt in de nek: dikke kraag over de schouders, plus de bult ernaast
        d.rectangle([4, 10 + bob, 11, 11 + bob], fill=SHIRT_S)
        d.point((4, 9 + bob), fill=SHIRT_S)
        d.point((11, 9 + bob), fill=SHIRT_S)
        if direction == 1:      # van achteren zie je de kap zelf, geen koord
            d.rectangle([5, 12 + bob, 10, 12 + bob], fill=SHIRT_S)
            return
        # koordjes en buikzak; opzij zie je maar een koordje
        cords = [6, 9] if direction == 0 else [6 if direction == 2 else 9]
        for cx in cords:
            d.rectangle([cx, 12 + bob, cx, 13 + bob], fill=OUT_C)
        d.rectangle([6, 15 + bob, 9, 15 + bob], fill=SHIRT_S)
    elif "buttons" in feat:
        if direction == 0:      # knopenlijst recht van voren
            d.rectangle([8, 11 + bob, 8, 15 + bob], fill=SHIRT_S)
            d.point((7, 11 + bob), fill=SHIRT_S)
            d.point((9, 11 + bob), fill=SHIRT_S)
            d.point((8, 12 + bob), fill=OUT_C)
            d.point((8, 14 + bob), fill=OUT_C)
        elif direction == 1:    # van achteren: kraag en pasnaad
            d.rectangle([6, 11 + bob, 9, 11 + bob], fill=SHIRT_S)
            d.rectangle([5, 13 + bob, 10, 13 + bob], fill=SHIRT_S)
        else:                   # zijaanzicht: lijst langs de voorkant
            bx = 6 if direction == 2 else 9
            d.rectangle([bx, 11 + bob, bx, 15 + bob], fill=SHIRT_S)
            d.point((bx, 13 + bob), fill=OUT_C)


def frame(direction, step, feat):
    img = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bob = 1 if step in (2, 4) else 0
    top = 2 + bob

    # benen
    if step == 2:      legs = [(5, -1), (10, 1)]
    elif step == 4:    legs = [(7, 1), (8, -1)]
    else:              legs = [(6, 0), (9, 0)]
    for (lx, off) in legs:
        d.rectangle([lx, 17 + bob, lx + 1, 21 + bob + off], fill=PANTS)
        d.rectangle([lx, 21 + bob + off, lx + 1, 22 + bob + off], fill=SHOES)

    # romp
    d.rectangle([4, 10 + bob, 11, 17 + bob], fill=SHIRT)
    d.rectangle([4, 16 + bob, 11, 17 + bob], fill=SHIRT_S)
    d.rectangle([4, 10 + bob, 11, 17 + bob], outline=OUT_C)

    # armen
    swing = {0: 0, 1: 0, 2: 1, 3: 0, 4: -1}[step]
    d.rectangle([3, 11 + bob + swing, 3, 15 + bob + swing], fill=SHIRT_S)
    d.rectangle([12, 11 + bob - swing, 12, 15 + bob - swing], fill=SHIRT_S)
    d.point((3, 16 + bob + swing), fill=SKIN)
    d.point((12, 16 + bob - swing), fill=SKIN)

    # hoofd
    d.rectangle([5, top, 10, top + 7], fill=SKIN)
    d.rectangle([5, top + 6, 10, top + 7], fill=SKIN_S)
    d.rectangle([5, top, 10, top + 7], outline=OUT_C)
    d.rectangle([4, top + 8, 11, top + 8], fill=SKIN_S)

    curly = "curly" in feat
    long_hair = "long" in feat

    if direction == 0:      # naar de speler toe
        d.rectangle([5, top, 10, top + 2], fill=HAIR)
        d.rectangle([4, top + 1, 4, top + 4], fill=HAIR_S)
        d.rectangle([11, top + 1, 11, top + 4], fill=HAIR_S)
        if curly:
            for (x, y) in [(4, top - 1), (6, top - 1), (9, top - 1), (11, top - 1),
                           (3, top + 2), (12, top + 2)]:
                d.point((x, y), fill=HAIR)
        if long_hair:
            d.rectangle([3, top + 1, 3, top + 8], fill=HAIR_S)
            d.rectangle([12, top + 1, 12, top + 8], fill=HAIR_S)
        d.point((6, top + 4), fill=EYE)
        d.point((9, top + 4), fill=EYE)
        if "beard" in feat:
            d.rectangle([5, top + 6, 10, top + 7], fill=HAIR_S)
            d.point((6, top + 5), fill=HAIR_S)
            d.point((9, top + 5), fill=HAIR_S)
        if "glasses" in feat:
            d.rectangle([5, top + 3, 7, top + 5], outline=GLASS, fill=LENS)
            d.rectangle([8, top + 3, 10, top + 5], outline=GLASS, fill=LENS)
            d.point((6, top + 4), fill=EYE)
            d.point((9, top + 4), fill=EYE)
    elif direction == 1:    # van de speler af
        d.rectangle([5, top, 10, top + 5], fill=HAIR)
        d.rectangle([4, top + 1, 4, top + 5], fill=HAIR_S)
        d.rectangle([11, top + 1, 11, top + 5], fill=HAIR_S)
        if curly:
            for (x, y) in [(4, top - 1), (6, top - 1), (9, top - 1), (11, top - 1)]:
                d.point((x, y), fill=HAIR)
        if long_hair:
            d.rectangle([4, top + 1, 11, top + 9], fill=HAIR_S)
    else:                   # zijaanzicht
        d.rectangle([5, top, 10, top + 2], fill=HAIR)
        if direction == 2:
            d.rectangle([9, top + 1, 11, top + 5], fill=HAIR_S)
            eye_x = 6
        else:
            d.rectangle([4, top + 1, 6, top + 5], fill=HAIR_S)
            eye_x = 9
        if curly:
            for (x, y) in [(5, top - 1), (8, top - 1), (11, top - 1)]:
                d.point((x, y), fill=HAIR)
        if long_hair:
            d.rectangle([4, top + 1, 11, top + 8], fill=HAIR_S)
            d.rectangle([5, top, 10, top + 1], fill=HAIR)
        d.point((eye_x, top + 4), fill=EYE)
        if "beard" in feat:
            d.rectangle([5, top + 6, 10, top + 7], fill=HAIR_S)
        if "glasses" in feat:
            d.rectangle([eye_x - 1, top + 3, eye_x + 1, top + 5], outline=GLASS, fill=LENS)
            d.point((eye_x, top + 4), fill=EYE)

    clothing(d, feat, direction, bob)
    return img


def main():
    out_dir = os.path.join(ROOT, "assets", "sprites", "characters")
    os.makedirs(out_dir, exist_ok=True)
    for vname, feat in VARIANTS.items():
        sheet = Image.new("RGBA", (FW * COLS, FH * ROWS), (0, 0, 0, 0))
        for r in range(ROWS):
            for c in range(COLS):
                sheet.paste(frame(r, c, feat), (c * FW, r * FH))
        p = os.path.join(out_dir, f"person_{vname}.png")
        sheet.save(p)
        print(f"person_{vname}.png  {sheet.width}x{sheet.height}")
    old = os.path.join(out_dir, "person_template.png")
    if os.path.exists(old):
        os.remove(old)
        for ext in (".import",):
            if os.path.exists(old + ext):
                os.remove(old + ext)
        print("oud person_template.png verwijderd")


if __name__ == "__main__":
    main()
