# Handoff — Kantoorvloer: samengestelde objecten + schaal/plattegrond-verhoudingen

**Date:** 2026-09-01 16:46 (2x bijgewerkt, zelfde sessie: scope tweemaal verbreed)
**Repo:** fun (`/Users/daan/Documents/fun`) — **niet een git-repo**, dus geen branch/commit om te noteren
**Next session focus:** twee gekoppelde maar aparte problemen op de kantoorvloer:
1. objecten worden opgebouwd uit veel identieke kleine tegelblokjes i.p.v. logisch samengestelde vormen (bureaus waren een voorbeeld, geen scope);
2. de schaal/verhouding tussen ruimtes klopt niet (toilet gigantisch, vergaderhokje piepklein, meetingrooms die volgens de doc verschillend groot horen te zijn hebben identieke footprints) én het toilet staat op de verkeerde plek.

**Aanbevolen volgorde:** eerst probleem 2 (schaal/plaatsing) oplossen, dan pas probleem 1 (objectcompositie) — anders wordt compositiewerk straks over verkeerde kamergrenzen heen gedaan en moet het deels over.

## Context
Godot-project: top-down kantoorspel gebaseerd op het echte kantoor van Bluebird Day (`docs/LEVEL.md`). De vloer wordt volledig procedureel gegenereerd: Python-scripts in `tools/generators/` schrijven `data/floor.json`, dat door `scripts/world/world_builder.gd` in een Godot `TileMapLayer` wordt geladen. Er wordt nooit met de hand in de tilemap getekend.

De gebruiker meldde eerst dat rijen van 8+ bureaus er niet uitzagen als een kantoor. Bij doorvragen bleek dat **niet bureau-specifiek**: de gebruiker wil dat de **hele plattegrond** logisch is opgebouwd uit grotere, herkenbare objecten in plaats van uit veel identieke kleine tegelblokjes. Dit is dus een architectuurvraag over de generator-pijplijn, niet een losse contentfix.

## Wat's been done so far
Alleen **onderzoek + diagnose**, nog geen code aangepast.

### Root cause (bevestigd, geldt voor vrijwel elk meubelstuk, niet alleen bureaus)
Twee feiten die samen het probleem veroorzaken:

1. **Eén legenda-teken = altijd precies één vaste 16×16-tegel**, getekend in `tools/generators/gen_tiles.py::build(ch)`. De atlas wordt gebouwd **los van de plattegrond** — puur uit de statische `CHARS`-lijst (`gen_tiles.py:16`) — dus dezelfde tegel wordt overal identiek hergebruikt. Er is geen enkel mechanisme waarmee hetzelfde teken er op positie A anders uitziet dan op positie B.
2. `tools/generators/gen_floor.py` plaatst multi-tegel meubels met `rect(x0, y0, x1, y1, ch)`: één teken geplakt over een hele rechthoek. Voor een object van bijvoorbeeld 5 tegels breed betekent dat: dezelfde tegel-afbeelding vijf keer naast elkaar geplakt, zonder rand/hoek/detail-variatie. Dat is precies "kleinere blokken ipv logische grotere vlakken."

### Inventarisatie: waar dit overal voorkomt
Ik heb alle `rect(...)`-aanroepen in `gen_floor.py` doorlopen (regel 51–155) en geclassificeerd:

**Legitiem homogeen (geen probleem — structuur/materiaal, hoort er hetzelfde uit te zien):**
muren (`#`), glas (`=`), vloer/deuren (`.`/`D`), lamellenwand (`l`), accentvloeren/schaakbordkleed (`E/O/L/G/I/C/q` — bewust getextureerd via noise, tilet daardoor prima).

**Al redelijk "logisch" (individuele objecten los geplaatst, niet blind gevuld):**
de losse kuipstoelen (`s`) rond de tafels in Summit/Birdhouse, losstaande planten (`p`), de ronde tafel (`r`, 2×2 als eigen object). Dit patroon — één object per plek, met gaten ertussen — is de juiste richting.

**Het probleem: multi-tegel meubels die blind met `rect()` gevuld worden, dus als repeterend blok ogen:**
| Teken | Object | Afmeting (voorbeeld) | Regel |
|---|---|---|---|
| `b` | bureau | 2×2 clusters (Basecamp), **16×2 en 12×2 stroken** (De Vloer — dit was het gemelde probleem), 6×2 (Weekend) | `gen_floor.py:106-109,134-136,150-151` |
| `B` | receptiebalie | 5×1 | `:78` |
| `K` | keukenblok | 5×1 | `:92` |
| `S` | serverrack | 2×4 | `:88` |
| `R` | tribune/bank | 10×2 | `:91` |
| `t` | tafel | 2×2 tot **26×2** (De Gang, één "tafel" van 26 tegels lang) | `:99,114,122,149` |
| `x` | whiteboard | 4×1 | `:97` |
| `T` | ticketbord | 3×1 | `:141` |
| `m` | wandmonitor/scherm | 4×1 (meerdere plekken — "4 identieke tv's" i.p.v. één dashboardwand) | `:111,118,143` |
| `n` | plantenkast | **3×8** (De Vloer scheidingswanden) | `:138` |
| `c` | bank | 4×1 | `:152` |
| `j` | gordijn | 2×6 | `:153` |
| `o` | kast/dozen | 2×3 | `:154` |
| `f` | koelkast | 1×2 | `:93` |

Dit is dus een **map-brede** aanpak, niet alleen "bureaus opknippen." Bijna elk meubelstuk met een footprint >1 tegel lijdt eraan.

### Relevante bestaande bouwstenen (ontdekt tijdens onderzoek — belangrijk!)
Er bestaat al een **tweede, tile-onafhankelijke sprite-pijplijn**:
- `tools/generators/gen_props.py` tekent losse, willekeurig-grote PNG's (bv. 32×32, 32×12) die **niet** aan het 16px-tile-grid vastzitten — nu alleen gebruikt voor een paardenkop/gat/logo in `mg_whack.gd` (een minigame), niet voor vloermeubilair.
- `scripts/world/world_object.gd` (`WorldObject`) heeft al een `_sprite`-slot en een werkende `op_swap_texture(path)`-methode — bedoeld voor interactieve objecten, maar functioneel is dit al een generieke "plaats een losse sprite op een wereldpositie"-mechaniek.
- **Maar:** `main.gd::_spawn_objects()` (regel 298-328) maakt vandaag alleen onzichtbare interactie-hotspots aan (cirkel + evt. Label) — er wordt nooit een `Sprite`-child toegevoegd. Alle zichtbare meubels komen dus 100% uit de TileMap; deze tweede pijplijn wordt voor visuele meubels nog helemaal niet benut.

Dit is de sleutelvondst: **de bouwstenen voor "één logisch, samengesteld object" bestaan al in de codebase, alleen niet toegepast op de vloer.**

## Aanvullende bevinding (2e feedbackronde): schaal en plattegrond-verhoudingen
De gebruiker meldde daarna een tweede, apart probleem: de **schaal tussen ruimtes klopt niet** ("het toilet lijkt bijna een voetbalveld, de kleine vergaderhok is heel klein, alles is uit perspectief"), plus een **plaatsingsfout**: het toilet staat niet waar het hoort.

### Eerst uitgesloten: dit is geen engine/camera-bug
Gecheckt: `scenes/entities/player.tscn` geeft de speler een `CapsuleShape2D` van radius 4 / height 10 (~8×18px) op een grid van 16px tegels — dat is een normale, mens-schaal verhouding t.o.v. de tegel. **De speler-tot-tegel-schaal is dus prima.** Het probleem zit puur in de tegel-aantallen die per ruimte in `gen_floor.py` zijn gekozen.

### Bevestigd met cijfers: ruimtes zijn niet proportioneel
`docs/LEVEL.md` legt uit dat alleen de **buitenomtrek** (130×26) gemeten is op de ontruimingsplattegrond (5,06:1-verhouding). De **interne kamergrenzen** in de `NOORD`-lijst (`gen_floor.py:41-48`) en elders zijn nooit gemeten, alleen "op gevoel" gekozen. Resultaat, opgeteld uit de huidige rects:

| Ruimte | Footprint (tegels) | Oppervlak | Noot |
|---|---|---|---|
| Toilet | 15×6 | 90 | voor 2 urinoirs + 1 wc — vrijwel net zo groot als een hele vergaderruimte |
| Summit | 16×6 | 96 | doc noemt dit "klein en leeg" |
| Basecamp | 16×6 | 96 | |
| Birdhouse | 16×6 | 96 | doc noemt dit expliciet **"de grote zaal voor de finale"** |
| Vergaderhokje | 7×2 (interieur) | 14 | een fractie van elke andere ruimte |

Concreet probleem: Summit, Basecamp én Birdhouse hebben **exact dezelfde footprint** (16×6), terwijl `docs/LEVEL.md` ze als merkbaar verschillend van grootte beschrijft ("Summit is klein... Birdhouse is de grote zaal"). De verhalende bedoeling en de daadwerkelijke tegel-afmetingen staan los van elkaar.

### Toilet staat op de verkeerde plek (bevestigd door de gebruiker met `schets idee.jpeg`)
In `assets/nieuwe assets/schets idee.jpeg` (al in de repo, de hand-schets van de vloer) staat de ingang-pijl praktisch tegen de Toilet-box aan: je loopt naar binnen en het toilet zit vrijwel meteen links, achter de muur — geen stuk gang ertussen.

In de huidige generator klopt dat niet: de toiletdeur zit op **x9, y7** (`gen_floor.py:42`, eerste regel van `NOORD`: `(2, 16, 9, 9, False)`), terwijl de speler bij spawn (x2,y11) en de voordeur (x0,y10-12) helemaal aan de westkant zitten. Dat betekent: vanaf de ingang eerst ~7 tegels naar rechts door de gang lopen vóór je bij de toiletdeur bent — geen "direct links achter de muur." De **kamer-breedte** (x2-16) is al ruwweg aan de juiste kant van het gebouw, maar de **deur** zit te ver naar het midden van die kamer i.p.v. vlak bij de ingang.

**Concrete fix:** verplaats de deur-kolommen in de `NOORD`-entry voor Toilet van `d0=9, d1=9` naar iets vlak bij de westkant (bv. rond x2-3, direct naast/achter de ingang), en overweeg of de hele toiletkamer smaller kan (huidige 90 tegels is fors t.o.v. 3 sanitaire objecten).

### Doorbraak: een echte meter-per-tegel-schaal afgeleid (bevestigd door de gebruiker)
De gebruiker stelde voor om real-life afstanden direct naar tegels te vertalen, en gaf één harde ankermaat: **"de grote ruimte is 12 meter breed."** **Bevestigd door de gebruiker: "de grote ruimte" is de volledige verdieping** (de korte as, 26 tegels in de grid) — geen aanname meer:

```
m_per_tile = 12 / 26 = 0,4615 m/tegel
gebouwlengte = 130 tegels × 0,4615 = 60,0 m  →  60 × 12 m, verhouding exact 5:1
```

Dat komt vrijwel exact overeen met de al-gemeten 5,06:1 uit `docs/LEVEL.md` (gemeten op de ontruimingsfoto) — te consistent om toeval te zijn, dus dit is met hoge zekerheid de juiste schaal.

**Met deze schaal doorgerekend blijkt niet alles fout te zijn — het beeld wordt juist scherper:**

| Ruimte | Footprint | Oppervlak (m²) | Oordeel |
|---|---|---|---|
| Toilet | 15×6 tegels | 6,92 × 2,77 = **19,2 m²** | **echt ~4× te groot** — een toilet met 2 urinoirs + 1 wc is realistisch ~5 m² |
| Patchhok | 4×6 | 1,85 × 2,77 = 5,1 m² | plausibel voor een technieckast |
| Koffiecorner | 18×6 | 8,31 × 2,77 = 23,0 m² | plausibel (keuken+lounge+tribune) |
| Summit / Basecamp / Birdhouse | elk 16×6 | elk **20,5 m²** | **absolute grootte is prima** (normale vergaderruimte) — het echte probleem is dat ze identiek zijn terwijl de doc ze als verschillend beschrijft, niet de schaal |
| Vergaderhokje | 7×2 (interieur) | 3,23 × 0,92 = 3,0 m² | **precies goed** voor een huddle-booth — de eerdere "te klein"-indruk kwam door het contrast met het te-grote toilet ernaast, niet door een echte fout |
| Bureaudiepte (2 tegels/rij) | — | ≈0,92 m diep per rij | realistisch voor bureaudiepte, geen wijziging nodig |

**Conclusie:** het is dus geen "alles is uit perspectief" over de hele linie — het is één harde fout (toilet ~4× te groot) plus het al genoteerde kopieer-probleem (Summit/Basecamp/Birdhouse identiek). Concreet doelgetal voor het toilet: bij dezelfde bandhoogte (6 tegels = 2,77m) geeft een breedte van **4-6 tegels** (i.p.v. de huidige 15) een realistische 5-7,5 m², vergelijkbaar met de Patchhok-breedte ernaast.

### Aanbeveling
1. Leg `M_PER_TILE = 12/26` (of het exacte getal, indien de aanname over "de grote ruimte" klopt) vast als constante bovenaan `gen_floor.py`, zodat elke toekomstige real-world maat direct omgerekend kan worden naar tegels — in plaats van te gokken.
2. Verklein de Toilet-breedte in de `NOORD`-lijst van 15 naar ~4-6 tegels en verplaats de deur naar bij de ingang (zie hierboven).
3. Laat Summit/Basecamp/Birdhouse qua absolute grootte met rust — geef ze in plaats daarvan verschillende footprints/inrichting voor narratieve variatie (dat is al genoteerd als onderdeel van de objectcompositie-stap).
4. Gebruik `schets idee.jpeg` voor de volgorde/aangrenzing van ruimtes (al bevestigd door de gebruiker) en de technische plattegrond + de nieuwe schaal-constante voor elke nieuwe of te herziene maat.

## Current state
- Geen enkel bestand aangepast. Alle generators en data staan op de oude staat.
- Er is nog geen architectuurkeuze gemaakt tussen de twee opties hieronder (objectcompositie), en de schaal/plaatsingscorrectie hierboven is ook nog niet doorgevoerd.

## Next steps
**Stap 0 — schaal en plaatsing eerst (goedkoop, puur cijferwerk in `gen_floor.py`, doe dit vóór stap 1-2):**
1. **Bevestig eerst met de gebruiker** of "de grote ruimte is 12 meter breed" inderdaad de volledige gebouwbreedte is (26 tegels → `M_PER_TILE = 12/26 ≈ 0,4615`) — de aanname klopt sterk (geeft exact 60×12m, 5:1, consistent met de eerder gemeten 5,06:1) maar is nog niet expliciet bevestigd.
2. Leg die schaal vast als constante bovenaan `gen_floor.py` (bv. `M_PER_TILE`), zodat toekomstige maten direct omgerekend worden i.p.v. geraden.
3. Verklein de Toilet-breedte in de `NOORD`-lijst (`gen_floor.py:42`) van 15 naar ~4-6 tegels (realistische 5-7,5 m² i.p.v. de huidige 19,2 m²) en verplaats de deur van x9 naar vlak bij de ingang (rond x2-3) — zie sectie hierboven.
4. **Niet nodig:** Summit/Basecamp/Birdhouse qua absolute grootte aanpassen — die zijn met ~20,5 m² elk al realistisch; hun probleem is dat ze identiek zijn (hoort bij de objectcompositie/variatie-stap hieronder, niet bij schaal). Vergaderhokje (~3 m²) is ook al correct.
5. Draai `gen_floor.py` na elke wijziging: het valideert bereikbaarheid zelf en weigert te schrijven bij onbereikbare tegels.
6. Pas hierna beginnen aan objectcompositie (stap 1-2 hieronder) — anders moet dat werk over als kamergrenzen alsnog verschuiven.

**Stap 1 — architectuurkeuze (met de gebruiker, dit is een ontwerpbeslissing, geen technisch detail):**

- **Optie A — binnen het tile-systeem blijven (kleinere ingreep).**
  Introduceer per samengesteld object een sjabloon: meerdere nieuwe legenda-tekens per "rol" binnen het object (bv. bureau-links/-midden/-rechts, of tafel-rand vs. tafel-midden, wandmonitor-1..4 met andere inhoud per scherm), plus een generieke `stamp(x, y, template: list[str])`-helper in `gen_floor.py` die een klein 2D-patroon plakt in plaats van `rect()` die blind vult. Werk dit uit voor élk object uit de tabel hierboven, niet alleen `b`.
  Voordeel: raakt `world_builder.gd`/TileSet-code niet aan, blijft data-driven zoals nu.
  Nadeel: blijft fundamenteel een mozaïek van 16×16-vierkantjes; herkenbaar detail (laptop + 2 aparte monitoren op één bureau) is op die resolutie beperkt, en elke variant kost een nieuwe atlas-tegel + editor-reimport.

- **Optie B — meubels van de TileMap af, als vrije composiet-sprites (grotere, maar "echte" ingreep).**
  Teken hele objecten (bureau-met-laptop-en-2-monitoren-en-stoel, een lange vergadertafel, een keukenblok, een plantenkast, een bank) als één PNG op willekeurige pixelgrootte via `gen_props.py` (dezelfde stijl als de paardenkop nu al), en plaats ze als `Sprite2D`-child onder een `WorldObject` (het `_sprite`/`op_swap_texture`-mechanisme bestaat al) op een wereldpositie uit een nieuw of uitgebreid databestand (bv. `data/props.json`: positie + prop-naam + solide footprint voor collision). De TileMap onder het object wordt dan gewoon vloer + een botsvlak ter grootte van de footprint.
  Voordeel: dit is de enige manier om objecten echt als één ontworpen vorm te laten lezen — geen tegel-seams, geen herhaling, past letterlijk bij "logische grotere vlakken."
  Nadeel: raakt meer aan (`world_builder.gd` voor het botsvlak zonder bijpassende tegel, `main.gd::_spawn_objects`, mogelijk y-sort per prop), en is dus meer werk.

**Aanbeveling:** Optie B is de eigenlijke, structurele oplossing voor wat de gebruiker vraagt; Optie A is een goedkope tussenstap die het zichtbaar beter maakt zonder architectuur aan te raken. Leg dit expliciet aan de gebruiker voor voordat je begint te bouwen — dit bepaalt hoeveel werk de rest van de sessie is.

**Stap 2 — ongeacht de keuze:**
1. Begin met 2-3 representatieve objecten uit de tabel (bv. bureau, lange tafel, wandmonitor-groep) als proof of concept voordat je alle ~13 objecttypes migreert.
2. Draai `python tools/generators/gen_tiles.py` en/of `gen_floor.py` (venv al aanwezig in `tools/.venv/`) — `gen_floor.py` valideert bereikbaarheid zelf en weigert te schrijven bij onbereikbare tegels.
3. **Verplicht bij nieuwe/gewijzigde atlas-tegels:** de Godot-editor moet eenmalig herimporteren (GUI, niet headless — zie `docs/LEVEL.md` rond regel 126) voordat `world_builder.gd::build_tileset()` werkt op tegels buiten de oude atlasbreedte.
4. Test visueel in Godot of de objecten nu als losse, herkenbare dingen lezen i.p.v. herhaald patroon.

## Open questions / unknowns
- **Optie A vs. B is nog niet gekozen** — dit moet eerst met de gebruiker besproken worden, het bepaalt de hele vervolgaanpak.
- Bij Optie B: hoe wordt het botsvlak van een vrije sprite gedefinieerd zonder de bestaande `TileSet`-physics-laag te dupliceren? (`world_builder.gd::is_solid()` leest nu puur uit de tegel-grid — een prop zonder onderliggende solide tegel zou de player er dwars doorheen laten lopen, tenzij er een aparte `CollisionShape2D`/`StaticBody2D` bij komt.)
- Gewenst totaal aantal bureaus/objecten per zone — nog niet besproken (relevant bleef ook bij het oorspronkelijke bureau-voorbeeld).
- Godot MCP-server (`godot`) gaf deze sessie een connectiefout ("Unable to connect") — kon niet gebruikt worden om live in de editor te kijken of te reimporteren; check of dat inmiddels werkt.

## Gotchas
- `data/floor.json` **nooit met de hand bewerken** — `tools/generators/gen_floor.py` is de enige bron van waarheid en overschrijft het stil bij de volgende run.
- Een nieuw legenda-teken zonder atlas-coördinaat rendert stil als gewone vloer (`world_builder._coord_for()` valt terug op `Vector2i(0,0)`) — vergeet niet elke nieuwe letter aan `CHARS` in `gen_tiles.py` toe te voegen.
- `gen_floor.py` weigert te schrijven bij onbereikbare tegels — handig als vangrail, maar een nieuw botsvlak (stoel, prop-footprint) kan een gang onbedoeld blokkeren; lees de foutmelding.
- Bij Optie B: `WorldObject`/`objects.json` is nu een **puur interactieve** laag (geen sprites) — als je hier visuele props aan toevoegt, zorg dat dit niet knalt met de bestaande 42 interactie-objecten die al op dezelfde `WorldObject`-klasse leunen.
- Deze map is geen git-repo — geen manier om dit als commit/diff te reviewen; bewaar zelf een kopie van `gen_floor.py`/`gen_tiles.py` voor je grote herschrijvingen doet.

## Pointers
- Referentiefoto's: `assets/nieuwe assets/bureaustoel.jpeg`, `assets/nieuwe assets/werkplek bureau.jpeg`
- Vloer-doc: `docs/LEVEL.md`
- Generator (plattegrond/meubelplaatsing): `tools/generators/gen_floor.py` — zie tabel hierboven voor regelnummers per object
- Generator (tegel-art, tile-gebonden): `tools/generators/gen_tiles.py` (`CHARS` regel 16, `build()` vanaf regel 63)
- Generator (vrije sprites, nog ongebruikt voor meubels): `tools/generators/gen_props.py`
- Runtime tilemap-loader: `scripts/world/world_builder.gd`
- Runtime object/sprite-laag: `scripts/world/world_object.gd`, `scripts/world/main.gd::_spawn_objects()`
- Gegenereerde data (niet handmatig bewerken): `data/floor.json`
