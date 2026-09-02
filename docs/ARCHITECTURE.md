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

## Autoloads (5)

Regel: een autoload bevat *state of routing*, nooit gameplaylogica.

| Autoload | Verantwoordelijkheid |
|---|---|
| `Bus` | Alleen signal-declaraties. Geen state, geen logica. |
| `GameData` | Laadt alle JSON één keer en parset naar getypte modellen. Daarna read-only. |
| `Session` | Muteerbare runtime-state: personage, flags, voorwerpen, ticketstanden, gevonden tickets en de gekozen ticket. Schrijft en leest de save. |
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

`Main._ready()` is expliciet en hangt niet af van de `_ready`-volgorde van
siblings.

## Minigames

Elf mechanieken dragen elf minigames: geen enkele draagt er nog twee. Elke
minigame is een JSON-config, geen eigen codebase.

| Mechaniek | Gebruikt door |
|---|---|
| `mg_scope` | BBD-201 |
| `mg_standup` | BBD-202 |
| `mg_choicescene` | BBD-203 |
| `mg_uitlijnen` | BBD-204 |
| `mg_cableboard` | BBD-205 |
| `mg_abtest` | BBD-206 |
| `mg_tagpicker` | BBD-207 |
| `mg_pijplijn` | BBD-208 |
| `mg_whack` | BBD-209 |
| `mg_oplevering` | BBD-210 |
| `mg_slotboard` | de urenstaat van Dirk (geen ticket) |

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
- **Vier minigames leunen op `emulate_mouse_from_touch`.** `mg_scope`,
  `mg_cableboard`, `mg_uitlijnen` en `mg_pijplijn` lezen in hun `_gui_input()`
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
  van ze te raden. De tussenruimte van de bovenste staat op 0: met twee pixels
  ertussen kijk je door de HUD heen op de bovenste rij van het kantoor, en dan
  loopt er een reepje collega tussen de teller en de doelregel door.
- **Wat aan een schermrand klemt moet weten waar de HUD ophoudt.** De doelwijzer
  (`objective_marker.gd`) klemt zich tegen de rand zodra het doel buiten beeld
  ligt. De hele noordelijke strook van het kantoor ligt op schermhoogte van de
  ticketteller, dus zonder correctie staat die pijl precies achter de HUD: hij
  is er wel en je ziet hem niet. Hij vraagt daarom `Hud.vrije_band()` op, en die
  is **gemeten** en niet geteld — de doelregel is één of twee regels hoog en er
  kunnen toasts onder hangen.
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
