# Overdracht — na de vastloper van 6 september

**Datum:** 2026-09-06 19:30 · **Repo:** 10-tickets-naar-vrijheid
**Stand:** `main` = `eef1193`, gelijk aan `origin/main`, checkout schoon
**Live:** https://daanbbd.github.io/10-tickets-naar-vrijheid/ (gh-pages `4973917`)
**Suite:** 22.646 controles, 0 fout · alle zeven personages 10/10 exit 0, ook met `--rommelig`

Er zijn geen branches en geen worktrees meer. Begin met een verse worktree vanaf
`main` en draai daar **eerst** `Godot --headless --path . --import`, anders krijg
je zwarte frames en nep-parsefouten.

---

## Lees dit eerst: het spel is nu wél uitspeelbaar

Daan had het spel nooit kunnen uitspelen. De oorzaak was `await <tween>.finished`
op een Tween die een ander pad killt — een gekillde Tween emit `finished` in
Godot 4 nooit meer, dus die await keerde nooit terug en `TicketController._busy`
bleef daarna voorgoed dicht: geen ticket op te pakken, geen collega aan te
spreken, geen foutmelding, terwijl lopen gewoon bleef werken.

Twee vindplaatsen, allebei gefixt: `Hud.toon_urenrol()` en `mg_abgevecht._meet()`.
`_test_geen_await_op_killbare_tween()` verbiedt de vorm nu overal.

**Dit is de belangrijkste les voor wie hier verder werkt:** de suite was al weken
groen en alle zeven personages haalden 10/10 terwijl een mens vastliep. Twee
blinde vlekken deden dat — een `Autopilot.gevraagd()`-afslag vlak vóór de kapotte
regel, en een autopilot die na een mislukte minigame altijd "Nog een keer" koos
waardoor `_ship_gebrekkig()` nooit gelopen werd. Beide zijn dicht (`_rol_duur()`
en de vlag `--rommelig`). **Vraag bij elke QA-afslag die je tegenkomt: wat test
dit nog als deze tak er niet is?**

---

## To do, op volgorde

### 1. Werk het playtestlog bij vóór je iets bouwt — een halfuur, en het scheelt dubbel werk

`docs/playtest/2026-09-06.md` staat op **45 punten open**, maar dat klopt niet
meer: alleen #37/#38 zijn afgevinkt. De uitlegteksten-ronde van diezelfde middag
en de nachtbranch (P1–P5) hebben er meer opgelost, en niemand heeft de statussen
bijgewerkt.

Draai de webbuild lokaal en loop het log punt voor punt na. Zet per punt
**gefixt** (met commit), **open**, of **vervallen**. Bouw pas daarna.

```bash
tools/export_web.sh && python3 tools/serve_web.py --http
# http://127.0.0.1:8060/index.html
```

Vermoedelijk al opgelost, maar **niet in de browser geverifieerd**: #19 (geen
uitlegscherm bij de stand-up), #24 en #26 (de laptop in de koffiecorner), #27
(Danny die uit het niets opdraaft), #28 (de klok liep tijdens de uitleg van A
tegen B). Neem dat niet aan — kijk.

### 2. De karakterdialoog — de grootste bak open punten

Ongeveer twintig van de 45 punten gaan over hetzelfde: dialoog die niet klopt in
de mond van dat personage, of nergens op slaat. Daans woorden: *"Dialog makes no
sense"*, *"Rare tekst"*, *"wederom; wat de fuck"*.

Punten: **#4, #10, #12, #14, #15, #16, #18, #21, #22, #23, #24, #25, #27, #33,
#33b, #34**. Dit is stem, geen uitleg — dus een aparte ronde met
`docs/CHARACTERS.md` en `docs/character-bibles-all.md` ernaast, niet met
`docs/SCHRIJFSTIJL.md` (dat gaat over uitlegtekst).

Twee concrete aanwijzingen uit het log die je richting geven:

- **#15/#16** — Victor zegt na een afgeronde dialoog ineens "Wat?", met "Oke." als
  antwoordoptie. Dat is geen tekstprobleem maar een dialoogboom die verkeerd
  aan elkaar hangt; zoek eerst waar die node vandaan komt.
- **#23** — *"Dit kunnen potentieel hele leuke dialoog opties zijn, maar het
  vervolg is bij alle 3 matig."* De keuzes zijn goed, de gevolgen niet. Dat is
  ontwerp, geen herschrijving.

> **Regel die hier hard geldt.** Tekst die Daan heeft goedgekeurd is leidend. Op
> 6 september zijn elf van zijn goedgekeurde uitlegteksten ingekort om een test
> uit een parallelle branch groen te krijgen. Dat is de verkeerde volgorde en hij
> heeft er expliciet iets van gezegd. Botst een test met goedgekeurde tekst: pas
> de test aan, of leg het hem voor. Nooit de tekst stilletjes bijknippen.

### 3. Vier invoersloten zonder gegarandeerde tegenhanger

Gevonden tijdens het zoeken naar de vastloper, geen van alle de oorzaak ervan,
allemaal nog aanwezig op `main`. Zelfde klasse: GDScript kent geen `finally`, dus
een hangende `await` binnen een slot laat dat slot permanent dicht.

| Waar | Wat er mist |
|---|---|
| `autoload/shell.gd:328` `await poort.besloten` en `:359` `await mg.finished` | geen timeout; `_active` én `Session.lock_input()` lekken samen |
| `scripts/ui/telefoon.gd:353` | de enige unlock zit achter een knop die alleen via `_open_bericht()` bereikbaar is |
| `scripts/world/main.gd:1303` `_verlaat_kantoor()` | `lock_input()` zonder lokale unlock; hangt volledig aan de scenewissel |
| `scripts/ui/hud.gd:601` `toggle_board()` | schermvullend bord dat géén invoerslot zet en niet als chrome geregistreerd is — één tik raakt zowel de knop op het bord als het object erachter |

`TicketController._slot_houdt()` is het model voor hoe je zoiets opvangt: laat het
slot los zodra het langer dan vijf seconden dichtstaat terwijl er geen dialoog,
geen minigame en geen invoerslot loopt, met een `push_error()` in plaats van
stilte.

### 4. Wereldlabels lopen door meubels heen — #31, #32, #36, #37

De teksten die tickets via `world_changes: set_text` neerzetten (`whiteboard_vergader`
in `data/tickets/t01.json`, `speaker_koffiecorner` in `t07.json`) worden gerenderd
door `scripts/world/world_object.gd:112-180` als een Label van vast 108 px
**zonder `z_index`**, en verdwijnen nooit meer. Daan zag ze door de vergadertafel
heen lopen en dacht dat het restanten van een vastloper waren.

Geef het label een `z_index` onder de props en klem de breedte. Klein werk.

### 5. Op telefoon-web kan het spel nog wél permanent bevriezen

`autoload/shell.gd:71` — `NOTIFICATION_APPLICATION_PAUSED` heeft géén
platformcheck, terwijl focus-in/-uit daaronder die wél heeft (en met een goede
reden, zie het commentaar erbij). Eén gemiste `APPLICATION_RESUMED` betekent
`paused = true` en `Engine.max_fps = 1` voor altijd.

Niet de oorzaak van Daans vastloper — op desktop-web bestaat
`APPLICATION_PAUSED` niet, nagekeken in `build/web/index.js` — maar op een echte
telefoon is dit een reëel risico. Alleen op een toestel te reproduceren.

### 6. Minigame-ontwerp, als er tijd is

Geen bugs, wel Daans oordeel. **#13** de uitlijn-minigame is te klein en kent geen
urgentie (P3 gaf hem drift, controleer of dat genoeg is). **#20** *"Ik kan maar
een paar keer afkappen, de rest zit ik passief te wachten. Wat een kutgame."*
**#28** hij verwachtte bij A tegen B een echte 1v1 arcade fighter met health bars
en CRO-grappen bij critical hits, geen quiz. **#35** de scope-minigame leest als
vaag. Dit is herontwerp, geen fix — stem het met hem af voor je begint.

---

## De commando's

```bash
# testsuite (~10 s; altijd met --quit-after, anders hangt hij bij een parsefout)
Godot --headless --path . --quit-after 8000 --scene res://tests/test_runner.tscn

# geautomatiseerde speelbeurt (~4 min per personage)
Godot --headless --path . --quit-after 90000 -- --speler=daan --playthrough --autoplay --quit-when-done

# ... en dezelfde beurt zoals een mens speelt: elke minigame gaat de eerste keer
# mis en wordt daarna gebrekkig geshipt. Dit is het pad waar de vastloper zat.
Godot --headless --path . --quit-after 90000 -- --speler=daan --playthrough --autoplay --rommelig --quit-when-done

# lokaal spelen
tools/export_web.sh && python3 tools/serve_web.py --http

# publiceren (force-pusht gh-pages)
tools/deploy_web.sh
```

Volledige vlaggenlijst in `docs/TESTING.md`.

---

## Werkwijze die geldt

- **Verse worktree vanaf `main`, en eerst `--import`.** Er staat niets meer klaar.
- **Nooit twee Godot-runs op dezelfde werkboom.** Ze schrijven allebei de
  importcache; op 6 september liepen er per ongeluk twee speelbeurten in één
  boom. Aparte worktree per parallelle run.
- **Eén fase per commit**, alleen als de suite groen is en een speelbeurt 10/10
  haalt. Pushen en deployen doe je pas als Daan het zegt.
- **Draait er een tweede sessie in deze checkout?** Stem eigendom van bestanden
  expliciet af vóór je begint. Op 6 september hebben twee sessies dezelfde
  teksten hersteld en elkaars werk overschreven; dat kostte meer tijd dan het
  werk zelf.
- **Claims van andere sessies narekenen.** Meerdere keren bleek een bewering over
  de codestand onjuist, in beide richtingen. Eén `git show` kost niets.

## Waar je moet kijken

| Onderwerp | Bestand |
|---|---|
| Playtestfeedback van 6 september | `docs/playtest/2026-09-06.md` |
| Testvlaggen en wat elke laag dekt | `docs/TESTING.md` |
| Valkuilen (o.a. de Tween-regel) | `docs/ARCHITECTURE.md` |
| Karakterstemmen | `docs/CHARACTERS.md`, `docs/character-bibles-all.md` |
| Schrijfregels voor uitlegtekst | `docs/SCHRIJFSTIJL.md` |
| Ticketstroom en questmotor | `docs/QUESTS.md`, `docs/AUDIT-TICKETSTROOM.md` |
