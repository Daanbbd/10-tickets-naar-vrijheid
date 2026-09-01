"""Gedeeld palet voor alle gegenereerde pixel-art. Eén bron van waarheid."""

P = {
    # basis
    "zwart":      (26, 24, 32),
    "inkt":       (43, 44, 58),
    "schaduw":    (62, 64, 82),
    "grijs":      (124, 128, 145),
    "lichtgrijs": (176, 180, 194),
    "wit":        (238, 240, 244),
    # vloer / kantoor
    "tapijt":       (150, 141, 128),
    "tapijt_licht": (166, 157, 143),
    "tapijt_donker":(130, 122, 111),
    "beton":        (188, 186, 180),
    "muur":         (72, 78, 96),
    "muur_top":     (96, 103, 124),
    "plint":        (54, 59, 74),
    # hout / meubels
    "hout":        (150, 103, 66),
    "hout_licht":  (176, 128, 87),
    "hout_donker": (112, 76, 48),
    "bureaublad":  (206, 200, 188),
    # merk — BBD huisstijl (Bluebird Day "Thema 2025"), letterlijke tokens.
    # Alleen als accent gebruiken, nooit als volledig vlak of lopende tekst —
    # zelfde regel als in colors_and_type.css.
    "bb_day":        (243, 243, 243),  # #F3F3F3 — primaire ondergrond
    "bb_night":      (36, 36, 36),     # #242424 — primaire inkt
    "bb_blue":       (36, 60, 236),    # #243CEC — accent, CTA's/focus
    "bb_light_blue": (219, 233, 255),  # #DBE9FF
    "bb_orange":     (247, 214, 194),  # #F7D6C2
    "bb_pink":       (255, 206, 227),  # #FFCEE3
    "bb_green":      (216, 255, 224),  # #D8FFE0
    # UI — game-chrome, afgeleid van bb_* (bron voor
    # tools/generators/gen_ui_kit_colors.py -> scripts/ui/ui_kit.gd). Losse
    # keys, niet gedeeld met de wereld-accenten hieronder, want UI-widgets op
    # 8-10px hebben andere contrasteisen dan pixel-art props/tegels.
    "ui_panel_donker":    (46, 46, 46),    # #2e2e2e — neutrale derivaat, INK/PANEL-grijsfamilie
    "ui_line":            (74, 74, 74),    # #4a4a4a — neutrale derivaat
    "ui_grijs":           (138, 138, 138), # #8a8a8a — neutrale derivaat
    "ui_bluebird_bright": (58, 134, 255),  # #3a86ff — derivaat voor donkere ondergrond (bb_blue is daar te donker om te lezen)
    "ui_groen":           (63, 174, 110),  # #3fae6e — verzadigd derivaat van bb_green, leesbaar op 8-10px
    "ui_rood":            (224, 82, 99),   # #e05263 — game-only utility, BBD heeft geen foutkleur
    "ui_oranje":          (244, 162, 89),  # #f4a259 — verzadigd derivaat van bb_orange, leesbaar op 8-10px
    "ui_neutraal_tint":   (228, 228, 228), # #e4e4e4 — letterlijk --color-line, voor niet-accent states (bv. LOCKED)
    # accenten
    "groen":      (67, 170, 139),
    "groen_donker":(42, 120, 96),
    "rood":       (224, 82, 99),
    "oranje":     (244, 162, 89),
    "geel":       (245, 215, 110),
    "paars":      (155, 93, 229),
    "cyaan":      (122, 209, 192),
    # het echte kantoor — uit assets/nieuwe assets/
    # De vloer is gepolijst beton, koel grijs, niet het warme tapijt van de
    # verzonnen vloer. Dit is de grootste enkele reden dat het beeld op het
    # echte kantoor gaat lijken.
    "beton_vloer":   (174, 174, 171),
    "beton_licht":   (186, 186, 183),
    "beton_donker":  (156, 157, 156),
    "teal":          (94, 158, 163),   # tribune-trap koffiecorner
    "teal_licht":    (122, 184, 188),
    "marine":        (34, 48, 80),     # donkerblauwe kastenwand
    "wit_kast":      (240, 238, 234),  # plantenkast / witte tafels
    "klimop":        (98, 132, 74),
    "klimop_donker": (66, 96, 56),
    # planten / glas
    "blad":       (76, 140, 74),
    "blad_donker":(48, 100, 52),
    "pot":        (168, 96, 72),
    "glas":       (150, 200, 220),
    "glas_rand":  (206, 232, 240),
}

# "bluebird*" zijn afgeleiden van het echte bb_blue-merktoken, geen losstaande
# kleuren meer. donker/licht zijn niet zelfverzonnen tinten maar de officiële
# gradient-stops uit colors_and_type.css (--bb-gradient-blue en
# --bb-gradient-blue-wide) — dezelfde blauwfamilie die BBD zelf al gebruikt
# voor donkere/lichte varianten van bb-blue.
P["bluebird"]        = P["bb_blue"]     # #243CEC, letterlijk
P["bluebird_donker"] = (26, 43, 173)    # #1A2BAD — gradient-blue dark stop
P["bluebird_licht"]  = (107, 139, 255)  # #6B8BFF — gradient-blue-wide mid stop

def rgba(name, a=255):
    r, g, b = P[name]
    return (r, g, b, a)
