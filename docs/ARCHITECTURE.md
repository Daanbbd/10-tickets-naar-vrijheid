# Architectuur

Godot **4.7.2**, GDScript met statische typering. Renderer `gl_compatibility`
(2D pixel art), viewport **480×270**, venster 1440×810, stretch `canvas_items`
met `nearest` filtering.

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
| `Session` | Muteerbare runtime-state: personage, flags, inventory, ticketstanden. |
| `Shell` | Scene-router, fades, host van de minigame-overlay. De enige plek die `get_tree().paused` aanraakt. |
| `AudioDirector` | SFX-pool, muziek-crossfade, ducking tijdens dialoog. |

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

## Data in JSON, niet in `.tres`

Alle content staat in platte JSON in `data/`. Reden: de content wordt grotendeels
gegenereerd en moet buiten de editor diff-baar en valideerbaar zijn. `.tres` is
een editorformaat met resource-UID's dat zich daar slecht voor leent. Een
laadlaag (`GameData`) zet JSON om in getypte `Resource`-klassen, zodat
gameplaycode nooit een rauwe `Dictionary` aanraakt.

## Twee mini-grammatica's

**Condition** — gedeeld door quest-requirements, dialoogvarianten en
interactable-gating. Keys: `character`, `trait`, `flags_all`, `flags_none`,
`tickets_done`, `tickets_not_done`, `has_item`, `min_tickets_done`.
Eén evaluator: `Conditions.check()`.

**Effect / WorldChange** — zie de tabel hierboven. Beide hebben een
whitelist die de validator controleert.

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
└── HUD (CanvasLayer 10)
```

Globaal daarboven uit `shell.tscn`: MinigameLayer (50), TransitionLayer (100),
DebugLayer (200).

`Main._ready()` is expliciet en hangt niet af van de `_ready`-volgorde van
siblings.

## Minigames

Zes herbruikbare mechanieken dragen tien minigames. Elke minigame is een JSON-
config, geen eigen codebase.

| Mechaniek | Gebruikt door |
|---|---|
| `mg_slotboard` | BBD-201, 202, 204, 206 |
| `mg_tagpicker` | BBD-207, 208 |
| `mg_choicescene` | BBD-203 |
| `mg_cableboard` | BBD-205 |
| `mg_whack` | BBD-209 |
| `mg_deploy` | BBD-210 (hergebruikt de andere drie voor zijn varianten) |

Contract: `MinigameBase.setup(config)` → signal `finished(MinigameResult)`.
`Shell.run_minigame()` pauzeert de wereld, hangt de minigame op MinigameLayer en
`await`t het resultaat.

## Valkuilen die hier expliciet zijn opgelost

- **`TileSetAtlasSource` moet aan de `TileSet` hangen vóór je `TileData` opvraagt**,
  anders kent hij de physics layers nog niet.
- **Een Control die in code onder een in code gemaakte `CanvasLayer` hangt blijft
  0×0.** `UiKit.fill_viewport()` zet het formaat zelf en volgt vensterwijzigingen.
- **`MOTION_MODE_FLOATING`** op de speler; `GROUNDED` (de standaard) geeft
  vreemde slide-effecten in top-down.
- **Area2D-monitoring staat stil tijdens pause.** De interactieprobe evalueert
  daarom elke frame de overlap opnieuw in plaats van enter/exit bij te houden.
- **Twee `await process_frame`-momenten** rond het openen en sluiten van een
  minigame, anders lekt de toetsaanslag door naar de volgende stap.
- **Godot herschrijft `project.godot` bij import** en verplaatst handmatig
  toegevoegde regels naar het eind. Input-acties horen ín `[input]`.
