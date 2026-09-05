# Mobile-audit — 10 Tickets naar Vrijheid (web/telefoon)

Werkmap: `/Users/daan/Documents/fun/.claude/worktrees/10-tickets-vrijheid-handover-079cbc`
Frames: `docs/audit-shots/mob_*.png` (in deze worktree)
Methode: broncode gelezen (geen wijzigingen), plus echte frames via `tools/qa_shot.py los ... --res=`
op 360x640, 390x844, 412x915, 900x700 en 1024x768. `export_presets.cfg` en `build/web/` zijn
alleen gelezen uit de hoofdcheckout (`/Users/daan/Documents/fun/`), niet gekopieerd.

## 1. Oordeel

**Half.** De besturing zelf is verrassend volwassen voor iets dat alleen met een muis getest is:
één invoerlaag voor toetsenbord én duim (`scripts/ui/besturing.gd`), tap-to-interact via
`tap_marker.gd`, een echte safe-area-implementatie en een op-de-achtergrond-lifecycle die
opslaat/pauzeert/dimt — dat is niet toevallig goed. De blocker zit ergens anders: **op elke
schermverhouding breder dan ~10:16 (tablet liggend, een bureaubladbrowser, een telefoon in
landscape) verdwijnt de hele HUD én de duimbesturing, en zoomt het beeld sterk in** — reproduceerbaar
op 900x700 én 1024x768. Daarnaast is het "overslaan »"-label in een gesprek een geïsoleerd tikdoel
van naar schatting 20–28 fysieke pixels hoog — ruim onder 44px en onder de 30-viewport-px-standaard
die de rest van de UI zelf hanteert. Op smalle portret-telefoons (360–412 CSS-breed, de kans dat een
speler dat toestel gebruikt) is het spel wél goed speelbaar.

## 2. Actie → toetsenbord → touch-equivalent

| Actie | Toetsenbord | Touch-equivalent | Bewijs |
|---|---|---|---|
| Lopen (WASD) | W/A/S/D + pijltjes | Duimjoystick, verschijnt waar je aanraakt (onderste 62% van het scherm) | `scripts/ui/besturing.gd:110,271-346,420-427` |
| Rennen (Shift) | Shift | Stick verder dan 82% uitduwen | `besturing.gd:37,427` |
| Interactie (E) | E / Space / Enter | Tik op het object zelf (ring + kaartje) | `scripts/world/tap_marker.gd` volledig; `besturing.gd:353-366` (`_probeer_tik`); `scripts/world/main.gd:883-886` |
| Ticketbord (Tab) | Tab | Loop naartoe en tik erop (geen losse knop meer); sluiten via een echte "Sluiten"-knop | `besturing.gd:216-220` (comment); `scripts/ui/scrumbord.gd:105-120` |
| Hint (Q) | Q | "?"-knop in de balk | `besturing.gd:221,63` (`GLYPH_HINT`) |
| Pauze/overslaan (Esc) | Esc | "☰"-knop in de balk | `besturing.gd:226,64`; `scripts/world/main.gd:875-878` |
| Dialoog verder | Elke toets/klik | Tik overal op het scherm | `scripts/ui/dialogue_controller.gd:305-317` (`_input`, globaal) |
| Dialoog overslaan | Esc | "overslaan »"-label, **eigen klein tikvlak, geen knop** | `scripts/ui/dialogue_box.gd:108-118`; zie bevinding Hoog-1 |
| Telefoon (De Klant) wegleggen | Elke toets/klik/Esc | Tik overal op het scherm | `scripts/ui/telefoon.gd:467-482` |
| Hint-briefje wegleggen | Esc | Tik op het briefje zelf (hele paneel) | `scripts/ui/hud.gd:1215-1240` |
| Debug-paneel (F12) | F12 | **Geen** — bewust: dev-only | `scripts/ui/hud.gd:442-445` |
| Feedback-toets (§) | § | **Geen** — bewust: playtest/QA-tool, geen spelersfunctie | `autoload/shell.gd:391-410` |
| mg_scope: wens verplaatsen | Muisklik | Tik op de rij — **werkt alleen via Godots `emulate_mouse_from_touch`-default**, niet expliciet | `scripts/minigames/mg_scope.gd:114-118` |
| mg_whack: paard raken | Muisklik | Zelfde risico als mg_scope | `scripts/minigames/mg_whack.gd:60-65` |
| mg_heatmap: knop slepen | Muis-drag | `InputEventScreenTouch`/`ScreenDrag` expliciet, plus 8px grow-marge | `scripts/minigames/mg_heatmap.gd:79-100,425-434` |
| mg_uitlijnen: blok slepen | Muis-drag | Expliciet touch+mouse, plus 4 richtingsknoppen als alternatief | `scripts/minigames/mg_uitlijnen.gd:151-209` |
| mg_pijplijn: clip doorschuiven | Muisklik | Expliciet touch+mouse (`_tik()`) | `scripts/minigames/mg_pijplijn.gd:337-360` |
| mg_slotboard (urenstaat) | Muisklik | **Was een sleepspel, is nu drie keuzeknoppen** — al mobiel-vriendelijk gemaakt (zie commit F4-a) | `scripts/minigames/mg_slotboard.gd:1-13,36-41` |

## 3. Schermmaat → frame → bevinding

| Schermmaat | Frame | Bevinding |
|---|---|---|
| 360×640 (16:9) | `mob_wereld_360x640.png`, `mob_bord_360x640.png` | Goed: HUD, duimbalk (? ☰), tap-kaartje "Victor 6 m", ticketbord met kolommen en Sluiten-knop — alles zichtbaar en op maat. |
| 390×844 (iPhone 19.5:9) | `mob_wereld_390x844.png`, `mob_bord_390x844.png`, `mob_mg_heatmap_390x844.png`, `mob_mg_scope_390x844.png`, `mob_select_390x844.png`, `mob_praat_dennis_390x844.png` | Goed op alle schermen. Dialoogvenster toont "overslaan »" + "tik verder" — zie Hoog-1 voor het kleine tikvlak. |
| 412×915 (Android 20:9) | `mob_wereld_412x915.png` | Extra hoogte (t.o.v. 416 basis) wordt correct als muur/lucht boven het kantoor getoond (`GameCamera.rand_voor()`), geen zwarte balken, geen kapotte HUD. |
| 900×700 (breed, willekeurig) | `mob_wereld_900x700.png` | **Kapot**: geen HUD-chips, geen duimbalk, camera sterk ingezoomd (veel minder wereld zichtbaar dan bij 390 breed), geen letterbox-balken zichtbaar. |
| 1024×768 (tablet landscape) | `mob_wereld_1024x768.png`, `mob_bord_1024x768.png`, `mob_praat_dennis_1024x768.png` | **Kapot, op drie schermen tegelijk getest**: wereld toont hetzelfde inzoom-defect zonder HUD; het ticketbord toont alleen een leeg middenstuk (kop, kolommen en Sluiten-knop buiten beeld) met wél twee smalle donkere randen links/rechts; het dialoogscherm toont helemaal geen dialoogbox, alleen de ingezoomde wereld erachter. |

`_test_responsief()` (scripts/tests/test_runner.gd:5396-5421) bewijst dat de **beslisfunctie**
`UiKit.schaal_aspect_voor()` op zichzelf correct is (1024×1366 en 1440×900 → `KEEP`, dus
verwacht letterboxen) — de test dekt alleen niet het gerenderde resultaat op een echt venster.
Het defect zit dus tussen die correcte beslissing en wat er echt op het scherm komt; zie
punt 6 voor hoe dat verder te testen is.

## 4. Bevindingen

### Hoog

- **H1 — "overslaan »" is een geïsoleerd tikdoel ver onder de duimmaat.**
  `scripts/ui/dialogue_box.gd:100-118`: `_skip_label` is een kale `UiKit.label(..., FS_SMALL, ...)`
  zonder `custom_minimum_size`; zijn eigen `gui_input` (regel 113-118) is het enige dat hem
  bruikbaar maakt. Op FS_SMALL=10 viewport-px komt de teksthoogte overeen met ~20–28 fysieke
  pixels op een 390px-brede telefoon (schaal ≈2,03) — ruim onder de 44px-richtlijn én onder de
  30 viewport-px (≈61px) die de rest van de UI zelf als ondergrens hanteert (`UiKit.KNOP_MIN_H`,
  `ui_kit.gd:100`). De reden staat er expliciet bij (regel 106-107): een echte knop zou de regel
  hoger maken en de autopilot-QA in de war brengen — een bewuste trade-off die op een telefoon
  een klein, moeilijk te raken tikvlak oplevert. Effect: skip-the-rest-of-conversation is lastig
  te raken; gewoon verder-tikken (elders op het scherm) werkt wel prima (`dialogue_controller.gd:305-317`).
  Voorstel: `_skip_label` een eigen `custom_minimum_size.y` geven (bv. 20-24 vp) zonder er een
  focus-pakkende `Button` van te maken.

- **H2 — Layout breekt op elke schermverhouding breder dan ~10:16.**
  Reproduceerbaar op zowel 900×700 als 1024×768 (drie schermen: wereld, ticketbord, dialoog — zie
  tabel 3): HUD-chips, duimbalk en dialoogbox verdwijnen, de camera toont een sterk ingezoomd
  fragment van de wereld. Dit raakt precies de categorie apparaten die de eigenaar niet zelf getest
  heeft (telefoon in landscape gedraaid tijdens het spelen; een tablet; een breed browservenster).
  `_test_responsief()` bewijst dat `UiKit.schaal_aspect_voor()` zelf correct `KEEP` teruggeeft voor
  zulke maten (`ui_kit.gd:208,214-224`; test in `test_runner.gd:5396-5421`), dus de fout zit
  vermoedelijk in wat er ná die beslissing gebeurt: of `Shell._pas_schaal_aan()`
  (`autoload/shell.gd:40-44`) wordt niet (op tijd) aangeroepen bij het aanmaken van een venster op
  zo'n maat, of de content-scale-toepassing zelf gedraagt zich anders dan de eenheidstest
  veronderstelt. Kan niet verder gediagnosticeerd worden zonder de engine interactief te draaien
  (zie punt 6). Effect: op een telefoon die tijdens het spelen gedraaid wordt, of op elk apparaat
  breder dan 10:16, is het spel niet te bedienen — geen duimbalk, geen pauzeknop.

### Midden

- **M1 — mg_scope en mg_whack hebben geen eigen touch-invoer, alleen `InputEventMouseButton`.**
  `scripts/minigames/mg_scope.gd:114-118` (`WensRij._gui_input`) en
  `scripts/minigames/mg_whack.gd:60-65` (`Hole._gui_input`) werken op een telefoon uitsluitend
  omdat Godots project-default `emulate_mouse_from_touch` aanstaat — een instelling die **niet**
  in `project.godot` staat (dus stilzwijgend de default, geen bewuste keuze). Dit is al expliciet
  gedocumenteerd als valkuil in `docs/ARCHITECTURE.md:302-311` ("geen fout, geen melding, alleen
  een minigame die niet reageert" als iemand die instelling ooit uitzet). Ter vergelijking: de
  drie andere aanraak/sleep-minigames (`mg_heatmap`, `mg_uitlijnen`, `mg_pijplijn`) handelen
  `InputEventScreenTouch`/`ScreenDrag` inmiddels wél expliciet af — de ARCHITECTURE.md-tekst zelf
  is op dat punt gedateerd (noemt mg_uitlijnen/mg_pijplijn nog als "leunen op emulatie", wat de
  huidige code weerlegt), dus alleen mg_scope en mg_whack blijven het echte risico.
  Voorstel: dezelfde expliciete `InputEventScreenTouch`-tak toevoegen als in de andere drie.

- **M2 — Tellerchip (▤ 0/10) in de HUD is een grensgeval-tikdoel.**
  `scripts/ui/hud.gd:310-330`: de knop die de doelregel uitklapt is een `full_rect(Button)` binnen
  `_teller_chip`, wiens hoogte volgt uit FS_BODY (12vp) + `panel_krap`-marge (2vp rondom) ≈ 16-18
  viewport-px — geschat 33-37 fysieke px op 390-breed, dus onder 44px en onder de 30vp-standaard
  van de rest van de UI. Minder ernstig dan H1 (dit is geen enkelvoudig letterlabel maar een
  bredere chip met tekst "▤ 0/10"), maar wel meetbaar krap.

- **M3 — Geen texture-compressie in de webexport.**
  `export_presets.cfg` (hoofdcheckout): `vram_texture_compression/for_desktop=false` én
  `for_mobile=false`. Bij pixel-art-sprites is VRAM-uitputting geen realistisch risico, maar het
  draagt wel bij aan de downloadgrootte (zie L1).

### Laag

- **L1 — Downloadgrootte ruim boven het aanbevolen web-budget.**
  Bestaande build in de hoofdcheckout: `index.wasm` 38MB + `index.pck` 29MB = 67MB (zie ook het
  commentaar in `tools/deploy_web.sh`: "een wasm van 38 MB en een pck van 29 MB"). De
  platform-web-richtlijn noemt ~50MB als praktisch budget. Op mobiel netwerk is dit een trage
  eerste load. Niet blokkerend voor speelbaarheid zodra geladen, wel voor de eerste indruk.

- **L2 — `thread_support=false`, dus geen COOP/COEP nodig; dit is geen bevinding maar een
  bevestiging dat het al goed staat** (zie "Wat goed is").

## 5. Wat goed is

- **Eén invoerlaag voor toetsenbord én duim**, in plaats van een aparte mobiele UI. `Besturing`
  drukt bestaande `InputMap`-acties in via `InputEventAction`/`Input.action_press`, zodat
  `player.gd` niets van touch hoeft te weten (`scripts/ui/besturing.gd:1-24,251-260,420-437`).
- **Muis-als-vinger is bewust geclausuleerd**: een muisklik telt als tik, maar stuurt de
  joystick alleen onder een expliciete QA-vlag (`--stick-muis`), zodat een laptop-test de
  duimbesturing niet per ongeluk anders laat werken (`scripts/core/invoer.gd:16-49`).
- **Echte safe-area-implementatie** via `DisplayServer.get_display_safe_area()`, omgerekend
  door de canvas-transform (niet een naïeve deling), toegepast op elke UI-laag via
  `UiKit.veilige_laag()` (`scripts/ui/ui_kit.gd:356-404`).
- **Volwassen app-lifecycle**: `NOTIFICATION_APPLICATION_PAUSED` bewaart de sessie, pauzeert de
  tree, zet `Engine.max_fps = 1` en dempt audio; `WM_WINDOW_FOCUS_OUT` is bewust NIET hetzelfde
  op mobiele browsers (zou een vastgelopen sessie geven) — met uitleg erbij waarom
  (`autoload/shell.gd:69-135`).
- **De webexport-shell doet het juiste**: viewport-meta met `user-scalable=no` en
  `touch-action: none` op body (voorkomt pinch-zoom/scroll), bevestigd in de bestaande
  `build/web/index.html` in de hoofdcheckout.
- **mg_slotboard is al van sleep naar tik omgebouwd** (commit-notitie "F4-a"), specifiek omdat
  het oude sleepspel het kleinste interactieve element van het spel was (36×16px-kaartjes).

## 6. Niet geverifieerd — en hoe dat in 5 minuten wel kan

- **Echte touch-events (vinger i.p.v. muis-emulatie), iOS Safari-gedrag, en of
  `emulate_mouse_from_touch` op iOS Safari hetzelfde default-gedrag heeft als op Android Chrome.**
  Test: open de gh-pages-build (of een lokale `tools/serve_web.py --http`) op een echte telefoon,
  speel minstens één ticket met `mg_scope` (Scope bepalen) en `mg_whack` (Paardenbugs) — precies
  de twee die op muis-emulatie leunen (bevinding M1).
- **Het layoutdefect bij brede/landscape schermverhoudingen (H2) — exacte oorzaak.** Ik kon dit
  alleen via `--write-movie`-frames reproduceren, niet interactief live debuggen. Test: open het
  spel in een browser, verklein/vergroot het venster naar een brede maat (bv. sleep het browser-
  venster naar ~1000×700) terwijl het spel open staat, of draai een telefoon naar landscape
  tijdens het spelen, en kijk of de HUD/duimbalk terugkomt of weg blijft.
- **Web-audio-unlock op de eerste tap.** Geen code hiervoor in `autoload/audio_director.gd`
  buiten Godots eigen runtime-gedrag (die de AudioContext doorgaans zelf ontgrendelt op de eerste
  input). Test: open de webbuild vanaf koud (geen cache), tik als eerste actie ergens in de
  wereld, en luister of muziek/sfx direct spelen of pas na een tweede tik.
- **Daadwerkelijke laadtijd op mobiel netwerk** voor de 67MB (L1). Test: Chrome DevTools →
  Network → "Fast 3G"-throttle op de gh-pages-URL, of gewoon op 4G op een telefoon.
- **Vibratie op iOS-web** (`Haptiek.tril()`, `scripts/core/haptiek.gd:32-39`): de code trilt
  alleen op Android/Web (via `navigator.vibrate()`) en verwacht op iOS een niet-aanwezige native
  plugin, dus daar blijft het bewust stil — klopt dat gedrag ook echt met hoe Safari/iOS zich
  gedraagt (geen foutmelding, gewoon stil)? Test: speel op een iPhone en let op of er ooit een
  crash/foutmelding komt rond een moment dat `Haptiek.tril()` had moeten vuren.

---

**Rapport**: `/private/tmp/claude-502/-Users-daan-Documents-fun--claude-worktrees-10-tickets-vrijheid-handover-079cbc/5f701028-9d25-4a7e-a4d7-0da3b68bd7aa/scratchpad/audit-mobile.md`
