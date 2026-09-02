# De vloer

**Eén verdieping van Bluebird Day, overgenomen uit de echte plattegrond.** De
referenties staan in `assets/nieuwe assets/`: een handschets met alle ruimtenamen,
een foto van de officiële ontruimingsplattegrond, en zeven foto's die de art
direction vastleggen.

## Verhouding

Opgemeten op de ontruimingsplattegrond: buitenwanden op x≈544 en x≈868,
boven- en onderwand op y≈310 en y≈1930 → **≈5,06 : 1**. Het spel gebruikt
**130 × 26 tegels** = 2080 × 416 px, dus 5,0 : 1.

De schets is dezelfde vloer 90° tegen de klok in gedraaid: schets-links =
plan-boven (toiletten, serverhok, entree), schets-boven = plan-rechts (de
gesloten ruimtes), schets-rechts = plan-onder (Weekend, spiltrap). Beide
referenties zijn consistent: open werkvloer aan de raamzijde, gesloten ruimtes
aan de binnenzijde, één circulatieband ertussen.

Op de schets staan met rood vier aanwijzingen die de indeling vastleggen en die
je in de tekening zelf makkelijk mist: **SERVER HOK** onder het toilet, **Kast
(Blauw)** en **RAAM** op de noordwand achter de koffiecorner, en de pijlen
"Ingang zit hier" (westwand, ónder het toiletblok) en "Scrumbord hangt hier"
(zuidwestkant, achter het eerste bureau-eiland).

## Vorm: een strook, één lange lus

De oude vloer was een verzonnen *ring* om een dichte kern. Die kern bestaat niet.
Wat er wel is:

| Band | y | West (x1–8) | Oost (x10–95) |
|---|---|---|---|
| buitenwand | 0 | | kastenwand `k` en raam `w` achter de koffiecorner |
| noordband | 1–6 | Toilet | open, met de **Koffiecorner als vrijstaand eiland**, dan Summit · Basecamp · Birdhouse |
| scheidingslijn | 7 | wand tussen toilet en serverhok | glas vóór de drie vergaderruimtes; **open van x10 tot x41** |
| circulatieband | 8–13 | Het Patchhok | De Gang, met het Vergaderhokje op x30–38 en de grote tafel met planten op x55–92 |
| open werkvloer | 14–24 | Entree bij de voordeur | De Vloer: vijf bureau-eilanden en twee plantenkasten, raamzijde |
| buitenwand | 25 | | |

Geen doodlopers: de gang loopt door van x10 tot x95 en de bureauband is een
tweede doorlopende baan. Samen één lange lus. Weekend ligt achter een glaslijn
op x96 met een brede opening op y10–15.

Het glas op y7 vóór Summit, Basecamp en Birdhouse is het wayfinding-wapen: je
blijft de drie vergaderruimtes door de hele gang zien.

### Toilet en serverhok zijn gestapeld, niet naast elkaar

Ze stonden náást elkaar in de noordband (Patchhok x6–9, Toilet x11–15). Op de
schets zijn het twee ruimtes op elkaar aan het westeinde: toilet boven
(x1–8, y1–6), Patchhok eronder (x1–8, y8–13), met de scheidingswand op y7 en
één deur per ruimte in de oostwand op x9. De **ingang zit op de westwand
daaronder**, in de bureauband — vandaar dat de Entree nu op y14–24 ligt en niet
meer in de gang.

Het trappenhuis is vervallen. Het vulde de noordwesthoek die nu het toilet is,
het was per definitie niet te betreden, en de schets kent het niet. Legenda-teken
`X` is daarmee weg.

### De koffiecorner is een eiland, geen kamer

Hij was een gesloten ruimte tegen de noordwand (x17–34, y1–6): je kon er per
definitie niet omheen lopen, terwijl dat het enige is wat een *corner* van een
kamer onderscheidt. Nu is het één solide blok op x18–33, y2–3 —
`keukenblok_5x2` · koelkast · `tribune_10x2`, met de speaker van t07 tegen het
oosteinde — met loopruimte aan alle vier de kanten: y1 boven, y4–y7 onder,
x10–17 west, x34–41 oost. Op de buitenwand erachter staan de kastenwand (`k`,
donkerblauw, met de bank ervoor) en het raam (`w`), precies waar de schets ze
rood aanwijst.

### Het vergaderhokje stond op de verkeerde plek

Het hokje stond op x44–50, maar `ACCENT_ROOMS` had nog een regel op
`(31, 8, 37, 9)` met het commentaar `# "vergaderhokje"` — en daar, op x31–36,
lagen ook `hokje_ipad` (het **anker van t08**), `hokje_telefoon` en
`samen_bingo_poster`. Het anker lag dus buiten de zone die het ontdekt. Het
hokje staat nu op x30–38, y8–11 waar de schets het zet; anker, zone en
accentvloer vallen daarmee weer samen.

## Zones (11)

`world_builder.zone_at()` geeft de **eerste** match terug, dus de volgorde in
`ZONES` is specifiek vóór algemeen: `z1_entree` staat vóór `z9_vloer` (anders
wordt de entree "De Vloer") en `z8_hokje` vóór `z11_gang`. `z11_gang` is het
vangnet voor de hele open oostkant, inclusief de noordband voorbij de
koffiecorner waar de blauwe tijger staat.

| id | naam | rect | licht |
|---|---|---|---|
| `z2_toilet` | Toiletten | 1,1 – 8,6 | klinisch |
| `z3_patchhok` | Het Patchhok | 1,8 – 8,13 | koud |
| `z8_hokje` | Het Vergaderhokje | 30,8 – 38,11 | dim |
| `z1_entree` | Entree | 1,14 – 4,24 | warm |
| `z4_koffiecorner` | Koffiecorner | 10,1 – 36,6 | warm |
| `z5_summit` | Summit | 43,1 – 53,6 | koel |
| `z6_basecamp` | Basecamp | 55,1 – 71,6 | neutraal |
| `z7_birdhouse` | Birdhouse | 73,1 – 92,6 | koel |
| `z10_weekend` | Weekend | 97,1 – 128,24 | jungle |
| `z9_vloer` | De Vloer | 1,14 – 95,24 | neutraal |
| `z11_gang` | De Gang | 10,1 – 95,13 | neutraal |

Elk van de tien ticketankers ligt in de zone die het ticket noemt. Dat gold niet
voor t08 (zie hierboven) en is geen toeval meer: wie een anker verplaatst, moet
de zone controleren, want de ontdekking hangt aan de zone en de interactie aan
het object.

De `light`-waarde wordt gelezen door `main.gd._tint_zone()` en getween'd op een
`CanvasModulate`. **Houd de waarden subtiel** (±2–4%): sterker en de grijze
betonvloer wordt zichtbaar bruin of blauw, en dan klopt het beeld niet meer met
de foto's.

## De drie vergaderruimtes zijn mechanisch verschillend

| Ruimte | x | Inrichting | Ticket |
|---|---|---|---|
| Summit | 43–58 | kleine tafel met 4 witte kuipstoelen op een zwart-wit schaakbordkleed; whiteboard op de noordwand | t01 |
| Basecamp | 60–75 | 4 werkplekken langs de wanden + ronde tafel in het midden; wand-tv's | t06 |
| Birdhouse | 77–92 | grote witte tafel met stoelen rondom; deploymentcomputer | t10 |

Summit is klein en leeg (overleg), Basecamp is halfbezet (je kunt er iemand
aantreffen), Birdhouse is de grote zaal voor de finale.

## De toiletgag

Één deur op x9,y3 voor de hele ruimte van 8 × 6 tegels, met twee urinoirs tegen
de westwand en één pot tegen de zuidwand. De absurde leegte **is** de grap.

## Art direction

Uit de foto's: **gepolijst beton** (koel grijs — niet het warme tapijt van de
oude vloer), grofkorrelig spuitplafond, zwart plafond boven de vergaderruimtes,
donkerblauwe kastenwand, teal tribune-trap met kussens plus Jura en DIA-awards,
glaswanden met witte organische print, houten lamellen, zwart-wit
schaakbordvloerkleed, de **blauwe tijger** als landmark in de gang, de "Samen
Bingo"-poster op de houten zijde van het vergaderhokje, blauwe gordijnen als
divider, plantenkast met klimop, clown en **speelgoedpaard**.

Tien legenda-letters uit die ronde: `u` urinoir · `R` tribune · `n` plantenkast ·
`l` lamellenwand · `j` gordijn · `Y` blauwe tijger · `J` jungle · `q`
schaakbordkleed · `s` kuipstoel · `r` ronde tafel. Plus `C` als teal
accentvloer voor de koffiecorner.

Daar kwamen bij, met de vrijstaande koffiecorner: `k` donkerblauwe kastenwand
met bank · `w` raam · `z` speaker. Alle drie staan ze óók in `CHARS` in
`gen_tiles.py` — zonder atlas-coördinaat rendert een nieuw teken stil als
gewone vloer.

## Looptijden

`gen_floor.py` valideert bereikbaarheid en print de looptijden vóór het
wegschrijven. Huidige stand:

| | |
|---|---|
| begaanbare tegels | 2404 |
| onbereikbaar | 0 (het script weigert te schrijven bij >0) |
| verste punt vanaf spawn | 140,5 tegels = **23,4 s lopen** |

Dat is de prijs van de echte verhouding (was 14,6 s op de vierkante verzonnen
vloer), plus de verhuizing van het spawnpunt naar de voordeur in de zuidwesthoek.
Wil je dat omlaag brengen, dan moet **`WALK_SPEED` in
`scripts/entities/player.gd`** omhoog. `WALK_SPEED_TILES` in `gen_floor.py`
moet dan mee: dat getal staat er alleen voor de looptijden die het script
print. Het stond ook als `walk_speed_tiles_per_sec` in `floor.json` en werd
daar door niets gelezen — die dode kopie is weg.

## Alles komt uit de generator

`tools/generators/gen_floor.py` is de enige bron van waarheid voor `data/floor.json`.
Bewerk `floor.json` **nooit** met de hand: de volgende run draait het stil terug.
`world_builder.gd` is volledig data-driven en leest elke legenda-letter uit
`assets/tilesets/office_atlas.json`, dus nieuwe tegels vragen geen GDScript.

> Een nieuw legenda-teken zonder atlas-coördinaat rendert **stil** als gewone
> vloer: `world_builder._coord_for()` geeft `Vector2i(0,0)` terug voor onbekende
> tekens. Voeg elke nieuwe letter ook toe aan `CHARS` in `gen_tiles.py`.

> Een gewijzigde `office_atlas.png` moet door de editor opnieuw geïmporteerd
> worden (`Godot --headless --path . --editor --quit`). Headless kan dat niet, en
> zonder reimport faalt `build_tileset()` op tegels buiten de oude atlasbreedte.

## Schaal

Ankermaat: de verdieping is over de korte as **12 meter** breed. Die as is 26
tegels, dus `M_PER_TILE = 12/26 = 0,4615`. Het gebouw is daarmee 60,0 × 12,0 m en
exact **5,00 : 1** — tegen de 5,06 : 1 die op de ontruimingsplattegrond is
opgemeten. 1,2% verschil, dus de schaal klopt.

Gebruik `tiles(meters)` en `m2(w, h)` uit `gen_floor.py` voor elke nieuwe maat.
**Niet meer op gevoel kiezen.**

| Ruimte | Tegels | m² |
|---|---|---|
| Toiletten | 8 × 6 | 10,2 |
| Het Patchhok | 8 × 6 | 10,2 |
| Koffiecorner (het eiland zelf) | 16 × 2 | 6,8 |
| **Summit** | 11 × 6 | **14,1** — klein en leeg |
| **Basecamp** | 17 × 6 | **21,7** — hybride werk/overleg |
| **Birdhouse** | 20 × 6 | **25,6** — de grote zaal |
| Het Vergaderhokje | 9 × 4 | 7,7 |

De drie vergaderruimtes zijn nu ook in tegels merkbaar verschillend, niet alleen
in de tekst.

## Samengestelde meubels: tegel doet collision, sprite doet beeld

Een legenda-teken is altijd precies één vaste 16×16-tegel. Een meubel van 16
tegels breed met `rect()` vullen geeft daarom zestien keer hetzelfde plaatje —
een mozaïek in plaats van één object.

Daarom: **`prop(naam, x0, y0, x1, y1)`** in `gen_floor.py`.

1. De footprint wordt gevuld met `_`, een **volledig transparante maar solide**
   tegel. De collision komt uit de `TileData`-polygon, niet uit de pixels, dus
   `world_builder.is_solid()` en de bereikbaarheidsvalidatie blijven ongemoeid.
   De `Ground`-laag eronder levert de vloer.
2. Het object wordt geregistreerd in `floor.json` onder `"props"`.
3. `main.gd::_spawn_props()` zet er één `Sprite2D` op, met de PNG uit
   `assets/sprites/props/` — gegenereerd door `gen_props.py` op vrije
   pixelmaat.

De **naam bevat de maat** (`bureau_16x2`), want de runtime schaalt niets: de PNG
moet exact op de footprint passen.

> Zou `_` vloer tekenen in plaats van transparant te zijn, dan dekt die tegel de
> sprite af — `Solid` heeft `y_sort_enabled` en zijn tegels sorteren dus
> individueel, waardoor ze bóven een sprite met een lagere y kunnen landen.

**De sprite mag groter zijn dan zijn footprint** — `_spawn_props()` centreert hem
erop. Zo staan de bureaustoelen buiten het blok, op beloopbare vloer: je loopt
naar een stoel toe, je botst er niet tegenaan.

### Bureau-eilanden staan een kwartslag gedraaid

Zoals in `schets idee.jpeg`: **vijf** blokken die de diepte in staan, met een
verticaal privacyscherm door het midden en twee kolommen werkplekken die naar
elkaar toe kijken — niet tien lange horizontale stroken. De hoogte volgt uit het
aantal werkplekken (`bureau_4x8` = 8 plekken, `bureau_4x4` = 4).

Volgorde in de zuidband, uit de schets:
8 werkplekken · plantenkast · 4 · 4 · plantenkast · 4 · 4.

Het vierde eiland stond hier lang op 8. De schets telt er vier, en met vier
plekken past de loopruimte naar de grote tafel met planten er weer naast.

### Omgezet

`bureau_4x4` (4×) · `bureau_4x8` · `plantenkast_3x6` · `plantenkast_3x8` ·
`tafel_lang_38x2` · `monitorwand_4x1` · `tribune_10x2` · `keukenblok_5x2` ·
`serverrack_2x4` (2×) — samen 13 geplaatste objecten.

Nog als `rect()`-vulling (allemaal klein genoeg dat één tegel volstaat, of nog
niet gedaan): whiteboard, ticketbord, bank, gordijn, kast, koelkast, prikbord,
urinoir, lamellen, jungle, kuipstoel, ronde tafel, kastenwand, raam, speaker.

## Objecten en NPC's

`data/objects.json` (42 objecten) en `data/npcs.json` (11 NPC's) staan op
absolute tegels. De testsuite is de vangrail: `_test_wereld` faalt op elk object
of NPC dat op een solide tegel staat, op **elke route-waypoint** die dat doet,
op elk object dat niet in `data/world_ids.json` voorkomt, en op een spawnpunt in
een muur.

Een hertekening van de vloer raakt dus altijd deze twee bestanden. Bij de
herindeling naar de schets verhuisden 26 objecttegels en zes NPC-routes mee;
het spawnpunt ging van `[2, 11]` (oude gang) naar `[2, 17]`, net binnen de
voordeur in de Entree — waar `wachtbank`, het anker van t03, nog steeds het
eerste is wat je tegenkomt.

Tickets ankeren op `world_id`, nooit op coördinaten. Daarom overleeft de
`--playthrough`-harnas een hertekening ongewijzigd: hij teleporteert naar
`t.anchor`, niet naar een tegel.
