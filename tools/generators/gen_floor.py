#!/usr/bin/env python3
"""Genereert data/floor.json — de enige bron van waarheid voor de kantoorvloer.

Vervang de rect-definities hieronder door de echte plattegrond en draai opnieuw.
Het script valideert bereikbaarheid en looptijden voordat het wegschrijft.
"""
import json, heapq, os, sys

W, H = 130, 26
TILE = 16
# Alleen voor de looptijden die dit script print. De echte snelheid staat in
# player.gd (WALK_SPEED = 96 px/s bij 16px tiles); dit getal moet daarmee
# meebewegen. Bewust NIET in floor.json: daar stond het jaren als tweede
# waarheid die niemand las, en een dode kopie van een constante is erger dan
# geen kopie — hij nodigt uit om hem te veranderen zonder dat er iets gebeurt.
WALK_SPEED_TILES = 6.0

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


def bord(naam, x0, y0, x1, y1):
    """Hangend ruimtebordje: beeld zonder footprint.

    Hij hangt aan het plafond, dus hij mag de gang niet dichtzetten — de tegels
    eronder blijven wat ze zijn. `hangend` vertelt main.gd dat deze sprite niet
    in de y-sortering meedoet maar boven de speler hangt.
    """
    volledig = "bord_%s_%dx%d" % (naam, x1 - x0 + 1, y1 - y0 + 1)
    PROPS.append({"prop": volledig, "rect": [x0, y0, x1, y1], "hangend": True})


def rect(x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < W and 0 <= y < H:
                g[y][x] = ch

# ---------------------------------------------------------------------------
# De echte Bluebird Day-vloer, gelegd naar `assets/nieuwe assets/schets idee.jpeg`
# inclusief de rode aantekeningen daarop (RAAM, SERVER HOK, Kast (Blauw),
# "Ingang zit hier", "Scrumbord hangt hier").
#
# Bandindeling (de schets is de plattegrond 90 graden gedraaid):
#   y0      buitenwand, binnenzijde — met de kastenwand en het raam achter
#           de koffiecorner, precies waar de schets ze rood aanwijst
#   y1-6    west  x1-8 : Toilet
#           oost x10+  : open noordband met de koffiecorner als vrijstaand
#                        eiland, daarna Summit / Basecamp / Birdhouse
#   y7      west: wand tussen toilet en serverhok
#           oost: glas voor de drie vergaderruimtes, open van x10 tot x41
#   y8-13   west  x1-8 : Het Patchhok, direct ónder het toilet
#           oost       : De Gang, met het Vergaderhokje op x30-38 en de
#                        grote tafel met planten op x55-92
#   y14-24  De Vloer: vijf bureau-eilanden (8·4·4·4·4) en twee plantenkasten,
#           met de voordeur op de westwand — direct onder het serverhok, met
#           het trappenhuis eronder — en het scrumbord ernaast
#   y25     buitenwand, raamzijde
#
# Wat hier veranderde t.o.v. de eerste opzet, en waarom:
# - Patchhok en Toilet stonden náást elkaar in de noordband. Op de schets zijn
#   ze gestápeld aan het westeinde, met de ingang op de westwand eronder.
# - De koffiecorner was een gesloten ruimte tegen de noordwand; je kon er per
#   definitie niet omheen. Nu is het een solide blok in een open band, met
#   loopruimte aan alle vier de kanten — dat is wat "corner" hier betekent.
# - Het vergaderhokje stond op x44-50, terwijl `hokje_ipad` (het anker van t08),
#   `hokje_telefoon` en `samen_bingo_poster` op x31-36 lagen. Het anker lag dus
#   buiten zijn eigen zone. Het hokje staat nu waar de schets het zet, en waar
#   de objecten al stonden.
#
# Eén lange lus in plaats van de oude ring: de gang loopt door van x10 tot x95,
# de bureauband is een tweede doorlopende baan. Geen doodlopers.
# ---------------------------------------------------------------------------

# alles binnen de buitenwanden is eerst vloer; muren komen er daarna weer in
rect(1, 1, W - 2, H - 2, '.')

# ---- Het westeinde: toilet boven, serverhok eronder ------------------------
# Twee gesloten ruimtes op elkaar, samen één blok tegen de westwand, met de
# scheidingswand op y7 en de gang erlangs op x10. De ingang zit eronder.
rect(9, 1, 9, 13, '#')        # oostwand van het blok, van buitenwand tot gang
rect(1, 7, 8, 7, '#')         # wand tussen toilet en serverhok
rect(1, 14, 9, 14, '#')       # zuidwand van het serverhok, tegen De Vloer aan
rect(9, 3, 9, 3, 'D')         # Toilet: één deur voor 8x6 tegels — dat ís de grap
rect(9, 10, 9, 10, 'D')       # Patchhok: één deur, achter de badgelezer

# de noordband is verder open; alleen de drie vergaderruimtes staan er dicht
NOORD = [   # (x0, x1, deur-x0, deur-x1, glas?)
    # docs/LEVEL.md beschrijft ze als merkbaar verschillend: Summit klein en
    # leeg, Birdhouse de grote zaal. Nu ook in tegels, via tiles(meters).
    (43, 53, 48, 49, True),    # Summit    11x6 = 14,1 m2
    (55, 71, 62, 63, True),    # Basecamp  17x6 = 21,7 m2
    (73, 92, 82, 83, True),    # Birdhouse 20x6 = 25,6 m2
]

# scheidingslijn y7: alleen dicht waar er een ruimte achter zit. Tussen x10 en
# x41 loopt de noordband gewoon door in de gang — dat is wat de koffiecorner
# tot een eiland maakt in plaats van tot een kamer.
rect(42, 7, 42, 7, '#')
rect(54, 7, 54, 7, '#')
rect(72, 7, 72, 7, '#')
rect(93, 7, 95, 7, '#')
for (x0, x1, d0, d1, glas) in NOORD:
    rect(x0, 7, x1, 7, '=' if glas else '#')
    rect(d0, 7, d1, 7, 'D')

# tussenwanden van de noordband
for x in (42, 54, 72):
    rect(x, 1, x, 6, '#')
# de strook tussen Birdhouse en Weekend is dicht: schacht, geen ruimte
rect(93, 1, 95, 6, '#')

# ---- Weekend: eigen helft achter een glaslijn met brede opening ----
rect(96, 1, 96, 24, '=')
rect(96, 10, 96, 15, 'D')

# ---- Noordwand achter de koffiecorner: kastenwand en raam ------------------
# De twee rode aantekeningen op de schets. Ze staan op de buitenwand zelf, dus
# ze kosten geen vloer: `k` is de donkerblauwe kastenwand met de bank ervoor,
# `w` het enige raam aan deze binnenzijde.
rect(11, 0, 11, 0, 'H')       # prikbord met de losse mini-tickets
rect(12, 0, 25, 0, 'k')       # "Kast (Blauw)"
rect(26, 0, 40, 0, 'w')       # "RAAM"

# ---- Voordeur op de westwand, direct onder het serverhok: de wincondititie ----
# De tweede schets tekent trappenhuis en ingang strak tegen elkaar, meteen onder
# het serverhok. Hij stond op y16-18, met y15 als lege tegelrij ertussen; dat gat
# staat op geen enkele schets. Nu sluit de bovenste deurtegel aan op de zuidwand
# van het Patchhok (y14).
rect(0, 15, 0, 17, 'V')

# ---- Trappenhuis: decor achter de ingang, per definitie niet te betreden ----
# Hier komt iedereen normaal binnen, dus het hóórt in beeld te staan — maar het
# ligt buiten deze verdieping. Vandaar geen kamer en geen deur: twee tegels in de
# buitenwand zelf, direct onder de voordeur, waar je door een glazen pui tegen de
# traptreden aan kijkt. Het kost geen vloer en kan dus ook geen route breken.
rect(0, 18, 0, 19, 'X')

# ---- Entree: geen balie. De receptie zit op een andere verdieping; deze
# verdieping is puur kantoor. Een scherm, een bank, en verder is het gang.
rect(0, 20, 0, 21, 'm')        # scherm_entree, in de westwand boven de bank
rect(1, 20, 1, 21, 'c')        # wachtbank: hier zit de klant

# ---- Toiletgag letterlijk: 2 urinoirs en 1 pot, alles achter één deur ----
rect(1, 2, 1, 2, 'u')
rect(1, 4, 1, 4, 'u')
rect(7, 6, 7, 6, 'W')

# ---- Patchhok: krappe warme techniekkast, direct onder de toiletten ----
prop("serverrack", 2, 9, 3, 12)
prop("serverrack", 5, 9, 6, 12)
rect(8, 12, 8, 12, 'P')        # printer, net binnen de deur

# ---- Koffiecorner: vrijstaand blok, loopruimte rondom ----------------------
# y1 vrij boven, y4-y7 vrij onder, x10-17 vrij west, x34-41 vrij oost. Je kunt
# er dus echt omheen — dat was het hele punt van de herindeling.
prop("keukenblok", 18, 2, 22, 3)
rect(23, 2, 23, 3, 'f')        # koelkast, aan het eind van het aanrecht
prop("tribune", 24, 2, 33, 3)
rect(34, 3, 34, 3, 'z')        # de speaker van t07, tegen het eind van de tribune

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

# ---- De Gang: de blauwe tijger, het vergaderhokje en de grote tafel ----
# De tijger staat in de open ruimte tussen de koffiecorner (accent tot x36) en de
# westwand van Summit (x42): het eerste wat je ziet als je de gang in kijkt.
#
# Hij stond op y4 en was daar in het spel niet te zien. De camera klemt verticaal
# volledig vast en de HUD dekt de bovenste vijf à zes tegelrijen af (zie
# docs/TESTING.md); op een shot van --kijk=38,5 stak alleen de onderste strook
# pixels onder de kompasstrip uit. y6 is de eerste rij die er helemaal onder
# vandaan komt, ligt nog steeds in dezelfde open ruimte, en zet hem bovendien
# tegen de gangmond op y7 aan in plaats van tegen de noordband.
rect(38, 6, 38, 6, 'Y')

# Vergaderhokje: vrijstaand blok in de gang, onder de koffiecorner. Hier ligt de
# iPad van t08 — het anker, de zone en de accentvloer vallen nu samen.
rect(30, 8, 38, 11, '#')
rect(31, 9, 37, 10, '.')
rect(34, 8, 34, 8, 'D')       # deur naar de noordband
rect(30, 9, 30, 10, 'l')      # houten lamellenzijde met de "Samen Bingo"-poster
rect(38, 9, 38, 10, '=')

# De grote tafel begint rechts van het vergaderhokje en loopt door tot het
# einde van Birdhouse. Tussen hokje en tafel blijft ruimte om door te lopen.
prop("tafel_lang", 55, 10, 92, 11)

# ---- De Vloer (raamzijde): bureau-eilanden en plantenkasten ----
# Elk eiland is een blok dat de diepte in staat, met een verticaal
# privacyscherm door het midden. Vijf eilanden en twee plantenkasten, in de
# volgorde van schets idee.jpeg:
#   8 werkplekken · plantenkast · 4 · 4 · plantenkast · 4 · 4
# Het vierde eiland stond hier jarenlang op 8; de schets zegt 4, en met vier
# stoelen erlangs klopt ook de loopruimte naar de grote tafel weer.
EILANDEN = [
    (5, 8),    # (x0, aantal werkplekken) — de hoogte volgt uit het aantal
    (24, 4),
    (38, 4),
    (60, 4),
    (76, 4),
]
for (x0, n) in EILANDEN:
    prop("bureau", x0, 15, x0 + 3, 15 + n - 1)
for (x0, h) in [(15, 8), (50, 6)]:
    prop("plantenkast", x0, 15, x0 + 2, 15 + h - 1)

# Zuidwand, west naar oost. De schets zet het scrumbord bij de ingang, achter
# het eerste bureau-eiland (zie "scrumboard achter bureau.jpeg"), daarna het
# ticketbord en dan de wandmonitor van t04.
# ---- Ruimtebordjes: wayfinding die je met je ogen oplost ----
# Ze hangen in de gang, bij de deur van de ruimte die ze aanwijzen. Geen
# footprint: je loopt eronderdoor. De toiletdeur zit op x9,y3 en heeft geen
# glas, dus dat bordje is het enige dat die ruimte aankondigt.
#
# Niet hoger dan y6 hangen: de camera klemt verticaal vast en de HUD-balk dekt
# de bovenste vier tegelrijen af. Een bordje op y2 hangt keurig boven de deur
# en is in het spel onzichtbaar. Vandaar dat het toiletbordje op de zuidoosthoek
# van het blok staat en niet naast de deur zelf.
bord("toilet", 10, 6, 12, 6)
bord("summit", 47, 8, 49, 8)
bord("basecamp", 61, 8, 63, 8)
bord("birdhouse", 81, 8, 83, 8)

rect(5, 25, 7, 25, 'T')      # scrumbord_gang: planning (t02) en paarden (t09)
rect(12, 25, 14, 25, 'T')    # ticketbord: opent het echte bord
rect(17, 25, 19, 25, 'm')    # wandmonitor_vloer: staging van t04

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
    # Muur met begaanbare vloer eronder: je kijkt tegen de face aan, dus die
    # krijgt een lichtere voet. Wordt hieronder automatisch afgeleid.
    "F": {"kind": "wall",  "solid": True},
    # Raamlicht op de zuidband: 1 ligt tegen de raamzijde, 3 is de uitdoving.
    "1": {"kind": "floor", "solid": False, "accent": "raamlicht"},
    "2": {"kind": "floor", "solid": False, "accent": "raamlicht_zacht"},
    "3": {"kind": "floor", "solid": False, "accent": "raamlicht_rand"},
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
    # de noordwand achter de koffiecorner, en de speaker van t07
    "k": {"kind": "wall",  "solid": True,  "prop": "kastenwand"},
    "w": {"kind": "wall",  "solid": True,  "prop": "raam"},
    "z": {"kind": "prop",  "solid": True,  "prop": "speaker"},
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
    (1, 15, 4, 24, 'E'),      # entree bij de voordeur — bb-blue, hero-moment
    (10, 1, 36, 6, 'C'),      # koffiecorner — teal, tot net voorbij de tribune
    (43, 1, 53, 6, 'L'),      # Summit — bb-light-blue
    (73, 1, 92, 6, 'L'),      # Birdhouse — bb-light-blue
    (31, 9, 37, 10, 'I'),     # vergaderhokje — bb-pink, nu op de echte binnenmaat
    (97, 1, 128, 24, 'G'),    # Weekend — groen, dichter gestrooid: de jungle
]
for (x0, y0, x1, y1, ch) in ACCENT_ROOMS:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < W and 0 <= y < H and g[y][x] == '.':
                g[y][x] = ch

# ---- Raamlicht: de tegels naast de raamzijde vangen daglicht ----------------
# y25 is de raamzijde. De vloer krijgt daarmee een richting: je ziet aan de
# helderheid welke kant het raam op ligt, ook als er geen raam in beeld is.
# Alleen op neutrale vloer — een accentvloer is al een uitspraak.
#
# Drie rijen en niet twee: de camera klemt verticaal vast (zie game_camera.gd)
# en de knoppenbalk dekt de onderste ~2,5 tegelrij af. Met alleen y24 en y23
# staat het hele effect achter de besturing en ziet niemand het ooit. De twee
# tegels tegen het raam dragen het licht, y22 is de uitdoving die wél in beeld
# staat.
for (rij, ch) in ((H - 2, '1'), (H - 3, '2'), (H - 4, '3')):
    for x in range(W):
        if g[rij][x] == '.':
            g[rij][x] = ch

# ---- Muurfaces: elke muur met vloer eronder toont zijn voorkant -------------
# Afgeleid en niet met de hand gezet: een muur is een face zodra je ertegenaan
# kijkt, en dat volgt uit de plattegrond. Zo kan er geen wand bijkomen die het
# vergeet.
for y in range(H - 1):
    for x in range(W):
        if g[y][x] == '#' and not LEGEND[g[y + 1][x]]["solid"]:
            g[y][x] = 'F'

# ZONES: specifiek vóór algemeen — world_builder.zone_at() geeft de eerste match
ZONES = [
    {"id": "z2_toilet",       "name": "Toiletten",        "rect": [1, 1, 8, 6],      "light": "klinisch"},
    {"id": "z3_patchhok",     "name": "Het Patchhok",     "rect": [1, 8, 8, 13],     "light": "koud"},
    {"id": "z8_hokje",        "name": "Het Vergaderhokje","rect": [30, 8, 38, 11],   "light": "dim"},
    {"id": "z1_entree",       "name": "Entree",           "rect": [1, 14, 4, 24],    "light": "warm"},
    {"id": "z4_koffiecorner", "name": "Koffiecorner",     "rect": [10, 1, 36, 6],    "light": "warm"},
    {"id": "z5_summit",       "name": "Summit",           "rect": [43, 1, 53, 6],    "light": "koel"},
    {"id": "z6_basecamp",     "name": "Basecamp",         "rect": [55, 1, 71, 6],    "light": "neutraal"},
    {"id": "z7_birdhouse",    "name": "Birdhouse",        "rect": [73, 1, 92, 6],    "light": "koel"},
    {"id": "z10_weekend",     "name": "Weekend",          "rect": [97, 1, 128, 24],  "light": "jungle"},
    {"id": "z9_vloer",        "name": "De Vloer",         "rect": [1, 14, 95, 24],   "light": "neutraal"},
    # Vangnet voor de hele open oostkant: de noordband voorbij de koffiecorner
    # (waar de blauwe tijger staat) hoort bij de gang, niet bij een kamer.
    {"id": "z11_gang",        "name": "De Gang",          "rect": [10, 1, 95, 13],   "light": "neutraal"},
]

SPAWN = [2, 17]   # net binnen de voordeur, in de entree

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
