#!/usr/bin/env python3
"""Genereert data/floor.json — de enige bron van waarheid voor de kantoorvloer.

Vervang de rect-definities hieronder door de echte plattegrond en draai opnieuw.
Het script valideert bereikbaarheid en looptijden voordat het wegschrijft.
"""
import json, heapq, os, sys

W, H = 130, 26
TILE = 16
WALK_SPEED_TILES = 6.0     # 96 px/s bij 16px tiles — zie player.gd WALK_SPEED

# ---- schaal ----------------------------------------------------------------
# Ankermaat van Daan: de verdieping is over de korte as 12 meter breed. Die as
# is 26 tegels, dus 0,4615 m per tegel. Daarmee is het gebouw 60,0 x 12,0 m en
# exact 5,00:1 — tegen de 5,06:1 die op de ontruimingsplattegrond is opgemeten.
# Te consistent om toeval te zijn, dus dit is de schaal.
#
# Gebruik tiles(meters) voor elke nieuwe maat. Niet meer op gevoel kiezen.
M_PER_TILE = 12.0 / 26.0

def tiles(meters):
    return max(1, round(meters / M_PER_TILE))

def m2(w, h):
    return w * h * M_PER_TILE * M_PER_TILE

g = [['#'] * W for _ in range(H)]

# ---- samengestelde objecten -------------------------------------------------
# De tegel doet de collision en de footprint (dus de bereikbaarheidsvalidatie
# blijft gelden), de sprite doet het beeld. '_' rendert als gewone vloer.
PROPS = []

def prop(naam, x0, y0, x1, y1):
    """Eén logisch object: footprint in tegels, beeld als losse sprite.

    De maat zit in de naam, want de PNG moet exact op de footprint passen —
    de runtime schaalt niets.
    """
    rect(x0, y0, x1, y1, '_')
    volledig = "%s_%dx%d" % (naam, x1 - x0 + 1, y1 - y0 + 1)
    PROPS.append({"prop": volledig, "rect": [x0, y0, x1, y1]})


def rect(x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < W and 0 <= y < H:
                g[y][x] = ch

# ---------------------------------------------------------------------------
# De echte Bluebird Day-vloer. Opgemeten op de ontruimingsplattegrond in
# assets/nieuwe assets/: buitenwanden op x 544/868 en y 310/1930 -> 5,06 : 1.
# 130 x 26 tegels geeft 5,0 : 1 (2080 x 416 px).
#
# Bandindeling (de schets is de plattegrond 90 graden gedraaid):
#   y0      buitenwand
#   y1-6    gesloten ruimtes, binnenzijde   (toilet .. birdhouse)
#   y7      scheidingslijn: glas voor de vergaderruimtes, wand voor de rest
#   y8-13   circulatieband ("De Gang")
#   y14-24  open werkvloer, raamzijde       (bureaus + plantenkasten)
#   y25     buitenwand
#
# Eén lange lus in plaats van de oude ring: de gang loopt door van x1 tot x95
# en de bureauband is een tweede doorlopende baan. Geen doodlopers.
# ---------------------------------------------------------------------------

# alles binnen de buitenwanden is eerst vloer; muren komen er daarna weer in
rect(1, 1, W - 2, H - 2, '.')

# Volgorde van west naar oost, afgelezen van de geannoteerde ontruimings-
# plattegrond: trappenhuis, serverhok, toilet, en dan pas de open kantoorvloer.
# Het serverhok zat eerder midden op de vloer (x18-21); dat klopte niet met de
# plattegrond en ook niet met de hint van t05 ("het Patchhok zit naast de
# toiletten"). De ingang ligt voorbij het trappenhuis, dat op slot zit.
NOORD = [   # (x0, x1, deur-x0, deur-x1, glas?)
    (6, 9, 7, 8, False),       # Het Patchhok, het echte serverhok — 4x6 = 5,1 m2
    (11, 15, 13, 13, False),   # Toilet — 5x6 = 6,4 m2
    (17, 34, 20, 22, False),   # Koffiecorner — brede doorgang, het is een corner
    # docs/LEVEL.md beschrijft ze als merkbaar verschillend: Summit klein en
    # leeg, Birdhouse de grote zaal. Nu ook in tegels, via tiles(meters).
    (43, 53, 48, 49, True),    # Summit    11x6 = 14,1 m2
    (55, 71, 62, 63, True),    # Basecamp  17x6 = 21,7 m2
    (73, 92, 82, 83, True),    # Birdhouse 20x6 = 25,6 m2
]

# scheidingslijn y7 dicht maken, per ruimte glas of wand, met deuropening
rect(1, 7, 95, 7, '#')
for (x0, x1, d0, d1, glas) in NOORD:
    rect(x0, 7, x1, 7, '=' if glas else '#')
    rect(d0, 7, d1, 7, 'D')

# tussenwanden van de noordband
for x in (5, 10, 16, 42, 54, 72):
    rect(x, 1, x, 6, '#')
rect(35, 1, 36, 6, '#')       # smalle schacht naast de koffiecorner
rect(41, 1, 42, 6, '#')       # en naast Summit; ertussen de tijgernis
rect(37, 7, 40, 7, '#')
rect(38, 7, 39, 7, 'D')       # opening naar de tijgernis

# ---- Trappenhuis: op slot, dus geen speelruimte ----
# Je komt de verdieping binnen voorbij de trap; de trap zelf is niet te
# bereiken. Als massief blok getekend, anders meldt de bereikbaarheidscheck
# terecht dat er vloer is waar niemand kan komen.
rect(1, 1, 4, 6, 'X')
rect(2, 7, 3, 7, 'N')         # deur op slot, zichtbaar vanuit de gang
# de strook tussen Birdhouse en Weekend is dicht: schacht, geen ruimte
rect(93, 1, 95, 6, '#')

# ---- Weekend: eigen helft achter een glaslijn met brede opening ----
rect(96, 1, 96, 24, '=')
rect(96, 10, 96, 15, 'D')

# ---- Vergaderhokje: vrijstaand blok in de gang, onder Summit ----
rect(44, 9, 50, 12, '#')
rect(45, 10, 49, 11, '.')
rect(47, 9, 47, 9, 'D')       # deur naar de gang, aan de Summit-kant
rect(44, 10, 44, 11, 'l')     # houten lamellenzijde met de "Samen Bingo"-poster
rect(50, 10, 50, 11, '=')

# ---- Voordeur op de westwand: de wincondititie ----
rect(0, 10, 0, 12, 'V')

# ---- Entree: geen balie. De receptie zit op een andere verdieping; deze
# verdieping is puur kantoor. Alleen een scherm en de printer bij de deur.
rect(1, 8, 1, 8, 'm')          # scherm_entree, tegen de westwand
rect(10, 8, 11, 8, 'c')        # wachtbank: hier zit de klant
rect(9, 6, 9, 6, 'P')          # printer, in het serverhok

# ---- Toiletgag letterlijk: 2 urinoirs en 1 pot, alles achter één deur ----
rect(12, 2, 12, 2, 'u')
rect(12, 4, 12, 4, 'u')
rect(15, 5, 15, 5, 'W')

# ---- Patchhok: krappe warme techniekkast, naast de toiletten ----
prop("serverrack", 7, 2, 8, 5)

# ---- Koffiecorner: tribune-trap, Jura en de DIA-awards ----
prop("tribune", 24, 2, 33, 3)
prop("keukenblok", 18, 2, 22, 2)
rect(33, 5, 33, 5, 'f')
rect(17, 2, 17, 2, 'H')        # prikbord met de losse mini-tickets

# ---- Summit: kleine tafel, 4 witte stoelen, schaakbordkleed ----
rect(44, 1, 46, 1, 'x')        # whiteboard_vergader: hier landt de user story
rect(46, 2, 51, 5, 'q')
rect(48, 3, 49, 4, 't')
rect(48, 2, 49, 2, 's')
rect(48, 5, 49, 5, 's')
rect(47, 3, 47, 4, 's')
rect(50, 3, 50, 4, 's')

# ---- Basecamp: 4 werkplekken langs de wanden, ronde tafel in het midden ----
rect(56, 2, 57, 3, 'b')
rect(56, 5, 57, 6, 'b')
rect(69, 2, 70, 3, 'b')
rect(69, 5, 70, 6, 'b')
rect(62, 3, 63, 4, 'r')
prop("monitorwand", 61, 1, 64, 1)   # de wand-tv's: dashboardmuur van t06

# ---- Birdhouse: de grote zaal voor de finale ----
rect(78, 3, 88, 5, 't')
rect(78, 2, 88, 2, 's')
rect(77, 3, 77, 5, 's')
rect(89, 3, 89, 5, 's')
rect(81, 1, 84, 1, 'm')       # deploycomputer aan de noordwand

# ---- De Gang: de blauwe tijger en de grote tafel met planten ----
# De tijger staat in de opening tussen de koffiecorner en Summit: het eerste
# wat je ziet als je de gang in kijkt.
rect(38, 4, 38, 4, 'Y')
# De grote tafel begint rechts van het vergaderhokje en loopt door tot het
# einde van Birdhouse. Tussen hokje en tafel blijft ruimte om door te lopen.
prop("tafel_lang", 55, 10, 92, 11)

# ---- De Vloer (raamzijde): bureau-eilanden en plantenkasten ----
# Een kwartslag gedraaid t.o.v. de eerste opzet: elk eiland is een blok dat de
# diepte in staat, met een verticaal privacyscherm door het midden. Vijf
# eilanden en twee plantenkasten, in de volgorde van schets idee.jpeg:
#   8 werkplekken · plantenkast · 4 · 4 · plantenkast · 8 · 4
EILANDEN = [
    (5, 8),    # (x0, aantal werkplekken) — de hoogte volgt uit het aantal
    (24, 4),
    (38, 4),
    (60, 8),
    (76, 4),
]
for (x0, n) in EILANDEN:
    prop("bureau", x0, 15, x0 + 3, 15 + n - 1)
for (x0, h) in [(15, 8), (50, 6)]:
    prop("plantenkast", x0, 15, x0 + 2, 15 + h - 1)

# Zuidwand, west naar oost — de route loopt zo monotoon mogelijk mee:
# ticketbord bij de ingang (waar de schets het zet), dan de wandmonitor van t04,
# dan het scrumbord van t02/t09.
rect(4, 25, 6, 25, 'T')      # ticketbord: opent het echte bord
rect(11, 25, 13, 25, 'm')    # wandmonitor_vloer: staging van t04
rect(27, 25, 29, 25, 'T')    # scrumbord_gang: planning (t02) en paarden (t09)

# ---- Weekend: jungle, chaos, en de spullen die hier niemand mist ----
rect(100, 3, 104, 7, 'J')
rect(112, 14, 117, 19, 'J')
rect(124, 5, 127, 9, 'J')
rect(103, 12, 110, 13, 't')
rect(118, 4, 124, 5, 'b')
rect(118, 21, 124, 22, 'b')
rect(108, 20, 112, 21, 'c')
rect(99, 17, 100, 22, 'j')     # blauw gordijn als divider
rect(127, 20, 128, 23, 'o')
rect(129, 20, 129, 21, 'N')    # spiltrap-uitgang, zie de ontruimingsplattegrond

LEGEND = {
    ".": {"kind": "floor", "solid": False},
    "D": {"kind": "floor", "solid": False, "door": True},
    "#": {"kind": "wall",  "solid": True},
    "=": {"kind": "glass", "solid": True},
    "V": {"kind": "exit",  "solid": True,  "prop": "voordeur"},
    "N": {"kind": "wall",  "solid": True,  "prop": "nooduitgang"},
    "X": {"kind": "wall",  "solid": True,  "prop": "trappenhuis"},
    "B": {"kind": "prop",  "solid": True,  "prop": "balie"},
    "P": {"kind": "prop",  "solid": True,  "prop": "printer"},
    "T": {"kind": "prop",  "solid": True,  "prop": "ticketbord"},
    "b": {"kind": "prop",  "solid": True,  "prop": "bureau"},
    "t": {"kind": "prop",  "solid": True,  "prop": "tafel"},
    "c": {"kind": "prop",  "solid": True,  "prop": "bank"},
    "K": {"kind": "prop",  "solid": True,  "prop": "keukenblok"},
    "f": {"kind": "prop",  "solid": True,  "prop": "koelkast"},
    "x": {"kind": "prop",  "solid": True,  "prop": "whiteboard"},
    "S": {"kind": "prop",  "solid": True,  "prop": "serverrack"},
    "A": {"kind": "prop",  "solid": True,  "prop": "archiefkast"},
    "W": {"kind": "prop",  "solid": True,  "prop": "wc"},
    "m": {"kind": "prop",  "solid": True,  "prop": "monitor"},
    "p": {"kind": "prop",  "solid": True,  "prop": "plant"},
    "o": {"kind": "prop",  "solid": True,  "prop": "kast"},
    "H": {"kind": "prop",  "solid": True,  "prop": "prikbord"},
    "_": {"kind": "prop",  "solid": True,  "prop": "footprint"},
    # het echte kantoor
    "u": {"kind": "prop",  "solid": True,  "prop": "urinoir"},
    "R": {"kind": "prop",  "solid": True,  "prop": "tribune"},
    "n": {"kind": "prop",  "solid": True,  "prop": "plantenkast"},
    "l": {"kind": "wall",  "solid": True,  "prop": "lamellen"},
    "j": {"kind": "prop",  "solid": True,  "prop": "gordijn"},
    "Y": {"kind": "prop",  "solid": True,  "prop": "blauwe_tijger"},
    "J": {"kind": "prop",  "solid": True,  "prop": "jungle"},
    "s": {"kind": "prop",  "solid": True,  "prop": "kuipstoel"},
    "r": {"kind": "prop",  "solid": True,  "prop": "ronde_tafel"},
    # accentvloeren
    "E": {"kind": "floor", "solid": False, "accent": "bb_blue"},
    "O": {"kind": "floor", "solid": False, "accent": "bb_orange"},
    "L": {"kind": "floor", "solid": False, "accent": "bb_light_blue"},
    "G": {"kind": "floor", "solid": False, "accent": "bb_green"},
    "I": {"kind": "floor", "solid": False, "accent": "bb_pink"},
    "C": {"kind": "floor", "solid": False, "accent": "teal"},
    "q": {"kind": "floor", "solid": False, "accent": "schaakbord"},
}

# ---- accentvloeren: één accent per ruimte, de rest blijft neutraal beton ----
ACCENT_ROOMS = [
    (1, 8, 16, 13, 'E'),      # entree/gang — bb-blue, hero-moment
    (23, 1, 40, 6, 'C'),      # koffiecorner — teal, de tribune-kleur
    (43, 1, 53, 6, 'L'),      # Summit — bb-light-blue
    (73, 1, 92, 6, 'L'),      # Birdhouse — bb-light-blue
    (31, 8, 37, 9, 'I'),      # vergaderhokje — bb-pink
    (97, 1, 128, 24, 'G'),    # Weekend — groen, dichter gestrooid: de jungle
]
for (x0, y0, x1, y1, ch) in ACCENT_ROOMS:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < W and 0 <= y < H and g[y][x] == '.':
                g[y][x] = ch

# ZONES: specifiek vóór algemeen — world_builder.zone_at() geeft de eerste match
ZONES = [
    {"id": "z2_toilet",       "name": "Toiletten",        "rect": [11, 1, 15, 6],    "light": "klinisch"},
    {"id": "z3_patchhok",     "name": "Het Patchhok",     "rect": [6, 1, 9, 6],      "light": "koud"},
    {"id": "z1_entree",       "name": "Entree",           "rect": [1, 7, 16, 13],    "light": "warm"},
    {"id": "z4_koffiecorner", "name": "Koffiecorner",     "rect": [17, 1, 40, 6],    "light": "warm"},
    {"id": "z5_summit",       "name": "Summit",           "rect": [43, 1, 53, 6],    "light": "koel"},
    {"id": "z6_basecamp",     "name": "Basecamp",         "rect": [55, 1, 71, 6],    "light": "neutraal"},
    {"id": "z7_birdhouse",    "name": "Birdhouse",        "rect": [73, 1, 92, 6],    "light": "koel"},
    {"id": "z8_hokje",        "name": "Het Vergaderhokje","rect": [44, 9, 50, 12],   "light": "dim"},
    {"id": "z10_weekend",     "name": "Weekend",          "rect": [97, 1, 128, 24],  "light": "jungle"},
    {"id": "z9_vloer",        "name": "De Vloer",         "rect": [1, 14, 95, 24],   "light": "neutraal"},
    {"id": "z11_gang",        "name": "De Gang",          "rect": [1, 7, 95, 13],    "light": "neutraal"},
]

SPAWN = [2, 11]   # net binnen de voordeur, in de circulatieband

# ---------------- validatie ----------------

def solid_set():
    return {(x, y) for y in range(H) for x in range(W)
            if LEGEND[g[y][x]]["solid"]}

def dijkstra(src, solid):
    dist = {src: 0.0}
    pq = [(0.0, src)]
    while pq:
        d, (x, y) = heapq.heappop(pq)
        if d > dist.get((x, y), 1e9):
            continue
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                n = (x + dx, y + dy)
                if not (0 <= n[0] < W and 0 <= n[1] < H) or n in solid:
                    continue
                if dx and dy and ((x + dx, y) in solid or (x, y + dy) in solid):
                    continue
                nd = d + (1.4142 if dx and dy else 1.0)
                if nd < dist.get(n, 1e9):
                    dist[n] = nd
                    heapq.heappush(pq, (nd, n))
    return dist

def validate():
    solid = solid_set()
    free = [(x, y) for y in range(H) for x in range(W) if (x, y) not in solid]
    assert tuple(SPAWN) in free, "spawnpunt staat in een muur"
    d0 = dijkstra(tuple(SPAWN), solid)
    unreach = [p for p in free if p not in d0]
    worst = max(d0.values())
    return free, unreach, worst

def main():
    free, unreach, worst = validate()
    ok = not unreach
    print(f"begaanbare tegels : {len(free)}")
    print(f"onbereikbaar      : {len(unreach)} {unreach[:12]}")
    print(f"verste punt       : {worst:.1f} tiles = {worst / WALK_SPEED_TILES:.1f}s lopen")
    for zid in [z["id"] for z in ZONES]:
        pass
    if not ok:
        print("AFGEKEURD: onbereikbare vloertegels.", file=sys.stderr)
        sys.exit(1)

    data = {
        "size": [W, H],
        "tile_size": TILE,
        "spawn": SPAWN,
        "walk_speed_tiles_per_sec": WALK_SPEED_TILES,
        "props": PROPS,
        "grid": ["".join(row) for row in g],
        "legend": LEGEND,
        "zones": ZONES,
    }
    out = os.path.join(os.path.dirname(__file__), "..", "..", "data", "floor.json")
    out = os.path.normpath(out)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
    print(f"geschreven        : {out}")

if __name__ == "__main__":
    main()
