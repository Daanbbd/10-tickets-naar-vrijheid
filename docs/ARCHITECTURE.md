# Architectuur

Godot **4.7.2**, GDScript met statische typering. Renderer `gl_compatibility`
(2D pixel art), viewport **192×416** (staand, telefoonformaat), venster 384×832,
stretch `canvas_items` met `integer` scaling en `nearest` filtering.

## Kernidee

> **De wereld is een pure functie van de sessie: `wereld = f(Session)`.**

Elke zichtbare verandering staat declaratief in data en is *idempotent*. Bij het
laden van de wereld draait `WorldMutator.replay_all()` alle veranderingen van
opgeloste tickets opnieuw af. Dat levert gratis op: state persistence, QA-starts
midden in het spel, en een minigame-overlay die de wereld niet hoeft te
herbouwen.

Daaruit volgt één harde scheiding:

| | draait | waar |
|---|---|---|
| `reward_effects` | **exact één keer** | `QuestEngine.run_effects()` |
| `world_changes` | **idempotent, elke replay** | `WorldMutator.apply()` |

De testsuite dwingt af dat de op-namespaces gescheiden blijven.

`world_changes` kent elf ops (`WorldMutator.OPS`): `set_visible`, `set_text`,
`set_modulate`, `set_locked`, `swap_texture`, `set_frame`, `spawn_npc`,
`despawn_npc`, `set_ambience`, `cue` en `camera_focus`. De twee beeld-ops
`swap_texture` en `set_frame` veranderen de sprite van een `WorldObject` — de
weg waarlangs een opgelost ticket pixels verandert in plaats van alleen een
label.

## Autoloads (5)

Regel: een autoload bevat *state of routing*, nooit gameplaylogica.

| Autoload | Verantwoordelijkheid |
|---|---|
| `Bus` | Alleen signal-declaraties. Geen state, geen logica. |
| `GameData` | Laadt alle JSON één keer en parset naar getypte modellen. Daarna read-only. |
| `Session` | Muteerbare runtime-state: personage, flags, tellers, voorwerpen, ticketstanden, gevonden tickets, de gekozen ticket en per opgelost ticket het klokmoment (`completed_at`, waar `Gevolgen.ongetest_na_vijf()` op leest). Schrijft en leest de save. |
| `Shell` | Scene-router, fades, host van de minigame-overlay. De enige plek die `get_tree().paused` aanraakt; het pauzemenu vraagt het via `pauzeer_voor_menu()`. |
| `AudioDirector` | SFX-pool en de muziekstapel. Luistert zelf naar de Bus, dus scenes regelen hun eigen muziek niet. |

Bewust géén autoload: dialoog (leeft als node in de wereldscene), quests
(`QuestEngine` is volledig statisch), inventory (dictionary in `Session`).

## Afhankelijkheidsgraaf (acyclisch)

```
GameEnums, models          (geen afhankelijkheden)
        ^
Conditions  ->  Session (autoload)
        ^
QuestEngine ->  Session, GameData, Bus, Conditions
```

`QuestEngine` is een klasse met uitsluitend statische methodes. Dat is bewust:
GDScript struikelt over wederzijdse `class_name`-verwijzingen, en zo blijft de
queststroom headless testbaar zonder scene.

Een speelbeurt begint op precies één plek: `QuestEngine.start_run(personage)`.
Die zet de sessie op en de tickets open. Roep `Session.start_new()` nooit los
aan — dan blijft elk ticket LOCKED en is er geen enkele interactie meer die
iets oplevert. De testsuite (`startroutes`) bewaakt dat.

## Data in JSON, niet in `.tres`

Alle content staat in platte JSON in `data/`. Reden: de content wordt grotendeels
gegenereerd en moet buiten de editor diff-baar en valideerbaar zijn. `.tres` is
een editorformaat met resource-UID's dat zich daar slecht voor leent. Een
laadlaag (`GameData`) zet JSON om in getypte `Resource`-klassen, zodat
gameplaycode nooit een rauwe `Dictionary` aanraakt.

## Twee mini-grammatica's

**Condition** — gedeeld door quest-requirements, dialoogvarianten en
interactable-gating. Keys: `character`, `trait`, `flags_all`, `flags_none`,
`tickets_done`, `tickets_not_done`, `has_item`, `min_tickets_done`, `overwerk`.
Eén evaluator: `Conditions.check()`.

> `overwerk` is een bool en staat daarom achter een `has()`-wacht, anders dan
> `min_tickets_done` erboven. Die draait onvoorwaardelijk met default 0, wat voor
> een getal onschuldig is; een bool met default `false` zou elke lége conditie
> "het is geen overwerk" laten beweren en na vijven elke fallbackvariant in de
> game omklappen. En niet via `_names()`, want dat maakt van een bool `&"true"`.

**Effect / WorldChange** — zie de tabel hierboven. Beide hebben een
whitelist die de validator controleert.

> De effect-op `kost_tijd` boekt minuten op de werkdag. Bedoeld voor scènes (een
> kop koffie, een praatje), niet voor tickets: die prijs hangt af van *hoe* je ze
> oploste en kan daarom niet uit data komen. Code boekt wat het systeem kost,
> data boekt wat een scène kost.

## Scene-boom van de wereld

```
Main (Node2D)                  main.gd — expliciete bootvolgorde
├── World (Node2D)             y_sort_enabled
│   ├── Ground (TileMapLayer)  z_index -10
│   ├── Solid  (TileMapLayer)  muren, glas, meubels — met collision
│   ├── Objects (Node2D)       WorldObjects met Interactable
│   └── Entities (Node2D)
│       └── Npcs (NpcLayer)
├── GameCamera (Camera2D)      los van de speler, kan naar objecten pannen
├── WorldRegistry              index van world_id -> WorldObject
├── WorldMutator               past world_changes toe
├── TicketController           ticketstroom en minigame-start
├── DialogueController         eigen CanvasLayer (20)
├── Telefoon (CanvasLayer 30)  De Klant — alleen een telefoonscherm
├── Pauzemenu (CanvasLayer 40) doorgaan, volume, run verlaten — PROCESS_MODE_ALWAYS
├── Besturing (CanvasLayer 9)  knoppenbalk + joystick, drukt gewone acties in
└── HUD (CanvasLayer 10)
```

Globaal daarboven uit `shell.tscn`: MinigameLayer (50) en TransitionLayer (100).

Los van de boom staat `Juice` (`scripts/core/juice.gd`, statisch): de
impactframes van het spel. `Juice.schok()` vindt de camera via de groep
`game_camera`, `Juice.confetti()` hangt een eenmalige `CPUParticles2D` onder
een willekeurige ouder, `Juice.squash()` deukt elke `UiKit.button()` in bij
`button_down`. Niemand geeft er een node voor door.

Naast de modale dialoogbox is er `Bark` (`scripts/world/bark.gd`): één regel
boven iets in de wereld, zonder invoerslot, zonder tik, zonder signaal — voor
een collega die iets zegt als je langsloopt (`NpcDef.barks`, gestuurd door
`NpcLayer._probeer_bark()`) en voor de `done`-regel van een opgelost ticket
(`DialogueController.speel_of_bark()`, alleen voor bomen van één node zonder
keuze of effect). En de box zelf kent sinds Fase 2b overslaan: Esc of het
"overslaan »" onderin laat de rest van een gesprek in één beweging doorlopen,
tot de eerste keuze; de effects van elke node draaien gewoon.

`Main._ready()` is expliciet en hangt niet af van de `_ready`-volgorde van
siblings.

## Minigames

Elf mechanieken dragen elf minigames: geen enkele draagt er nog twee. Elke
minigame is een JSON-config, geen eigen codebase.

| Mechaniek | Gebruikt door |
|---|---|
| `mg_scope` | BBD-201 |
| `mg_planning` (scene `mg_standup.tscn`) | BBD-202 |
| `mg_klantfeedback` (wereldhandeling, geen scene) | BBD-203 |
| `mg_uitlijnen` | BBD-204 |
| `mg_backend_fix` (wereldhandeling, geen scene) | BBD-205 |
| `mg_heatmap` | BBD-206 |
| `mg_abgevecht` | BBD-207 |
| `mg_pijplijn` | BBD-208 |
| `mg_paarden` (wereldhandeling, geen scene) | BBD-209 |
| `mg_oplevering` | BBD-210 |
| `mg_slotboard` | de urenstaat van Dirk (geen ticket) |

Een wereldhandeling-ticket draagt `wereldhandeling: true` en loopt via
`TicketController._resolve_wereldhandeling()`, nooit via
`Shell.run_minigame()`: zijn `minigame_id` is alleen nog een sleutel in
`data/minigame_content.json`, niet in `data/minigames.json`. Zie
`docs/MINIGAMES.md` voor de details.

Contract: `MinigameBase.setup(config)` → signal `finished(MinigameResult)`.
`Shell.run_minigame()` pauzeert de wereld, hangt de minigame op MinigameLayer en
`await`t het resultaat.

## Muziek als stapel, niet als playlist

Het kantoor is het hoofdthema en het enige dat vrij doorspeelt. Al het andere is
een variant op hetzelfde akkoordenschema, zodat het spel als één stuk muziek
klinkt. `AudioDirector` houdt vier lagen bij; de hoogste gevulde laag is wat je
hoort, en zodra die leeg is valt het terug naar wat eronder lag.

| Laag | Gevuld door | Stuk |
|---|---|---|
| `basis` | `set_base()` vanuit de wereld, het titelscherm en `set_ambience` | `kantoor`, `kantoor_merksound`, `intro` |
| `gesprek` | `Bus.dialogue_started` / `_finished` | `gesprek` |
| `minigame` | `Bus.minigame_started` / `_finished` | `mg_<minigame_id>`, tien eigen varianten |
| `overwinning` | `Bus.all_tickets_done` | `overwinning` |

Geen enkele scene roept muziek aan behalve voor zijn eigen basislaag: de
AudioDirector is op de Bus aangesloten en volgt de spelstand vanzelf. Een
minigame zonder eigen stuk laat het kantoor gewoon staan — een gemis, geen bug.

Twee dingen houden dit weg bij "hetzelfde deuntje, de hele dag":

- **Stukken hervatten waar ze verlaten werden.** Kom je uit een minigame, dan
  gaat het kantoor verder in plaats van opnieuw bij maat een te beginnen.
  Zonder dat hoor je die eerste maat twintig keer op een dag.
- **De intro en de overwinning loopen pas ná hun kop** (`LOOP_START`, via
  `loop_offset`). Je hoort die aanloop één keer, en dat is precies wat er een
  begin en een winstmoment van maakt.

Het kantoorthema zelf duurt een minuut en bestaat uit negen secties waarvan er
geen twee achter elkaar hetzelfde zijn. Alle arrangementen staan in
`tools/generators/gen_audio.py`; de looppunten in `LOOP_START` horen bij die
arrangementen en worden bij het genereren meegeprint.

## Valkuilen die hier expliciet zijn opgelost

- **`TileSetAtlasSource` moet aan de `TileSet` hangen vóór je `TileData` opvraagt**,
  anders kent hij de physics layers nog niet.
- **Een Control die in code onder een in code gemaakte `CanvasLayer` hangt blijft
  0×0.** `UiKit.fill_viewport()` zet het formaat zelf en volgt vensterwijzigingen.
- **De minimummaat van een afbrekend label is onbetrouwbaar, en containers leggen
  zich erop vast.** Eén oorzaak, drie gedaanten, alle drie in dit project
  tegengekomen op een canvas van 192 px:

  | Gedaante | Wat je ziet |
  |---|---|
  | label of Button **zonder** autowrap | meldt de volledige tekstbreedte als minimum; een `PanelContainer` met `GROW_DIRECTION_BOTH` groeit daar aan *beide* kanten buiten beeld voor, dus je verliest het begin én het eind van de regel |
  | afbrekend label **naast** een buur met `SIZE_EXPAND_FILL` | de buur pakt alle breedte, het label krijgt een paar pixels, en de autowrap breekt per teken af: `1 1 : 2 0` als kolom |
  | afbrekend label **in** een `Container` | in de eerste meetronde is er nog geen breedte, dus het vraagt hoogte voor één letter per regel — en die opgeblazen maat krimpt daarna niet meer |

  Vandaar dat `UiKit.label()` en `UiKit.button()` autowrap standaard aanzetten, en
  dat je bij een buur met `SIZE_EXPAND_FILL` autowrap juist **uit** moet zetten met
  een `custom_minimum_size` erbij. Wat vast breed is (een tijdstip, een getal, een
  naam) hoort af te kappen met `OVERRUN_TRIM_ELLIPSIS`, niet af te breken.
- **Het venster moet op een laptop passen, en `--shot` verklapt niet dat het
  niet past.** Het canvas is 192x416, dus 3x is 576x1248. Dat is hoger dan de
  982 logische punten van een 14" MacBook, en dan knijpt het besturingssysteem
  het venster af: het dialoogvenster en de duimknoppen hangen aan de onderrand
  en vallen daar dus onder weg. `window_height_override` staat daarom op **2x**
  (384x832).

  De reden dat dit lang onopgemerkt bleef: `--shot` schrijft de **viewport**
  weg, niet het OS-venster. Op een afbeelding van 576x1248 is altijd alles te
  zien, ook wanneer het venster op het scherm afgekapt wordt. Een layoutbug
  hierin is dus alleen met een echte schermafbeelding te zien, niet met de
  QA-shots.
- **De schaal binnen de letterbox is breukig, en dat is een keuze die je niet in
  `project.godot` terugvindt.** `stretch/scale_mode` stond op `"integer"`. De
  schaal is `min(breedte / 192, hoogte / 416)`, en integer rondt die naar
  beneden af op een heel getal — dus wat het kost hangt er volledig van af hoe
  dicht je net *onder* een grens uitkomt. Gemeten met
  `get_viewport().get_screen_transform()`:

  | venster | verhouding | integer | breukig |
  |---|---|---|---|
  | 390x844 (fullscreen) | 2,029 | 2,0 — balken 3 x 6 | 2,026 — balken 1 x 0 |
  | 390x664 (Safari met URL-balk) | 1,596 | **1,0** — balken 99 x 124 | 1,594 — balken 42 x 0 |

  Die tweede regel is het hele punt. Met de URL-balk in beeld valt de
  verhouding net onder 2, en dan tekent integer het spel op **1x**: 192x416
  midden in een venster van 390x664, met bijna honderd pixels zwart aan
  weerszijden. Dat leest als een spel dat het scherm niet gebruikt, en het is
  nergens aan te zien dat een afronding de oorzaak is. Breukig haalt daar 1,594
  uit — de volle hoogte, en alleen links en rechts nog een band.

  Fullscreen verandert er vrijwel niets, en dat is de andere helft van het
  verhaal: het canvas 192x416 (0,4615) is bewust vlak bij de verhouding van een
  telefoon (390x844 is 0,4621), dus daar zát integer al goed. De winst zit
  volledig in het geval waar de speler feitelijk in zit.

  Wat het kost is ongelijke pixels op een niet-heel veelvoud
  (`default_texture_filter=0`, dus nearest). Bij 1,594 tegenover 1,0 is dat de
  betere ruil; bij 2,026 tegenover 2,0 is het verschil niet te zien.

  **En er staat geen regel in `project.godot` die dit vasthoudt.** `"fractional"`
  is de engine-default, en de export gooit default-waarden eruit (zie de
  waarschuwing in `tools/deploy_web.sh`), dus een expliciete regel zou bij de
  eerstvolgende deploy stil verdwijnen. Het ontbreken van de regel *is* de
  instelling. Zet iemand `"integer"` terug, dan blijft die er wel staan — en dan
  is dit de plek waar staat waarom dat een verslechtering is.

  Op iOS is er geen weg naar echte fullscreen in een Safari-tab: iOS heeft daar
  geen Fullscreen API. Dat kan alleen via "Zet op beginscherm", en daarvoor staat
  `apple-mobile-web-app-capable` al in de Web-preset (zie `docs/TESTING.md`).
- **`Control.size` zetten gooit je verankering weg.** `Besturing._bouw_balk()`
  zette `offset_bottom = -MARGE` en sloot af met
  `_balk.size = _balk.get_combined_minimum_size()` om de breedte te bepalen —
  het commentaar erboven zei dat ook zo. Maar `set_size()` rekent **alle vier**
  de offsets opnieuw uit de gevraagde maat, dus die ene regel overschreef de
  ondermarge: de balk landde op y408 in een viewport van 416. Van elke knop van
  30 px stonden er 24 onder het scherm, en op een telefoon zag je van ▤ ? ☰ nog
  net de bovenrand.

  Wil je één as zetten en de andere aan de ankers laten, zet dan de offset van
  die ene as (`offset_right = MARGE + breedte`) en niet `size`. Er is geen
  `set_width()`.

  Waarom dit maanden bleef staan: `_test_balkmaat()` legt de *hoogte* van de
  balk vast en `_test_hudband()` wat de HUD bovenin afdekt, maar geen van beide
  vroeg wáár de balk terechtkomt. Op een QA-shot is het te zien, maar het zit in
  de onderste acht pixels van een beeld van 416 hoog en daar kijkt niemand.
  `_test_wereldchrome_past()` en `_test_schermen_passen()` stellen die vraag nu
  wel — voor elke `PanelContainer` en elke `Button`, tegen `get_visible_rect()`,
  en met een uitzondering voor wat in een klemmende ouder hangt (de
  personagerijen staan in een `ScrollContainer` en horen eronderuit te lopen).
- **De besturingsuitleg is een modaal venster, geen strook die wegfaadt.** Hij
  lag onderaan, negen seconden lang, en verdween bovendien zodra je zelf een
  stick maakte (`besturing.stick_begonnen`). Wie het spel opstart en meteen zijn
  duim neerzet — precies wat je op een telefoon doet — had de enige uitleg die
  het spel heeft dus nooit gezien. Nu staat hij midden op het scherm met één
  knop ("Ik begrijp het") en blijft hij staan tot die knop ingedrukt is.

  Twee dingen die daarbij horen. De verduistering gaat mee in
  `Hud.chrome_vlakken()`, want `Besturing._input()` loopt vóór de GUI en zou
  onder het paneel dat de stick uitlegt een stick achterlaten. En hij komt
  alleen bij een nieuwe dag op: `Session.hervat` (gezet in `load_from_disk()`,
  gewist in `start_new()`) en niet `done_count() > 0` — wie hervat vóór zijn
  eerste opgeloste ticket staat ook op nul.
- **Drie minigames leunen op `emulate_mouse_from_touch`.** `mg_scope`,
  `mg_uitlijnen` en `mg_pijplijn` lezen in hun `_gui_input()`
  een `InputEventMouseButton`. Dat werkt op een telefoon omdat Godot standaard
  muis uit touch emuleert, en die instelling staat **niet** in `project.godot` —
  hij is dus de default en geen keuze. Zet iemand
  `input_devices/pointing/emulate_mouse_from_touch` uit, dan accepteren die vier
  stil geen tikken meer: geen fout, geen melding, alleen een minigame die niet
  reageert. Alles wat via `UiKit.button()` loopt is hier ongevoelig voor, want
  een `Button` handelt `InputEventScreenTouch` zelf af.
- **`custom_minimum_size` is een ondergrens, niet de maat.** Een `Button` meldt
  zelf regelhoogte plus de marges van zijn stijlbox, en die som wint als hij
  groter is: met `UiKit.KNOP_MIN_H` (24) komt er 26 uit (14 regel + 2 × 6
  marge). De knoppenbalk rekende eerst met 24, at daardoor twee pixels van zijn
  eigen ondermarge op — een `Control` groeit standaard naar `GROW_DIRECTION_END`,
  en dat is onderaan het scherm de kant waar niets meer is — en trok de
  onderste HUD-regels mee. Het verschil is twee canvaspixels en op een
  screenshot niet te zien. Vandaar dat `Besturing.KNOP_HOOGTE` een **gemeten**
  getal is, dat `_test_balkmaat()` in de testsuite vastzet, en dat de balk naar
  `GROW_DIRECTION_BEGIN` groeit.
- **De HUD stapelt in VBoxen, hij verankert geen losse panelen op y-waarden.**
  Dat deed hij wel, en alle drie de rijen boven elkaar vielen mis: de doelbalk
  op `MARGE + 18` (y22) lag over de tellerbalk die tot y30 doorloopt, de toasts
  op y46 lagen over een doelregel die bij twee regels tot y76 komt, en de prompt
  van 18 px hoog groeide door zijn `GROW_DIRECTION_END` acht pixels naar
  beneden, over de zonenaam. Elk van die getallen klopte voor precies één
  tekstlengte, en op een canvas van 184 px breed is "één tekstlengte" geen
  aanname die je mag maken. Twee VBoxen — één die van boven naar beneden groeit,
  één die van de onderrand naar boven groeit — tellen de hoogtes op in plaats
  van ze te raden.
- **Permanente chrome kost wereld, en die kosten waren niet begroot.** De
  bovenstapel was vier dekkende dingen over de volle breedte — teller + klok,
  doelregel (bijna altijd twee regels), kompasstrip, toasts — samen zo'n 80 van
  de 416 canvaspixels. De camera klemt verticaal volledig vast, dus dat is niet
  "bovenaan het scherm" maar "over de vergaderkamers": rij 0 is muur, maar op
  rij 1 staan `deploycomputer` en `sprintbord_vloer`, en in de rijen 1 tot 6
  lopen collega's. Wat er nu staat is 26 px hoog en op twee chips na
  doorzichtig — `[▤ 3/10]` links, `[09:12]` rechts, de kompasstrip ertussen
  zonder paneel eromheen (hij tekent zijn eigen onderlegger, zie
  `Kompas._draw()`). De doelregel is niet weg maar klapt uit als hij verandert,
  en met een tik op de tellerchip. Dezelfde afweging als bij de knoppenbalk,
  die om zijn drie knoppen sloot toen de actieknop verdween.
- **Wat aan de bovenkant bij komt, gaat er onderaan af.** De verdieping is 26
  tegels en de viewport precies even hoog, dus `GameCamera.zak_onder_hud()`
  verdeelt ruimte, hij maakt hem niet. Via `Camera2D.offset`, want dat is de
  enige knop die voorbij de limieten gaat — `limit_top`/`limit_bottom` klemmen Y
  onherroepelijk op 208. Het plafond staat op 12 px: onderaan draagt rij 24 het
  fysieke ticketbord, en de volle 26 px van de chips zou dat onder de
  knoppenbalk duwen. `_test_hudband()` legt beide kanten vast — de balkhoogte
  tegen rij 1, en het laagste object tegen de onderrand.
- **De interactieprompt hangt op het object, niet aan de onderrand.** Hij stond
  in de onderstapel, gecentreerd, net boven de knoppenbalk. Dat klopte zolang er
  een actieknop was: de tekst hoorde bij de knop, en die knop stond daar. Sinds
  je direct op het object tikt, stond de enige regel die zegt wát een tik doet
  maximaal ver van het ding dat je aantikt, in de strook waar ook de joystick
  onder je duim opkomt. `TapMarker` draagt nu de ring én het bijschrift.
- **Wat aan een schermrand klemt moet weten waar de HUD ophoudt.** De doelwijzer
  (`objective_marker.gd`) klemt zich tegen de rand zodra het doel buiten beeld
  ligt. De hele noordelijke strook van het kantoor ligt op schermhoogte van de
  ticketteller, dus zonder correctie staat die pijl precies achter de HUD: hij
  is er wel en je ziet hem niet. Hij vraagt daarom `Hud.vrije_band()` op, en die
  is **gemeten** en niet geteld — de doelregel staat er soms wel en soms niet, is
  één of twee regels hoog, en er kunnen toasts onder hangen. Sinds kort vragen
  `TapMarker` (voor zijn bijschrift) en `Hud.toon_ticket_melding()` (voor het
  briefje dat naar ▤ vliegt) dezelfde band op.
- **Eén besturing, geen platformvertakking.** Er was een `Invoer.touch()` en zes
  plekken die daar hun eigen indeling uit haalden (HUD, besturingskaart,
  ticketbord, dialoogbox, prompt, elke minigame). Dat leverde twee spellen met
  dezelfde inhoud op, en van die twee werd de mobiele helft alleen bekeken:
  elke QA-shot stond op `--touch` terwijl er met een toetsenbord gespeeld werd,
  dus de toetsenbordroute was de ongeteste. `Invoer.touch()` bestaat niet meer;
  wat overblijft is `muis_als_vinger()`, en dat gaat over gebeurtenistypes en
  niet over indeling.
- **`Session.input_locked` is een teller, geen bool.** Vier systemen zetten hem
  rechtstreeks: de dialoogcontroller, de telefoon van De Klant, de intro en het
  vertrek uit het kantoor. Die overlappen, en wie als laatste `false` schreef
  zette de vloer open terwijl een ander er nog op rekende. Zetten gaat daarom
  via `lock_input()` / `unlock_input()`; `input_locked` is puur een lezing van
  de teller en een directe toewijzing levert een `push_error`.
  `Shell._change_scene()` doet `reset_input_lock()`, want geen enkele aanroeper
  overleeft een scenewissel.
- **Een minigame leest zijn opgave uit `content()`, niet uit `config`.** Dat zijn
  twee gescheiden ingangen: `config` (via `setup()`, gelezen met `cfg()`) is
  parameters, `content()` is de opgave uit `data/minigame_content.json`.
  `TraitModifier` schreef zijn voordeel jarenlang naar `config`, waar geen
  enkele minigame naar kijkt — en las bovendien uit `t.minigame_config`, een
  veld dat in alle tien de tickets `{}` is. Twee losse redenen waarom hetzelfde
  niets gebeurde, mét een toast op het scherm die de speler een voordeel
  beloofde. Een aangepaste opgave gaat nu als configsleutel `inhoud` mee, die
  `MinigameBase.setup()` op `content_override` zet.
- **Een tabel die tegelijk dekkingslijst is.** `TraitModifier.VOORDEEL` en
  `GEEN_VOORDEEL` samen moeten elk `type` uit `minigame_content.json` dekken, en
  `_test_traits()` eist dat plus dat een belofte uit die tabel de opgave écht
  verandert. Zonder die eis kon een `match` zonder tak voor een nieuw type stil
  niets doen — precies wat er gebeurde toen zes minigames nieuwe mechanieken
  kregen.
- **`MOTION_MODE_FLOATING`** op de speler; `GROUNDED` (de standaard) geeft
  vreemde slide-effecten in top-down.
- **Area2D-monitoring staat stil tijdens pause.** De interactieprobe evalueert
  daarom elke frame de overlap opnieuw in plaats van enter/exit bij te houden.
- **Twee `await process_frame`-momenten** rond het openen en sluiten van een
  minigame, anders lekt de toetsaanslag door naar de volgende stap.
- **Godot herschrijft `project.godot` bij import** en verplaatst handmatig
  toegevoegde regels naar het eind. Input-acties horen ín `[input]`.
