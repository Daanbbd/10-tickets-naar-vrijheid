# PLAN — 10 Tickets naar Vrijheid — van "goed geschreven" naar "leuk"

## Status (bijgewerkt 2 september 2026)

**F0, F1 en F2 zijn klaar en gemerged in `main`.** Testsuite staat op
**16.872 controles, 0 fout, ALLES GOED** (baseline bij de start van dit plan
was 16.658). F3 t/m F6 zijn nog niet begonnen.

| Fase | Status | Noot |
|---|---|---|
| F0-a save/laden/pauzemenu | ✅ Klaar | `_test_save_ronde()` erbij, `--doorgaan`-QA-vlag toegevoegd |
| F0-b kapotte layouts | ✅ Klaar | Ook `ui_kit.gd`/`mg_slotboard.gd`'s dode minimum-overrides meegepakt |
| F0-c dode data/code | ✅ Klaar | Zie "Afwijkingen" hieronder — groter dan de briefing beschreef |
| F0-d losse eindjes | 🟡 Klaar, één blokkade | Dirks portret kan niet: `assets/personen/dirk.png` (bronfoto) ontbreekt — heeft een foto van jou nodig |
| F1-a vloer herontwerp | 🟡 Klaar, met een openstaand correctiepunt | Zie "Openstaande beslissingen" — de toilet/serverhok/ingang-hoek moet nog herzien worden |
| F1-b 40% vloer belonen | ⬜ Geen eigen actie | Realiseert zichzelf via F3-a (toilet) en F4-b (paardenbugs) — nog te doen als onderdeel daarvan |
| F1-c prop-art en diepte | ✅ Klaar | Vond en repareerde de y-sort-bug zelf; ontdekte dat HUD+balk ~6,5 tegelrijen permanent afdekken (gedocumenteerd in `docs/TESTING.md`) |
| F2-a typografie | ✅ Klaar | Fonts gedownload, geen fallback nodig |
| F2-b knopstijl | ✅ Klaar | 13 bevestigende acties, `KNOP_MIN_H` 30 |
| F2-c leesbaarheid | ✅ Klaar | Twee grijzen i.p.v. één (licht/donker ondergrond); vond een 4e stapelfout die de briefing niet noemde |
| F2-d kompasstrip | ✅ Klaar | Leest vloerbreedte uit data, geen hardcoded 130 |
| F2-e minigame-chrome | ✅ Klaar | Vond en repareerde een portret-overflow-bug en twee misplaatste knoppen |
| F3 De dag aanzetten | ⬜ Nog te doen | — |
| F4 Tien tickets, zes schermen | ⬜ Nog te doen | — |
| F5 Wereld van pause af | ⬜ Nog te doen | — |
| F6 Verificatie en docs | ⬜ Nog te doen | — |

### Openstaande beslissingen (niet acteren zonder overleg)

Uit een tweede, preciezere schets kwamen twee correcties naar boven op wat
F1-a al bouwde. **Vastgelegd, bewust nog niet doorgevoerd:**

1. **Trappenhuis + de ingang-hoek.** F1-a heeft het trappenhuis volledig
   verwijderd (onbereikbaar, stond niet op de eerdere schets). De nieuwe
   schets toont het juist als zichtbaar-maar-niet-toegankelijk decor vlak bij
   de ingang — en onthult dat de huidige plaatsing van toilet + serverhok
   t.o.v. de ingang niet klopt (mensen komen daar normaliter binnen). Dit
   raakt de westhoek van de vloer opnieuw en moet in samenhang worden
   herzien, niet als los patchje.
2. **"Blauwe tijger."** Een bestaand asset in het spel dat op de nieuwe
   schets omcirkeld staat tussen de kastenwand en Summit — moet daar correct
   geplaatst worden. Nog te doen.
3. De bureau-eiland-indeling (8·4·4·4·4) is **bevestigd correct** zoals
   F1-a hem bouwde — geen actie nodig.

### Afwijkingen t.o.v. de oorspronkelijke briefing (F0–F2)

- **F0-c** vond dat de "gecontroleerde helft van `mg_slotboard`" groter was
  dan beschreven: ook `TraitModifier._slotboard()` was er ongemerkt van
  afhankelijk en is meegenomen. Twee van de 26 keuzevlaggen (`klant_prioriteit`,
  `klant_echtgenoot` in t03) waren echt dood en zijn weggehaald i.p.v.
  aangesloten. Drie extra dode `set_flag`-effecten (`frontend_ok`,
  `backend_ok`, `cro_ok`) zijn *niet* opgeruimd — ze vielen buiten de
  acceptatietest, kandidaat voor een latere fase.
- **F1-c** vond onderweg dat `populate()` accentvloeren op de verkeerde
  (y-gesorteerde) laag zette, wat schaduwen/meubelranden kon afdekken —
  gerepareerd als bijvangst.
- Een kleine, losstaande hygiëne-fix onderweg: `tools/generators/__pycache__/*.pyc`
  stond onder versiebeheer en werd bij elke generator-run herschreven —
  nu gegitignored.

---

## Context

`docs/AUDIT.md` concludeert: de fictie, de tekst en de wereld zijn goed
(kernfantasie 7/10), de speelbeurt is dood. De kernlus
`OBSERVEREN → BEGRIJPEN → KIEZEN → HANDELEN → GEVOLG → NIEUWE INFORMATIE`
breekt na HANDELEN:

- **KIEZEN ontbreekt** — 9 van 10 tickets staan vanaf seconde één open, niets
  ontsluit iets. `unlocks` is `[]` in alle tien de ticketbestanden, terwijl
  `QuestEngine.run_effects()` `unlock_ticket` al implementeert.
- **GEVOLG is half** — 6 van 11 minigames voeden `Gevolgen` niet.
- **NIEUWE INFORMATIE ontbreekt** — `klant_berichten.json` heeft geen
  `effects`-schema, dus de klant kan alleen achteruit kijken.
- **De wereld staat stil terwijl je werkt** — `Shell.run_minigame()` zet
  `get_tree().paused = true`, dus het kantoor is precies stil op de momenten
  dat de chaos zou moeten landen.

Daarbovenop: twee kapot gerenderde schermen, geen typografische hiërarchie
(`FS_SMALL == FS_BODY == 10`), en een save die geschreven maar nooit gelezen
wordt (`Session.load_from_disk()` heeft nul aanroepers).

**Doel: het spel leuk maken.** Niet meer content — de dag aanzetten, de
onderbrekingen laten landen, en het beeld op het niveau brengen van het enige
scherm dat al klopt (`character_select`).

### Vier richtinggevende besluiten (door jou gemaakt)

| Vraag | Besluit |
|---|---|
| Ticketaantal | **Tien blijven.** Vier ervan worden opgelost dóór in de wereld te handelen in plaats van in een puzzelscherm. Titel blijft kloppen, geen geschreven materiaal weg. |
| Chaos | **Volledig.** De wereld pauzeert niet meer; onderbrekingen landen tijdens je werk. |
| Klok | **Loopt echt.** Harde regel blijft: tijd blokkeert nooit iets en kan het spel nooit onwinbaar maken. |
| Visueel | **Volledige art-direction pass.** |

### De centrale ingreep, in één regel

> **De inbox loopt vol.** Je begint met vier tickets, niet met negen. De rest
> komt binnen terwijl je werkt — van de klant, van een collega, doordat iets
> stuk gaat. Geen enkel ticket zit áchter een ander (vrije volgorde blijft
> intact), maar de stapel groeit, en dus is er eindelijk een "waarom nu".

Dat is wat de zes uitwisselbare middenboodschappen uit de audit verandert in
een dag die uit de hand loopt, en het kost bijna geen nieuwe code:
`unlock_ticket` bestaat en is getest.

---

## Wat onaangeraakt blijft

Deze systemen zijn goed en de plannen hieronder mogen ze niet uithollen:

- `world = f(Session)` — `reward_effects` één keer, `world_changes` idempotent
  en replaybaar (`quest_engine.gd:6-8`, `world_mutator.gd:5-7`).
- `Gevolgen.finale_start()` — echte accumulatie over negen vlaggen naar vier
  getallen. Uitbreiden mag, herschrijven niet.
- De briefing/trait-symmetrie: eigen vak → mechanisch voordeel, niet je vak →
  de kennis van wie het wél is. `Briefing` interpoleert uit de echte config en
  kan daarom niet verouderen.
- `Shell` als enige eigenaar van `get_tree().paused`; `Session._sloten` als
  enige waarheid over input-lock; `Conditions.check()` als enige plek waar een
  conditie betekenis krijgt; `QuestEngine.next_hint_ticket()` als enige plek
  die bepaalt waar het spel je naartoe stuurt.
- Alle static, scene-loze, headless-testbare kernklassen.
- De QA-harnas (`--minigame=`, `--shot=`, `--playthrough`, `--autoplay`,
  `qa_solve` per minigame). Elke fase hieronder wordt hierdoor geverifieerd.

---

## Fasering

```
F0  Fundament & hygiëne        ─┐
F1  De vloer (nieuwe schets)    ├─ parallel
F2  Visueel systeem            ─┘
F3  De dag (inbox, klok, storingen)   ─┐
F4  Minigames (10 tickets, 6 schermen) ├─ F4 start zodra F2 klaar is
F5  Wereld van pause af               ─┘  (F5 na F3+F4)
F6  Verificatie & docs
```

Elke fase levert een groene testsuite en een shot-sweep op. **Niets wordt
gecommit met een rode suite.**

---

# F0 · Fundament & hygiëne

Geen ontwerprisico, alles onafhankelijk. Vier parallelle sub-agents.

### F0-a · Save, laden en een pauzemenu

**Status: ✅ Klaar.**

**Waarom:** `Session.load_from_disk()` (`autoload/session.gd:330`) heeft nul
aanroepers terwijl `save_to_disk()` bij elk ticket én bij achtergrondgang
draait (`quest_engine.gd:159`, `shell.gd:64-65`). Een run van 30 minuten is op
een telefoon onherstelbaar kwijt terwijl de save al op schijf staat.

**Doen:**

1. Derde knop `"Doorgaan"` op `scripts/ui/title_screen.gd`, alleen zichtbaar
   als de save bestaat én een `character_id` heeft. Route:
   `load_from_disk()` → `QuestEngine.refresh_availability()` →
   `Shell.goto_game()`. `WorldMutator.replay_all()` doet de rest — de wereld ís
   al een pure functie van de sessie.
2. Pauzemenu: nieuwe `scripts/ui/pauzemenu.gd` op een eigen CanvasLayer
   (**laag 40** — boven telefoon 30, onder minigame 50). Inhoud: doorgaan,
   volume, "run verlaten". Open via `cancel` in de wereld en via een vierde
   knop op de balk.
3. `ticket_states` wordt als rauwe int geserialiseerd — schrijf de
   `TicketState`-namen weg in plaats van de int, zodat een enum-herordening
   geen saves corrumpeert. Migratiepad voor bestaande saves: int accepteren als
   fallback.
4. `followers` blijft bewust niet in de save (`session.gd:17-20`) — laat dat zo
   en documenteer het in de nieuwe laadroute.

**Acceptatie:** nieuwe suite `_test_save_ronde()` — `to_dict()`/`from_dict()`
round-trip over een halve run reproduceert flags, items, ticketstanden,
`gevolgen`, `worked_minutes`. Handmatig: `--playthrough --gedaan=5`, app
killen, `Doorgaan`, wereld staat er weer zoals hij was.

### F0-b · De twee kapotte layouts, meteen

**Status: ✅ Klaar.**

**Waarom:** BBD-207 en BBD-209 worden in F4 vervangen, maar tot die tijd mag de
werkboom geen kapot scherm bevatten.

**Doen:** `scripts/minigames/mg_whack.gd:100-102` `h_separation` 26 → 8
(4×34 + 3×8 = 160 px, past in de 172 px interieur); `mg_tagpicker.gd:41`
`Vector2(0,18)` → `Vector2(46, 26)`. Twee getallen.

**Let op:** `Vector2(0,18)` is *dode code* — een `Button` met `panel()`'s 6 px
content margin rapporteert 14+12 = 26 als minimum, dus de 18 doet niets en de
werkelijke rijhoogte is al 26. Het echte probleem is de ontbrekende
minimum**breedte**. Zelfde klasse dode override: `ui_kit.gd:187`
`Vector2(94,22)` en `mg_slotboard.gd:88` `Vector2(0,20)` — ruim die drie in één
keer op.

### F0-c · Dode data en dode code opruimen

**Status: ✅ Klaar** — zie "Afwijkingen" in de statussectie bovenaan.

**Doen — verwijderen:**

- `Bus.effects_requested` (`bus.gd:42`) — nooit geëmit, nooit verbonden.
- `Shell.debug_layer()` (`shell.gd:214-215`) + de `DebugLayer` uit
  `autoload/shell.tscn` — geen aanroepers.
- De zes nooit-uitgedeelde items uit `data/items.json` (`laptop`,
  `koffiebeker`, `toegangspas`, `figma_link`, `hdmi`, `usb_stick`).
- De gecontroleerde helft van `mg_slotboard` — alle drie de `accepts`-lijsten
  zijn leeg in de data, dus dat is dode code in een verzonden build.
- `tools/generators/floor_reference.py` — beschrijft de oude 72×40-vloer met
  ruimtes die niet bestaan. Actief misleidend.
- De vier verouderde docstrings (`mg_slotboard.gd:3-4`,
  `mg_choicescene.gd:2-3`, `mg_cableboard.gd:2-3`, `mg_tagpicker.gd:3`).

**Doen — aansluiten in plaats van slopen** (dit is de helft die wél moet
blijven, want F3/F4 gebruiken ze):

- `unlock_ticket`, `kost_tijd`, `add_counter`, `remove_item` — allemaal
  geïmplementeerd en ongebruikt. F3 gebruikt `unlock_ticket` en `kost_tijd`.
- `flags_none` als conditie-key — ongebruikt in data, wordt in F3 gebruikt.
- `set_visible` als world-op — ongebruikt, wordt in F1/F4 gebruikt.

**Doen — de 26 keuzevlaggen:** deze belóven nu gevolgen die er niet zijn.
Beslis per vlag: aansluiten op een `Gevolgen`-effect, of het keuze-effect
weghalen zodat de keuze eerlijk alleen een andere zin geeft. Geen middenweg.

**Acceptatie:** nieuwe suite `_test_geen_dode_data()` — elk item in
`items.json` wordt door minstens één `add_item`-effect uitgedeeld; elke vlag
die een keuze-effect zet wordt door minstens één `Conditions`-lezer of
`Gevolgen`-regel gelezen.

### F0-d · Losse eindjes met eigen impact

**Status: 🟡 Klaar op één blokkade na.** Dirks portret kon niet gegenereerd
worden — `assets/personen/dirk.png` (de bronfoto) ontbreekt, en die moet van
jou komen. Alle vijf andere punten zijn gedaan.

- **Één functietitel per personage.** Vijf van zeven hebben er twee, Koen drie.
  `TicketDef.owner_role` wordt al uit `characters.json` afgeleid
  (`game_data.gd:191-192`) en `_test_briefings()` bewaakt dat — dus dwing
  `npcs.json[].role == characters.json[].role` af met een testregel en kies:
  Daan = Product Owner (elke dialoogregel behandelt hem al zo), Willem = Client
  Lead, Koen = Backend / AI & automatisering, Victor en Bastiaan = Frontend
  developer met hun specialisme in de tagline.
- **Haptiek aansluiten.** Drie van vier sterktes zijn nooit afgevuurd.
  `GELUKT` in `MinigameBase.finish_with_banner(true, …)`, `SLAG` in de
  `false`-tak, `STOOT` bij een geslaagde interactie en bij `dialogue_started`.
  En haal de twee losse `Input.vibrate_handheld(20/45)` uit
  `character_select.gd:295, :358` — die zijn niet door
  `OS.has_feature("mobile")` gedekt.
- **`set_modulate` echt laten werken.** `WorldObject` krijgt nooit een
  `Sprite`-kind, dus `_sprite` is altijd `null` (`world_object.gd:14`) en de
  twee momenten waarop de wereld zichtbaar geneest, gebeuren niet. Los dit op
  in samenhang met F1 (de props zijn daar sprites).
- **Dirks portret bestaat niet.** `data/npcs.json:89` verwijst naar
  `portraits/dirk.png`; `_portrait_for()` slikt dat stil. Genereer hem met
  `tools/generators/gen_portraits.py`.
- **`docs/ARCHITECTURE.md:1-4` is stale** — zegt viewport 480×270, het is
  192×416.
- **`walk_speed_tiles_per_sec` in `floor.json` is dode data** — niets leest het.
  Weghalen of laten lezen door `player.gd`.

---

# F1 · De vloer volgens de nieuwe schets

**Bron van waarheid:** `tools/generators/gen_floor.py`. `data/floor.json`
**nooit** met de hand bewerken — de volgende run draait het stil terug
(`docs/LEVEL.md:118`).

### Wat de schets zegt en de huidige vloer niet doet

`assets/nieuwe assets/schets idee.jpeg`, west→oost gelezen:

1. **Toilet in de noordwesthoek, serverhok eronder.** Nu staan Patchhok
   (x6–9) en Toilet (x11–15) náást elkaar in de noordband. In de schets zijn
   ze *gestapeld* aan het westeinde: toilet boven, serverhok direct daaronder,
   en de ingang zit op de westwand ónder dat blok.
2. **De koffiecorner is een vrijstaand blok waar je omheen kunt lopen.** Nu is
   het een gesloten ruimte tegen de noordwand (x17–34, y1–6) — je kunt er per
   definitie niet omheen. In de schets staat hij los, met op de noordwand
   achter hem een **kastenwand/bank** en een **raam**.
3. **Het vergaderhokje staat westelijker**, ruwweg boven het tweede
   bureau-eiland, niet onder Summit.
4. **De bureau-eilanden zijn 8 · kast · 4 · 4 · kast · 4 · 4.** Nu is het
   8 · kast · 4 · 4 · kast · **8** · 4 (`EILANDEN` in `gen_floor.py:174-180`).
5. **Weekend rechts** — de "jungle" waar het lawaai vandaan komt. Blijft.

### De vondst die het t08-anker gratis repareert

`gen_floor.py:258-271` heeft een `ACCENT_ROOMS`-regel op `(31, 8, 37, 9, 'I')`
met het commentaar `# "vergaderhokje"` — een **stale accent uit een oudere
layout**, want het hokje staat nu op x44–50. En precies op x31–36, y8–9 staan
`hokje_ipad`, `hokje_telefoon` en `samen_bingo_poster`.

De audit noemt dat een bug (§E: "het anker van t08 ligt niet in de zone die het
ontdekt"). De schets zegt dat het hokje daar *hoort*. Verplaats het hokje terug
naar x30–38, y8–11 en het anker, de zone en de accentvloer kloppen weer in één
zet — geen enkel object hoeft te verhuizen.

### Doelindeling

```
y0        buitenwand (raamloos, binnenzijde)
y1-6      WEST  x1-8  : Toilet (dichte wand + één deur — de leegte ís de grap)
          OOST  x10+  : open band met de KOFFIECORNER als eiland,
                        daarna Summit · Basecamp · Birdhouse achter glas
y7        west: wand tussen toilet en serverhok
          oost: scheidingslijn — glas voor de drie vergaderruimtes
y8-13     WEST  x1-8  : Het Patchhok (serverhok), direct onder het toilet
          OOST         : De Gang, met het Vergaderhokje op x30-38
                         en de grote tafel met planten op x55-92
y14-24    De Vloer: 5 bureau-eilanden (8·4·4·4·4) + 2 plantenkasten
          voordeur op de westwand in deze band; scrumbord ernaast
y25       buitenwand (raamzijde)
x96       glaslijn naar Weekend, brede opening
```

### F1-a · Herteken de vloer

**Status: 🟡 Klaar, met een openstaand correctiepunt** — zie "Openstaande
beslissingen" bovenaan: de toilet/serverhok/ingang-hoek moet nog herzien
worden op basis van een tweede schets. De rest (koffiecorner als eiland,
vergaderhokje verplaatst + t08-anker gerepareerd, eilanden 8·4·4·4·4) staat
en is getest.

**Bestanden:** `tools/generators/gen_floor.py` (de `NOORD`-lijst, de
tussenwanden, `EILANDEN`, `ACCENT_ROOMS`, het hokje-blok), en daarna
`gen_tiles.py`/`gen_props.py` voor nieuwe legenda-letters en props.

**Nieuw nodig:**

- De koffiecorner als eiland: solide blok met loopruimte rondom, `keukenblok`,
  `tribune`, `koelkast` en de `speaker` erop of ertegen.
- Kastenwand + raam op de noordwand achter de koffiecorner — twee nieuwe
  legenda-letters (bv. `k` kastenwand, `o` raam). **Elke nieuwe letter moet in
  `CHARS` in `gen_tiles.py` én een atlas-coördinaat krijgen**, anders rendert
  hij stil als gewone vloer (`world_builder._coord_for()` geeft
  `Vector2i(0,0)` voor onbekende tekens).
- De vijfde bureau-eiland van 8 → 4 werkplekken.

**Harde randvoorwaarden** (allemaal al door de suite afgedwongen,
`test_runner.gd:795-840`):

- `grid.size() == size[1]`, elke rij exact `size[0]` lang.
- Elk teken in `legend` én in de atlas.
- Spawn niet solide; elk `objects.json`-tegel niet solide; elk `world_id` in
  `world_ids.json`.
- Elke NPC `home_tile` **en elke route-waypoint** in `npcs.json` niet solide.
  Te herijken: `dennis` home `[61,23]` route `[53,20] [40,12] [26,12]`,
  `dirk` `[33,11]`, `npc_bastiaan` `[12,18]`, `npc_koen` `[7,6]` → `[21,4]`.
- `gen_floor.py` weigert te schrijven bij >0 onbereikbare tegels.
- **De vloer blijft 26 tegels hoog.** Dat is exact de viewporthoogte en
  daarom volgt de camera alleen horizontaal (`game_camera.gd:5-9`). Elke
  wijziging aan de y-omvang breekt die aanname.
- `office_atlas.png` moet na wijziging door de editor opnieuw geïmporteerd
  worden (`Godot --headless --path . --editor --quit`); headless kan dat niet
  en zonder reimport faalt `build_tileset()`.

**Acceptatie:** suite groen, `gen_floor.py` print 0 onbereikbaar, en een
shot-sweep over de hele vloer (vijf shots op x=10/35/60/85/110) laat zien dat
je om de koffiecorner heen kunt lopen.

### F1-b · 40% van de vloer belonen

**Status: ⬜ Geen eigen actie ondernomen.** Deze paragraaf heeft geen
zelfstandige "Doen"-lijst — hij realiseert zich via F3-a (toilet als
ticketbron) en F4-b (paardenbugs als wereldobjecten). Blijft open tot die
fases lopen.

De audit meet dat Toiletten, De Gang en Weekend samen 1.025 van 2.340
begaanbare tegels beslaan en **geen enkel werk bevatten**. Na F1-a:

- **De paardenbugs lopen door het kantoor** (zie F4-b) — ze dwalen in het
  toilet, in de gang en in Weekend. Dat maakt die 40% in één zet de plek waar
  BBD-209 leeft.
- **Weekend** krijgt één interactie die iets geeft: het lawaai waar de schets
  over schrijft is de bron van een storing (F3-c).
- **Het toilet** krijgt de deploysleutel-achtige rol: één van de vier
  binnenkomende tickets (F3-a) ontdek je alleen door er te gaan kijken.

### F1-c · Prop-art en diepte

**Status: ✅ Klaar.** Alle vijf punten gedaan plus de y-sort-bug hieronder
gerepareerd (via de footprint-offset, dezelfde conventie als de speler).
Bijvangst: `populate()` zette accentvloeren op de verkeerde render-laag,
waardoor ze schaduwen/meubelranden konden afdekken — meegerepareerd. Ontdekt
en gedocumenteerd: de camera klemt verticaal volledig vast en HUD+knoppenbalk
dekken samen ~6,5 tegelrijen af, dus y0–3 en y24–25 (incl. de koffiecorner
op y2–3) staan er wel maar zijn nooit zichtbaar tijdens normaal spelen.

**Waarom:** de huidige vloer leest als grijze cellenblokken (zie
`docs/audit-shots/s_wereld.png`). De pixelart zelf is goed; wat ontbreekt is
diepte en dat muren als muren lezen.

**Doen** in `tools/generators/gen_tiles.py` + `gen_props.py`:

1. **Muren met een top en een face.** Nu is elke muur één 16×16-tegel; geef de
   noordwand een donkerder bovenrand en een lichtere voet, zodat de gesloten
   ruimtes ruimtes worden in plaats van strepen.
2. **Slagschaduw onder elke prop.** `schaduw_karakter.png` bestaat al voor
   personages; doe hetzelfde voor bureaus, plantenkasten en de tribune.
3. **Raamlicht op de zuidband.** De raamzijde is y25; leg er een lichtgradient
   over de eerste twee tegels van de werkvloer, zodat de vloer een richting
   krijgt.
4. **Vloervariatie** — de huidige `draw_floor` gebruikt vaste ruispunten;
   voeg twee of drie varianten toe zodat 1.407 vloertegels niet identiek zijn.
5. **Ruimtebordjes** als hangende props in de gang: `Summit`, `Basecamp`,
   `Birdhouse`, `Toilet`. Dat is wayfinding die je met je ogen oplost, precies
   wat `docs/QUESTS.md:91-96` al belóóft met "de tweede glazen ruimte".

**Let op één bestaande bug:** `main.gd:365-387` zet prop-sprites met
`centered = false` in een `y_sort_enabled` node, dus hun sorteersleutel is de
**bovenrand** van de sprite, niet de voet. Bij `bureau_4x8` en
`plantenkast_3x8` (8 tegels hoog) kan de speler daardoor achter een prop
verdwijnen waar hij vóór hoort te staan. Repareer dat met een expliciete
`z_index`/`y_sort_origin` per prop.

---

# F2 · Visueel systeem

**Richting: één huisstijl, twee oppervlakken.**

- **Shell-oppervlak (donker):** HUD, minigames, borden, telefoon, menu's. De
  donkere leisteen van `character_select` — het enige scherm met echte
  hiërarchie (audit §G) — wordt de norm. Dat heft in één zet de crème-versus-
  donker-breuk op die het spel nu twee spellen laat lijken.
- **Wereld-oppervlak (pixel):** de vloer, per F1.

**Kritieke randvoorwaarde:** de kleurconstanten in `scripts/ui/ui_kit.gd:11-32`
zijn **gegenereerd** door `tools/generators/gen_ui_kit_colors.py` uit
`palette.py`. Elke kleurwijziging gaat daar naartoe en wordt geregenereerd,
anders is hij bij de volgende run weg.

### F2-a · Typografische hiërarchie

**Status: ✅ Klaar.** Beide fonts succesvol gedownload uit dezelfde release —
geen fallback nodig. Ladder 10/12/16/20/30 staat, `FS_SUB` (16) heeft echte
lezers gekregen.

`FS_SMALL == FS_BODY == 10`. Elk teken in het spel is 10 px; hiërarchie loopt
volledig via kleur, en `ORANJE` betekent daarom vier verschillende dingen.

**Doen:** haal `ark-pixel-12px-proportional-latin` en
`ark-pixel-16px-proportional-latin` uit dezelfde OFL-release die al in
`assets/fonts/HERKOMST.md` staat (release 2026.09.01,
github.com/TakWolf/ark-pixel-font), en maak de ladder
**10 / 12 / 16 / 20 / 30**. Ark Pixel is per grootte een eigen ontwerp, dus 12
en 16 zijn even scherp als 10 — dat is het hele punt van de familie, en het is
precies de reden dat de huidige ladder met één bestand "alleen hele veelvouden"
moest zijn.

**Belangrijk mechanisch detail:** er is **geen `Theme`-resource in het project**
en de globale font staat als één bestand in `project.godot:51`
(`[gui] theme/custom_font`). `font_size` op één TTF *schaalt* die font, en dat
is voor een pixelfont juist waziger — dus 12 en 16 vragen een **font per
grootte**. Twee routes:

- **Aanbevolen:** `UiKit` krijgt een `FONTS`-map (grootte → `FontFile`) en elke
  constructor doet `add_theme_font_override` naast `font_size`. Past bij het
  bestaande patroon: alle styling gaat al per node via `add_theme_*_override`.
- Alternatief: één echte `Theme`-resource introduceren. Structureel netter,
  maar dat is een aparte verbouwing en raakt elk scherm.

Importeer alle drie met antialiasing, hinting, subpixel-positionering en MSDF
**uit** — anders is een pixelfont waziger dan een vectorfont
(`assets/fonts/HERKOMST.md`).

**Als die bestanden niet beschikbaar blijken:** val terug op hiërarchie via
kapitalisatie, letterafstand en `FS_HEAD := 20` op minigametitels, en meld dat
expliciet — niet stil 10 px houden.

**Bijkomend:** `ORANJE` mag één betekenis houden (huidig doel). De andere drie
(vastgezet ticket, overwerk, net tijd geboekt) krijgen een eigen kleur.

### F2-b · Eén primaire knopstijl

**Status: ✅ Klaar.** `knop_primair()` staat en is toegepast op 13
bevestigende acties (inclusief het nieuwe pauzemenu); bewust niet op
afwijzende acties ("Run verlaten", "Stoppen", "Afsluiten"). `KNOP_MIN_H` op
30, `_test_balkmaat()` groen.

`UiKit` heeft precies één knopconstructor-familie; `Beginnen` en `Afsluiten`
zijn pixelidentiek op de focusring na, en elke touchknop zet `FOCUS_NONE` —
dus op een telefoon bestaat dat verschil niet. Zelfde voor `Vastleggen` naast
`Stoppen`.

**Doen:** `UiKit.knop_primair()` met blauwe vulling (zoals `DEPLOYEN` en
`Aan het werk` al hebben) en toepassen op *elke* bevestigende actie. Plus:
`KNOP_MIN_H` van 24 naar **30**. Op een Galaxy S21 (integer scale 5) is 26 px
= 43,3 dp en op elke 750×1334-iPhone (scale 3) 39 pt — onder het minimum van
44. 30 px geeft 50 dp / 45 pt.

**Let op:** `KNOP_MIN_H` heeft drie lezers — de knoppenbalk leidt zijn hoogte
eraf af en de HUD hangt zijn onderste rijen boven die balk
(`besturing.gd:53` → `hud.gd:32`). `_test_balkmaat()` meet een echte knop en
faalt als die keten breekt; dat is de vangrail.

### F2-c · De vijf leesbaarheidsingrepen uit de audit

**Status: ✅ Klaar**, en breder dan gepland: één grijs bleek niet te volstaan
(licht én donker oppervlak in het spel), dus zijn er twee gekomen —
`GRIJS_OP_LICHT` en `GRIJS_OP_DONKER`, elk apart contrastgetest. Tijdens de
eigen shot-sweep is een **vierde** stapelfout gevonden (een sliver van de
wereld zichtbaar tussen twee HUD-rijen) die de briefing niet noemde, en
meteen gerepareerd.

1. **`GRIJS` als body-tekst vervangen.** 3,0:1 op `WIT`, 3,1:1 op `PANEL`,
   3,9:1 op `PANEL_DARK` — elk voorkomen faalt op contrast, en het is de kleur
   van alle secundaire uitleg inclusief élke minigame-intro
   (`minigame_base.gd:106-109`).
2. **Hinttoast persistent** met tik-om-weg-te-leggen, zoals de telefoon al
   doet. De hint van t10 is 184 tekens over 6 regels in 2,6 s; Nederlands
   leest op ~15–20 tekens/s.
3. **De drie stapelfouten in `hud.gd`:**
   - doelbalk over tellerbalk: `_objective.offset_top = 22` terwijl de
     tellerbalk y4…30 beslaat → 8 px overlap (`hud.gd:132`).
   - toasts over de doelregel: `_toasts.offset_top = 46` terwijl de doelbalk
     bij twee regels tot y62–76 loopt (`hud.gd:178`).
   - zonenaam onder het interactiepaneel: `_prompt` specificeert 18 px hoogte
     maar heeft 26 px minimum en groeit met `GROW_DIRECTION_END` over de
     zonenband heen (`hud.gd:161-162`).
   Los ze op door de HUD-rijen **te stapelen in een VBox** in plaats van drie
   losse anchored panelen met hardgecodeerde offsets. Dat verwijdert de hele
   klasse fouten in plaats van drie getallen.
4. **Doelregel ontdubbelen:**
   `Nu: BBD-204 · De Vloer · Haal Victor uit De Vloer` →
   `Nu: BBD-204 · Haal Victor uit De Vloer` (`hud.gd:461-482`).
5. **De off-palette literals opruimen** — `#141824`, `#0b0d14`, `#e9e4d6`,
   `#484e60`, `#2b3144` staan nu los in zes bestanden. Naar `palette.py`.

Plus: `192` staat hardgecodeerd in `hud.gd:176` en `:230`; leiden uit de
viewport.

### F2-d · Navigatie: de kompasstrip

**Status: ✅ Klaar**, beide onderdelen gebouwd en aangezet (niet alleen punt 1
als fallback). Vloerbreedte komt uit `data/floor.json`, niet hardcoded — de
strip overleeft dus een latere vloerwijziging. `docs/GAME_DESIGN.md` is
bijgewerkt met de uitkomst.

**Waarom:** de camera toont 12 van 130 tegels (9,2% van de vloer). In 6 van de
11 trajecten ligt het doel buiten beeld, in 4 daarvan meer dan 20 tegels, en
`ObjectiveMarker` (`objective_marker.gd`) is een 8 px driehoek met **nul**
off-screen-behandeling — geen randklemming, geen pijl, geen afstand.

**Doen, twee dingen:**

1. **Randklemming + afstand op de bestaande marker.** Ligt het doel buiten
   beeld, dan een pijl tegen de schermrand met de ruimtenaam en het aantal
   meters. Dit is de minimale ingreep en hij is onomstreden.
2. **Een kompasstrip in de HUD** — een balk van 130 px (1 px per tegel) met je
   eigen positie en je doel erop.

Punt 2 spreekt `docs/GAME_DESIGN.md` tegen, dat een minimap afwijst omdat het
"een plaatje van een lijn" zou zijn. Die afwijzing is precies verkeerd om:
**deze vloer ís een lijn**, dus een 1D-strip is niet een arme kaart maar de
exacte vorm van het probleem. 130 px in een canvas van 192, één pixel per
tegel. Bouw het, zet het aan, en meet het in een playthrough; blijkt het ruis,
dan is punt 1 alleen ook al voldoende. **Werk `GAME_DESIGN.md` bij met de
uitkomst** in plaats van de tegenspraak te laten staan.

### F2-e · Minigames in de shell-look

**Status: ✅ Klaar.** Chrome is donker (zelfde ondergrond als titel-/
uitlegscherm), portretten tonen bij de intro. Onderweg gevonden en
gerepareerd: het portret at 37px van de tekstkolom, waardoor Willems en
Koens langere briefings onder de rand vielen (`DialogueBox.HOOGTE_MAX`
verhoogd); en twee knoppen stonden in de scroll i.p.v. `chrome_footer()`,
zichtbaar geplet/onder-de-vouw. F2-b bleek de primaire-knop-eis al overal te
dekken.

`minigame_base.build_chrome()` bouwt nu een crème `UiKit.panel()` met een 10 px
titel en een grijze intro. Zet dat om naar het donkere oppervlak, met de nieuwe
typografische ladder, portretten bij de intro (`say()` geeft nooit een portret
mee, dus de meest karaktergedreven tekst van het spel is gezichtsloos), en één
primaire knop per scherm.

**Concreet:** `DialogueController.say()` krijgt een optionele portret-parameter.
`DialogueBox.show_line()` ondersteunt hem al (`dialogue_box.gd:98-111`); alleen
de losse-regel-route geeft hem niet door (`dialogue_controller.gd:100-109`).

**Acceptatie voor heel F2:** een shot-sweep over álle schermen
(`--minigame=<id>` × 6, `--scherm=uitleg|select|einde`, `--bord`, `--kaart`,
`--klant=1..4`, `--briefing=<t>`) waarin geen scherm meer crème is, geen tekst
onder 4,5:1 contrast zit, en geen enkel element buiten de 192 px valt.
`_test_balkmaat()` blijft groen.

---

# F3 · De dag aanzetten

**Status: ⬜ Nog niet gestart.**

Dit is de fase die de audit "de kernlus" noemt.

### F3-a · De inbox loopt vol

**Waarom:** alle negen tickets staan open vanaf 09:12, dus "kiezen" is kiezen
in welke volgorde je negen identieke boodschappen doet. Het scherpste bewijs
uit de audit: de ticketvolgorde kost twee keer zoveel lopen als de optimale
volgorde (66,9 s tegen 33,7 s) en niets breekt daarvan — de volgorde betekent
niets.

**Doen — alleen data, nul nieuwe code:**

1. **Vier tickets open bij de start**, gekozen zodat ze west-naar-oost een
   natuurlijke eerste ronde vormen — de audit meet dat de huidige nummering
   vier keer over de vloer zigzagt terwijl de optimale route simpelweg
   west-naar-oost is.
   > De verdeling van eigendom maakt "altijd één eigen ticket in de eerste
   > vier" onmogelijk: zeven personages, en Daan (t01+t02) en Danny (t06+t07)
   > bezitten er elk twee. De invariant die wél haalbaar is en hetzelfde doet:
   > **het eigen ticket van elk personage zit in de eerste vier óf in de
   > eerste ontsluitingsgolf.** Leg dat vast in `_test_vrije_volgorde`'s
   > vervanger, want anders begint iemand met vier boodschappen van anderen en
   > dat is precies de opening die dit plan wil vermijden.
2. **De andere zes komen binnen tijdens de dag**, via `unlock_ticket` uit drie
   bronnen:
   - een klantbericht (F3-b),
   - een `reward_effects` van een eerder ticket ("nu dit werkt, blijkt dat
     stuk"),
   - een storing (F3-c).
3. **Narratieve motivatie per ontsluiting.** Niet "ticket 5 opent na ticket 3",
   maar: de merksound staat in Jira ómdat de klant hem 's ochtends noemde; de
   backend blijkt stuk ómdat de frontend nu wél data opvraagt.

**Wat níet mag:** een ticket achter een ánder ticket zetten zonder dat er een
tweede route naartoe is. `_test_vrije_volgorde()` (`test_runner.gd:1081`) eist
nu dat élk ticket het eerste kan zijn dat je doet. Die test moet **niet
worden weggehaald** maar herschreven naar de nieuwe invariant:

> Elk ticket is bereikbaar binnen elke speelvolgorde, en er is nooit een
> toestand waarin er nul tickets open staan terwijl er nog werk ligt.

Die tweede helft is de echte vangrail: hij maakt een dood punt onmogelijk. Voeg
er `_test_geen_dood_punt()` bij die over alle 10! volgordes (of een
gerandomiseerde steekproef) controleert dat er na elke voltooiing minstens één
ticket open staat zolang `done_count() < 10`.

### F3-b · De klant kan de middag laten ontsporen

**Waarom:** de vier telefoonbeats (87 woorden totaal) moeten de dramatische
boog dragen en zijn read-only. `Bus.klant_bericht` heeft één luisteraar en dat
is een QA-teller (`main.gd:121`).

**Doen:**

1. `data/klant_berichten.json` krijgt een `effects`-array per variant, met de
   bestaande whitelist uit `QuestEngine.run_effects()`: `unlock_ticket`,
   `set_flag`, `toast`, `kost_tijd`, `add_item`.
2. `telefoon.gd::_toon()` roept `QuestEngine.run_effects(v.effects)` aan nadat
   het bericht op het scherm staat — niet ervoor, zodat de speler de oorzaak
   ziet vóór het gevolg.
3. **Effects moeten precies één keer draaien.** `_gehad[bid]` bestaat al als
   idempotentie-wacht; koppel de effects daaraan en niet aan `_toon()`, want
   `--klant=` kan `_toon()` los aanroepen.
4. Voeg beats toe: van vier naar zes of zeven, waarvan minstens twee een
   ticket ontsluiten en één een ticket *wijzigt* (andere scope, andere
   eigenaar).

**Let op de bekende race:** `_wachtrij` is bewust een queue en niet een slot
(`telefoon.gd:39-47`) — k1 op 3/10 werd anders overschreven door k2 op 5/10 en
verscheen nooit, terwijl `_gehad` al was afgevinkt. Effects erbij zetten maakt
die bug van "een gemiste zin" tot "een ticket dat nooit opengaat". Breid
`_test_gevolgen()` uit met een controle dat elk `unlock_ticket` in
`klant_berichten.json` een ticket noemt dat bestaat, en dat de
playthrough-audit in `main.gd:252-275` faalt als een beat niet is geland.

### F3-c · Storingen: het kantoor wil iets van je

**Waarom:** de audit meet dat de énige momenten waarop het spel versnelt
*onderbrekingen* zijn — een nieuwe zone, een klanttelefoon, en Dirk. Dirk is
"het enige moment dat aanvoelt als een kantoor dat iets van je wil". Alle drie
zijn niet het werk zelf.

**Doen:** generaliseer Dirk. Nieuw `data/storingen.json` + een `Storingen`-node
in de wereldscene:

```
{ "id": "...", "when": { <Conditions-grammatica> },
  "trigger": { "min_tickets_done": n } | { "na_minuten": m } | { "zone": "..." },
  "soort": "npc_komt_langs" | "iets_gaat_stuk" | "ticket_wijzigt",
  "dialogue": "...", "effects": [ ... ], "world_changes": [ ... ] }
```

Hergebruik **volledig** wat er is: `Conditions.check()` voor `when`,
`QuestEngine.run_effects()` voor `effects`, `WorldMutator.apply()` voor
`world_changes`. Nul nieuwe grammatica.

Drie soorten, met verschillende texturen:

- **Een collega komt langs** — loopt naar je toe en vraagt iets. Dirk is het
  model; `npc.start_following()` bestaat al.
- **Iets gaat stuk** — een `world_change` maakt een prop rood, een ticket gaat
  terug naar TO DO. `docs/GAME_DESIGN.md` staat dit expliciet toe ("tickets
  mogen terugvallen naar TO DO").
- **Weekend maakt lawaai** — de "jungle" uit de schets. Kost je concentratie
  tijdens een minigame (F5).

**Harde regel, letterlijk overnemen uit het faalbeleid:** een storing kost
tijd en informatie, nooit voortgang. Geen enkele storing mag een ticket
onoplosbaar maken of een deur sluiten.

### F3-d · De klok gaat lopen

**Waarom:** `Session.worked_minutes` beweegt alleen bij een voltooid ticket.
Vier seconden en veertien minuten in het spel staat er allebei `09:12`. Een
spel over een overvolle werkdag kent geen enkele tijdsdruk.

**Doen:**

1. Een `Klok`-node in de wereldscene die met de speeltijd meetikt via
   `Session.book_time(1, &"verloop")`. `book_time` is al de enige plek die
   `worked_minutes` verhoogt en emit al `Bus.time_booked`, dus de HUD-klok
   loopt gratis mee (`hud.gd:332-337` kleurt hem al oranje na
   `Urenstaat.BUDGET_MIN`).
2. **Herbalanceer.** Nu boekt een ticket 30 of 45 minuten en het ophalen 15.
   Met een lopende klok wordt dat dubbel geteld. Doel:
   - een sessie van ~25 minuten reëel bestrijkt 09:12 → ergens rond 19:00,
   - de goedkoopst mogelijke dag van **elk** personage komt nog steeds boven
     acht uur uit — dat is een ontwerpinvariant, niet een balansdetail, en
     `_test_urenstaat()` faalt als een herbalancering hem stilletjes sloopt,
   - de gebeurtenisboekingen blijven bestaan als *zichtbare sprongen* (de
     urenrol-animatie is goed), de klok levert de onderstroom.
3. **De klok pauzeert niet tijdens een minigame** (dat is F5) en **loopt niet**
   tijdens dialoog en menu's — anders straf je lezen.
4. Zet de bestaande `overwerk`-conditie aan het werk: na 17:00 verandert wat
   collega's zeggen. Vier varianten gebruiken hem al.

**Acceptatie:** `_test_urenstaat()` uitgebreid met "de klok kan het spel niet
onwinbaar maken": simuleer een dag van 24 uur speeltijd en eis dat elk ticket
nog oplosbaar is en de voordeur nog opengaat.

---

# F4 · Tien tickets, zes puzzelschermen

**Status: ⬜ Nog niet gestart.**

**Het principe:** `docs/MINIGAMES.md` koos bewust elf mechanieken voor elf
tickets, om te ontsnappen aan vier tickets die dezelfde `SlotBoard` deelden.
Dat was de juiste correctie op het verkeerde probleem. De audit meet dat de elf
er alsnog vier zijn, geclusterd in "lees een prompt, tik één van N knoppen,
vergelijk met een drempel" (4×) en "verplaats een kaart, druk op controleren"
(3×).

De uitweg is niet minder tickets en niet gedeelde mechanieken, maar: **niet elk
ticket verdient een afgesloten scherm.** Vier tickets worden opgelost dóór in
de wereld te handelen. Dat is precies de "Kon dit een gewone interactie zijn?"-
tabel uit de audit, en het haalt vier van de tien puzzelschermen weg die het
kantoor stilzetten.

### F4-a · Blijft een volwaardig scherm (6)

| Ticket | Minigame | Ingreep |
|---|---|---|
| BBD-201 | `mg_scope` | **SIMPLIFY.** Sterkste ticket, dichtste scherm. 37 labels, negen kaarten met twee onbenoemde getallen, twee gelijktijdige budgetten, kolomkop afgekapt door de scrollbar. Benoem de twee getallen per kaart in de kaart zelf; `Vastleggen` wordt primair en `Stoppen` secundair. Mechaniek en dubbel budget **niet aankomen** — die zijn bewezen goed door de eigen brute-force `qa_solve`. |
| BBD-202 | `mg_standup` | **REDESIGN.** Sterkste concept, amper een spel: 45 s spreektijd in 42 s betekent precies één afkapping. En de briefing interpoleert `{belangrijk}` naar "Jonathan" — hij noemt wie je moet sparen. Maak het budget krapper (meerdere afkappingen nodig), laat de briefing één *soort* aanwijzing geven in plaats van de naam, en laat Danny als tweede belangrijke spreker ongemarkeerd — dat is de enige verborgen informatie in het spel en die is briljant. Repareer ook de tegenspraak "drie keer" in de prozatekst versus `4x afkappen` in de statusregel. |
| BBD-204 | `mg_uitlijnen` | **SLEPEN PRIMAIR.** Mooiste scherm van het spel, met een dpad erop. Vier pijltjes indrukken is de mobiele-UX-fout, niet de precisie: los precisie op met snapping naar het raster tijdens het slepen, niet met knoppen. En `perfect` valt nu vrijwel nooit (`VORM`-offsets en stap 4 delen nooit een rest), dus Victors enige gevolg valt nooit — repareer de data. |
| BBD-206 | `mg_abtest` | **HOUDEN, TRAIT OMDRAAIEN.** Beste feedback van alle elf. Maar Danny's voordeel (`toon_effect: true`) *verwijdert zijn eigen minigame*: de CRO'er is de enige die niet hoeft te meten. Draai om: hij krijgt een extra ronde, of hij ziet de spreiding in plaats van het effect. |
| BBD-208 | `mg_pijplijn` | **SIMPLIFY.** Hoogste cognitieve last van het spel (score 1/5 op hanteerbaarheid) en één van slechts drie minigames met een echte beslissing. Behoud het knelpunt-idee, halveer het aantal gelijktijdige dingen om te lezen. |
| BBD-210 | `mg_oplevering` | **DRUK EROP, MECHANIEK ONGEMOEID.** Zie F4-c. |

En `mg_urenstaat` (`mg_slotboard`): **vervangen door een lichtere vorm.** De
urenstaat moet blijven bestaan — de meest geloofwaardige handeling in het spel
— maar niet als 22-elementen sleepspel met kaartjes van 36×16 px, het kleinste
interactieve element van het spel. Drie voorgestelde verdelingen als
dialoogkeuze, of een schuifform met vier regels. Dirks oordeel accepteert per
code toch alles.

### F4-b · Wordt een wereldhandeling (4)

| Ticket | Nu | Wordt |
|---|---|---|
| BBD-203 De klant heeft feedback | `mg_choicescene` — een quiz waarvan het 3-puntsantwoord in alle drie de rondes **de eerste knop** is, en in alle drie de "stel een verduidelijkende vraag"-optie | **Een gesprek op de telefoon.** Zij bestaat al als telefoonscherm; maak dat scherm één keer tweerichtings. `DialogueBox.show_choices()` bestaat, `Telefoon` heeft al een eigen laag. Dit is het beste kanaal in het spel en het wordt eindelijk interactief. |
| BBD-205 De backend is stuk | `mg_cableboard` — één juist antwoord dat in de intro staat | **Een handeling bij het serverrack in het Patchhok.** Jonathans briefing geeft de aanwijzing, de dialoogkeuze is de handeling, `set_modulate` (na F0-d echt werkend) is het gevolg. |
| BBD-207 We hebben muziek nodig | `mg_tagpicker` — kapot gerenderd; de keuze is "ontwijk vijf grappen" | **Een dialoogkeuze van drie bij de speaker in de koffiecorner.** De grap blijft, het scherm verdwijnt. |
| BBD-209 Paardenbugs | `mg_whack` — slechtste fictie-fit (1/5), kapot gerenderd, nul gevolg | **De paarden lopen door het kantoor.** Als wereldobjecten die dwalen — ook in het toilet, de gang en Weekend, de 40% van de vloer die nu niets beloont. Je spreekt ze aan. `paard_bug.png` en `paard_klant.png` bestaan al, `spawn_npc`/`despawn_npc` bestaan al, en het klantpaard-dat-op-een-bug-lijkt blijft de grap. |

**Randvoorwaarde:** deze vier tickets moeten nog steeds een *werkwoord* hebben
dat uit hun eigenaar komt, en nog steeds in `Gevolgen` landen (F4-d). Een
wereldhandeling is geen degradatie — het is de vorm die de fictie al had.

### F4-c · Druk op de finale

**Waarom:** mechanisch de beste minigame in het project — verborgen bugs,
testen-om-te-weten, gepoorte fix, geen enkel juist antwoord, en de
begintoestand komt uit je hele dag via `Gevolgen.finale_start()`. Emotioneel
het vlakst: geen klok, geen gelijktijdigheid, geen onderbreking, en falen is
per ontwerp onmogelijk.

**Doen — geen nieuwe mechaniek, alleen opvoering:**

1. **Een klok.** De acht handelingen krijgen een deadline.
2. **Een onderbreking.** Minstens één storing landt tijdens de oplevering
   (F5). Het gescripte incident bij zes bestede handelingen bestaat al —
   maak er een echte onderbreking van.
3. **Laat de uitkomst verschillen in de banner.** Nu heet elke uitkomst
   `OPGELEVERD`; laat de score in de titel meebewegen. Falen blijft onmogelijk
   — dat is een goed besluit — maar niet-falen moet ergens in kosten
   uitdrukken.
4. **Snijd de tweede fase.** Een volledig schermvullende nep-deploymentconsole
   met zeven controleregels voor een uitkomst die per ontwerp altijd slaagt is
   het meest overgeëngineerde onderdeel van het spel. Houd drie regels en de
   foutcode (die is per personage anders en dat is goed).

### F4-d · Elk gevolg landt

**Waarom:** `Gevolgen.GETALLEN` leest vijf minigames uit; zes verdwijnen. Vijf
van de tien tickets kun je slecht doen zonder dat de dag het merkt, en dat
ondermijnt de vijf die het wél doen — de speler kan het patroon niet leren.

**Doen:** breid `GETALLEN` en de `match` in `Gevolgen.boek()` uit zodat **alle
tien** tickets een gevolg hebben, en zorg dat minstens acht ervan meewegen in
`finale_start()`. Nu doen BBD-203, 205, 207 en 209 niet mee.

**Randvoorwaarde uit de code zelf:** buiten de `GETALLEN`-tabel wordt geen
payload-veld gelezen, dus een minigame die morgen een veld krijgt kan het spel
niet stil veranderen (`gevolgen.gd:39-40`). Houd die eigenschap.
`_test_gevolgen()` bewaakt hem al.

---

# F5 · De wereld gaat van pause af

**Status: ⬜ Nog niet gestart.**

De zwaarste ingreep en de enige die de kernervaring echt verandert.

**Waarom:** `Shell.run_minigame()` zet `get_tree().paused = true`
(`shell.gd:190`), dus het kantoor is stil op precies de momenten dat de speler
werkt. De goede chaos die de opdracht beschrijft — een collega onderbreekt, een
ticket verandert, iets anders gaat stuk *terwijl* je bezig bent — is met een
pauzemodel structureel onmogelijk.

### F5-a · Ontkoppel "de speler kan niet lopen" van "de wereld staat stil"

Alle bouwstenen bestaan al:

- `Session._sloten` is een **getelde semafoor** met precies deze
  geschiedenis: vier systemen schreven een platte bool en de laatste
  `false`-schrijver opende de vloer onder een andere eigenaar
  (`session.gd:232-246`). Dat is exact wat hier nodig is.
- `Besturing._input()` bailt al op
  `Session.input_locked or Shell.minigame_active()` (`besturing.gd:178-180`).
- De minigame-root heeft `mouse_filter = STOP` en een `dimmer`, dus invoer gaat
  al naar de minigame.

**Doen:** `run_minigame()` vervangt `paused = true` door
`Session.lock_input()`, en `paused = false` door `unlock_input()`. Vervolgens
**elk `PROCESS_MODE_ALWAYS` nalopen** dat er alleen stond om de pauze te
overleven:

- `minigame_base` en `Shell` zelf (blijven ALWAYS — correct).
- `Shell._qa_shot()` gebruikt `create_timer(..., process_always = true)`
  expliciet omdát de tree gepauzeerd was (`shell.gd:95-96`). Herzien.
- `finish_with_banner()` gebruikt hetzelfde patroon (`minigame_base.gd:219`).
- `Autopilot` (`process_mode = ALWAYS`) — controleren dat hij niet dubbel gaat
  tikken nu de wereld ook draait.
- `Shell._naar_achtergrond()` slaat de vorige pauzestand op in
  `_pauze_voor_achtergrond` (`shell.gd:54-70`) zodat terugkomen uit de
  achtergrond geen lopende minigame ontpauzeert. Die logica moet mee.

**Wat wél blijft stilstaan:** de dialoogbox. Lezen mag geen straf zijn, en
`DialogueController` heeft zijn eigen input-grab. Dat is een expliciete keuze,
niet een omissie — zet hem in de code als commentaar.

### F5-b · Storingen landen in de minigame

**Het layerprobleem:** de telefoon zit op laag 30 en de minigame op 50 — bewust
("een melding mag een gesprek overstemmen maar nooit een minigame",
`telefoon.gd:32`). Dus een onderbreking tijdens een minigame kan niet als
overlay komen; hij moet **binnen het minigameframe** landen.

Dat is niet een beperking maar het betere ontwerp: de onderbreking komt in
hetzelfde kader waarin je werkt, en kost je iets binnen die mechaniek.

**Doen:** `MinigameBase` krijgt

```gdscript
func storing(tekst: String, kosten: Dictionary) -> void
```

die een strip in `chrome_header()` schuift (die functie bestaat al en is precies
hiervoor gemaakt, `minigame_base.gd:168-173`) en de minigame laat beslissen wat
`kosten` betekent — een seconde, een handeling, een bug. Elke minigame
implementeert het of negeert het expliciet.

De `Storingen`-node uit F3-c kijkt naar `Shell.minigame_active()` en routeert
naar `storing()` in plaats van naar de wereld.

**Frequentie is een ontwerpknop, niet een technische:** begin met **maximaal
één onderbreking per minigame** en nooit in de eerste 5 seconden. Meet het in
een playthrough voordat je opschaalt. Een onderbreking die je een oplossing
kost is chaos; twee die je een oplossing kosten zijn een bug.

**Acceptatie:** `--playthrough --autoplay` haalt 10/10 voor alle zeven
personages, ook met storingen aan. Nieuwe suite `_test_storingen()`: geen
storing kan een ticket onoplosbaar maken, en elke `qa_solve` blijft slagen met
een storing actief.

---

# F6 · Verificatie en docs

**Status: ⬜ Nog niet gestart.**

1. **Testsuite** — `Godot --headless --path . --scene res://tests/test_runner.tscn`.
   Nieuw of herschreven: `_test_save_ronde`, `_test_geen_dode_data`,
   `_test_geen_dood_punt`, `_test_storingen`, `_test_vrije_volgorde`
   (herschreven naar de nieuwe invariant), `_test_urenstaat` (klok),
   `_test_gevolgen` (tien tickets), `_test_wereld` (nieuwe vloer),
   `_test_balkmaat` (KNOP_MIN_H 30).
   > De audit merkt op dat 16.658 controles groen stonden terwijl twee layouts
   > kapot waren, `load_from_disk()` nul aanroepers had en zes items dode data
   > waren — omdat de suite data-integriteit test en geen spelerervaring. De
   > nieuwe tests hierboven moeten die kloof dichten, niet de teller verhogen.
2. **Playthrough** — `--playthrough --autoplay --quit-when-done` voor alle
   zeven personages. Eist 10/10 en dat elke klantbeat is geland (die audit
   staat al in `main.gd:252-275`).
3. **Shot-sweep** — alle zes minigames, alle shell-schermen, en vijf
   wereldshots over de nieuwe vloer. Vergelijken met `docs/audit-shots/`.
4. **Docs bijwerken** — `docs/LEVEL.md` (nieuwe vloer),
   `docs/MINIGAMES.md` (zes schermen, vier wereldhandelingen; de
   "elf mechanieken"-stelling herzien met de reden),
   `docs/QUESTS.md` (de inbox loopt vol),
   `docs/GAME_DESIGN.md` (lopende klok, storingen, de kompasstrip-uitkomst),
   `docs/ARCHITECTURE.md` (viewport 192×416, geen pauze meer tijdens
   minigames, de nieuwe lagen 40/50). En `docs/AUDIT.md` afsluiten met wat is
   gedaan en wat bewust niet.

---

## Expliciet niet doen

Uit de audit's "ONLY IF NECESSARY", plus wat dit plan overbodig maakt:

- **Een relatiesysteem met echte effecten.** Het probleem "personages voelen
  niet anders" wordt in F0-d en F4 goedkoper opgelost: één functietitel per
  persoon, en trait-voordelen die je opmerkt.
- **Dennis speelbaar maken.** De zeven bestaande personages zijn nog niet
  mechanisch onderscheiden; een achtste voegt een naamplaatje toe aan een
  probleem dat over naamplaatjes gaat. Wel: haal het dode `can_follow: true`
  uit zijn data of sluit het aan.
- **Nieuwe minigames.** Er is geen probleem dat een twaalfde oplost.
- **Een tweede werkdag of meer content.** Beter gebruik van bestaande content
  gaat voor meer content — dat is de hele stelling van de audit.
- **"Maak het mooier."** De pixelart is goed. F1-c en F2 gaan over diepte,
  leesbaarheid en hiërarchie, niet over afwerking.

---

## Orkestratie

Ik voer dit niet zelf uit — per stap gaat er een sub-agent op af met de
bovenstaande sectie als briefing, plus de codemap-feiten die erbij horen.

| Stap | Sub-agent | Uitgevoerd als | Status |
|---|---|---|---|
| F0-a t/m F0-d | 4 agents, parallel | 4 agents, parallel (git worktrees) | ✅ Alle vier gemerged |
| F1-a | 1 agent (vloergenerator) | 1 agent | ✅ Gemerged (met openstaand correctiepunt, zie boven) |
| F1-b, F1-c | 2 agents, ná F1-a | F1-b geen aparte agent (zie F1-b); F1-c 1 agent | 🟡 F1-c ✅, F1-b ⬜ |
| F2-a t/m F2-e | 3 agents | 3 waves: (F2-a+F2-b samen), (F2-c+F2-d samen), F2-e apart, telkens 1 agent | ✅ Alle vijf gemerged |
| F3-a, F3-b | 1 agent (data + telefoon) | nog te doen | ⬜ |
| F3-c, F3-d | 1 agent (storingen + klok) | nog te doen | ⬜ |
| F4-a | 1 agent per minigame, max 3 tegelijk | nog te doen | ⬜ |
| F4-b | 1 agent (vier wereldhandelingen) | nog te doen | ⬜ |
| F4-c, F4-d | 1 agent | nog te doen | ⬜ |
| F5 | 1 agent, seriëel — dit raakt Shell | nog te doen | ⬜ |
| F6 | 1 agent + ik lees de shots | nog te doen | ⬜ |

**Twee dingen geleerd tijdens de uitvoering, relevant voor de resterende
fases:**

- **Git-worktree-isolatie van sub-agents pinde tweemaal op de sessie-start-
  commit** in plaats van op de actuele `main`-HEAD op het moment van
  uitgeven — merkbaar doordat een agent zijn eigen taak niet kon voltooien
  (bijv. een verwezen bestand dat pas door een eerdere fase was toegevoegd
  bestond niet). Elke sub-agentbriefing bevat sindsdien een verplichte
  stap 0: bevestig de HEAD-commit, en als hij achterloopt (een schone
  fast-forward, geen echte divergentie), reset de eigen worktree er zelf
  op voordat je verder werkt. Dit patroon blijft nodig voor F3 t/m F6.
- Elke merge is los gedaan (nooit alles tegelijk), met een testrun ertussen.
  Twee keer was een handmatige conflictresolutie nodig (`mg_slotboard.gd`
  tussen F0-b/F0-c, en `hud.gd`/`palette.py` tussen F2-a+b/F2-c+d) — in
  beide gevallen ging het om twee kanten die onafhankelijk hetzelfde
  bestand op een net iets andere plek aanraakten, geen inhoudelijk conflict.

**Regels voor elke sub-agent:**

- Testsuite groen bij oplevering, of expliciet melden wat rood staat en waarom.
- `data/floor.json` en de gegenereerde kleurconstanten in `ui_kit.gd` nooit met
  de hand bewerken — altijd via de generator.
- Elke nieuwe legenda-letter krijgt een atlas-coördinaat, anders rendert hij
  stil als vloer.
- Nieuwe invarianten worden een test, niet een commentaarregel.
- Één commit per stap, in het Nederlands, in de bestaande stijl van de log.
