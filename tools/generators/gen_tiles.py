#!/usr/bin/env python3
"""Genereert de tileset-atlas voor de kantoorvloer.

Elke legenda-letter uit data/floor.json krijgt één 16x16 tegel.
Output: assets/tilesets/office_atlas.png + office_atlas.json (char -> atlas-coord).
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw
from palette import P, rgba

T = 16
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))

# volgorde bepaalt de atlas-kolom
CHARS = (list(".D#=VNXBPTbtcKfxSAWmpo") + list("EOLGI") + list("H")
         + list("uRnljYJqsr") + list("C") + list("kwz") + list("_")
         + list("F") + list("123") + list(",;"))

# Vloervarianten. Ze staan niet in de legenda en dus niet in het grid: het is
# geen plattegrondinformatie maar korrel, en drie extra tekens door 2400
# gridtegels strooien maakt floor.json onleesbaar voor de enige lezer die telt —
# een mens die de plattegrond nakijkt. `world_builder` kiest ze deterministisch
# per tegel bij het vullen van de Ground-laag.
FLOOR_VARIANTEN = ".,;"


def tile():
    return Image.new("RGBA", (T, T), (0, 0, 0, 0))


def noise(d, col, pts):
    for (x, y) in pts:
        d.point((x, y), fill=col)


# Drie korrelpatronen. Eén vast patroon over de hele vloer geeft een zichtbaar
# raster zodra je twee tegels naast elkaar ziet — precies wat een betonvloer
# niet doet.
KORREL = [
    ([(2, 3), (9, 1), (13, 6), (5, 11), (11, 13), (1, 8), (7, 7)],
     [(4, 5), (12, 2), (6, 14), (14, 10)]),
    ([(6, 2), (1, 5), (10, 4), (14, 9), (3, 13), (8, 10), (12, 15)],
     [(2, 9), (7, 4), (11, 8), (5, 1)]),
    ([(4, 1), (12, 5), (2, 12), (7, 14), (15, 3), (9, 9), (6, 6)],
     [(1, 2), (9, 12), (13, 13), (3, 7)]),
]


def draw_floor(d, light=False, variant=0):
    """Gepolijst beton. Koel grijs met een fijne korrel — zie de referentiefoto's;
    het warme tapijt van de verzonnen vloer bestaat in dit kantoor niet."""
    base = "beton_licht" if light else "beton_vloer"
    d.rectangle([0, 0, T - 1, T - 1], fill=rgba(base))
    donker, licht = KORREL[variant % len(KORREL)]
    noise(d, rgba("beton_donker"), donker)
    noise(d, rgba("beton_licht" if not light else "wit"), licht)


def draw_raamlicht(d, stap):
    """De zuidband vangt daglicht: drie stops die naar het noorden uitdoven.

    De helderheid zit in de hele tegel en de overgang in een dithering langs de
    bovenrand. Een echte gradient bínnen een tegel van 16 px leest niet als
    licht maar als een streep dwars door de vloer.
    """
    draw_floor(d, variant=stap)
    if stap == 2:
        # de uitdoving: alleen nog gestrooide lichtpixels, geen vlak
        for y in range(2, T, 2):
            for x in range((y // 2) % 3, T, 3):
                d.point((x, y), fill=rgba("beton_raam_zacht"))
        return
    kleur = rgba("beton_raam") if stap == 0 else rgba("beton_raam_zacht")
    d.rectangle([0, 2, T - 1, T - 1], fill=kleur)
    for x in range(0, T, 2):          # dithering langs de bovenrand
        d.point((x, 1), fill=kleur)
    for x in range(1, T, 4):
        d.point((x, 0), fill=kleur)
    if stap == 0:
        noise(d, rgba("wit", 110), [(3, 12), (11, 9), (14, 14), (6, 5)])


def draw_wall(d, face=False):
    """Een muur is drie banden: een donkere kap, de bovenkant, en — waar er
    vloer onder ligt — de face met een lichtere voet. Zonder die voet is een
    gesloten ruimte een streep in plaats van een ruimte."""
    d.rectangle([0, 0, T - 1, T - 1], fill=rgba("muur"))
    d.rectangle([0, 0, T - 1, 2], fill=rgba("muur_kap"))
    d.rectangle([0, 3, T - 1, 5], fill=rgba("muur_top"))
    d.line([(0, 6), (T - 1, 6)], fill=rgba("plint"))
    if face:
        d.rectangle([0, T - 3, T - 1, T - 2], fill=rgba("muur_voet"))
    d.line([(0, T - 1), (T - 1, T - 1)], fill=rgba("plint"))


def draw_glass(d):
    d.rectangle([0, 0, T - 1, T - 1], fill=rgba("glas", 90))
    d.rectangle([0, 0, T - 1, T - 1], outline=rgba("glas_rand", 210))
    d.line([(3, T - 1), (T - 1, 3)], fill=rgba("wit", 70))


def furn(d, body, top=None, knobs=None, shadow=True):
    """Generiek meubelstuk: vloer eronder, blok erop, schaduw."""
    draw_floor(d)
    if shadow:
        d.rectangle([1, 12, T - 1, T - 1], fill=rgba("tapijt_donker"))
    d.rectangle([1, 3, T - 2, 13], fill=rgba(body))
    d.rectangle([1, 3, T - 2, 5], fill=rgba(top or body))
    d.rectangle([1, 3, T - 2, 13], outline=rgba("inkt", 160))
    for k in (knobs or []):
        d.point(k, fill=rgba("inkt"))


def build(ch):
    img = tile()
    d = ImageDraw.Draw(img)
    if ch == ".":
        draw_floor(d)
    elif ch == "D":
        draw_floor(d, light=True)
        d.line([(0, 0), (0, T - 1)], fill=rgba("plint", 120))
        d.line([(T - 1, 0), (T - 1, T - 1)], fill=rgba("plint", 120))
    elif ch == "#":
        draw_wall(d)
    elif ch == "F":  # muur met vloer eronder: je kijkt tegen de face aan
        draw_wall(d, face=True)
    elif ch in "123":  # raamlicht: 1 tegen de raamzijde, 3 de uitdoving
        draw_raamlicht(d, int(ch) - 1)
    elif ch in ",;":  # vloervarianten, alleen voor de Ground-laag
        draw_floor(d, variant=FLOOR_VARIANTEN.index(ch))
    elif ch == "=":
        draw_glass(d)
    elif ch == "V":  # voordeur
        draw_wall(d)
        d.rectangle([2, 2, T - 3, T - 2], fill=rgba("bluebird_donker"))
        d.rectangle([3, 4, T - 4, 10], fill=rgba("glas", 150))
        d.point((T - 5, 12), fill=rgba("geel"))
    elif ch == "N":  # nooduitgang, op slot
        draw_wall(d)
        d.rectangle([2, 3, T - 3, T - 2], fill=rgba("groen_donker"))
        d.line([(2, 7), (T - 3, 10)], fill=rgba("geel"))
        d.line([(2, 10), (T - 3, 7)], fill=rgba("geel"))
    elif ch == "X":  # trappenhuis achter de ingang — decor, niet te betreden
        # Geen eigen kunststijl: dit is dezelfde muur als overal (`draw_wall`),
        # met een glazen pui erin waar je tegen de traptreden aan kijkt. De kap
        # van de onderste tegel leest daarbij als het bordes tussen twee steken,
        # dus twee van deze tegels op elkaar geven een trap en geen twee losse
        # hokjes.
        draw_wall(d)
        d.rectangle([1, 3, T - 2, T - 2], fill=rgba("schaduw"))
        for y in range(4, T - 2, 4):
            d.line([(2, y), (T - 3, y)], fill=rgba("lichtgrijs"))
            d.line([(2, y + 1), (T - 3, y + 1)], fill=rgba("grijs"))
        d.line([(T - 4, 3), (T - 4, T - 2)], fill=rgba("bluebird_licht"))  # leuning
        d.rectangle([1, 3, T - 2, T - 2], outline=rgba("glas_rand", 200))
        d.line([(1, 3), (T - 2, 3)], fill=rgba("glas", 120))
    elif ch == "B":  # receptiebalie
        furn(d, "hout", "hout_licht")
        d.rectangle([2, 1, T - 3, 3], fill=rgba("bluebird"))
    elif ch == "P":  # printer
        furn(d, "lichtgrijs", "wit", knobs=[(4, 8), (6, 8)])
        d.rectangle([3, 9, T - 4, 11], fill=rgba("wit"))
    elif ch == "T":  # ticketbord
        draw_wall(d)
        d.rectangle([1, 2, T - 2, T - 3], fill=rgba("wit"))
        for (x, y, c) in [(3, 4, "geel"), (7, 4, "oranje"), (11, 4, "cyaan"),
                          (3, 8, "rood"), (7, 8, "geel"), (11, 8, "groen")]:
            d.rectangle([x, y, x + 2, y + 2], fill=rgba(c))
    elif ch == "b":  # bureau
        furn(d, "bureaublad", "wit")
        d.rectangle([4, 4, 11, 9], fill=rgba("inkt"))
        d.rectangle([5, 5, 10, 8], fill=rgba("bluebird_licht"))
    elif ch == "t":  # tafel — wit blad, zoals de grote tafels in de foto's
        furn(d, "wit_kast", "wit")
    elif ch == "c":  # bank
        furn(d, "bluebird_donker", "bluebird")
    elif ch == "K":  # keukenblok
        furn(d, "lichtgrijs", "beton", knobs=[(4, 9), (8, 9), (12, 9)])
    elif ch == "f":  # koelkast
        furn(d, "wit", "lichtgrijs")
        d.line([(T - 5, 6), (T - 5, 10)], fill=rgba("grijs"))
    elif ch == "x":  # whiteboard
        draw_wall(d)
        d.rectangle([1, 2, T - 2, T - 4], fill=rgba("wit"))
        d.line([(3, 5), (11, 5)], fill=rgba("rood"))
        d.line([(3, 8), (9, 8)], fill=rgba("bluebird"))
        d.line([(3, 11), (12, 11)], fill=rgba("groen"))
    elif ch == "S":  # serverrack
        draw_floor(d)
        d.rectangle([1, 0, T - 2, T - 1], fill=rgba("inkt"))
        d.rectangle([1, 0, T - 2, T - 1], outline=rgba("zwart"))
        for y in range(2, 15, 3):
            d.line([(3, y), (T - 4, y)], fill=rgba("schaduw"))
            d.point((T - 4, y), fill=rgba("rood"))
    elif ch == "A":  # archiefkast
        furn(d, "grijs", "lichtgrijs")
        for y in (5, 8, 11):
            d.line([(3, y), (T - 4, y)], fill=rgba("inkt", 150))
    elif ch == "W":  # wc / wastafel
        furn(d, "wit", "wit")
        d.ellipse([4, 5, 11, 11], fill=rgba("lichtgrijs"), outline=rgba("grijs"))
    elif ch == "m":  # wandmonitor
        draw_wall(d)
        d.rectangle([1, 3, T - 2, 12], fill=rgba("zwart"))
        d.rectangle([2, 4, T - 3, 11], fill=rgba("bluebird_donker"))
        d.line([(3, 9), (6, 6)], fill=rgba("groen"))
        d.line([(6, 6), (9, 8)], fill=rgba("groen"))
        d.line([(9, 8), (12, 5)], fill=rgba("groen"))
    elif ch == "p":  # plant
        draw_floor(d)
        d.rectangle([5, 10, 10, T - 2], fill=rgba("pot"))
        d.ellipse([2, 2, 13, 11], fill=rgba("blad"))
        d.ellipse([4, 4, 9, 8], fill=rgba("blad_donker"))
    elif ch == "o":  # losse kast / doos
        furn(d, "hout_donker", "hout")
        d.line([(1, 8), (T - 2, 8)], fill=rgba("inkt", 120))
    # ---- kamerkleurzonering — vloervarianten, één BBD-accent per hoofdstuk ----
    # Gewoon draw_floor() met een dun accent-fleck erin (2 van 256 pixels):
    # tapijt/beton blijft dominant, het accent is een highlight, geen vlak.
    elif ch == "E":  # entree/receptie — bb-blue, hero-moment
        draw_floor(d)
        noise(d, rgba("bb_blue"), [(6, 6), (10, 9)])
    elif ch == "O":  # keuken — bb-orange
        draw_floor(d)
        noise(d, rgba("bb_orange"), [(6, 6), (10, 9)])
    elif ch == "L":  # vergaderruimte De Zwaluw — bb-light-blue
        draw_floor(d)
        noise(d, rgba("bb_light_blue"), [(6, 6), (10, 9)])
    elif ch == "G":  # Weekend — groen, dichter gestrooid dan elders: de jungle
        draw_floor(d)
        noise(d, rgba("bb_green"), [(6, 6), (10, 9), (2, 12), (13, 2), (8, 14)])
        noise(d, rgba("klimop"), [(3, 5), (11, 11), (14, 7)])
    elif ch == "I":  # belhokken — bb-pink
        draw_floor(d)
        noise(d, rgba("bb_pink"), [(6, 6), (10, 9)])
    elif ch == "H":  # prikbord — losse grappige mini-tickets + hart-accent
        draw_wall(d)
        d.rectangle([1, 2, T - 2, T - 3], fill=rgba("hout_licht"))
        for (x, y, c) in [(3, 4, "geel"), (7, 4, "wit"), (11, 4, "oranje"),
                          (4, 8, "rood"), (9, 8, "cyaan")]:
            d.rectangle([x, y, x + 2, y + 2], fill=rgba(c))
        d.point((12, 10), fill=rgba("bb_pink"))  # hart-sticker (accent, echte vorm volgt in Fase 1)
    # ---- het echte kantoor: props uit assets/nieuwe assets/ ----
    elif ch == "u":  # urinoir — tegen de wand, de toiletgag moet zichtbaar zijn
        draw_wall(d)
        d.rectangle([4, 4, 11, 12], fill=rgba("wit"))
        d.ellipse([5, 5, 10, 10], fill=rgba("lichtgrijs"), outline=rgba("grijs"))
        d.point((8, 3), fill=rgba("grijs"))
    elif ch == "R":  # tribune — teal traptrede-bank met kussens + Jura
        draw_floor(d)
        d.rectangle([0, 8, T - 1, T - 1], fill=rgba("teal"))
        d.rectangle([0, 3, T - 1, 8], fill=rgba("teal_licht"))
        d.line([(0, 8), (T - 1, 8)], fill=rgba("teal", 200))
        for (x, c) in [(2, "lichtgrijs"), (6, "wit"), (10, "bluebird_licht"), (13, "geel")]:
            d.rectangle([x, 4, x + 2, 7], fill=rgba(c))
    elif ch == "n":  # plantenkast — wit open rek met klimop erover
        draw_floor(d)
        d.rectangle([2, 9, T - 3, T - 2], fill=rgba("wit_kast"))
        d.rectangle([2, 2, T - 3, 9], fill=rgba("wit_kast", 120), outline=rgba("lichtgrijs"))
        for y in (5, 8):
            d.line([(3, y), (T - 4, y)], fill=rgba("lichtgrijs"))
        for (x, y) in [(4, 3), (5, 6), (4, 9), (6, 11), (11, 4), (12, 7), (10, 10)]:
            d.point((x, y), fill=rgba("klimop"))
        d.line([(4, 3), (4, 12)], fill=rgba("klimop_donker", 170))
        d.line([(11, 4), (11, 10)], fill=rgba("klimop", 150))
    elif ch == "l":  # houten lamellenwand
        d.rectangle([0, 0, T - 1, T - 1], fill=rgba("hout_donker"))
        for x in range(1, T, 3):
            d.line([(x, 0), (x, T - 1)], fill=rgba("hout_licht"))
            d.line([(x + 1, 0), (x + 1, T - 1)], fill=rgba("hout"))
    elif ch == "j":  # blauw gordijn als roomdivider
        d.rectangle([0, 0, T - 1, T - 1], fill=rgba("bluebird_donker"))
        for x in range(0, T, 4):
            d.line([(x, 0), (x, T - 1)], fill=rgba("bluebird"))
            d.line([(x + 2, 0), (x + 2, T - 1)], fill=rgba("marine"))
    elif ch == "Y":  # de blauwe tijger — landmark, geen gewone prop
        draw_floor(d)
        d.rectangle([1, 7, T - 2, 12], fill=rgba("bluebird"))
        d.rectangle([2, 5, 6, 8], fill=rgba("bluebird"))
        for x in (4, 7, 10, 13):
            d.line([(x, 7), (x, 11)], fill=rgba("bluebird_donker"))
        d.line([(2, 12), (2, T - 2)], fill=rgba("bluebird_donker"))
        d.line([(T - 3, 12), (T - 3, T - 2)], fill=rgba("bluebird_donker"))
        d.point((3, 6), fill=rgba("wit"))
    elif ch == "J":  # jungle — Weekend, dichte groene massa
        draw_floor(d)
        d.ellipse([0, 1, 10, 11], fill=rgba("blad"))
        d.ellipse([5, 4, T - 1, T - 2], fill=rgba("klimop"))
        d.ellipse([2, 6, 8, 12], fill=rgba("blad_donker"))
        d.ellipse([8, 2, 14, 8], fill=rgba("klimop_donker"))
        d.point((4, 4), fill=rgba("groen"))
        d.point((11, 10), fill=rgba("groen"))
    elif ch == "q":  # zwart-wit schaakbordvloerkleed onder de tafel in Summit
        draw_floor(d)
        for gx in range(0, 4):
            for gy in range(0, 4):
                col = "wit" if (gx + gy) % 2 == 0 else "inkt"
                d.rectangle([gx * 4, gy * 4, gx * 4 + 3, gy * 4 + 3], fill=rgba(col))
    elif ch == "s":  # witte kuipstoel
        draw_floor(d)
        d.ellipse([4, 5, 11, 13], fill=rgba("wit"), outline=rgba("lichtgrijs"))
        d.rectangle([4, 4, 11, 8], fill=rgba("wit_kast"), outline=rgba("lichtgrijs"))
        d.point((8, 13), fill=rgba("grijs"))
    elif ch == "r":  # ronde tafel — Basecamp
        draw_floor(d)
        d.ellipse([1, 2, T - 2, 13], fill=rgba("wit_kast"), outline=rgba("inkt", 160))
        d.ellipse([3, 4, T - 4, 11], fill=rgba("wit"))
    elif ch == "_":
        # Footprint van een samengesteld object: volledig transparant. De
        # Ground-laag eronder levert de vloer, de collision komt uit de
        # TileData-polygon (niet uit de pixels), en het beeld komt van de
        # sprite die main.gd erbovenop zet. Zou deze tegel vloer tekenen, dan
        # dekte hij die sprite af.
        pass
    elif ch == "C":  # koffiecorner-accent — teal fleck
        draw_floor(d)
        noise(d, rgba("teal"), [(6, 6), (10, 9)])
    # ---- de noordwand achter de koffiecorner, rood aangewezen op de schets ----
    elif ch == "k":  # donkerblauwe kastenwand met de bank ervoor
        draw_wall(d)
        d.rectangle([0, 2, T - 1, T - 4], fill=rgba("marine"))
        for x in range(1, T, 5):              # deurtjes, doorlopend over de wand
            d.line([(x, 3), (x, T - 6)], fill=rgba("inkt", 150))
        d.rectangle([0, T - 5, T - 1, T - 2], fill=rgba("bluebird_donker"))  # de bank
        d.line([(0, T - 5), (T - 1, T - 5)], fill=rgba("bluebird"))
        d.line([(0, T - 1), (T - 1, T - 1)], fill=rgba("plint"))
    elif ch == "w":  # het enige raam aan deze binnenzijde
        draw_wall(d)
        d.rectangle([0, 2, T - 1, T - 5], fill=rgba("glas", 200), outline=rgba("glas_rand"))
        d.line([(0, 4), (T - 1, 4)], fill=rgba("wit", 120))
        d.line([(T // 2, 2), (T // 2, T - 5)], fill=rgba("glas_rand"))   # roede
        d.rectangle([0, T - 4, T - 1, T - 2], fill=rgba("wit_kast"))     # vensterbank
        d.line([(0, T - 1), (T - 1, T - 1)], fill=rgba("plint"))
    elif ch == "z":  # de speaker van t07 — op statief, tegen de tribune aan
        draw_floor(d)
        d.rectangle([4, 1, 11, 11], fill=rgba("inkt"), outline=rgba("zwart"))
        d.ellipse([5, 2, 10, 7], fill=rgba("schaduw"), outline=rgba("grijs"))
        d.ellipse([6, 8, 9, 10], fill=rgba("schaduw"), outline=rgba("grijs"))
        d.line([(7, 12), (7, T - 2)], fill=rgba("grijs"))                # statief
        d.line([(4, T - 2), (11, T - 2)], fill=rgba("grijs"))
        d.point((10, 3), fill=rgba("rood"))                              # aan-lampje
    return img


def main():
    atlas = Image.new("RGBA", (T * len(CHARS), T), (0, 0, 0, 0))
    coords = {}
    for i, ch in enumerate(CHARS):
        atlas.paste(build(ch), (i * T, 0))
        coords[ch] = [i, 0]

    out_png = os.path.join(ROOT, "assets", "tilesets", "office_atlas.png")
    out_json = os.path.join(ROOT, "assets", "tilesets", "office_atlas.json")
    atlas.save(out_png)
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump({"tile_size": T, "coords": coords}, f, indent=1)
    print(f"atlas  : {out_png}  ({atlas.width}x{atlas.height}, {len(CHARS)} tegels)")
    print(f"mapping: {out_json}")


if __name__ == "__main__":
    main()
