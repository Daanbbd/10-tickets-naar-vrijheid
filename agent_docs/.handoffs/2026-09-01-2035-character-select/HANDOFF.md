# Handoff — Karakterselectie herontwerp + intro-animaties + Bastiaan speelbaar

**Date:** 2026-09-01 20:35
**Repo:** fun (`/Users/daan/Documents/fun`) — branch `main`, HEAD `61f9e34`
(HEAD schoof tijdens deze sessie twee keer door parallel werk: `8f7e927`
"Pixelfont en HUD voor het portretcanvas" en `61f9e34` "Minigames leesbaar en
bedienbaar op een portretscherm". Zie *Wat er al door anderen is opgelost*.)
**Next session focus:** drie samenhangende brokken, in deze volgorde:
1. het selectiescherm herbouwen (het is nu niet alleen saai, het is **stuk** op 192×416);
2. zes intro-animaties (één per speelbaar personage) in de sprite-generator;
3. Bastiaan als zesde speelbaar personage toevoegen.

**Aanbevolen volgorde:** eerst 3 (Bastiaan in de data), dan 1 (scherm), dan 2 (animaties).
Reden: het scherm moet zes rijen aankunnen en de animaties hangen aan het scherm.
Bouw je het scherm eerst voor vijf, dan moet de layout er daarna weer door.

## Wat er in deze sessie is gebeurd

**Alleen één ding is daadwerkelijk gewijzigd:** de klant is hernoemd van
*Mevrouw Van Zutphen* naar **Mevrouw P. Aardenmens** (op verzoek van de gebruiker;
het is een woordgrap die past bij de paardensupplementen-webshop). Twaalf
voorkomens over zes bestanden:

- `data/npcs.json` (het `klant`-record)
- `data/minigame_content.json` (4×)
- `data/tickets/t03.json`
- `data/dialogue/tickets.json` (2×)
- `docs/CHARACTERS.md`, `docs/dialogue-content.md`

Testsuite daarna: **6500 controles, 0 fout.** Het id blijft `klant`, dus er is
geen dialoogregel geraakt — de naam stond alleen in spelerzichtbare teksten.

Al het andere in deze sessie is **onderzoek, ontwerp en mockups**. Er is geen
regel GDScript en geen regel generator-code aangepast.

> **Let op bij het lezen van `git status`:** de working tree bevat ook
> wijzigingen die **niet** van deze sessie zijn — `scripts/ui/ui_kit.gd`,
> `scripts/ui/hud.gd`, `scripts/ui/boot.gd`, `scripts/minigames/*`,
> `tools/generators/palette.py`, `gen_ui_kit_colors.py`. Die kwamen er tijdens de
> sessie bij vanuit parallel werk (palet/UI-kit). Schrijf ze niet op dit werk.
> Van deze sessie zijn alleen de zes bestanden met de naamswijziging hierboven,
> plus deze handoff-map.

## Wat er al door anderen is opgelost (tijdens deze sessie)

Twee dingen die eerder in deze sessie als probleem zijn benoemd, zijn door
parallel werk al weg. Ga er niet meer aan beginnen:

1. **De pixelfont hangt nu in een Theme** (`8f7e927`). De eerste shot van dit
   scherm liet nog de standaard Godot-sans zien; dat is verholpen.
2. **`_qa_shot()` is verhuisd naar `autoload/shell.gd:28`** en werkt nu op elk
   scherm. Dus dit werkt gewoon:
   ```
   /Applications/Godot.app/Contents/MacOS/Godot --path . -- \
     --scherm=select --shot=/tmp/select.png --shot-na=1.5
   ```
   Eerder zat die functie alleen in `scripts/world/main.gd` en viel hij niet bij
   `--scherm=select`. Gebruik dit om na elke wijziging te verifiëren.

Ook is de kaartenrij inmiddels een wrappende layout geworden (3+2 in plaats van
5 naast elkaar). Het scherm is daarmee **niet** af — zie hieronder.

## Deel 1 — Het selectiescherm

### Diagnose: het is kapot, niet alleen saai

Zie `00-nu-kapot.png` in deze map — een echte shot uit de build op `61f9e34`,
niet een reconstructie.

De viewport is **192×416** (`project.godot:29`), portrait, integer stretch. Het
scherm bevat meer content dan er in 416 px past, en er is geen enkel plek waar dat
budget wordt afgedwongen. Wat je op de shot ziet:

- **de kop "WIE BEN JIJ VANDAAG?" staat boven de bovenrand**, buiten beeld —
  helemaal bovenaan is alleen nog het staartje "niet." van de subtitel te zien;
- **de knop "Aan het werk" staat onder de onderrand**, dus de speler ziet zijn
  eigen bevestigingsknop niet;
- de laatste regel van het detailpaneel ("collega.") wordt door de onderrand
  afgesneden.

De `VBoxContainer` groeit dus aan twee kanten het scherm uit. Dit is een andere
uiting van hetzelfde probleem als vóór `8f7e927` (toen liep dezelfde overvloed
horizontaal uit beeld, omdat vijf kaarten van 84 px 436 logische px in een kolom
van 168 px vroegen). Een andere container lost dat niet op: **de content moet op
dieet.** Dat is precies wat het voorstel hieronder doet.

Daarnaast, en dat was de eigenlijke vraag van de gebruiker ("niet saai"):

- het is een spec-sheet: naam, rol, tagline, description, specialisms plus een
  telregel — zes tekstblokken op 8 px in 168 px breedte;
- "Jij lost 4 van de 10 tickets zelf op" is een abstract getal op het enige
  moment dat de speler nog geen enkel ticket kent;
- nul beweging; elke kaart speelt dezelfde `klik` via `AudioDirector.play_ui`;
- de wereldsprite waar je 30 minuten naar kijkt is nergens te zien, alleen de
  fotoportretten;
- geen `grab_focus`, geen toetsenbordnavigatie (het titelscherm doet dat wél,
  `scripts/ui/title_screen.gd:43`).

### Het ontwerp dat is afgesproken

Verticale lijst in plaats van een rij, met een podium erboven. Zie
`01-voorstel-bastiaan.png` en `02-voorstel-victor.png`.

Van boven naar beneden:

1. **Kop** "WIE BEN JIJ VANDAAG?" in `BLUEBIRD_BRIGHT`.
2. **Podium** (~105 px hoog): een strook echte vloertegels uit `office_atlas.png`
   met `monitorwand_4x1` en een op de helft geschaalde `bureau_4x4`, en daarop de
   gekozen collega als **volledige gelaagde sprite op 3×** (54×102) met
   contactschaduw (`schaduw_karakter.png`) en een vloerlicht in zijn accentkleur.
   Bij wisselen loopt de oude eruit met `walk_left/right` en komt de nieuwe van de
   andere kant in lopen, ~0,25 s.
3. **Tagline** in de accentkleur, gecentreerd, max 2 regels.
4. **Ticketbalk**: tien blokjes van 15×10 = de tien tickets. De tickets die jij
   zelf oplost lichten op in je accentkleur, de rest blijft `#2b3144`. Wissel je
   van collega, dan *verspringen* de opgelichte blokjes. Dat is de kernspanning
   uit `docs/GAME_DESIGN.md` in één beweging, zonder er een zin over te schrijven.
   **Puur weergave, niet aantikbaar** (zie mobiel hieronder).
5. **Stijlregel**: één regel over hoe jouw dag speelt, die `description` en
   `specialisms` op dit scherm vervangt. Bijv. Victor: "Twee tickets zelf. Je zit
   veel aan je eigen bureau." Willem: "Eén ticket zelf. Je loopt de hele dag heen
   en weer. Dat is het punt." Dit is wat een 1-ticketrun van een mindere keuze in
   een andere speelstijl verandert.
6. **Lijst** van zes rijen, 26 px hoog met 28 px pitch: portret 16×20, naam, rol,
   en `n/10` rechts in de accentkleur. Geselecteerde rij krijgt accentrand,
   lichtere vulling en een 3 px accentbalk links.
7. **Knop** "Aan het werk", 28 px hoog.

`description` en `specialisms` verhuizen naar het ticketbord — ze zijn hier niet
actiegericht.

**Naam en rol staan bewust niet meer los onder het podium.** Ze stonden dubbel op
het scherm; de opgelichte rij zegt hetzelfde. Dat schrapte de 24 px die zes rijen
nodig hadden.

### Mobiel is de harde randvoorwaarde

De gebruiker heeft bevestigd: **dit is een mobile game.** Doorgerekend: op een
1080-brede telefoon schaalt 192×416 met integer stretch naar 5× (960×2080,
nauwelijks letterbox — het formaat is goed gekozen). Eén logische px is dan
ongeveer **0,34 mm**. Android's 48 dp ≈ 9 mm komt daarmee uit op **26 logische px
als comfortabel minimum**, 21 px als absolute bodem. Vandaar rijen van 26 en een
knop van 28.

Wat daaruit volgt:

- **Geen hover.** Het idee om op een ticketblokje te tikken voor de tickettitel is
  geschrapt: 15×10 px is niet aan te tikken. De balk is weergave.
- **Swipen over het podium** wisselt van collega. De veegrichting is de richting
  waarin de sprite in- en uitloopt, dus gebaar en animatie vallen samen.
- **Haptiek naast geluid.** `Input.vibrate_handheld(20)` bij wisselen, langer bij
  bevestigen. Mobiel speelt vaak met de klank uit, dus de vijf/zes eigen
  selectiegeluiden mogen niet het enige onderscheid zijn.
- **Duimzone.** Lijst en knop in de onderste tweederde, podium bovenin en
  niet-interactief. Klopt al in de layout, maar het is nu een eis.
- Toetsenbordnavigatie mag blijven, maar niet als hoofdroute — de headless
  QA-flags en desktoptests hebben er wat aan.

**Prijs die nog niet betaald is:** de regel "Wisselen kan niet" is uit de layout
gevallen (er was geen ruimte meer onder de knop). Voorstel dat met de gebruiker is
gedeeld: maak er de eerste dialoogregel van de dag zelf van, in de wereld. Dat
landt daar harder dan als grijze 8 px onder een knop. Nog niet uitgevoerd.

### Nog niet besloten / niet gebouwd

- Zes eigen selectiegeluiden in `tools/generators/gen_audio.py` (Victor
  toetsaanslag, Jonathan serverfan, Danny notificatie, Willem hoorn die neergaat,
  Daan marker, Bastiaan een kort *tik*). Alleen voorgesteld.
- De pixelfont daadwerkelijk in een Godot-`Theme` hangen.

## Deel 2 — Intro-animaties

**Scope is expliciet afgebakend door de gebruiker: alleen het intro-selectiescherm.**
Niet in de wereld, niet voor NPC's op hun standplaats. Dat maakt het aanzienlijk
goedkoper dan de eerste inschatting.

### De lijst

| Personage | Bezigheid | Variantnaam |
|---|---|---|
| Danny | blikje bier naar de mond | `bier` |
| Victor | hobby horse | `hobbyhorse` |
| Daan | huilen en Claude vragen | `huilen` |
| Jonathan | gamen | `gamen` |
| Willem | padel | `padel` |
| Bastiaan | zoekglas | `zoekglas` |
| ~~Koen~~ | peukie roken | `peuk` |

**Koen viel uit de scope.** De gebruiker noemde hem in de oorspronkelijke lijst,
maar hij is NPC (`data/npcs.json`, Backend developer, Patchhok) en staat dus niet
in het selectiescherm. Advies dat is gegeven: bouw de variant `peuk` alsnog — hij
kost niets extra in een data-driven laag en ligt klaar als Koen ooit speelbaar
wordt of als je hem aan iemand anders hangt. **Openstaande vraag aan de gebruiker:
wil je Koen ook speelbaar? Dan zijn het zeven personages.**

### Hoe het in het systeem past

Niet als sheet per persoon. Als **zevende laag**, precies zoals `accessory` werkt:

- `tools/generators/gen_characters.py`: `laag_bezigheid(v, richting, p, variant)`
  erbij, plus een entry in `LAGEN` (regel 438).
- `scripts/entities/character_sprites.gd`: `&"bezigheid"` toevoegen aan `VOLGORDE`
  (regel 20) en aan `STANDAARD_LOOK` (regel 26).
- Variantnaam per persoon in `data/characters.json`, in het `look`-blok.

Daarmee blijft "één sheet, oneindig veel collega's" overeind en blijft de cache op
de look-combinatie staan (`_looksleutel`, regel 116).

### De sheet zit vol — en dat is nu goedkoop op te lossen

De 8 kolommen zijn allemaal in gebruik: 0 idle, 1 adem, 2 knipper, 3–6 loop, 7
praat (`gen_characters.py:17`, `pose()` op regel 102).

Omdat het podium je altijd aankijkt is **alleen de rij `down` nodig**:

- `COLS, ROWS = 8, 4` → `12, 4` in `gen_characters.py:30` en `const COLS := 8` →
  `12` in `character_sprites.gd:15`. Sheets gaan van 144×136 naar 216×136.
- `pose()` krijgt vier nieuwe kolommen (8–11).
- `bouw_sheet` vult die kolommen alleen voor rij 0; rijen 1–3 blijven daar
  transparant. Dat is geen fout maar de bedoeling.
- De runtime krijgt één animatie `bezig_down` in plaats van vier richtingen.

Er is precedent voor richting-afhankelijk weglaten: het knipperframe doet al
`2 if rij != 1 else 0` (regel 97) en de helft van de accessoires doet
`if richting == 1: return`.

### Het echte knelpunt: `pose()` heeft één `arm`-waarde

`pose()` geeft `arm` terug als één getal, en dat wordt op **drie** plekken
symmetrisch tegengesteld toegepast — linkerarm `+arm`, rechterarm `-arm`:

- `gen_characters.py:149` (armen in `laag_body`)
- `gen_characters.py:158-159` (handen/outlines in `laag_body`)
- `gen_characters.py:260` (mouwen in `laag_outfit`)

**Eén arm omhoog is daarmee niet uit te drukken**, en vijf van de zes bezigheden
hebben dat nodig. Fix: maak er `arm=(links, rechts)` van en pas die drie call
sites aan. Zonder deze splitsing werkt geen enkele van deze animaties. Dit is de
eerste taak van deel 2.

Daarna komt het gratis: elke laag krijgt `p` al binnen, dus body en outfit volgen
de nieuwe armstand zonder dat ze iets over bezigheden hoeven te weten.

### Per animatie

Vier frames elk, alleen rij `down`.

| Variant | Wat beweegt | Prop | Aandachtspunt |
|---|---|---|---|
| `bier` | rechterarm omhoog naar de mond | blikje 2×3 in accentkleur | leest goed, blikje op ooghoogte |
| `peuk` | rechterarm half omhoog, blijft daar | peuk 1×1 + rookpixel die omhoog drijft | de rook doet het werk |
| `gamen` | beide armen naar voren, duimen tikken | controller 4×2 voor de romp | — |
| `hobbyhorse` | rechterarm vast, romp wipt (`bob` 0/-1) | stok verticaal + paardenkop 4×4 op schouderhoogte | kop **binnen** de 16 px houden |
| `padel` | rechterarm achter → door | racket verticaal 3×5 | krap, verticaal houden |
| `huilen` | frames 8–9 handen naar het gezicht, 10–11 hoofd omlaag | traan 1×1, scherm 5×4 met `BLUEBIRD_INK`-gloed | **de moeilijkste**: twee grappen in één animatie, dus serieel maken |
| `zoekglas` | rechterarm omhoog naar ooghoogte, romp leunt 1 px in op frame 3 | glas 3×3 met lenspixel + 2 px steel | op frame 4 licht één pixel op de monitorwand **rood** op: hij heeft weer iets gevonden |

**De 16 px-grens.** Het logische vak is 16 breed met 1 px marge voor de
outline-shader (`gen_characters.py:27-29`). Een racket of paardenkop die
zijwaarts uitsteekt wordt afgesneden. Alles verticaal en tegen het lichaam
houden. `FW` verbreden kan, maar dan moet elke bestaande laag-sheet opnieuw en de
runtime-constante mee — niet doen voor twee props.

### Speelgedrag op het podium

Idle, na ~1,2 s één keer de bezigheid, terug naar idle. Niet doorlussen — dan
wordt het een tic in plaats van een grap.

## Deel 3 — Bastiaan als zesde speelbaar personage

De gebruiker wil dit ("hij is erg precies en heeft oog voor detail"). Hij is al
verder gebouwd dan het lijkt:

**Bestaat al:**
- portret: `assets/sprites/portraits/bastiaan.png`
- look: `data/npcs.json` → `bastiaan` (slank / stekels / hoodie / pet, kleuren erbij)
- **zijn stem, compleet**: de `TICS`-tabel in `scripts/tests/test_runner.gd:258`
  geeft hem `,,`, "hiya", "trouwens", "planning is toch ver leeg", "tikkie" — met
  een mechanische test op zijn dubbele komma (regel 297). Er is geen stemwerk
  nodig, alleen toewijzing.

**Moet gebeuren:**
1. `data/characters.json`: entry erbij. Rol Frontend developer. Accent
   **`#e8c547`** — de enige vrije hoek van het palet (bezet: `#f4a259` Daan,
   `#43aa8b` Danny, `#5b8def` Victor, `#9b5de5` Jonathan, `#e05263` Willem). Let
   op het neveneffect: zijn `pet` is een accessoire in accentkleur, dus hij krijgt
   een gele pet. In de mockup ziet dat er goed uit.
   Voorgestelde tagline: "Vindt altijd nog één ding."
2. `data/npcs.json`: `bastiaan` wordt `npc_bastiaan` met
   `is_playable_colleague: true` en `dialogue_id: collega_bastiaan`, zoals de
   andere vijf. Zie `npc_victor` als model.
3. Een finale: `finale_id` + een `bastiaan`-variant in `mg_deploy.varianten`
   (`data/minigame_content.json`). Voorstel in de stijl van de rest
   (SCOPE NOT APPROVED, FRONTEND BUILD FAILED, …): **VISUAL REGRESSION DETECTED**.
4. `scripts/tests/test_runner.gd:53` staat hardgecodeerd op
   `character_ids().size() == 5`.
5. Zijn intro-animatie `zoekglas` (deel 2).

**Goed nieuws voor de dialoog:** de 69 `variants`-lijsten in
`data/dialogue/tickets.json` werken op `"when": {"character": [...]}` en eindigen
allemaal op een fallback zonder `when` (dat wordt door de testsuite afgedwongen).
Bastiaan valt daar dus overal netjes door: hij is **direct speelbaar** en klinkt
alleen nog generiek. Zijn regels kunnen daarna per ticket worden toegevoegd, in
plaats van in één keer.

### De openstaande beslissing: welk ticket wordt zijn vakgebied

Dit is een ontwerpkeuze voor de gebruiker, nog niet gemaakt.

Huidige verdeling (9 van de 10; `t10`/BBD-210 is de gedeelde finale en heeft geen
eigenaar): Daan `t01,t02` · Danny `t06,t07` · Victor `t04,t08` · Jonathan
`t05,t09` · Willem `t03`.

**Aanbeveling: BBD-209 (`t09`, "Er lopen paardenbugs door het kantoor") → Bastiaan.**
Dat is een vind-probleem, niet een bouw-probleem, en het valt exact samen met het
zoekglas. `t04` moet bij Victor blijven — "de frontend is stuk / het staat scheef"
ís letterlijk zijn tagline.

Prijs: Jonathan zakt naar één ticket (alleen `t05`). Verdeling wordt 2/2/2/1/1/1.
De stijlregel op het scherm verkoopt een 1-ticketrun al als een andere speelstijl.

Alternatief: `t08` (de AI-video) van Victor afhalen. Thematisch een stuk zwakker.

**Deze verdeling zit al zo in de mockup** (`mockup_select.py`, regels met
`BAS = {...}` en de `jonathan`-override) — dat is een aanname in de mockup, geen
besluit in de data.

## Current state

- Alleen de naamswijziging is doorgevoerd. Testsuite groen (6500/0).
- `data/characters.json` heeft nog **vijf** personages; Bastiaan is nergens
  speelbaar.
- `scripts/ui/character_select.gd` is onaangeraakt en dus nog kapot op 192×416.
- `gen_characters.py` staat nog op `COLS = 8`; geen bezigheid-laag.
- Er is geen enkele animatie getekend.

## Next steps

**Stap 0 — beslissing ophalen (blokkeert stap 1):**
- Welk ticket wordt Bastiaans vakgebied? (aanbeveling: `t09`, zie hierboven)
- Wordt Koen ook speelbaar? (bepaalt of het zes of zeven personages worden)

**Stap 1 — Bastiaan in de data (klein, mechanisch):**
1. Entry in `data/characters.json`, `bastiaan` → `npc_bastiaan` in `data/npcs.json`.
2. `finale_id` + `mg_deploy`-variant.
3. `test_runner.gd:53` naar 6.
4. Testsuite draaien: die loopt de questketen voor **elk** personage van 0 tot
   10/10 af en controleert ook dat een ticket buiten je vakgebied *niet* oplosbaar
   is zonder collega. Dat is de vangrail voor deze hele stap.

**Stap 2 — het selectiescherm herbouwen:**
1. `scripts/ui/character_select.gd` herschrijven volgens deel 1 (~200 regels).
   Alles in code met `UiKit`, zoals de rest van het project.
2. Een `stijl`-veld toevoegen aan `data/characters.json` voor de stijlregel.
3. Swipe op het podium, `Input.vibrate_handheld`, tapformaten aanhouden (26/28 px).
4. Verifiëren met een echte shot na elke wijziging:
   `--scherm=select --shot=/tmp/select.png --shot-na=1.5`. Dat werkt sinds
   `_qa_shot()` in `autoload/shell.gd` staat.

**Stap 3 — de animaties:**
1. Eerst `arm=(links, rechts)` in `pose()` + de drie call sites. Draai
   `gen_characters.py` en controleer dat de loopcyclus er nog identiek uitziet
   (regressie-check vóór je nieuwe kolommen toevoegt).
2. `COLS` naar 12 op beide plekken, `pose()` kolommen 8–11.
3. `laag_bezigheid` met **twee** varianten eerst — `bier` en `zoekglas` — en
   visueel checken of ze leesbaar zijn op 16×32 vóór de andere vier erbij komen.
   Dat was de expliciete aanpak die met de gebruiker is afgesproken.
4. `bezig_down` in `character_sprites.gd`, en het podium laten spelen: idle → na
   1,2 s één keer → idle.

## Gotchas

- **De mockups zijn Pillow, geen Godot.** `mockup_select.py` in deze map
  repliceert de laagcompositie en herkleuring van `character_sprites.gd` in
  Python. Als je `gen_characters.py` verandert (zeker de `arm`-splitsing), loopt
  de mockup uit de pas met de echte sprites. Hij is een ontwerptekening, geen test.
- **Bastiaan staat hardgecodeerd in `mockup_select.py`** omdat hij nog niet in
  `data/characters.json` staat. Haal dat blok weg zodra hij er wel in staat.
- **Er staat een `.gdignore` in deze map.** Zonder die file importeert Godot de
  drie PNG's en maakt er `.import`-bestanden bij. Zet hem niet weg. (Zelfde truc
  als bij `GD-Agentic-Skills/`, zie `docs/TESTING.md`.)
- **Regelbreedte is een harde grens.** Met de ark-pixel-font op 10 px passen er
  ongeveer **34 tekens** per regel binnen de marges (gemeten: 18 tekens = 88 px).
  Elke regel copy op dit scherm moet daaronder blijven, anders valt hij eraf —
  precies wat er nu misgaat.
- **`.godot/global_script_class_cache.cfg` niet weggooien** zonder daarna
  `Godot --headless --path . --editor --quit` te draaien; alleen de editor kan die
  cache herbouwen. Zie `docs/TESTING.md`.
- De Godot MCP-server (`godot`) gaf deze sessie een connectiefout
  ("ConnectionRefused") en kon niet gebruikt worden. Screenshots zijn via
  `--shot=` uit de gewone build gehaald.
- `data/characters.json` heeft **geen** `t10` in enige `owned_tickets` — dat is
  correct, BBD-210 is de gedeelde finale. Voeg hem nergens toe.

## Pointers

**Deze map:**
- `00-nu-kapot.png` — echte shot van het huidige scherm op 192×416
- `01-voorstel-bastiaan.png`, `02-voorstel-victor.png` — mockup, zes personages
- `mockup_select.py` — genereert die mockups:
  `tools/.venv/bin/python agent_docs/.handoffs/2026-09-01-2035-character-select/mockup_select.py <id>`

**Het scherm:**
- `scripts/ui/character_select.gd` — te herschrijven
- `scripts/ui/ui_kit.gd` — palet en bouwstenen (kleuren zijn gegenereerd uit
  `tools/generators/palette.py`, niet handmatig bewerken)
- `scripts/ui/title_screen.gd` — model voor focus/geluid (`grab_focus` regel 43)
- `autoload/shell.gd` — routing, fades, en `_qa_shot()` (regel 28)

**De sprites:**
- `tools/generators/gen_characters.py` — `pose()` regel 102, `LAGEN` regel 438,
  `laag_accessory` regel 370 als model voor `laag_bezigheid`
- `scripts/entities/character_sprites.gd` — `VOLGORDE` regel 20, `COLS` regel 15,
  animatie-opbouw vanaf regel 84
- `assets/sprites/props/paard_bug.png`, `paard_klant.png` — bestaande paardenkop,
  te lenen voor de hobby horse

**De data:**
- `data/characters.json`, `data/npcs.json` (`npc_victor` als model voor
  `npc_bastiaan`)
- `data/dialogue/tickets.json` — 69 `variants`-lijsten op `{"character": [...]}`
- `data/minigame_content.json` — `mg_deploy.varianten` voor de finales
- `scripts/tests/test_runner.gd` — regel 53 (aantal personages), regel 258 (`TICS`)

**Docs:**
- `docs/GAME_DESIGN.md` — kernloop en de 70/30-richtlijn
- `docs/CHARACTERS.md` — cast (bijgewerkt met P. Aardenmens; **nog niet** met
  Bastiaan als speelbaar)
- `docs/TESTING.md` — QA-vlaggen, incl. `--scherm=select` en `--shot=`
