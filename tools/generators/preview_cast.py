#!/usr/bin/env python3
"""Zet de hele cast naast elkaar, gelezen uit data/. Ontwerptekening, geen test.

Repliceert de laagcompositie en herkleuring van scripts/entities/character_sprites.gd
zodat je de silhouetten kunt beoordelen zonder de game te starten.
"""
import json, os, sys
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
D = os.path.join(ROOT, "assets", "sprites", "characters")
FW, FH = 18, 34
VOLGORDE = ["hair_back", "body", "outfit", "hair", "facial", "accessory", "bezigheid"]
MET_ACHTERHAAR = {"lang", "staart", "knot"}
SLEUTELS = {  # (basis, schaduw) -> veld
    ((255, 0, 0), (170, 0, 0)): "skin",
    ((0, 255, 0), (0, 170, 0)): "hair",
    ((0, 0, 255), (0, 0, 170)): "shirt",
    ((255, 0, 255), (170, 0, 170)): "pants",
    ((0, 255, 255), (0, 170, 170)): "accent",
}
DONKERDER = {"skin": 0.28, "hair": 0.25, "shirt": 0.30, "pants": 0.30, "accent": 0.30}


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def herkleur(img, kl):
    kaart = {}
    for (basis, schaduw), veld in SLEUTELS.items():
        c = kl[veld]
        kaart[basis] = c
        kaart[schaduw] = tuple(int(v * (1.0 - DONKERDER[veld])) for v in c)
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in kaart:
                px[x, y] = kaart[(r, g, b)] + (a,)
    return img


def compose(look, kl, col=0, rij=0):
    uit = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    for slot in VOLGORDE:
        variant = look.get("hair" if slot == "hair_back" else slot, "")
        if slot == "hair_back" and variant not in MET_ACHTERHAAR:
            continue
        if not variant:
            continue
        pad = os.path.join(D, "%s_%s.png" % (slot, variant))
        if not os.path.exists(pad):
            continue
        sheet = Image.open(pad).convert("RGBA")
        uit.alpha_composite(sheet.crop((col * FW, rij * FH, (col + 1) * FW, (rij + 1) * FH)))
    return herkleur(uit, kl)


def cast():
    uit = []
    zien = set()
    for pad in ("data/characters.json", "data/npcs.json"):
        for r in json.load(open(os.path.join(ROOT, pad))):
            basis = r["id"][4:] if r["id"].startswith("npc_") else r["id"]
            if basis in zien or "look" not in r:
                continue
            zien.add(basis)
            uit.append((basis, r["look"], dict(
                skin=hexc(r["skin"]), hair=hexc(r["hair"]), shirt=hexc(r["color"]),
                pants=hexc(r.get("pants", "#34384e")), accent=hexc(r.get("accent", "#f4a259")))))
    return uit


def main():
    # zonder argument de idle-rij; met "bezig" de vier bezigheidsframes
    bezig = len(sys.argv) > 1 and sys.argv[1] == "bezig"
    kolommen = [8, 9, 10, 11] if bezig else [int(sys.argv[1]) if len(sys.argv) > 1 else 0]
    mensen = cast()
    schaal = 6
    blad = Image.new("RGBA", (FW * len(mensen), FH * len(kolommen)), (30, 30, 36, 255))
    for i, (naam, look, kl) in enumerate(mensen):
        for j, col in enumerate(kolommen):
            f = compose(look, kl, col)
            blad.paste(f, (i * FW, j * FH), f)
    uit = os.path.join(ROOT, "qa", "cast_preview.png")
    blad.resize((blad.width * schaal, blad.height * schaal), Image.NEAREST).save(uit)
    print(" ".join(n for n, _, _ in mensen))
    print("->", uit)


if __name__ == "__main__":
    main()
