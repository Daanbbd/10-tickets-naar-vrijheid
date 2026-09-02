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
    # Een muur is geen streep maar een blok: een donkere kap bovenop, een
    # zichtbare face eronder en een lichtere voet waar het vloerlicht hem raakt.
    # Zonder die drie banden leest een gesloten ruimte als een lijn.
    "muur":         (72, 78, 96),
    "muur_kap":     (40, 44, 58),
    "muur_top":     (96, 103, 124),
    "muur_voet":    (110, 118, 141),
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
    "ui_grijs":           (138, 138, 138), # #8a8a8a — neutrale derivaat. GEEN tekstkleur:
                                           # 3,1:1 op bb_day, 3,9:1 op ui_panel_donker, 2,7:1 op
                                           # ui_papier — alle drie onder de 4,5:1 van WCAG AA.
                                           # Alleen nog voor niet-tekst: balkvullingen, randen en
                                           # uitgeschakelde knoppen (die vallen buiten 1.4.3).
    # Secundaire tekst. Eén grijs kon dit niet doen: de HUD, de telefoon en de
    # startschermen zijn donker en de minigames zijn licht, dus wat op de een
    # leest verdwijnt op de ander. Vandaar een paar, met de ondergrond in de
    # naam zodat de aanroeper de keuze niet kan overslaan.
    "ui_grijs_op_licht":  (90, 90, 90),    # #5a5a5a — 6,2:1 op bb_day, 5,7:1 op wit,
                                           # 5,7:1 op ui_papier, 4,9:1 op postit_leeg
    # De donkere tegenhanger is `lichtgrijs` hieronder: 6,6:1 op ui_panel_donker,
    # 7,5:1 op bb_night en 4,8:1 op de opgelichte rij van de karakterselectie.
    # Geen nieuwe key, want die kleur bestond al en is precies goed.
    "ui_bluebird_bright": (58, 134, 255),  # #3a86ff — derivaat voor donkere ondergrond (bb_blue is daar te donker om te lezen)
    "ui_groen":           (63, 174, 110),  # #3fae6e — verzadigd derivaat van bb_green, leesbaar op 8-10px
    "ui_rood":            (224, 82, 99),   # #e05263 — game-only utility, BBD heeft geen foutkleur
    "ui_oranje":          (244, 162, 89),  # #f4a259 — verzadigd derivaat van bb_orange, leesbaar op 8-10px
    "ui_neutraal_tint":   (228, 228, 228), # #e4e4e4 — letterlijk --color-line, voor niet-accent states (bv. LOCKED)
    # ui_oranje droeg vier betekenissen tegelijk: doel, vastgezet ticket,
    # overwerk en net-geboekte tijd. Vier dingen in één kleur is geen kleurcode
    # meer. Het doel houdt ui_oranje; de andere drie krijgen hieronder een
    # eigen kleur, elk gekozen op de ondergrond waar hij echt op staat.
    "ui_vastgezet":       (155, 93, 229),  # #9b5de5 — game-only utility: rand om een vastgeprikt ticket. Paars botst met geen enkel postit-papier (geel/roze/blauw/groen/oranje) en niet met de blauwe primaire knop
    "ui_overwerk":        (233, 76, 130),  # #e94c82 — verzadigd derivaat van bb_pink: de klok na vijven. Overwerk gaat over mensen, en bb-pink is bij BBD de mensen/cultuur-kleur
    "ui_geboekt":         (109, 205, 214), # #6dcdd6 — game-only utility: de "+45 min" die net geboekt is. Een registratie-cue, geen waarschuwing, dus koel en niet warm
    # Schermvlakken die geen paneel zijn. Deze stonden als losse hex-literals in
    # zes GDScript-bestanden, en een kleur die maar op één plek bestaat is geen
    # kleur maar een typefout die nog niet is opgevallen.
    "ui_scherm_nacht":    (20, 24, 36),    # #141824 — ondergrond van titel- en uitlegscherm
    "ui_scherm_diep":     (11, 13, 20),    # #0b0d14 — de aftiteling, één tint dieper: de dag is voorbij
    "ui_papier":          (233, 228, 214), # #e9e4d6 — een papieren vlak in een minigame (briefing, promptkaart)
    "ui_vak_leeg":        (43, 49, 68),    # #2b3144 — een ticketvakje dat niet van jou is
    # post-its — tickets zijn briefjes op het scrumbord, geen tabelrijen.
    # De randkleur is een donkerder versie van het papier zelf: een zwarte lijn
    # op 10 px maakt er een formulierveld van.
    "postit_geel":       (247, 226, 138),
    "postit_geel_rand":  (206, 180, 88),
    "postit_leeg":       (222, 218, 208),
    "postit_leeg_rand":  (196, 191, 180),
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
    # Raamlicht op de zuidband: de twee tegels naast de raamzijde vangen het
    # daglicht. Twee stops, want één sprong van vloer naar wit leest als een
    # verfstreep in plaats van als licht.
    "beton_raam":    (206, 205, 199),
    "beton_raam_zacht": (190, 190, 186),
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
