#!/usr/bin/env python3
"""Genereert de personage-spritesheets als losse, stapelbare lagen.

Waarom lagen en niet één sheet per uiterlijk-variant: met zeven vaste sheets
deelden zestien cast-entries hun silhouet. Zes gebruikten dezelfde 'plain', en
maar twee mensen hadden een vorm voor zichzelf. Identiteit hing volledig aan
drie hex-waarden, en op 16x24 met ogen van een pixel zie je dat niet.

Nu tekent elke laag alleen zijn eigen onderdeel. De runtime stapelt ze en
herkleurt daarna een keer. Zes lagen met 3 tot 8 varianten dragen duizenden
combinaties, dus elke collega kan een eigen vorm krijgen zonder dat er per
persoon een sheet bij komt.

Frame : 18 x 34. Het personage staat in een logisch vak van 16 x 32 met 1 px
        transparante marge rondom. Die marge is er voor de outline-shader:
        zonder ruimte naast de sprite valt de rand eraf.
Layout : 8 kolommen (idle, adem, knipper, loop 1-4, praat) x 4 rijen
        (down, up, left, right). Rechts is een spiegeling van links.
Kleuren: alleen sleutelkleuren en vaste tinten. De runtime vervangt de
        sleutels per personage.
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw

# --- kader -------------------------------------------------------------------
MARGE = 1
LW, LH = 16, 32                       # logisch vak
FW, FH = LW + MARGE * 2, LH + MARGE * 2
COLS, ROWS = 8, 4
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "sprites", "characters")

# --- sleutelkleuren ----------------------------------------------------------
# De runtime zoekt exact deze waarden op en vervangt ze. Vijf paren: elk paar is
# een basiskleur plus zijn schaduw, zodat de herkleuring zelf geen tint hoeft te
# verzinnen voor de donkere kant.
SKIN,   SKIN_S   = (255, 0, 0, 255),   (170, 0, 0, 255)
HAIR,   HAIR_S   = (0, 255, 0, 255),   (0, 170, 0, 255)
SHIRT,  SHIRT_S  = (0, 0, 255, 255),   (0, 0, 170, 255)
PANTS,  PANTS_S  = (255, 0, 255, 255), (170, 0, 170, 255)
ACCENT, ACCENT_S = (0, 255, 255, 255), (0, 170, 170, 255)

# --- vaste tinten (niet herkleurd) -------------------------------------------
OUT_C  = (26, 24, 32, 255)
EYE    = (28, 26, 34, 255)
WIT    = (238, 240, 244, 255)
SHOES  = (58, 54, 66, 255)
GLAS_R = (44, 42, 52, 255)
LENS   = (198, 216, 230, 255)

# --- anatomie, in logische coordinaten ---------------------------------------
# Kop 13 van de 32 px is ~41 procent. Stardew zit rond 34 procent; iets groter
# mag hier, want in portrait staat de speler dichter op het beeld.
# De kop is even breed als de romp: dat is de chibi-verhouding. Een kop die
# breder is dan de schouders leest als een bobblehead, niet als een mens.
KOP_TOP, KOP_BOT = 1, 12              # 12 van de 32 px is ~38 procent
KOP_L,  KOP_R    = 4, 11
OOG_Y            = 7                  # 2x2 ogen met oogwit, was 1x1
OOG_L,  OOG_R    = 5, 9
MOND_Y           = 10
NEK_TOP, NEK_BOT = 13, 14
ROMP_TOP, ROMP_BOT = 15, 22
ROMP_L,  ROMP_R    = 4, 11
ARM_L,   ARM_R     = 2, 12            # 2 px breed, sluit aan op de romp
HAND_Y             = 22
BEEN_TOP, BEEN_BOT = 23, 29
BEEN_A,  BEEN_B    = 5, 9             # linkerbeen x5-6, rechterbeen x9-10
SCHOEN_TOP         = 30

DIRS = ["down", "up", "left", "right"]


class Vel:
    """Tekenlaag met marge-correctie, zodat elke functie in logische
    coordinaten kan denken en de 1 px rand nergens hoeft mee te rekenen."""

    def __init__(self):
        self.img = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def rect(self, x0, y0, x1, y1, kleur):
        # volgorde-onafhankelijk: bij een gespiegelde pose loopt een strook soms
        # van rechts naar links, en Pillow weigert dat
        if x1 < x0:
            x0, x1 = x1, x0
        if y1 < y0:
            y0, y1 = y1, y0
        self.d.rectangle([x0 + MARGE, y0 + MARGE, x1 + MARGE, y1 + MARGE], fill=kleur)

    def px(self, x, y, kleur):
        self.d.point((x + MARGE, y + MARGE), fill=kleur)

    def omlijn(self, x0, y0, x1, y1, kleur):
        if x1 < x0:
            x0, x1 = x1, x0
        if y1 < y0:
            y0, y1 = y1, y0
        self.d.rectangle([x0 + MARGE, y0 + MARGE, x1 + MARGE, y1 + MARGE], outline=kleur)


def pose(col):
    """Wat er per kolom verandert. bob geldt voor alles boven de benen.

    `arm` is een paar (links, rechts) in plaats van één getal. Bij lopen zijn de
    twee elkaars tegengestelde, maar de bezigheid-animaties hebben er juist één
    arm omhoog voor nodig en dat kon met één waarde niet.
    """
    if col == 0:                        # idle
        return dict(bob=0, been=(0, 0), arm=(0, 0), knipper=False, mond=False)
    if col == 1:                        # ademen
        return dict(bob=-1, been=(0, 0), arm=(0, 0), knipper=False, mond=False)
    if col == 2:                        # knipperen
        return dict(bob=0, been=(0, 0), arm=(0, 0), knipper=True, mond=False)
    if col == 7:                        # praten
        return dict(bob=0, been=(0, 0), arm=(0, 0), knipper=False, mond=True)
    stap = col - 3                      # 0..3
    # passeerstand staat het hoogst, contactstand het laagst
    bob = -1 if stap in (0, 2) else 0
    been = [(0, 0), (-2, 2), (0, 0), (2, -2)][stap]
    zwaai = [0, 1, 0, -1][stap]
    return dict(bob=bob, been=been, arm=(zwaai, -zwaai), knipper=False, mond=False)


# =============================================================================
# 1. body — huid, kop, nek, armen, handen, blote benen, schoenen
# =============================================================================
BODIES = {
    "slank":     dict(romp=-1, arm=0),
    "gemiddeld": dict(romp=0,  arm=0),
    "stevig":    dict(romp=1,  arm=1),
}


def laag_body(v, richting, p, variant):
    b = BODIES[variant]
    bob = p["bob"]
    rl, rr = ROMP_L - b["romp"], ROMP_R + b["romp"]
    al, ar = ARM_L - b["arm"], ARM_R + b["arm"]
    # opzij zie je maar een schouder, dus daar is het silhouet smaller
    if richting in (2, 3):
        rl, rr = rl + 1, rr - 1
        al, ar = al + 1, ar - 1
    kl, kr = (KOP_L, KOP_R) if richting in (0, 1) else (KOP_L + 1, KOP_R)

    # benen en schoenen staan vast op de grond, die bobben niet mee
    for i, bx in enumerate((BEEN_A, BEEN_B)):
        off = p["been"][i]
        top = BEEN_TOP + max(0, off)
        v.rect(bx, top, bx + 1, BEEN_BOT, SKIN_S)
        v.rect(bx - 1, SCHOEN_TOP, bx + 2, SCHOEN_TOP + 1, SHOES)

    # armen: 2 px breed, zwaaien tegengesteld aan de benen
    for ax, zwaai in ((al, p["arm"][0]), (ar, p["arm"][1])):
        v.rect(ax, ROMP_TOP + bob + zwaai, ax + 1, HAND_Y - 1 + bob + zwaai, SKIN)
        v.rect(ax, HAND_Y + bob + zwaai, ax + 1, HAND_Y + bob + zwaai, SKIN_S)

    # romp als huid: de outfit tekent er overheen, maar een mouwloos shirt
    # moet schouders laten zien. Geen omlijning op de zijkanten: die zou de
    # armen als losse stokjes van de romp scheiden.
    v.rect(rl, ROMP_TOP + bob, rr, ROMP_BOT + bob, SKIN)
    v.rect(rl, ROMP_TOP + bob, rr, ROMP_TOP + bob, OUT_C)
    v.rect(al, ROMP_TOP + bob + p["arm"][0], al, HAND_Y + bob + p["arm"][0], OUT_C)
    v.rect(ar + 1, ROMP_TOP + bob + p["arm"][1], ar + 1, HAND_Y + bob + p["arm"][1], OUT_C)

    # nek
    v.rect(6, NEK_TOP + bob, 9, NEK_BOT + bob, SKIN_S)

    # kop
    v.rect(kl, KOP_TOP + bob, kr, KOP_BOT + bob, SKIN)
    v.rect(kl, KOP_BOT - 1 + bob, kr, KOP_BOT + bob, SKIN_S)
    v.omlijn(kl, KOP_TOP + bob, kr, KOP_BOT + bob, OUT_C)
    if richting in (2, 3):
        v.rect(kl - 1, OOG_Y + 1 + bob, kl - 1, OOG_Y + 2 + bob, SKIN)   # neus
        v.px(kl - 1, OOG_Y + 3 + bob, SKIN_S)
        v.px(kl - 2, OOG_Y + 2 + bob, OUT_C)

    if richting == 1:                   # van achteren: geen gezicht
        return

    if richting == 0:
        ogen = [OOG_L, OOG_R]
    else:
        # profiel: een oog, een pixel naar binnen. Precies op de rand van de
        # kop werd het een witte vlek in plaats van een oog.
        ogen = [kl + 1]
    for ox in ogen:
        y = OOG_Y + bob
        if p["knipper"]:
            v.rect(ox, y + 1, ox + 1, y + 1, SKIN_S)
        else:
            if richting == 0:
                v.rect(ox, y, ox + 1, y + 1, WIT)
                v.px(ox + 1, y + 1, EYE)
            else:
                v.px(ox, y, WIT)
                v.rect(ox, y + 1, ox + 1, y + 1, EYE)
        v.rect(ox, y - 2, ox + 1, y - 2, SKIN_S)  # wenkbrauw

    if p["mond"]:
        v.rect(7, MOND_Y + bob, 8, MOND_Y + 1 + bob, OUT_C)
    else:
        v.rect(7, MOND_Y + bob, 8, MOND_Y + bob, SKIN_S)


# =============================================================================
# 2. hair_back — haar dat achter de schouders valt
# =============================================================================
HAIR_BACK = ["lang", "staart", "knot"]


def laag_hair_back(v, richting, p, variant):
    bob = p["bob"]
    if variant == "lang":
        v.rect(KOP_L - 1, KOP_TOP + bob, KOP_R + 1, ROMP_TOP + 3 + bob, HAIR_S)
    elif variant == "staart":
        v.rect(KOP_L - 1, KOP_TOP + 1 + bob, KOP_R + 1, KOP_BOT + bob, HAIR_S)
        x = 7 if richting in (0, 1) else (KOP_R + 1)
        v.rect(x, KOP_BOT + bob, x + 1, ROMP_TOP + 4 + bob, HAIR_S)
    elif variant == "knot":
        v.rect(KOP_L - 1, KOP_TOP + 1 + bob, KOP_R + 1, KOP_BOT - 4 + bob, HAIR_S)
        v.rect(6, KOP_TOP - 3 + bob, 9, KOP_TOP - 1 + bob, HAIR_S)


# =============================================================================
# 3. outfit — romp, mouwen, kraag, broek
# =============================================================================
# mouw: 0 = geen (hemd), 1 = kort, 2 = lang
OUTFITS = {
    "tshirt":   dict(mouw=1, kraag=None,     broek="lang"),
    "polo":     dict(mouw=1, kraag="polo",   broek="lang"),
    "overhemd": dict(mouw=2, kraag="kraag",  broek="lang"),
    "hoodie":   dict(mouw=2, kraag="kap",    broek="lang"),
    "trui":     dict(mouw=2, kraag="rond",   broek="lang"),
    "blazer":   dict(mouw=2, kraag="revers", broek="lang"),
    "vest":     dict(mouw=0, kraag="rond",   broek="lang"),
    "blouse":   dict(mouw=2, kraag="kraag",  broek="rok"),
}


def laag_outfit(v, richting, p, variant):
    o = OUTFITS[variant]
    bob = p["bob"]

    # broek of rok over de blote benen heen
    if o["broek"] == "rok":
        v.rect(ROMP_L, ROMP_BOT + bob, ROMP_R, BEEN_TOP + 2, PANTS)
        v.rect(ROMP_L, BEEN_TOP + 2, ROMP_R, BEEN_TOP + 2, PANTS_S)
    else:
        for i, bx in enumerate((BEEN_A, BEEN_B)):
            off = p["been"][i]
            top = BEEN_TOP + max(0, off)
            v.rect(bx, top, bx + 1, BEEN_BOT - 1, PANTS)
            v.rect(bx, BEEN_BOT - 1, bx + 1, BEEN_BOT - 1, PANTS_S)
        v.rect(ROMP_L + 1, ROMP_BOT + bob, ROMP_R - 1, BEEN_TOP, PANTS)

    # romp
    v.rect(ROMP_L, ROMP_TOP + bob, ROMP_R, ROMP_BOT + bob, SHIRT)
    v.rect(ROMP_L, ROMP_BOT - 1 + bob, ROMP_R, ROMP_BOT + bob, SHIRT_S)
    v.omlijn(ROMP_L, ROMP_TOP + bob, ROMP_R, ROMP_BOT + bob, OUT_C)

    # mouwen over de armen
    if o["mouw"]:
        eind = (ROMP_TOP + 3) if o["mouw"] == 1 else (HAND_Y - 1)
        for ax, zwaai in ((ARM_L, p["arm"][0]), (ARM_R, p["arm"][1])):
            v.rect(ax, ROMP_TOP + bob + zwaai, ax + 1, eind + bob + zwaai, SHIRT)
            v.rect(ax, eind + bob + zwaai, ax + 1, eind + bob + zwaai, SHIRT_S)

    if richting == 1 and o["kraag"] != "kap":
        return                          # van achteren zie je de meeste kragen niet

    k = o["kraag"]
    y = ROMP_TOP + bob
    if k == "kraag":
        v.rect(5, y, 6, y + 1, WIT)
        v.rect(9, y, 10, y + 1, WIT)
        v.rect(7, y, 8, y, SHIRT_S)
    elif k == "polo":
        v.rect(6, y, 9, y, SHIRT_S)
        v.rect(7, y + 1, 8, y + 2, SHIRT_S)
    elif k == "rond":
        v.rect(6, y, 9, y, SHIRT_S)
    elif k == "revers":
        v.rect(5, y, 6, y + 3, SHIRT_S)
        v.rect(9, y, 10, y + 3, SHIRT_S)
        v.rect(7, y, 8, y + 4, ACCENT)          # overhemd eronder
    elif k == "kap":
        v.rect(ROMP_L, y - 1, ROMP_R, y + 1, SHIRT_S)
        if richting == 1:
            v.rect(5, y - 3, 10, y, SHIRT_S)    # de kap zelf, van achteren
        else:
            v.px(6, y + 2, OUT_C)               # koordjes
            v.px(9, y + 2, OUT_C)
            v.rect(6, ROMP_BOT - 3 + bob, 9, ROMP_BOT - 2 + bob, SHIRT_S)


# =============================================================================
# 4. hair — kruin, pony, zijkanten
# =============================================================================
HAIRS = ["kaal", "kort", "stekels", "zijscheiding", "krullen", "lang",
         "staart", "dunnend", "knot"]


def laag_hair(v, richting, p, variant):
    bob = p["bob"]
    top = KOP_TOP + bob
    vol = 2 if variant in ("krullen", "lang", "knot") else 1

    if variant == "kaal":
        # Geen haar, wel een glans op de schedel: zonder dat leest een kale kop
        # als een vlak vlekje in plaats van als een hoofd.
        v.rect(KOP_L + 1, top, KOP_L + 3, top, SKIN)
        v.px(KOP_L + 1, top + 1, SKIN)
        return

    # De kruin begint op de schedel zelf, niet erboven: anders zweeft het haar
    # als een plank los van het hoofd. Alleen het volume steekt 1 px uit.
    diepte = 5 if richting == 1 else 2
    if variant == "dunnend":
        v.rect(KOP_L + 1, top, KOP_R - 1, top + diepte - 1, HAIR)
        v.rect(KOP_L, top + 1, KOP_L, top + 2, HAIR_S)
        v.rect(KOP_R, top + 1, KOP_R, top + 2, HAIR_S)
    else:
        v.rect(KOP_L, top, KOP_R, top + diepte, HAIR)
        v.rect(KOP_L + 1, top - 1, KOP_R - 1, top - 1, HAIR)
        v.rect(KOP_L - 1, top + 1, KOP_L - 1, top + 4, HAIR_S)
        v.rect(KOP_R + 1, top + 1, KOP_R + 1, top + 4, HAIR_S)

    if variant == "stekels":
        for x in (KOP_L, KOP_L + 3, KOP_R - 2, KOP_R):
            v.rect(x, top - 2, x, top - 1, HAIR)
    elif variant == "krullen":
        for x, y in ((KOP_L - 1, top), (KOP_L + 1, top - 2),
                     (KOP_R - 2, top - 2), (KOP_R + 1, top)):
            v.rect(x, y, x + 1, y + 1, HAIR)
        v.rect(KOP_L - 2, top + 2, KOP_L - 2, top + 5, HAIR_S)
        v.rect(KOP_R + 2, top + 2, KOP_R + 2, top + 5, HAIR_S)
    elif variant == "zijscheiding" and richting != 1:
        v.rect(KOP_L, top, KOP_L + 4, top + 1, HAIR_S)
    elif variant in ("lang", "staart", "knot"):
        v.rect(KOP_L - 1, top + 1, KOP_L - 1, KOP_BOT + bob, HAIR_S)
        v.rect(KOP_R + 1, top + 1, KOP_R + 1, KOP_BOT + bob, HAIR_S)


# =============================================================================
# 5. facial — snor, stoppels, baard
# =============================================================================
FACIALS = ["snor", "stoppels", "baard"]


def laag_facial(v, richting, p, variant):
    if richting == 1:
        return
    bob = p["bob"]
    if variant == "snor":
        v.rect(6, MOND_Y - 1 + bob, 9, MOND_Y - 1 + bob, HAIR_S)
    elif variant == "stoppels":
        for x in range(KOP_L + 1, KOP_R):
            if (x + bob) % 2 == 0:
                v.px(x, MOND_Y + 1 + bob, HAIR_S)
        v.rect(KOP_L + 1, KOP_BOT + bob, KOP_R - 1, KOP_BOT + bob, HAIR_S)
    elif variant == "baard":
        v.rect(KOP_L, MOND_Y - 1 + bob, KOP_R, KOP_BOT + bob, HAIR_S)
        v.rect(7, MOND_Y + bob, 8, MOND_Y + bob, OUT_C)   # mond blijft leesbaar
        v.rect(KOP_L, MOND_Y - 2 + bob, KOP_L + 1, MOND_Y - 2 + bob, HAIR_S)
        v.rect(KOP_R - 1, MOND_Y - 2 + bob, KOP_R, MOND_Y - 2 + bob, HAIR_S)


# =============================================================================
# 6. accessory — bril, koptelefoon, pet, lanyard, doos, tas
# =============================================================================
ACCESSORIES = ["bril", "koptelefoon", "pet", "lanyard", "doos", "tas"]


def laag_accessory(v, richting, p, variant):
    bob = p["bob"]
    y = OOG_Y + bob

    if variant == "bril":
        if richting == 1:
            v.rect(KOP_L - 1, y, KOP_R + 1, y, GLAS_R)   # pootjes van achteren
            return
        # dun montuur: een dikke rand wordt op deze schaal een donkere balk
        # over het halve gezicht
        if richting == 0:
            v.rect(OOG_L, y, OOG_L + 1, y + 1, LENS)
            v.rect(OOG_R, y, OOG_R + 1, y + 1, LENS)
            v.px(OOG_L + 1, y + 1, EYE)
            v.px(OOG_R + 1, y + 1, EYE)
            v.rect(OOG_L - 1, y - 1, OOG_R + 2, y - 1, GLAS_R)
            v.px(OOG_L - 1, y, GLAS_R)
            v.px(OOG_R + 2, y, GLAS_R)
            v.rect(OOG_L + 2, y, OOG_R - 1, y, GLAS_R)
        else:
            v.rect(OOG_L, y, OOG_L + 1, y + 1, LENS)
            v.px(OOG_L, y + 1, EYE)
            v.rect(OOG_L - 1, y - 1, OOG_L + 2, y - 1, GLAS_R)
            v.rect(OOG_L + 2, y, KOP_R, y, GLAS_R)

    elif variant == "koptelefoon":
        v.rect(KOP_L - 1, KOP_TOP - 2 + bob, KOP_R + 1, KOP_TOP - 2 + bob, ACCENT_S)
        v.rect(KOP_L - 1, KOP_TOP + bob, KOP_L - 1, KOP_TOP + 3 + bob, ACCENT)
        v.rect(KOP_R + 1, KOP_TOP + bob, KOP_R + 1, KOP_TOP + 3 + bob, ACCENT)

    elif variant == "pet":
        # bol op de schedel, klep eronder: een pet die boven het hoofd zweeft
        # leest als een plank
        v.rect(KOP_L, KOP_TOP - 1 + bob, KOP_R, KOP_TOP + 1 + bob, ACCENT)
        v.rect(KOP_L + 1, KOP_TOP - 2 + bob, KOP_R - 1, KOP_TOP - 2 + bob, ACCENT)
        if richting == 0:
            v.rect(KOP_L - 1, KOP_TOP + 2 + bob, KOP_R + 1, KOP_TOP + 2 + bob, ACCENT_S)
        elif richting != 1:
            v.rect(KOP_L - 3, KOP_TOP + 2 + bob, KOP_R - 2, KOP_TOP + 2 + bob, ACCENT_S)

    elif variant == "lanyard":
        if richting == 1:
            return
        v.px(6, ROMP_TOP + 1 + bob, ACCENT)
        v.px(9, ROMP_TOP + 1 + bob, ACCENT)
        v.px(7, ROMP_TOP + 2 + bob, ACCENT)
        v.px(8, ROMP_TOP + 2 + bob, ACCENT)
        v.rect(7, ROMP_TOP + 3 + bob, 8, ROMP_TOP + 5 + bob, WIT)
        v.omlijn(7, ROMP_TOP + 3 + bob, 8, ROMP_TOP + 5 + bob, OUT_C)

    elif variant == "doos":
        # voor je uit gedragen, dus alleen zichtbaar van voren en opzij
        if richting == 1:
            return
        v.rect(ROMP_L, ROMP_BOT - 4 + bob, ROMP_R, ROMP_BOT + 1 + bob, ACCENT)
        v.omlijn(ROMP_L, ROMP_BOT - 4 + bob, ROMP_R, ROMP_BOT + 1 + bob, OUT_C)
        v.rect(7, ROMP_BOT - 4 + bob, 8, ROMP_BOT + 1 + bob, ACCENT_S)

    elif variant == "tas":
        zij = ARM_R if richting != 2 else ARM_L
        v.rect(zij - 1, ROMP_TOP + 4 + bob, zij + 2, ROMP_BOT + 2 + bob, ACCENT)
        v.omlijn(zij - 1, ROMP_TOP + 4 + bob, zij + 2, ROMP_BOT + 2 + bob, OUT_C)
        v.rect(6, ROMP_TOP + bob, zij, ROMP_TOP + 1 + bob, ACCENT_S)


# =============================================================================
# sheet-opbouw
# =============================================================================
LAGEN = [
    ("body",      BODIES.keys(), laag_body),
    ("hair_back", HAIR_BACK,     laag_hair_back),
    ("outfit",    OUTFITS.keys(), laag_outfit),
    ("hair",      HAIRS,         laag_hair),
    ("facial",    FACIALS,       laag_facial),
    ("accessory", ACCESSORIES,   laag_accessory),
]


def bouw_sheet(teken, variant):
    sheet = Image.new("RGBA", (FW * COLS, FH * ROWS), (0, 0, 0, 0))
    for rij in range(ROWS):
        for col in range(COLS):
            # rechts is een spiegeling van links: scheelt de helft van het werk
            # en garandeert dat het profiel aan beide kanten hetzelfde leest
            bron = 2 if rij == 3 else rij
            v = Vel()
            teken(v, bron, pose(col), variant)
            beeld = v.img.transpose(Image.FLIP_LEFT_RIGHT) if rij == 3 else v.img
            sheet.paste(beeld, (col * FW, rij * FH))
    return sheet


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    # de oude monolithische sheets zijn vervangen door lagen
    for oud in ("plain", "beard", "glasses", "curly", "long", "hoodie",
                "buttons", "template"):
        for ext in ("", ".import"):
            pad = os.path.join(OUT_DIR, "person_%s.png%s" % (oud, ext))
            if os.path.exists(pad):
                os.remove(pad)

    totaal = 0
    for naam, varianten, teken in LAGEN:
        for variant in varianten:
            sheet = bouw_sheet(teken, variant)
            sheet.save(os.path.join(OUT_DIR, "%s_%s.png" % (naam, variant)))
            totaal += 1
        print("%-10s %s" % (naam, ", ".join(varianten)))
    print("%d laag-sheets van %dx%d, frame %dx%d (logisch %dx%d + %d px marge)"
          % (totaal, FW * COLS, FH * ROWS, FW, FH, LW, LH, MARGE))


if __name__ == "__main__":
    main()
