#!/usr/bin/env python3
"""Losse sprites die niet in de tileset passen.

Twee soorten:
- minigame-art (paardenkoppen, gat, logo)
- **meubelcomposieten**: één PNG per samengesteld object, op vrije pixelmaat.
  De tegel eronder doet de collision en de footprint; deze sprite doet het
  beeld. Zo leest een bureau-eiland als één ontworpen ding in plaats van als
  zestien keer dezelfde tegel. Maat = footprint uit gen_floor.py x 16 px.
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw
from palette import rgba

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "sprites", "props")
S = 32


def horse(bug: bool):
    """Paardenkop van voren. De bug-variant is groen en glitcht."""
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body = "groen" if bug else "hout"
    dark = "groen_donker" if bug else "hout_donker"
    light = "cyaan" if bug else "hout_licht"

    # hals
    d.polygon([(11, 31), (21, 31), (20, 20), (12, 20)], fill=rgba(dark))
    # kop
    d.rounded_rectangle([9, 8, 23, 24], radius=4, fill=rgba(body))
    # snuit
    d.rounded_rectangle([11, 18, 21, 26], radius=3, fill=rgba(light))
    d.point((14, 23), fill=rgba("inkt"))
    d.point((18, 23), fill=rgba("inkt"))
    # oren
    d.polygon([(9, 9), (7, 3), (12, 7)], fill=rgba(body))
    d.polygon([(23, 9), (25, 3), (20, 7)], fill=rgba(body))
    # manen
    d.line([(16, 4), (16, 12)], fill=rgba(dark), width=2)
    # ogen
    if bug:
        for (x, y) in [(12, 13), (20, 13)]:
            d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=rgba("rood"))
        # glitchbalken
        d.line([(6, 15), (26, 15)], fill=rgba("cyaan", 190))
        d.line([(4, 21), (28, 21)], fill=rgba("paars", 160))
    else:
        d.rectangle([11, 12, 13, 14], fill=rgba("inkt"))
        d.rectangle([19, 12, 21, 14], fill=rgba("inkt"))
        d.point((12, 12), fill=rgba("wit"))
        d.point((20, 12), fill=rgba("wit"))
    d.rounded_rectangle([9, 8, 23, 24], radius=4, outline=rgba("inkt"))
    return img


def hole():
    img = Image.new("RGBA", (S, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, S - 2, 10], fill=rgba("zwart", 200), outline=rgba("inkt"))
    d.ellipse([3, 3, S - 4, 8], fill=rgba("schaduw", 120))
    return img


def logo():
    """Bluebird-vogeltje voor het titelscherm en de hintvogel."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([3, 5, 12, 12], fill=rgba("bluebird"))
    d.polygon([(12, 8), (15, 6), (14, 10)], fill=rgba("bluebird_donker"))
    d.polygon([(3, 8), (0, 7), (2, 11)], fill=rgba("bluebird_licht"))
    d.polygon([(9, 3), (12, 6), (7, 6)], fill=rgba("bluebird_licht"))
    d.point((10, 7), fill=rgba("wit"))
    d.polygon([(5, 12), (7, 15), (3, 14)], fill=rgba("geel"))
    return img


T = 16   # tegelgrootte, moet gelijk zijn aan gen_floor.TILE


def _canvas(tw, th):
    img = Image.new("RGBA", (tw * T, th * T), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def _stoel(d, cx, cy, naar_boven):
    """Bureaustoel van boven: donkere kuip, bruine armleuning, chromen voet."""
    d.ellipse([cx - 5, cy - 4, cx + 5, cy + 5], fill=rgba("inkt"), outline=rgba("zwart"))
    rug_y = cy - 5 if naar_boven else cy + 4
    d.rectangle([cx - 5, rug_y, cx + 5, rug_y + 2], fill=rgba("zwart"))
    d.point((cx - 6, cy), fill=rgba("hout"))
    d.point((cx + 6, cy), fill=rgba("hout"))
    d.point((cx, cy + 1), fill=rgba("lichtgrijs"))


def _monitor(d, x, y, w=9, h=7):
    d.rectangle([x, y, x + w, y + h], fill=rgba("zwart"), outline=rgba("inkt"))
    d.rectangle([x + 1, y + 1, x + w - 1, y + h - 2], fill=rgba("schaduw"))
    d.line([(x + w // 2, y + h + 1), (x + w // 2, y + h + 2)], fill=rgba("inkt"))
    d.line([(x + w // 2 - 2, y + h + 2), (x + w // 2 + 2, y + h + 2)], fill=rgba("inkt"))


def bureau_eiland(tw, th=2):
    """Twee rijen werkplekken rug-aan-rug met een donker privacyscherm door het
    midden — dat scherm is wat het eiland als één object laat lezen. Zie
    assets/nieuwe assets/werkplek bureau.jpeg."""
    img, d = _canvas(tw, th)
    W, H = img.width, img.height
    mid = H // 2

    # bladen: wit, met een grijze rand die als metalen frame leest
    d.rectangle([0, 5, W - 1, mid - 3], fill=rgba("wit_kast"), outline=rgba("lichtgrijs"))
    d.rectangle([0, mid + 2, W - 1, H - 6], fill=rgba("wit_kast"), outline=rgba("lichtgrijs"))
    # privacyscherm
    d.rectangle([0, mid - 2, W - 1, mid + 1], fill=rgba("inkt"))
    d.line([(0, mid - 2), (W - 1, mid - 2)], fill=rgba("schaduw"))

    # per werkplek van 2 tegels: monitorpaar + stoel, boven en onder
    for i, x in enumerate(range(1, W - 20, 2 * T)):
        _monitor(d, x + 3, mid - 12)
        _monitor(d, x + 15, mid - 12)
        _stoel(d, x + 12, 5, True)
        _monitor(d, x + 3, mid + 4)
        _monitor(d, x + 15, mid + 4)
        _stoel(d, x + 12, H - 6, False)
        if i % 3 == 1:      # af en toe een laptopstandaard, zoals op de foto
            d.rectangle([x + 26, mid - 9, x + 32, mid - 5], fill=rgba("lichtgrijs"))
            d.rectangle([x + 27, mid - 12, x + 31, mid - 9], fill=rgba("grijs"))
        if i == 0:          # de rode pet aan het scherm
            d.rectangle([x + 8, mid - 1, x + 12, mid + 1], fill=rgba("rood"))
    return img


def bureau_eiland_v(th, tw=4):
    """Bureau-eiland een kwartslag gedraaid: twee kolommen werkplekken rug-aan-rug
    met een verticaal privacyscherm ertussen, zoals de blokken in schets idee.jpeg.

    De sprite is 2 tegels breder dan de footprint: de stoelen staan buiten het
    blok, op beloopbare vloer. main.gd centreert de sprite op de footprint.
    """
    img, d = _canvas(tw + 2, th)
    W, H = img.width, img.height
    mid = W // 2                       # verticale hartlijn = midden footprint
    links, rechts = T, W - T           # footprintranden

    # twee bladen, wit met grijs frame
    d.rectangle([links, 0, mid - 3, H - 1], fill=rgba("wit_kast"), outline=rgba("lichtgrijs"))
    d.rectangle([mid + 2, 0, rechts - 1, H - 1], fill=rgba("wit_kast"), outline=rgba("lichtgrijs"))
    # privacyscherm door het midden
    d.rectangle([mid - 2, 0, mid + 1, H - 1], fill=rgba("inkt"))
    d.line([(mid - 2, 0), (mid - 2, H - 1)], fill=rgba("schaduw"))

    # per werkplek van 2 tegels: monitor tegen het scherm, stoel buiten het blok
    for i, y in enumerate(range(2, H - 8, 2 * T)):
        _monitor(d, mid - 13, y + 4)
        _stoel(d, links // 2 + 1, y + 12, True)
        _monitor(d, mid + 4, y + 4)
        _stoel(d, W - links // 2 - 2, y + 12, True)
        if i % 2 == 1:                 # af en toe een laptopstandaard
            d.rectangle([links + 2, y + 20, links + 8, y + 24], fill=rgba("lichtgrijs"))
        if i == 0:                     # de rode pet aan het scherm
            d.rectangle([mid - 1, y + 2, mid + 1, y + 6], fill=rgba("rood"))
    return img


def plantenkast_v(th, tw=3):
    """Wit open rek als roomdivider, met klimop die eroverheen valt."""
    img, d = _canvas(tw, th)
    W, H = img.width, img.height
    d.rectangle([2, 0, W - 3, H - 1], fill=rgba("wit_kast"), outline=rgba("lichtgrijs"))
    for y in range(0, H, 2 * T):       # schappen
        d.line([(2, y), (W - 3, y)], fill=rgba("lichtgrijs"))
    for y in range(4, H - 4, 9):       # klimop, wisselend links en rechts
        x = 4 if (y // 9) % 2 == 0 else W - 7
        d.ellipse([x, y, x + 3, y + 3], fill=rgba("klimop"))
        d.line([(x + 1, y), (x + 1, y + 7)], fill=rgba("klimop_donker"))
    d.ellipse([W // 2 - 4, H // 3, W // 2 + 4, H // 3 + 8], fill=rgba("blad"))
    return img


def tafel_lang(tw, th=2):
    """De lange tafel met planten in de gang: één blad, geen rij losse tafels."""
    img, d = _canvas(tw, th)
    W, H = img.width, img.height
    d.rectangle([0, 4, W - 1, H - 5], fill=rgba("wit_kast"), outline=rgba("lichtgrijs"))
    d.line([(0, 6), (W - 1, 6)], fill=rgba("wit"))
    for x in range(T, W - T, 5 * T):     # planten erop, niet ernaast
        d.ellipse([x, 8, x + 11, 19], fill=rgba("blad"))
        d.ellipse([x + 2, 10, x + 8, 16], fill=rgba("blad_donker"))
        d.rectangle([x + 4, 19, x + 8, 22], fill=rgba("pot"))
    for x in range(T, W - T, 2 * T):     # stoelen langs beide zijden
        _stoel(d, x, 4, True)
        _stoel(d, x + T, H - 5, False)
    return img


def tribune(tw=10, th=2):
    """Teal traptrede-bank met kussens, de Jura en de DIA-awards. Eén trap, geen
    rij losse bankjes. Zie assets/nieuwe assets/koffiecorner.jpeg."""
    img, d = _canvas(tw, th + 1)
    W, H = img.width, img.height
    d.rectangle([0, T, W - 1, H - 1], fill=rgba("teal"), outline=rgba("teal_licht"))
    d.rectangle([0, 4, W - 1, T + 2], fill=rgba("teal_licht"), outline=rgba("teal"))
    d.line([(0, T + 2), (W - 1, T + 2)], fill=rgba("teal"))
    for i, (x, c) in enumerate([(6, "lichtgrijs"), (26, "wit"), (46, "bluebird_licht"),
                                (66, "rood"), (86, "geel"), (106, "lichtgrijs")]):
        if x + 12 > W:
            break
        d.rectangle([x, T + 5, x + 12, H - 3], fill=rgba(c), outline=rgba("schaduw"))
    d.rectangle([2, 2, 12, T + 1], fill=rgba("zwart"))          # de Jura
    d.point((7, 6), fill=rgba("rood"))
    for x in range(W - 40, W - 8, 10):                           # DIA-awards
        d.rectangle([x, 5, x + 5, T], fill=rgba("glas", 200), outline=rgba("wit"))
    return img


def keukenblok(tw=5, th=1):
    """Keukenblok met kraan en twee spoelbakken, als één aanrecht."""
    img, d = _canvas(tw, th + 1)
    W, H = img.width, img.height
    d.rectangle([0, 6, W - 1, H - 1], fill=rgba("lichtgrijs"), outline=rgba("grijs"))
    d.rectangle([0, 4, W - 1, 9], fill=rgba("beton"), outline=rgba("grijs"))
    for x in (T + 4, 3 * T + 4):
        d.rectangle([x, 6, x + 9, 8], fill=rgba("schaduw"), outline=rgba("grijs"))
        d.line([(x + 4, 3), (x + 4, 6)], fill=rgba("lichtgrijs"))
    for x in range(6, W - 6, T):                                 # deurtjes
        d.line([(x, 10), (x, H - 2)], fill=rgba("grijs"))
    return img


def balie(tw=5, th=1):
    """Receptiebalie: één blad met een bb-blue front."""
    img, d = _canvas(tw, th + 1)
    W, H = img.width, img.height
    d.rectangle([0, 8, W - 1, H - 1], fill=rgba("bluebird_donker"), outline=rgba("inkt"))
    d.rectangle([0, 4, W - 1, 10], fill=rgba("wit_kast"), outline=rgba("lichtgrijs"))
    d.rectangle([3, 12, W - 4, H - 3], fill=rgba("bluebird"))
    d.rectangle([W - 22, 1, W - 8, 6], fill=rgba("zwart"))       # monitor op de balie
    return img


def serverrack(tw=2, th=4):
    """Eén rack in plaats van acht identieke tegels: doorlopende ledkolommen."""
    img, d = _canvas(tw, th)
    W, H = img.width, img.height
    d.rectangle([1, 0, W - 2, H - 1], fill=rgba("inkt"), outline=rgba("zwart"))
    for y in range(3, H - 2, 5):
        d.line([(4, y), (W - 5, y)], fill=rgba("schaduw"))
        d.point((W - 6, y), fill=rgba("rood") if (y // 5) % 3 else rgba("groen"))
    d.line([(W // 2, 1), (W // 2, H - 2)], fill=rgba("zwart"))
    return img


def monitorwand(tw, th=1):
    """Eén dashboardwand in plaats van vier identieke tv's."""
    img, d = _canvas(tw, th)
    W, H = img.width, img.height
    d.rectangle([0, 0, W - 1, H - 1], fill=rgba("muur"))
    d.rectangle([1, 1, W - 2, H - 3], fill=rgba("zwart"), outline=rgba("inkt"))
    # één doorlopende grafiek over de hele wand: dat maakt het één object
    punten = [(2, H - 5), (W // 5, 5), (2 * W // 5, H - 7), (3 * W // 5, 3),
              (4 * W // 5, H - 6), (W - 3, 4)]
    d.line(punten, fill=rgba("groen"), width=1)
    for i in range(1, tw):               # dunne naden tussen de panelen
        d.line([(i * T, 2), (i * T, H - 4)], fill=rgba("schaduw"))
    d.line([(0, H - 2), (W - 1, H - 2)], fill=rgba("plint"))
    return img


def schaduw_karakter():
    """Contactschaduw onder een personage. Zonder dit zweeft elke sprite los
    boven de vloer. Hard begrensd met een half-transparante rand: een echte
    gradient valt op deze schaal uit elkaar in banden."""
    img = Image.new("RGBA", (14, 6), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, 13, 5], fill=(0, 0, 0, 40))
    d.ellipse([2, 1, 11, 4], fill=(0, 0, 0, 72))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    items = {"paard_bug.png": horse(True), "paard_klant.png": horse(False),
             "gat.png": hole(), "vogel.png": logo(),
             "schaduw_karakter.png": schaduw_karakter()}
    # meubelcomposieten: naam moet exact matchen met PROPS uit gen_floor.py
    # gedraaide eilanden: 4 tegels breed, hoogte bepaalt het aantal werkplekken
    for th in (4, 8):
        items["bureau_4x%d.png" % th] = bureau_eiland_v(th)
    for th in (6, 8):
        items["plantenkast_3x%d.png" % th] = plantenkast_v(th)
    items["tafel_lang_26x2.png"] = tafel_lang(26)
    items["monitorwand_4x1.png"] = monitorwand(4)
    items["tribune_10x2.png"] = tribune(10)
    items["keukenblok_5x1.png"] = keukenblok(5)
    items["balie_5x1.png"] = balie(5)
    items["serverrack_2x4.png"] = serverrack(2, 4)
    for name, img in items.items():
        img.save(os.path.join(OUT, name))
        print(f"{name:18s} {img.width}x{img.height}")


if __name__ == "__main__":
    main()
