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
plan-boven (entree, trappenhuis, toiletten), schets-boven = plan-rechts (de
gesloten ruimtes), schets-rechts = plan-onder (Weekend, spiltrap). Beide
referenties zijn consistent: open werkvloer aan de raamzijde, gesloten ruimtes
aan de binnenzijde, één circulatieband ertussen.

## Vorm: een strook, één lange lus

De oude vloer was een verzonnen *ring* om een dichte kern. Die kern bestaat niet.
Wat er wel is:

| Band | y | Inhoud |
|---|---|---|
| buitenwand | 0 | |
| gesloten ruimtes | 1–6 | Toilet · Patchhok · Koffiecorner · Summit · Basecamp · Birdhouse |
| scheidingslijn | 7 | glas vóór de drie vergaderruimtes, wand met deuropening vóór de rest |
| circulatieband | 8–13 | De Gang, met het vrijstaande Vergaderhokje en de grote tafel met planten |
| open werkvloer | 14–24 | De Vloer: vijf bureau-eilanden en twee plantenkasten, raamzijde |
| buitenwand | 25 | |

Geen doodlopers: de gang loopt door van x1 tot x95 en de bureauband is een tweede
doorlopende baan. Samen één lange lus. Weekend ligt achter een glaslijn op x96
met een brede opening op y10–15.

Het glas op y7 vóór Summit, Basecamp en Birdhouse is het wayfinding-wapen: je
blijft de drie vergaderruimtes door de hele gang zien. Toilet, Patchhok en
Koffiecorner hebben een dichte wand met een deuropening.

## Zones (11)

`world_builder.zone_at()` geeft de **eerste** match terug, dus de volgorde in
`ZONES` is specifiek vóór algemeen: `z1_entree` staat vóór `z11_gang`, anders
wordt de entree "De Gang".

| id | naam | licht |
|---|---|---|
| `z1_entree` | Entree | warm |
| `z2_toilet` | Toiletten | klinisch |
| `z3_patchhok` | Het Patchhok | koud |
| `z4_koffiecorner` | Koffiecorner | warm |
| `z5_summit` | Summit | koel |
| `z6_basecamp` | Basecamp | neutraal |
| `z7_birdhouse` | Birdhouse | koel |
| `z8_hokje` | Het Vergaderhokje | dim |
| `z10_weekend` | Weekend | jungle |
| `z9_vloer` | De Vloer | neutraal |
| `z11_gang` | De Gang | neutraal |

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

Één deur op x9,y7 voor de hele ruimte van 15 × 6 tegels, met twee urinoirs tegen
de westwand en één pot tegen de zuidwand. De absurde leegte **is** de grap.

## Art direction

Uit de foto's: **gepolijst beton** (koel grijs — niet het warme tapijt van de
oude vloer), grofkorrelig spuitplafond, zwart plafond boven de vergaderruimtes,
donkerblauwe kastenwand, teal tribune-trap met kussens plus Jura en DIA-awards,
glaswanden met witte organische print, houten lamellen, zwart-wit
schaakbordvloerkleed, de **blauwe tijger** als landmark in de gang, de "Samen
Bingo"-poster op de houten zijde van het vergaderhokje, blauwe gordijnen als
divider, plantenkast met klimop, clown en **speelgoedpaard**.

Tien nieuwe legenda-letters: `u` urinoir · `R` tribune · `n` plantenkast ·
`l` lamellenwand · `j` gordijn · `Y` blauwe tijger · `J` jungle · `q`
schaakbordkleed · `s` kuipstoel · `r` ronde tafel. Plus `C` als teal
accentvloer voor de koffiecorner.

## Looptijden

`gen_floor.py` valideert bereikbaarheid en print de looptijden vóór het
wegschrijven. Huidige stand:

| | |
|---|---|
| begaanbare tegels | 2231 |
| onbereikbaar | 0 (het script weigert te schrijven bij >0) |
| verste punt vanaf spawn | 131,6 tegels = **21,9 s lopen** |

Dat is de prijs van de echte verhouding (was 14,6 s op de vierkante verzonnen
vloer). Wil je dat omlaag brengen, dan moet **`WALK_SPEED` in
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
| Toiletten | 5 × 6 | 6,4 |
| Het Patchhok | 4 × 6 | 5,1 |
| Koffiecorner | 18 × 6 | 23,0 |
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
8 werkplekken · plantenkast · 4 · 4 · plantenkast · 8 · 4.

### Omgezet

`bureau_4x4` · `bureau_4x8` · `plantenkast_3x6` · `plantenkast_3x8` ·
`tafel_lang_26x2` · `monitorwand_4x1` · `tribune_10x2` · `keukenblok_5x1` ·
`balie_5x1` · `serverrack_2x4` — samen 13 geplaatste objecten.

Nog als `rect()`-vulling (allemaal klein genoeg dat één tegel volstaat, of nog
niet gedaan): whiteboard, ticketbord, bank, gordijn, kast, koelkast, prikbord,
urinoir, lamellen, jungle, kuipstoel, ronde tafel.

## Objecten en NPC's

`data/objects.json` (42 objecten) en `data/npcs.json` (11 NPC's) staan op
absolute tegels. De testsuite is de vangrail: `_test_wereld` faalt op elk object
of NPC dat op een solide tegel staat, op elk object dat niet in
`data/world_ids.json` voorkomt, en op een spawnpunt in een muur.

Tickets ankeren op `world_id`, nooit op coördinaten. Daarom overleeft de
`--playthrough`-harnas een hertekening ongewijzigd: hij teleporteert naar
`t.anchor`, niet naar een tegel.
