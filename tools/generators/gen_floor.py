#!/usr/bin/env python3
"""Genereert data/floor.json — de enige bron van waarheid voor de kantoorvloer.

Vervang de rect-definities hieronder door de echte plattegrond en draai opnieuw.
Het script valideert bereikbaarheid en looptijden voordat het wegschrijft.
"""
import json, heapq, os, sys

W, H = 80, 26
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
# De echte Bluebird Day-vloer, gelegd naar `assets/office plattegrond - new.png`
# en daarvoor naar `assets/nieuwe assets/schets idee.jpeg`.
#
# De verdieping is van 130 naar 80 tegels ingekort. Reden: de ruimtes waren
# groter dan wat er in het echt in staat -- Birdhouse had twintig tegels en een
# zaal vol stoelen voor een kamer met één bureau en zes stoelen -- en de gang
# ertussen was leeg. docs/PLAN.md F1-b telde 1025 van 2340 beloopbare tegels
# zonder werk erop, en docs/AUDIT.md mat de openingszet op 8,6 s lopen. Korter
# maken lost die twee tegelijk op.
#
# Wat dat kost, expliciet: het gebouw is nu 36,9 x 12,0 m in plaats van
# 60,0 x 12,0. De korte as blijft het anker (12 m over 26 tegels), maar de
# lengte klopt niet meer 1:1 met de ontruimingsplattegrond. De doelwijzer blijft
# wél echte meters tonen; zie LENGTE_COMPRESSIE in world_builder.gd.
#
# Bandindeling (ongewijzigd -- alleen de x-maten zijn anders):
#   y0      buitenwand, binnenzijde -- kastenwand en raam achter de koffiecorner
#   y1-6    west  x1-8 : Toilet
#           oost x11+  : open noordband met de koffiecorner als vrijstaand
#                        eiland, daarna Summit / Basecamp / Birdhouse
#   y7      west: wand tussen toilet en serverhok
#           oost: glas voor de drie vergaderruimtes, open van x11 tot x28
#   y8-13   west  x1-8 : Het Patchhok, direct onder het toilet
#           oost       : De Gang, met het Vergaderhokje op x27-33 en de
#                        grote tafel op x37-63
#   y14-24  west  x1-8 : de lobby -- nieuw, zie hieronder
#           oost x11+  : De Vloer, vijf bureau-eilanden (8-4-4-4-4) en twee
#                        plantenkasten
#   y25     buitenwand, raamzijde
#
# Nieuw t.o.v. de vorige opzet:
# - De entree is een echte lobby geworden. Je komt binnen op de westwand (x0),
#   staat in een afgesloten hal onder het patchhok, en stapt door de binnendeur
#   op x9 de werkvloer op. Daarvoor was de entree een hoek van de open vloer,
#   en merkte je van binnenkomen niets.
# - De scheidingswanden tussen de drie vergaderruimtes zijn glas in plaats van
#   metselwerk. Dat is wat er in het echt staat, en het maakt de noordband in
#   één oogopslag leesbaar in plaats van drie dichte dozen.
# - De koffiecorner staat westelijker en is smaller; de blauwe tijger is
#   daardoor naar de gangmond op y8 verhuisd, waar hij nog steeds het eerste is
#   wat je ziet als je de gang in kijkt.
# - Weekend is van 32 naar 9 tegels. Het is bewust geen speelruimte maar een
#   end-of-map-grap: je kijkt er doorheen, je loopt er even in, en je wordt
#   teruggeduwd.
#
# Eén lange lus, geen doodlopers: de gang loopt door van x11 tot x68, de
# bureauband is een tweede doorlopende baan.
# ---------------------------------------------------------------------------

# De x-remap van de oude 130-brede vloer naar deze. Staat hier omdat het de
# enige plek is waar beide maten samen betekenis hebben; tools/remap_x.py
# importeert hem, zodat de transformatie één definitie heeft en niet twee.
# Let op: dit is een coordinatentransformatie voor objects.json en npcs.json,
# geen beschrijving van deze vloer. Kolom 67-68 is nieuwe gangvloer en heeft
# dus geen oude bron.
X_REMAP = [   # (oud_van, oud_tot, nieuw_van, nieuw_tot)
    (0, 0, 0, 0),        # westwand
    (1, 8, 1, 8),        # toilet / patchhok / lobby -- ongewijzigd
    (9, 9, 9, 9),        # oostwand van het blok, nu met de binnendeur erin
    (10, 41, 11, 28),    # koffiecorner + open gang      32 -> 18
    (42, 42, 29, 29),    # glaswand Summit-west
    (43, 53, 30, 40),    # Summit                        11 -> 11
    (54, 54, 41, 41),    # glazen scheidingswand
    (55, 71, 42, 51),    # Basecamp                      17 -> 10
    (72, 72, 52, 52),    # glazen scheidingswand
    (73, 92, 53, 63),    # Birdhouse                     20 -> 11
    (93, 95, 64, 66),    # schacht
    (96, 96, 69, 69),    # Weekend-glaslijn
    (97, 128, 70, 78),   # Weekend                       32 -> 9
    (129, 129, 79, 79),  # oostwand
]

# alles binnen de buitenwanden is eerst vloer; muren komen er daarna weer in
rect(1, 1, W - 2, H - 2, '.')

# ---- Het westeinde: toilet boven, patchhok eronder, lobby onderaan ---------
# Drie gesloten ruimtes op elkaar, samen één blok tegen de westwand. De oostwand
# loopt van de buitenwand tot de raamzijde door: alles ten westen ervan is
# "binnengekomen maar nog niet op kantoor".
rect(9, 1, 9, 24, '#')        # oostwand van het blok, over de volle hoogte
rect(1, 7, 8, 7, '#')         # wand tussen toilet en patchhok
rect(1, 14, 8, 14, '#')       # wand tussen patchhok en lobby
rect(9, 3, 9, 3, 'D')         # Toilet: één deur voor 8x6 tegels -- dat is de grap
rect(9, 10, 9, 10, 'D')       # Patchhok: één deur, achter de badgelezer
rect(9, 19, 9, 20, 'D')       # de binnendeur: van de lobby naar de werkvloer

# de noordband is verder open; alleen de drie vergaderruimtes staan er dicht
NOORD = [   # (x0, x1, deur-x0, deur-x1)
    # Kleiner dan hiervoor, en naar wat er echt in staat. Birdhouse is niet meer
    # de grootste omdat het de finale is, maar omdat er een boardroomtafel in
    # past; Basecamp is precies vier werkplekken breed.
    (30, 40, 35, 36),    # Summit    11x6 = 14,1 m2
    (42, 51, 46, 46),    # Basecamp  10x6 = 12,8 m2
    (53, 63, 59, 59),    # Birdhouse 11x6 = 14,1 m2
]

# scheidingslijn y7: alleen dicht waar er een ruimte achter zit. Tussen x11 en
# x28 loopt de noordband gewoon door in de gang -- dat is wat de koffiecorner
# tot een eiland maakt in plaats van tot een kamer.
for (x0, x1, d0, d1) in NOORD:
    rect(x0, 7, x1, 7, '=')
    rect(d0, 7, d1, 7, 'D')

# Tussenwanden van de noordband: glas, niet metselwerk. Je kijkt vanaf de gang
# dwars door alle drie de ruimtes heen en ziet in één blik of er iemand zit.
for x in (29, 41, 52):
    rect(x, 1, x, 7, '=')
# de strook tussen Birdhouse en Weekend is dicht: schacht, geen ruimte
rect(64, 1, 66, 7, '#')

# ---- Weekend: eigen hoek achter een glaslijn ----
# Negen tegels, en dat is expres. Dit is geen tweede verdieping om te verkennen
# maar het einde van de kaart: je ziet dat het doorloopt, je mag er even in, en
# main.gd duwt je terug.
rect(69, 1, 69, 24, '=')
rect(69, 11, 69, 14, 'D')

# ---- Noordwand achter de koffiecorner: kastenwand en raam ------------------
rect(11, 0, 11, 0, 'H')       # prikbord met de losse mini-tickets
rect(12, 0, 20, 0, 'k')       # "Kast (Blauw)"
rect(21, 0, 28, 0, 'w')       # "RAAM"

# ---- Voordeur op de westwand: de winconditie ----
rect(0, 15, 0, 17, 'V')

# ---- Trappenhuis: decor achter de ingang, per definitie niet te betreden ----
rect(0, 18, 0, 19, 'X')

# ---- De lobby: waar je binnenkomt en het kantoor nog niet ziet -------------
# Geen balie -- de receptie zit op een andere verdieping. Een scherm, een bank
# en een kapstok, en dan de binnendeur.
rect(0, 20, 0, 21, 'm')        # scherm_entree, in de westwand boven de bank
rect(1, 20, 1, 21, 'c')        # wachtbank: hier zit de klant
rect(8, 16, 8, 17, 'o')        # kapstok tegen de binnenwand

# ---- Toiletgag letterlijk: 2 urinoirs en 1 pot, alles achter één deur ----
rect(1, 2, 1, 2, 'u')
rect(1, 4, 1, 4, 'u')
rect(7, 6, 7, 6, 'W')

# ---- Patchhok: krappe warme techniekkast, direct onder de toiletten ----
prop("serverrack", 3, 9, 4, 12)
prop("serverrack", 6, 9, 7, 12)
rect(8, 12, 8, 12, 'P')        # printer, net binnen de deur

# ---- Koffiecorner: vrijstaand blok, loopruimte rondom ----------------------
# y1 vrij boven, y4-7 vrij onder, x11-12 vrij west, x28 vrij oost.
prop("keukenblok", 12, 2, 16, 3)
rect(17, 2, 17, 3, 'f')        # koelkast, aan het eind van het aanrecht
prop("tribune", 18, 2, 27, 3)
rect(27, 4, 27, 4, 'z')        # de speaker van t07, onder het eind van de tribune

# ---- Summit: één lange tafel op een schaakbordkleed ----
# Was vier losse tafeltjes in een 2x2. In het echt staat er één tafel waar je
# met z'n allen omheen zit, en dat leest ook beter op deze schaal.
rect(30, 2, 30, 4, 'x')        # whiteboard_vergader tegen de westwand
rect(31, 2, 39, 5, 'q')        # schaakbordkleed
prop("vergadertafel", 33, 3, 38, 4)   # één tafel, geen raster van tafeltjes
rect(34, 2, 34, 2, 's')
rect(36, 2, 36, 2, 's')
rect(34, 5, 34, 5, 's')
rect(36, 5, 36, 5, 's')
rect(34, 0, 37, 0, 'm')        # wandscherm, in de noordwand zelf: kost geen vloer

# ---- Basecamp: 4 werkplekken, 2 links en 2 rechts, ronde tafels ertussen ----
rect(42, 2, 43, 3, 'b')
rect(42, 5, 43, 6, 'b')
rect(50, 2, 51, 3, 'b')
rect(50, 5, 51, 6, 'b')
rect(46, 3, 47, 4, 'r')        # de twee ronde tafels in het midden
prop("monitorwand", 45, 1, 48, 1)   # de wand-tv's: dashboardmuur van t06

# ---- Birdhouse: één boardroomtafel tegen de oostwand ----
# Stond hier als zaal met rijen losse krukjes. Er staat in het echt één bureau
# met zes stoelen, en dat is nu ook wat er staat.
prop("boardroomtafel", 56, 3, 62, 4)
rect(57, 2, 57, 2, 's')
rect(59, 2, 59, 2, 's')
rect(61, 2, 61, 2, 's')
rect(57, 5, 57, 5, 's')
rect(59, 5, 59, 5, 's')
rect(61, 5, 61, 5, 's')
rect(59, 0, 62, 0, 'm')        # deploycomputer, in de noordwand zelf

# ---- De Gang: de blauwe tijger, het vergaderhokje en de grote tafel ----
# De tijger stond op y6 in de open ruimte tussen koffiecorner en Summit. Die
# ruimte is er niet meer, dus hij staat nu in de gangmond op y8 -- nog steeds
# het eerste wat je ziet als je de gang in kijkt, en nog verder onder de HUD
# vandaan dan hiervoor.
rect(26, 8, 26, 8, 'Y')

# Vergaderhokje: vrijstaand blok in de gang, onder de koffiecorner. Hier ligt de
# iPad van t08 -- het anker, de zone en de accentvloer vallen samen. De houten
# lamellen zijn de buitenkant die je vanaf de gang ziet.
rect(27, 10, 33, 13, '#')
rect(28, 11, 32, 12, '.')
rect(30, 10, 30, 10, 'D')      # deur naar de gang
rect(27, 11, 27, 12, 'l')      # houten lamellenzijde met de "Samen Bingo"-poster
rect(33, 11, 33, 12, '=')

# De grote tafel begint rechts van het vergaderhokje en loopt door tot het
# einde van Birdhouse. Tussen hokje en tafel blijft ruimte om door te lopen.
prop("tafel_lang", 37, 10, 63, 11)

# ---- De Vloer (raamzijde): bureau-eilanden en plantenkasten ----
# Vijf eilanden en twee plantenkasten, in de volgorde van de plattegrond:
#   8 werkplekken - plantenkast - 4 - 4 - plantenkast - 4 - 4
EILANDEN = [
    (15, 8),   # (x0, aantal werkplekken) -- de hoogte volgt uit het aantal
    (30, 4),
    (39, 4),
    (53, 4),
    (62, 4),
]
for (x0, n) in EILANDEN:
    prop("bureau", x0, 15, x0 + 3, 15 + n - 1)
# Twee op de werkvloer, en een derde als roomdivider in de gang. Die derde staat
# er omdat het stuk gang tussen de koffiecorner en het vergaderhokje anders zes
# bij zestien tegels kaal beton is -- precies wat PLAN.md F1-b als onbeloonde
# vloer aanmerkt. Een plantenkast in een gang is bovendien wat er in het echt
# staat, zie "plantenkast.jpeg".
for (x0, y0, h) in [(22, 15, 8), (47, 15, 6), (19, 8, 6)]:
    prop("plantenkast", x0, y0, x0 + 2, y0 + h - 1)

# ---- Ruimtebordjes: wayfinding die je met je ogen oplost ----
# Ze hangen in de gang, bij de deur van de ruimte die ze aanwijzen. Geen
# footprint: je loopt eronderdoor. Niet hoger dan y6 hangen -- de camera klemt
# verticaal vast en de HUD dekt de bovenste tegelrijen af.
bord("toilet", 10, 6, 12, 6)
bord("summit", 34, 8, 36, 8)
bord("basecamp", 45, 8, 47, 8)
bord("birdhouse", 58, 8, 60, 8)

# Zuidwand, west naar oost. Het scrumbord staat achter het eerste bureau-eiland
# (zie "scrumboard achter bureau.jpeg"), daarna het ticketbord en dan de
# wandmonitor van t04. Ze staan nu allemaal ten oosten van de binnendeur: in de
# lobby horen ze niet, want daar ben je nog niet aan het werk.
rect(11, 25, 13, 25, 'T')    # scrumbord_gang: planning (t02) en paarden (t09)
rect(16, 25, 18, 25, 'T')    # ticketbord: opent het echte bord
rect(21, 25, 23, 25, 'm')    # wandmonitor_vloer: staging van t04

# ---- Weekend: jungle, chaos, en de spullen die hier niemand mist ----
rect(71, 3, 74, 7, 'J')
rect(75, 17, 77, 21, 'J')
rect(71, 12, 74, 13, 't')
rect(76, 4, 78, 5, 'b')
rect(72, 20, 74, 21, 'c')
rect(70, 16, 70, 19, 'j')      # blauw gordijn als divider
rect(77, 22, 78, 23, 'o')
rect(79, 20, 79, 21, 'N')      # spiltrap-uitgang, zie de ontruimingsplattegrond

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
    (1, 15, 8, 24, 'E'),      # lobby bij de voordeur — bb-blue, hero-moment
    (11, 1, 28, 6, 'C'),      # koffiecorner — teal, tot net voorbij de tribune
    (30, 1, 40, 6, 'L'),      # Summit — bb-light-blue
    (53, 1, 63, 6, 'L'),      # Birdhouse — bb-light-blue
    (28, 11, 32, 12, 'I'),    # vergaderhokje — bb-pink, op de echte binnenmaat
    (70, 1, 78, 24, 'G'),     # Weekend — groen, dichter gestrooid: de jungle
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
# ZONES: specifiek vóór algemeen — world_builder.zone_at() geeft de eerste match
ZONES = [
    {"id": "z2_toilet",       "name": "Toiletten",        "rect": [1, 1, 8, 6],      "light": "klinisch"},
    {"id": "z3_patchhok",     "name": "Het Patchhok",     "rect": [1, 8, 8, 13],     "light": "koud"},
    {"id": "z8_hokje",        "name": "Het Vergaderhokje","rect": [27, 10, 33, 13],  "light": "dim"},
    {"id": "z1_entree",       "name": "Entree",           "rect": [1, 15, 8, 24],    "light": "warm"},
    {"id": "z4_koffiecorner", "name": "Koffiecorner",     "rect": [11, 1, 28, 6],    "light": "warm"},
    {"id": "z5_summit",       "name": "Summit",           "rect": [30, 1, 40, 6],    "light": "koel"},
    {"id": "z6_basecamp",     "name": "Basecamp",         "rect": [42, 1, 51, 6],    "light": "neutraal"},
    {"id": "z7_birdhouse",    "name": "Birdhouse",        "rect": [53, 1, 63, 6],    "light": "koel"},
    {"id": "z10_weekend",     "name": "Weekend",          "rect": [70, 1, 78, 24],   "light": "jungle"},
    {"id": "z9_vloer",        "name": "De Vloer",         "rect": [1, 14, 68, 24],   "light": "neutraal"},
    # Vangnet voor de hele open oostkant: de noordband voorbij de koffiecorner
    # (waar de blauwe tijger staat) hoort bij de gang, niet bij een kamer.
    {"id": "z11_gang",        "name": "De Gang",          "rect": [10, 1, 68, 13],   "light": "neutraal"},
]

SPAWN = [2, 17]   # in de lobby, net binnen de voordeur

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
    return free, unreach, worst, solid, d0

# ---- de vloer tegen de rest van data/ houden -------------------------------
# Deze checks stonden alleen in scripts/tests/test_runner.gd. Dat betekende dat
# een vloer met verschoven coordinaten pas na een Godot-run zichtbaar werd, en
# dan als honderd failures tegelijk. Hier kosten ze een seconde en noemen ze
# precies welk object, welke NPC-stap en welk ticketanker is gestrand — dat is
# de worklist, niet de schade.

def _data(*p):
    return os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "data", *p))

def _laad(*p):
    with open(_data(*p), encoding="utf-8") as f:
        return json.load(f)

def zone_at(x, y):
    """Port van world_builder.gd zone_at(): eerste treffer wint, dus de
    volgorde van ZONES is betekenisdragend."""
    for z in ZONES:
        a, b, c, d = z["rect"]
        if a <= x <= c and b <= y <= d:
            return z["id"]
    return ""

def _tegel_ok(t, solid, bereik):
    p = (int(t[0]), int(t[1]))
    if not (0 <= p[0] < W and 0 <= p[1] < H):
        return "ligt buiten de vloer"
    if p in solid:
        return "staat in een muur of meubel"
    if p not in bereik:
        return "is onbereikbaar vanaf de spawn"
    return None

def controleer_data(solid, bereik):
    klachten = []

    objecten = _laad("objects.json")
    wereld_ids = set(_laad("world_ids.json"))

    # 1 + 5: elk object op een begaanbare, bereikbare tegel met een bekend id
    for o in objecten:
        wid = o["world_id"]
        fout = _tegel_ok(o["tile"], solid, bereik)
        if fout:
            klachten.append("object '%s' op %s %s" % (wid, o["tile"], fout))
        if wid not in wereld_ids:
            klachten.append("object '%s' staat niet in world_ids.json" % wid)

    # 6: de winconditie. main.gd vuurt hem als de speler het voordeur-object
    # gebruikt, maar alleen de 'V'-tegel is de echte uitgang. Verhuist de deur
    # wel en het object niet, dan is het spel stil onuitspeelbaar en vangt
    # alleen een volledige playthrough dat. Dus hard.
    per_id = {o["world_id"]: o for o in objecten}
    uitgangen = {(x, y) for y in range(H) for x in range(W)
                 if LEGEND[g[y][x]]["kind"] == "exit"}
    if "voordeur" in per_id:
        vx, vy = per_id["voordeur"]["tile"]
        if not any((vx + dx, vy + dy) in uitgangen
                   for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1))):
            klachten.append(
                "object 'voordeur' op (%d,%d) ligt niet naast een exit-tegel — "
                "de winconditie in main.gd kan nooit vuren" % (vx, vy))

    # 2: NPC's staan stil op hun home_tile en lopen hun route echt af
    for n in _laad("npcs.json"):
        fout = _tegel_ok(n["home_tile"], solid, bereik)
        if fout:
            klachten.append("NPC '%s' home_tile %s %s" % (n["id"], n["home_tile"], fout))
        for i, wp in enumerate(n.get("route", [])):
            fout = _tegel_ok(wp, solid, bereik)
            if fout:
                klachten.append("NPC '%s' route[%d] %s %s" % (n["id"], i, wp, fout))

    # 3: een ticketanker moet in de zone liggen die het ticket zelf noemt.
    # Precies de bug die vorige ronde met de hand gevonden is (t08).
    tdir = _data("tickets")
    for naam in sorted(os.listdir(tdir)):
        if not naam.endswith(".json"):
            continue
        t = _laad("tickets", naam)
        anker, zone = t.get("anchor"), t.get("zone")
        if not anker or not zone:
            continue
        if anker not in per_id:
            klachten.append("ticket %s ankert op '%s', dat geen object is" % (t["id"], anker))
            continue
        ax, ay = per_id[anker]["tile"]
        echt = zone_at(ax, ay)
        if echt != zone:
            klachten.append(
                "ticket %s zegt zone '%s', maar anker '%s' op (%d,%d) ligt volgens zone_at() in '%s'"
                % (t["id"], zone, anker, ax, ay, echt or "geen zone"))

    # 4: een zone moet binnen de vloer vallen en ook echt beloopbaar zijn
    for z in ZONES:
        a, b, c, d = z["rect"]
        if not (0 <= a <= c < W and 0 <= b <= d < H):
            klachten.append("zone '%s' rect %s valt buiten de vloer %dx%d" % (z["id"], z["rect"], W, H))
            continue
        if not any((x, y) not in solid for y in range(b, d + 1) for x in range(a, c + 1)):
            klachten.append("zone '%s' heeft geen enkele begaanbare tegel" % z["id"])

    # 7: twee props op dezelfde tegel betekent twee sprites over elkaar. De
    # rects zijn met de hand geplaatst, dus dit is makkelijk mis te gaan.
    vast = [p for p in PROPS if not p.get("hangend")]
    for i, p in enumerate(vast):
        ax0, ay0, ax1, ay1 = p["rect"]
        for q in vast[i + 1:]:
            bx0, by0, bx1, by1 = q["rect"]
            if ax0 <= bx1 and bx0 <= ax1 and ay0 <= by1 and by0 <= ay1:
                klachten.append("props '%s' %s en '%s' %s overlappen"
                                % (p["prop"], p["rect"], q["prop"], q["rect"]))

    return klachten

def losse_meubels(objecten):
    """Objecten die naar een meubel vernoemd zijn maar er niet naast liggen.

    Zacht, geen afkeuring: het meubel kan een samengestelde prop zijn in plaats
    van een enkel legenda-teken, en dan klopt de tegel wel maar het teken niet.
    Bruikbaar als handleiding bij het verplaatsen, niet als poort.
    """
    per_id = {o["world_id"]: o for o in objecten}
    prop_bij = {}
    for p in PROPS:
        stam = p["prop"].rsplit("_", 1)[0]
        prop_bij.setdefault(stam, []).append(p["rect"])
    los = []
    for ch, info in LEGEND.items():
        naam = info.get("prop")
        if naam not in per_id:
            continue
        ox, oy = per_id[naam]["tile"]
        buren = [(ox, oy), (ox - 1, oy), (ox + 1, oy), (ox, oy - 1), (ox, oy + 1)]
        if any(0 <= x < W and 0 <= y < H and g[y][x] == ch for x, y in buren):
            continue
        if any(x0 - 1 <= ox <= x1 + 1 and y0 - 1 <= oy <= y1 + 1
               for x0, y0, x1, y1 in prop_bij.get(naam, [])):
            continue
        if not any(g[y][x] == ch for y in range(H) for x in range(W)):
            los.append("'%s' op (%d,%d): teken '%s' staat nergens op de vloer" % (naam, ox, oy, ch))
        else:
            los.append("'%s' op (%d,%d) ligt niet naast zijn '%s'-tegel" % (naam, ox, oy, ch))
    return los


def main():
    alleen_vloer = "--alleen-vloer" in sys.argv
    free, unreach, worst, solid, bereik = validate()
    ok = not unreach
    print(f"begaanbare tegels : {len(free)}")
    print(f"onbereikbaar      : {len(unreach)} {unreach[:12]}")
    print(f"verste punt       : {worst:.1f} tiles = {worst / WALK_SPEED_TILES:.1f}s lopen")
    if not ok:
        print("AFGEKEURD: onbereikbare vloertegels.", file=sys.stderr)
        sys.exit(1)

    klachten = controleer_data(solid, bereik)
    if klachten:
        kop = "WAARSCHUWING" if alleen_vloer else "AFGEKEURD"
        print(f"{kop}      : {len(klachten)} punten uit data/ passen niet op deze vloer",
              file=sys.stderr)
        for k in klachten:
            print("  - " + k, file=sys.stderr)
        if not alleen_vloer:
            print("Draai met --alleen-vloer om de vloer toch te schrijven en deze lijst "
                  "als worklist te gebruiken.", file=sys.stderr)
            sys.exit(1)
    else:
        print("data/ tegen vloer : alles past")

    los = losse_meubels(_laad("objects.json"))
    if los:
        print("los van hun meubel : %d (zacht, ter info)" % len(los))
        for l in los:
            print("  ~ " + l)

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
