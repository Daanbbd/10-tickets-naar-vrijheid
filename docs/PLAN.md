# PLAN — 10 Tickets naar Vrijheid

> **Ronde 2 — het herontwerp** (nacht van 4 op 5 september 2026), op basis van de
> audit van 4 september van dialoog, minigames, tickets en de visuele wereld.
> Begin bij *Overdracht*. Ronde 1 (F0–F5, afgerond en gemerged op 3 september)
> staat in de git-geschiedenis (zie onderaan).

## Overdracht — lees dit eerst

### Waar het werk staat

- **Worktree:** `/Users/daan/Documents/fun/.claude/worktrees/fase1-fundament`,
  branch `fase1-fundament`. Sinds `d6abdcd` bevat hij óók Daans playtestronde
  van 4 september (`audit/opening-besturing-standup`, 16 commits: besturings-
  uitleg, bord met To Do / Doing / Done zonder ▤, Dennis loopt voorop, de
  Dennis-storing die nooit eindigde, BFS-padvinding, wereldlabels op maat,
  dialoogfixes). **Op 5 september 17:30 is alles naar `main` gegaan** (fast-
  forward op GitHub, `9a5bdec`; geen enkele branch had werk dat hier niet in
  zat) en is de webbuild opnieuw gedeployd. De branch bestaat nog als
  `origin/fase1-fundament`. Let op: de *lokale* `main` in de hoofdcheckout
  (`/Users/daan/Documents/fun`) loopt achter tot daar `git pull --ff-only` is
  gedaan — vanuit een worktree kan dat niet. Deployen gaat vanuit een worktree
  met `cp ../../../export_presets.cfg . && tools/deploy_web.sh`.
- **Stand op `main`:** suite 23.378 controles, 0 fout; alle zeven personages
  halen 10/10 in de geautomatiseerde speelbeurt. Elke fase is als eigen commit
  gecommit met een leesbare boodschap — lees `git log` als je wilt weten wát er
  veranderde en waarom.
- **Nieuwe worktree sinds 5 september, later op de avond:**
  `/Users/daan/Documents/fun/.claude/worktrees/fase3-rest-e-f`, branch
  `fase3-rest-e-f`, gebaseerd op de kop van `main` (`7df1330`). Drie commits,
  zie Overdracht C, E en F hierboven voor wat erin zit. Suite: 23.329
  controles, 0 fout (minder dan op `main` ondanks nieuwe tests: twee dode
  minigame-scenes eruit trekt ook hun losse canvas-fit-controles mee).
  `--playthrough --autoplay --quit-when-done` voor Daan: 10/10, exit 0 — de
  overige zes personages zijn dit keer niet stuk voor stuk herhaald, alleen
  Daan. Nog niet naar `main` gemerged of gepusht.
- **Werkwijze die geldt:** één fase per commit, alleen als de suite groen is en
  een speelbeurt 10/10 haalt. Nooit pushen of naar `main` mergen. Eerst in de
  worktree `--import` draaien als je class-cache-fouten ziet ("Could not find
  type …").

### De vier commando's

```bash
# spelen
/Applications/Godot.app/Contents/MacOS/Godot --path .
# testsuite (2 s; altijd met --quit-after, anders hangt hij bij een parsefout)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 3000 --scene res://tests/test_runner.tscn
# geautomatiseerde speelbeurt (~3 min per personage; print "gewerkt … uit om HH:MM")
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 40000 -- --speler=daan --playthrough --autoplay --quit-when-done
# een frame van een scherm (schrijft docs/audit-shots/<naam>.png)
python3 tools/qa_shot.py los 3.0 --speler=daan --kijk=20,20 --minuten=480      # de wereld om 17:12
python3 tools/qa_shot.py los 1.1 --minigame=mg_cro --speler=danny --autoplay    # een minigame, na 1 s spel
python3 tools/qa_shot.py wereld --res=360x640                                   # een andere schermverhouding
```

QA-vlaggen achter `--`: `--speler=<id>`, `--kijk=x,y`, `--minuten=<n>`,
`--minigame=<id>`, `--praat=<npc_id>`, `--auto=<world_id>`, `--bord`,
`--gedaan=<n>` (alleen met `--minigame`), `--scherm=uitleg|select|einde`.
Volledige lijst in `docs/TESTING.md`.

### Valkuilen die tijd kostten

- **De sandbox weigert lange of "complexe" shellcommando's** (heredocs met
  `git`-woorden erin, `for`-lussen met variabelen, lange `&&`-ketens). Werkwijze
  die werkt: schrijf een Python-script met de Write-tool naar het scratchpad
  (exacte tekstvervangingen met `assert s.count(old) == 1`) en run het met één
  plat `python3 <pad>`. Korte heredocs zonder het woord "git" gaan wel.
- **Movie Maker + `--resolution` liegt:** het frame komt op de maat van
  `window_*_override`, de layout op de nieuwe maat. Gebruik `qa_shot.py --res`,
  die een tijdelijke `override.cfg` schrijft en opruimt.
- **Een autowrap-Label zonder breedte** in een Control die geen Container is
  rekent zijn hoogte uit op nul pixels breed (één woord per regel). Geef hem
  `custom_minimum_size.x` of zet hem in een Container.
- **Een async test moet met `await` geregistreerd worden** in `_ready()`, anders
  telt alleen wat vóór de eerste `await` staat.
- **`Time.get_ticks_msec()` loopt onder Movie Maker ver voor** op de gerenderde
  seconden; tel `delta` op als het om speeltijd gaat.
- De pixelfont kent geen `€`. Schrijf "Prijs 24,95".

### Welk model waarvoor

Daan let op zijn tokens. Vuistregel: **Fable ontwerpt en diagnosticeert, Sonnet
voert uit en verifieert, Fable leest de diff.**

| Werk | Model | Waarom |
|---|---|---|
| Suite draaien, speelbeurten, frames maken en beschrijven | **Sonnet** | mechanisch, veel tokens, geen oordeel nodig |
| Data-edits met een gegeven spec (storingen, barks, ticket-JSON, docs) | **Sonnet** | de spec hieronder is exact genoeg; round-trip-check erbij |
| Code-edits met exacte ankers (het patroon van de `fase*_*.py`-scripts) | **Sonnet** | Fable schrijft het script, Sonnet mag het ook schrijven als de spec regel-voor-regel is |
| Tests schrijven voor al ontworpen gedrag | **Sonnet** | de invariant staat in het plan |
| Schrijfwerk in een bestaande stem (collega-regels, Danny's lowercase, Bastiaans `,,`) | **Sonnet, met 3 voorbeeldregels in de prompt** | daarna Fable één blik |
| Ontwerp met gevolgen over systemen heen (de finale, `build_speelveld`, een nieuwe minigame, balans in `Gevolgen`) | **Fable** | fouten hier kosten een dag |
| Een storing waarvan de oorzaak niet voor de hand ligt | **Fable** | zie de valkuilen hierboven — elk daarvan was een uur voor het gevonden was |
| De diff vóór een commit lezen | **Fable, kort** | één blik, geen herschrijf |

Praktisch: doe het ontwerp en de spec in een Fable-sessie, laat de uitvoering
via `Agent` met `model: "sonnet"` lopen (of een aparte Sonnet-sessie), en laat
Fable alleen de diff en de testuitslag zien. Geen Workflow-fan-outs zonder
Daans opt-in; die kosten het meest.

### Wat af is (8 commits)

1. **Fase 1** — één klok (`Klok.TICK_SEC` 20 s), finale die zichzelf niet meer
   wint (`Gevolgen.finale_start`/`oplevering_score`, drempels 13/9/4/0), daglicht
   (`Urenstaat.daglicht`), `Juice` (schok/confetti/squash), `set_frame`/
   `swap_texture`, tijdlekken dicht, "goed genoeg, shippen" bij falen, responsief
   portret (`aspect expand`, `RAND_RIJEN`, `rand_voor`, `schaal_aspect_voor`).
2. **Fase 2a** — deploy open vanaf 8/10, `Session.dag_klaar()`/`niet_af()`,
   deploylabel telt mee, wijzer wijst pas als laatste naar de deploy, collega's
   ontdooid, 16 storingen, `zoek_npc` voor BBD-209.
3. **Fase 2b** — `Bark` (terzijdes boven NPC's en objecten), overslaan (Esc /
   "overslaan »").
4. **Fase 4** — cold open: haar telefoonkaartje in `IntroUitleg`.
5. **Fase 3a** — BBD-206 is `mg_heatmap` (kijk waar ze klikken, sleep de knop);
   `mg_abtest` weg.
6. **Fase 3b** — eerste deploy kan falen (`faalt_deploy`, ROLLBACK), speler
   speelt `bezig_down` tijdens een minigame.

7. **Na de ochtend van 5 september** — de samenvoeging met Daans playtestronde
   (`d6abdcd`, zie hierboven), het "overslaan »"-label dat per letter omliep
   (`295a761`), en Dirk heeft een gezicht: zijn AI-gegenereerde avatar staat als
   `assets/personen/dirk.png`, `gen_portraits.py` strijkt hem glad, en hij geeft
   het toe in een terzijde ("Ik ben een stockfoto. Mijn urenstaat is echt.",
   `03f52e1`).

8. **Eén eigen ticket per personage** (BBD-202 en BBD-207 zijn van iedereen,
   briefer-veld); de oplevering kost 60 min (`kosten_min`).

Bewijs in `docs/audit-shots/`: `licht_*.png`, `resp_*.png`, `f2_*.png`,
`f3_heatmap.png`, `f4_uitleg.png`, `f5_merge_wereld.png`, `praat_dirk.png`.

### Wat open staat, in volgorde van waarde

**A. Fase 5 — de oplevering als Space Team (Fable ontwerpt, Sonnet bouwt).**
Nu: 8 acties op één klok van 75 s, drie gebeurtenissen op verbruikte acties,
dan de console. Doel: alles schreeuwt tegelijk. Concreet ontwerp om van te
vertrekken (nog niet met Daan doorgesproken — doe dat eerst):

- *Brandjes* in plaats van acties: kaartjes die binnenkomen met een eigen
  aflopende balk (6-10 s), twee tot drie tegelijk, sneller naarmate de klok
  vordert. Elk brandje noemt in Jira-Nederlands wat er brandt ("STAGING: 502 op
  /checkout", "Dennis: statusje!", "Klant belt over het paard", "Kabel B ligt
  los") en heeft één juiste handeling uit de bestaande zeven (`testen`, `fixen`,
  `scope`, `collega`, `informeren`, `nakijken`, `risico`). Goed gedoofd: het
  effect van die handeling. Verlopen: de straf (bugs +1 of vertrouwen −1).
- De dag zaait de brandjes: `gevolg_backend_fout_gekozen` → het kabelbrandje
  komt als eerste; `gevolg_klant_ontevreden` → de klant belt twee keer;
  `Session.niet_af()` → per open ticket een brandje "… is nooit afgekomen".
- De console-fase (DEPLOYEN → DEPLOYMENT FAILED → HERSTELLEN → LIVE) blijft als
  payoff; `faalt_deploy` blijft gelden.
- Data: `mg_deploy.brandjes: [{id, tekst, handeling, duur, straf, zaad?}]`,
  `spawn_curve: [[t, interval], …]`. Score blijft `Gevolgen.oplevering_score`.
- Autopilot: `qa_solve` dooft het brandje met de kortste balk. Tests: geen
  brandje zonder geldige handeling; de curve is monotoon; met perfect spel haalt
  een zorgvuldige dag de top (herbruik `scratchpad/finale_model.py`-aanpak).
- Raakt: `scripts/minigames/mg_oplevering.gd` (788 regels — overweeg een nieuw
  `mg_brandjes.gd` en laat de console-fase intact), `data/minigame_content.json`,
  `docs/MINIGAMES.md`, `test_runner.gd`.

**B. Fase 5.2 — een echte slotscène (Fable ontwerpt, Sonnet bouwt).** Nu zes
regels op zwart (`scripts/ui/ending.gd`). Wens: de vloer om 17:00 met je
collega's, de tien tickets teruggelezen met wat jij besloot (uit
`Session.completed_at`, `gebrekkig_*`, `niet_af`, de `gevolg_*`-vlaggen), het
bericht van de klant, de urenclou, de Jira-sting.

**C. Fase 3 rest (Sonnet met spec).** Gedaan in de `fase3-rest-e-f`-worktree
(`e3a3471`): geverifieerd dat t03/t05/t09 écht `wereldhandeling: true` dragen
en dus nooit via `Shell.run_minigame()` lopen, en op basis daarvan
`mg_choicescene.gd`/`.tscn` en `mg_cableboard.gd`/`.tscn` verwijderd (met
regressiewacht, naast de bestaande `mg_abtest`-wacht), `data/minigames.json`
en `_test_verwijzingen()` bijgewerkt, en `MINIGAMES.md`/`ARCHITECTURE.md`
gecorrigeerd (die noemden BBD-206 trouwens nog als `mg_abtest.gd`, al dood).
**`mg_whack.gd`/`.tscn` blijft bewust staan**: die wordt — anders dan de
andere twee — wél rechtstreeks aangeroepen, maar alleen door de testsuite zelf
(`Shell.call(&"run_minigame", &"mg_paarden", {})` op zes plekken in
`_test_storingen()`/`_test_minigame_pauze()`, als generieke "er loopt een
echte minigame"-fixture voor de onderbrekings- en pauzetests). Die zes
call sites verdienen eigen rewiring naar een ander fixture-minigame vóór
`mg_whack` ook weg kan — apart op te pakken.

Nog open: `build_speelveld()` als tweede chrome in `minigame_base.gd` (vast,
niet-scrollend veld — `mg_heatmap`/`mg_uitlijnen` laten zien hoe het eruit
moet zien); `mg_pijplijn` strakker (3× ruimte over); `mg_standup` is één
binaire beslissing. Deze raken `minigame_base.gd`'s publieke contract voor
alle overige minigames tegelijk — eerst een concreet ontwerp (Fable), dan
bouwen (Sonnet), net als bij Fase 5.

**D. Fase 2 rest.** Ophaalvariatie (`fetch`/`recruit` is 8-9× dezelfde beat;
`Npc.start_following`, `HelperStand` bestaan al) — Fable voor het ontwerp, Sonnet
voor de regels. De klant heeft geen gezicht (`"portrait": ""` in `data/npcs.json`;
art wordt door `tools/generators/*.py` gemaakt met Pillow uit
`/Users/daan/Documents/fun/tools/.venv`). Audio-escalatie via
`AudioDirector.LAGEN`.

**E. Klein en Sonnet-waardig.** Grotendeels gedaan in de `fase3-rest-e-f`-
worktree (`7d3c472`, `63f03a0`):
- **Gedaan** — de 37 ticketbomen waar de verkeerde mond bewoog: nieuw signaal
  `Bus.dialogue_speaker_changed` vuurt per regel (niet meer eenmalig bij de
  start van een boom); `npc.gd` volgt nu de daadwerkelijke spreker. Nieuwe test
  bewijst eerst dat er bomen met meerdere sprekers bestaan, dan de fix zelf.
- **Gedaan** — `Hud._on_toast()` had geen plafond; `TOAST_MAX = 3`, oudste
  gaat weg.
- **Gedaan** — `docs/dialogue-content.md` bijgewerkt: Dirk (volledig
  transcript + de niet-gewandelde `dirk_urenstaat`-boom) en een nieuwe sectie
  over `wereld.json` (tabel van alle 28 objecten, twee volledig uitgeschreven
  als voorbeeld). Dirk deelt zijn `role`-veld ("Scrum Master") met Dennis in
  `data/npcs.json` — geen bug: Dirk is een AI-scrummaster, Dennis de "echte",
  en de grap is dat Dirk Dennis' werkdruk met precies nul vermindert.
- **Nog open** — het scrumbord als sleepbaar bord (`scripts/ui/scrumbord.gd`);
  dialoogkeuzes op de `recruit`-momenten (`data/dialogue/tickets.json`,
  `variants`/`choices`-grammatica).

**F. Overgenomen uit de playtestronde (Sonnet).**
- **Gedaan** (`7d3c472`) — de Done-landing-animatie: Daan vroeg "animatie,
  geen wandeling" voor een ticket dat naar Done gaat; `Scrumbord.
  positie_van()`/`laat_klaar_landen()` onthouden de oude plek vóór `vul()` het
  briefje weggooit en laten het van daar naar zijn nieuwe kolom vliegen.
  Onderweg een echte bug gevonden en gefikst: `pivot_offset`/`rotation` moeten
  vóór `global_position` gezet worden, anders start de vlucht een paar pixels
  naast de onthouden positie.
- **Al opgelost, niet meer flaky** — de vermeende flaky test op
  `mag_onderbreken_minigame()` (`storingen.gd`): geverifieerd tegen de
  huidige code (niet blind op deze regel vertrouwd, zie
  [[peer-claims-verifieren]]), en de test injecteert de `nu`-parameter al
  overal waar het uitmaakt (`b9373d76`, 2 september) — inclusief de
  `_mg_gestart_op = -1000.0`-truc voor het ene pad dat de echte klok gebruikt.
  Geen actie nodig; deze regel stond hier op een oudere stand van de code.

### Wat Daan zelf moet doen

Spelen op een echte telefoon (de heatmap-sleep is alleen met een muis getest;
de barks en het overslaan zijn door geen mens gezien), en voor Fase 5 de
ontwerpkeuzes maken vóór iemand bouwt.

## Context

`10 Tickets naar Vrijheid` is technisch gezond en uitstekend geschreven, maar het
speelt niet leuk. Deze audit zocht de oorzaak in de systemen die de speelbeurt
dragen — dialoog, minigames, tickets, en de visuele wereld eromheen.

Vastgesteld bij aanvang (Daans keuzes, sturend voor dit plan):

- **Doel: een hele sterke playthrough voor elke speler — visueel, speltechnisch
  en qua plezier.** De speler moet denken: *"nondeju dit is een leuk spel, ik wil
  het halen."*
- **Geen Steam.** Portret 192×416, web, Nederlands, ~25 minuten blijven staan.
  Landschapsresolutie, i18n, controller en desktopbuild zijn **buiten scope**.
- **De echte collega's en hun foto's blijven.**
- **Twee gevoelens, niet één:** de **dag** (BBD-201 t/m 209) is een leuke maar
  chaotische queeste om met een disfunctioneel team een functionerende webshop
  te bouwen voor een disfunctionele klant — grappig, steeds anders, nooit saai of
  repetitief. De **finale** (BBD-210, de oplevering) is **Space Team**: alles
  schreeuwt tegelijk, en dat is de climax waar de hele dag naartoe werkt.
- **De introductie moet echt het waarom, wat, waar en hoe landen.**
- **De visuele wereld (UX en UI) wordt in dezelfde slag aangescherpt.**

## De diagnose

Drie dingen zijn kapot, en ze zijn niet hetzelfde probleem.

### 1 · De dag is repetitief, en er is geen reden om hem te willen halen

De speelbeurt is **tien keer exact hetzelfde ritueel**:

```
loop naar het anker  →  niet jouw vak  →  loop naar de collega  →  loop terug
   →  offer-dialoog + briefing  →  intro-kaart  →  formulier  →  toast  →  ×10
```

- `fetch` XOR `recruit` speelt **8 of 9 keer per beurt** dezelfde beat.
- **Elke minigame draagt identieke chrome.** `build_chrome()`
  (`minigame_base.gd:88-167`) = dimmer → titel → **ScrollContainer** → "Stoppen".
  Alle elf roepen dit aan, ook whack-a-mole (`mg_whack.gd:94`). Het commentaar
  noemt de oorzaak zelf: portretcanvas → geen ruimte → scroll. Gevolg: elf
  "verschillende" mechanieken zien er identiek uit — een verticale lijst witte
  knoppen met een blauwe bevestigknop. Zelfs `mg_pijplijn`, een realtime
  tikspel, ziet eruit als een spreadsheet.
- **Elf minigames zijn vijf werkwoorden over acht spellen**, en twee van die acht
  zijn hetzelfde spel: `mg_abtest` en `mg_abgevecht` delen de codestructuur én 7
  van 9 antwoordopties. Beide van Danny, achter elkaar te spelen.
- **Het collegagesprek bevriest na het eerste bezoek.** `tweede` is alleen
  trait-gated (dezelfde regel elke keer), `slot` heeft geen varianten, en **alle
  drie** de keuzes zetten `X_bezocht`. Bij hérpraten zijn regel 2 en 3
  byte-identiek; ~22 regels per beurt zijn permanent onbereikbaar.
- **Niets escaleert.** 5 van 11 minigames hebben geen timer. De klant stuurt 6
  berichten en verschuift nooit de opdracht. Er zijn **4 storingen in het hele
  spel**, en `storingen.gd:133-137` *onderdrukt* ze: hoogstens één per minigame.
- **En er is geen trek.** Niets kondigt de oplevering aan tot 9/10, en de laatste
  twee tickets zijn een gedwongen enkele rij — de vorm klapt van zandbak naar gang
  precies waar een komedie wil versnellen.

Het disfunctionele team en de disfunctionele klant staan **in de tekst** maar
bijna niet **in het spel**: "hoe je gespeeld hebt" verandert ~21 van 679 regels
(**3%**), 16 van 323 dialoognodes hebben een keuze (**4,9%**), en van de 59
ticketbomen branchet er precies **één**.

### 2 · Niets staat op het spel, dus de finale is geen climax

- **De finale wint zichzelf.** Score =
  `vertrouwen + min(getest, …) − 2·bugs + scope`. Op een goede dag levert
  `finale_start()` `{bugs 2, vertrouwen 7, getest 1, scope 9}` → **7+1−4+9 = 13**
  tegen een topdrempel van 10. Nul acties geeft de beste uitslag *én* ontwijkt
  alle drie de gebeurtenissen. En `mg_oplevering.gd:568` hardcodeert
  `finish_with_banner(true, …)`: de finale **kan niet falen**.
- **De klok is stuk.** Twee klokken tellen dubbel: `Urenstaat` is
  gebeurtenisgestuurd (30/45/15/15 min), maar `klok.gd:37-45` boekt daarnaast
  1 minuut per 2,5 reële seconde en draait dóór tijdens minigames. Een sessie van
  25 minuten boekt ~600 minuten wandklok bovenop ~510-540 uit het grootboek;
  `formatteer()` loopt niet rond: **het einde print ~28:12** waar
  `ending.gd:6-10` 17:42 belooft.
- **28 geldige scope-keuzes vallen samen op 2 waarden** via
  `clampi(scope_punten, 1, 9)`; `getest` kan alleen 0 of 1 zijn.
- **Falen kost 15 in-game minuten op een klok die niets poort**; Esc kost nul.
- `Gevolgen` schrijft 15 getallen en leest er **één**.

### 3 · De wereld is af; het spel eromheen heeft geen beeld

Dit is de visuele diagnose, en hij is scherper dan "maak het mooier".

**Wat af is:** de verdieping (`plattegrond_3x.png`) — elf ruimtes, coherent,
leesbaar, charmant. Acht lichtmoods per zone (`main.gd:12-21`, `warm`…`jungle`),
per zone een eigen lowpass-akoestiek, y-sort, dakdoorzicht op het hokje, een
dobberende wijzer met afstandskaartje, 9×9 post-it-badges, een tikring, een
zonenaam die opkomt, NPC's die na een tijdje stilstaan één keer hun eigen
bezigheid doen, een knipperende idle. En `UiKit` is inmiddels een echt systeem:
vijf-traps typeladder, contrastbewuste kleurderivaten, primaire/secundaire/
keuze-knoppen, post-it-stijl, veilige insets. Het personagekeuzescherm bewijst
wat dat systeem kan: podium, sprite, schaduw, accentgloed, tagline — het enige
scherm met echte hiërarchie.

**Wat niet af is, in vier zinnen:**

1. **Elk niet-wereldscherm is tekst op `SCHERM_NACHT`.** Titel
   (`title_screen.gd:10-13`: een `ColorRect` en labels, nul art-haken), uitleg
   (negen zinnen), de minigame-introkaart (WAT/WAAROM-muur, **8× per beurt**),
   tien van elf minigames, en het einde (zes regels). De speler brengt een groot
   deel van 25 minuten door op schermen die de wereld verbergen.
2. **De wereld is een podium waarop niets wordt opgevoerd.** Een opgelost ticket
   verandert een **tekstlabel** (`set_text` ×10 van 27 `world_changes`), pant de
   camera 1,5 s en toont een toast van 2,6 s. Geen sprite die verandert, geen
   deeltje, geen schok, geen viering. De speler speelt **nooit** `bezig` in de
   wereld (`player.gd:55`: alleen `walk_`/`idle_`): je "werkt" door stil te staan
   terwijl een formulier over je heen valt.
3. **Het licht volgt de dag niet.** De acht moods bestaan, maar de enige drijver
   van verandering is ticketaantal (`Gevolgen.tint()`, ≤35% naar een warme
   gloed). 09:12 → 17:00 heeft geen zichtbare boog: geen koele ochtend, geen
   middaglicht, geen 17:00-gloed, geen tl-avond bij overwerk. De klok is de
   ruggengraat van het spel en is onzichtbaar in de pixels.
4. **Nul juice, dertien geluiden.** Projectbreed geen `shake`, geen particles;
   vijf minigames zonder één tween; haptiek op twee plekken. 13 sfx voor het
   hele spel — geen stemblip per personage, geen kantoorgeluid (toetsenborden,
   telefoons, printer), geen UI-whoosh. De muziek (15 stukken, gelaagd,
   hervattend) is daarentegen uitstekend.

Het ene minigamescherm dat wél als een spel leest is `mg_uitlijnen`: een
begrensd canvas met objecten erop. **Dat is het model.**

### Eén eigen meting die ik terugneem

Ik dacht eerst dat het spel meer leeswerk bevat dan het lang is (9.214 woorden ≈
46 minuten). Dat is **fout**: één beurt raakt ~32% van de tekst (~215 regels) en
de typemachine loopt op 55 tekens/seconde — ~4 minuten typeanimatie. **Het volume
is niet het probleem.** De vorm wel: ~215 modale tikken die de wereld
stilzetten; **geen skip, geen auto-advance, geen tekstsnelheid**, en ESC wordt
nooit gepolld (een node van 5 regels kost **10 tikken**,
`dialogue_controller.gd:172-179`); en **64% van de stemmen is de speler tegen
zichzelf of een naamloze verteller** (218 + 191 van 634) — de acht collega's
hebben er samen 191.

### Wat goed is, en dus moet blijven

- **Het schrijfwerk.** 679 regels, 337 met een `when`; **30,5% van de nodes
  rendert andere tekst afhankelijk van wie je speelt**. `t10_offer` heeft 8 eigen
  foutcodes, `t07_fail` een vier-tiers-escalatie. Het plan verplaatst dit,
  snijdt het niet.
- De testsuite (8 gerichte dialoogtests, **nul dode flag-lezingen** in 47).
- De muziekmotor, `Briefing`/`TraitModifier`, `Conditions`, `Haptiek`, het
  `_geweigerd`-instrument, de plattegrond en de zonemoods.
- **De wereld pauzeert al niet meer tijdens een minigame** (F5-a) — het fundament
  voor gelijktijdigheid én voor een speler die zichtbaar werkt onder de overlay.
- `Bus.toast_requested` als bestaand niet-blokkerend kanaal.
- De klant als **paard-GIF** in de telefoon (`telefoon.gd:251-259`) — een
  diegetisch gezicht. Alleen: in haar 12 dialoogregels in de wereld heeft ze géén
  portret (`"portrait": ""`). Geef haar daar hetzelfde paard.

## De vorm van het spel, na dit plan

```
09:12  opening        cold open óver de verdieping: waarom, wat, waar, hoe —
                      gespeeld in ~30 s, koel ochtendlicht, collega's druppelen in
       ↓
       de dag         chaotische queeste. Elk ticket een ander werkwoord en een
                      ander beeld. Het team wordt zichtbaar disfunctioneler, de
                      klant verschuift de opdracht, storingen lopen op, het licht
                      draait mee met de klok. Overal hangt de oplevering al boven
                      de dag; elk opgelost ticket verandert pixels, niet labels.
       ↓
17:00  DE OPLEVERING  Space Team. Alles schreeuwt tegelijk. Wat je die dag
                      besloot komt binnen als brandjes. Dit is de climax.
       ↓
       het slot       de verdieping in avondlicht, je collega's, jouw dag
                      teruggelezen
```

### Vijf staande visuele regels (gelden in elke fase)

1. **Geen scherm verbergt de wereld zonder reden.** Titel, uitleg, intro-kaart,
   einde en zoveel mogelijk minigames spelen zich *op* of *boven* de verdieping
   af, niet op `SCHERM_NACHT`.
2. **Elk opgelost ticket verandert pixels.** Een `set_text` is nooit het enige
   gevolg.
3. **Het licht volgt de klok.** De zonemood blijft; de dagfase komt erbij.
4. **Wie werkt, is te zien.** Speler en NPC's spelen `bezig` als ze bezig zijn.
5. **Foto's krijgen een diegetisch kader.** Ze blijven, maar als badge- of
   Slack-avatar in de dialoogbox, zodat foto en pixel niet meer botsen.

---

## Het plan

Vijf fases. Elke fase is los speelbaar en los te beoordelen.

## Fase 1 — Fundament: inzet, licht en juice-primitieven

> **Stand:** gedaan (`53a302e`), inclusief het responsieve portret.

Alles wat latere fases nodig hebben en nu ontbreekt. Goedkoopste fase, grootste
sprong.

1. **Repareer de dubbele klok.** Kies het grootboek; `klok.gd` toont alleen nog.
   Werk `ending.gd:6-10` bij.
2. **Dicht de twee tijdlekken.** `nooduitgang/keuze` kost `kost_tijd: 15` **elke
   keer**, ongated; `koffiemachine/keuze` 5. Zodra de klok tanden krijgt is dit
   een exploit.
3. **Geef 17:00 tanden.** Niet door voortgang te blokkeren — die regel blijft —
   maar door de dag te laten aflopen: wat om 17:00 niet af is gaat *ongetest*
   live en komt terug in de oplevering, bij collega's en in het slot.
4. **Laat het licht de klok volgen.** Eén functie die `CanvasModulate $Licht`
   mengt uit zonemood × dagfase (`Urenstaat.nu()`): koel om 09:12, warm om 15:00,
   gloed richting 17:00, tl-avond bij overwerk. Bouwt op `_tint_zone()` en
   `Gevolgen.tint()`, vervangt ze niet. Dit maakt de gerepareerde klok in één
   klap zichtbaar én is de eerste bron van "ik wil het halen".
5. **Ontplat de finalemeters.** Herschaal `scope` (`gevolgen.gd:211`, `:216-218`)
   en geef `getest` meer standen. Let op: `paard` zit in **alle 28** winnende
   scope-sets (dus `gevolg_paard_beloofd` heeft nul variantie) en
   `gevolg_scope_te_groot` is bij cap 13 **onbereikbaar** — alleen Daan kan hem
   krijgen.
6. **Laat falen een keuze zijn.** Bied bij FAIL *"goed genoeg, we shippen het"*:
   het ticket sluit, en het bijt in de oplevering.
7. **Lees de dode gevolgen, of gooi ze weg.** 13 van 15 getallen hebben nul lezers.
8. **Juice-primitieven in `UiKit`/`Haptiek`.** Eén `schok(px, duur)` op de camera
   (klein: 2-3 px), één post-it-confetti-emitter, één knop-squash, één
   paneel-slide. Projectbreed bestaat er nu niets van; elke latere fase gebruikt
   ze.
9. **Nieuwe `WorldMutator`-ops: `set_frame` / `set_texture`.** Nu bestaan alleen
   `set_text`/`set_modulate`/`set_visible`. Zonder deze twee kan regel 2 ("elk
   ticket verandert pixels") niet.
10. **Responsief op elke telefoon — geen zwarte balken.** (Toegevoegd door Daan,
    4 september 's avonds.) `project.godot` heeft geen `window/stretch/aspect`,
    dus Godot valt terug op `keep`: elke telefoon die niet exact 6:13 is krijgt
    balken links/rechts of boven/onder. Fix: `aspect = "expand"` — 192×416 wordt
    een *minimum* en het canvas groeit in de as waar het toestel ruimte heeft
    (9:16 → ~234 breed; 9:21 → ~448 hoog). Voorwaarde: niets mag 192/416
    hardcoderen — HUD, besturing, wijzer, dialoogbox en minigame-chrome moeten
    van `get_visible_rect()` of ankers uitgaan. Voor hogere toestellen toont de
    camera ruimte boven/onder de 26 tegels hoge vloer: die leegte moet als muur
    lezen (wandtegels of de wandkleur als `default_clear_color`), niet als
    zwart. Bewijs: frames op 9:16, 9:19,5 en 9:21 via `--resolution` +
    `--write-movie`, zonder balk en zonder afgesneden knop.

    *Uitvoering:* na de Fase 1-workflow, als eigen workflow (raakt
    `project.godot`, `game_camera.gd`, `world_builder.gd`, en elke plek die
    een canvasmaat hardcodeert).

**Raakt:** `scripts/world/klok.gd`, `scripts/core/urenstaat.gd`,
`scripts/core/gevolgen.gd`, `scripts/world/main.gd` (`_tint_zone`),
`scripts/world/world_mutator.gd`, `scripts/ui/ui_kit.gd`,
`scripts/core/haptiek.gd`, `scripts/world/game_camera.gd`,
`data/dialogue/wereld.json`, `scripts/ui/ending.gd`.

## Fase 2 — De dag: chaotisch, grappig, zichtbaar, nooit repetitief

> **Stand:** deels. 2a (`76624b2`: deploy open vanaf 8/10, collega's ontdooid,
> zestien storingen, `zoek_npc`) en 2b (`50e0f94`: terzijdes, overslaan) zijn
> gedaan. Open: ophaalvariatie, het gezicht van de klant, de klant die de
> opdracht verschuift, audio-escalatie — zie Overdracht D.

1. **Breek de identieke lus.** Geef het ophaalritueel variatie in de *vorm*: een
   collega die niet mee wil, een die al ergens anders staat, een die de verkeerde
   collega meeneemt, een die je onderweg kwijtraakt. `Npc.start_following()` en
   de vier `HelperStand`-standen staan er al.
2. **Maak het team zichtbaar disfunctioneel — in de wereld.** Collega's die
   elkaar tegenspreken, iets "al gefixt" hebben dat nu stuk is, jouw ticket
   overnemen terwijl je weg bent, of aan een bureau zitten te typen (`bezig` op
   NPC's die nu stilstaan). Elke stoornis is een grap plús een obstakel plús iets
   om te zien.
3. **Elk ticket verandert pixels.** Met de nieuwe ops uit Fase 1: het whiteboard
   krijgt écht een zin, de serverrack-leds gaan groen, het paard op de
   wandmonitor schuift naar links, het koffiecorner-speakertje krijgt een
   geluidsgolf. Nu is 10 van 27 wereldveranderingen een tekstlabel.
4. **De speler werkt.** Speel `bezig_down` bij het anker tijdens een
   wereldhandeling en onder de minigame-overlay (de wereld draait door, dus dat
   kan). En vier het einde van een ticket: schok, confetti, `overwinning`-laag
   kort omhoog, de camera-pan van 1,5 s blijft.
5. **Ontdooi het collegagesprek.** Varianten voor `tweede` en `slot` op
   voortgang, tijd en `gevolg_*`; ontkoppel de drie keuzes van één gedeelde
   `X_bezocht`.
6. **Laat de klant de opdracht verschuiven.** Ze moet tijdens de dag scope
   toevoegen, iets terugdraaien wat je net af hebt en een ticket wijzigen.
   `klant_berichten` kan al `unlock_ticket`; `storingen.gd` kan al
   `ticket_wijzigt`/`reopen_ticket`. Geef haar het paard als portret in de
   dialoogbox.
7. **Storingen worden comedybeats met oplopende frequentie.** Haal de throttle
   weg en zet er een curve voor: rustig om 10:00, druk om 15:00, en om 17:00
   klapt het over in de finale. Vier worden er vijftien-plus; het dataformaat
   kan dit al.
8. **Laat de oplevering de hele dag boven de dag hangen.** Een deployteller in
   de HUD, een collega die er steeds naar vraagt, de klant die naar morgen
   verwijst. Repareer de gedwongen enkele rij aan het eind.
9. **Zet de stemmen buiten de modale box.** Verhuis niet-kritieke regels naar
   `Bus.toast_requested` als *barks* boven de spreker in de wereld — overhoord,
   geen tik, geen `input_locked`. Herverdeel de stemmen: 64% is nu speler of
   verteller.
10. **Geluid van een kantoor.** Per zone een ambientlaag (toetsenborden,
    telefoon, printer, de koffiemachine) op de bestaande lowpass-akoestiek; een
    stemblip per personage op de typemachine; UI-whoosh op panelen. De
    muziekmotor kan de escalatie al dragen via `LAGEN`.

**Raakt:** `scripts/world/storingen.gd`, `data/storingen.json`,
`data/klant_berichten.json`, `data/npcs.json`, `data/dialogue/npcs.json`,
`scripts/entities/npc.gd`, `scripts/entities/player.gd`, `scripts/ui/hud.gd`,
`scripts/ui/telefoon.gd`, `scripts/ui/dialogue_box.gd`,
`autoload/audio_director.gd`, `data/tickets/*.json`, `tools/generators/`.

## Fase 3 — Handen in plaats van formulieren, en elk spel een eigen beeld

> **Stand:** deels. 3a (`c2bbe66`: BBD-206 is `mg_heatmap`, `mg_abtest` weg) en
> 3b (`a07a2e5`: de eerste deploy kan falen, de speler werkt zichtbaar) zijn
> gedaan. Open: `build_speelveld()`, de overige minigames, de juice-toepassing —
> zie Overdracht C. Waar hieronder nog `mg_abtest` staat is `mg_heatmap` bedoeld.

1. **`build_speelveld()` naast `build_chrome()`.** Een vast, niet-scrollend
   speelvlak met de bestaande header/footer-stroken. `mg_uitlijnen` is het model:
   een begrensd canvas met objecten erop.
2. **Elk minigame krijgt een eigen visuele identiteit.** Het whiteboard is een
   whiteboard (papier, stift), de pijplijn is een lopende band, de stand-up is
   een kring mensen met een klok, het gevecht is een ring. Nu is de identiteit
   de chrome; het spel zelf is verwisselbaar.
3. **Elf minigames worden vier, plus korte beats.** Houd en verdiep wat een
   eigen werkwoord heeft — `mg_uitlijnen` (sleepwerk), `mg_pijplijn` (tikken
   onder druk), `mg_oplevering` (de finale) — en zet de rest om in
   wereldhandelingen of beats van 5-15 s. Het `wereldhandeling`-pad bestaat al.
4. **De intro-kaart wordt een tekstballon.** WAT/WAAROM komt uit de mond van de
   eigenaar, boven de wereld, in plaats van als 8× een schermvullende muur.
5. **Ruim de dubbele quiz op** (Daans keuze: één blijft, de ander wordt echt
   anders). Houd `mg_abgevecht`; geef BBD-206 een ander werkwoord. Let op twee
   geverifieerde fouten in het gevecht: maximale tegenklap 20+25+20 = **65 <
   100** (A's levensbalk is decoratie) en **1 van 27 paden wint** (35+40+35 =
   110; de tweede beste haalt 90). De maximale-schade-optie heeft in elke ronde
   óók de laagste tegenklap; Danny's trait toont de irrelevante as.
6. **Repareer wat kapot is in de rest.** `_wh_klantfeedback`: opties **niet
   gehusseld**, 3-punter altijd bovenaan → drie keer knop 1 = 9/9. `mg_standup`:
   één binaire beslissing (alleen Jonathan te vroeg afkappen verliest, en de
   briefing wijst hem aan). `mg_pijplijn`: 3× ruimte over. `mg_scope`/
   `mg_uitlijnen`: geen timer, geen pogingenlimiet, en de statusregel vertelt
   wanneer je gewonnen hebt. `mg_scope` is bovendien nog steeds het drukste
   scherm van het spel (37 labels, twee budgetten) én het eerste dat je ziet.

**Raakt:** `scripts/minigames/minigame_base.gd`, `scripts/minigames/*.gd`,
`scripts/ui/minigame_intro.gd`, `scripts/world/ticket_controller.gd`,
`data/minigame_content.json`, `tools/generators/gen_props.py`.

## Fase 4 — De opening: waarom, wat, waar, hoe — óver de verdieping

> **Stand:** gedaan (`6319427`, `0228d93`).

Nu: negen zinnen plus "Begrepen", en een titelscherm van labels op een
`ColorRect`. Het moet *gespeeld* worden, in ~30 seconden, op de vloer:

- **Titel over de verdieping**: de camera drijft om 09:00 over het kantoor in
  koel ochtendlicht, collega's druppelen binnen, de titel staat erboven.
- **waarom** — de webshop moet morgen live, laatste dag van sprint 14, uit een
  mond (`_intro_beat()` doet dit al goed — behouden);
- **wat** — Manege De Vrije Teugel, paardensupplementen, en één blik op wat er
  nu staat, zodat elke grap over het paard naar links later landt;
- **waar** — deze verdieping, deze zeven ruimtes, deze mensen;
- **hoe** — er vuurt één opdracht, de wijzer wijst, jij rent erheen en doet het.

Dennis die je ophaalt en het lege bord dat volloopt blijven — dat is al goed.

**Raakt:** `scripts/ui/title_screen.gd`, `scripts/ui/intro_uitleg.gd`,
`scripts/world/main.gd`, `autoload/shell.gd`.

## Fase 5 — De climax: de oplevering als Space Team, en het slot

> **Stand:** open, op de faalstaat van 5.1 na (`a07a2e5`). Het ontwerp om van te
> vertrekken staat in Overdracht A en B; eerst met Daan bespreken, dan bouwen.

1. **De oplevering wordt de chaosscène.** Nu het rustigste moment van het spel:
   een lijst tekstknoppen met "DEPLOYEN" eronder. Het moet het luidste worden:
   - **alles schreeuwt tegelijk** — meerdere brandjes met elk een eigen aflopende
     balk, in plaats van 8 rustige acties op één klok;
   - **wat je die dag besloot komt binnen als brandjes** — de `gevolg_*`-vlaggen
     en finalemeters zijn de brandhaarden, niet alleen startgetallen;
   - **het team schreeuwt tegenstrijdige instructies** — het disfunctionele team
     uit Fase 2 komt hier samen; `_test_finale_heeft_team` is de bestaande haak;
   - **de verdieping is het paneel** — de props die je de hele dag gebruikte
     worden hier de knoppen; de camera leidt, het licht flakkert, de muziek
     stapelt lagen;
   - **en falen moet kunnen.** Zonder faalstaat is er geen climax.
2. **Een echte slotscène op de vloer.** Nu zes gecentreerde regels op zwart met
   **één van vier** titel/tekst-paren als variatie. Maak het de verdieping in
   avondlicht: je collega's, de tien tickets teruggelezen met wat jíj besloot en
   wat er van te zien is, het bericht van de klant, de urenclou, de Jira-sting.
   Dit is het moment waarop iemand besluit of het leuk was — en of hij het nog
   eens als iemand anders doet.
3. **Geef de dialoog iets te vragen.** Keuzes op de momenten die al betekenis
   hebben (een collega ophalen, de telefoon, "is dit klaar?") en via `Gevolgen`
   naar de oplevering. De uitweg is er al: overslaan via Esc en "overslaan »"
   (2b, `50e0f94`); alleen een tekstsnelheid ontbreekt nog.
4. **Maak het scrumbord fysiek.** Het heeft al post-its (`UiKit.postit()`), maar
   ze staan in een lijst. Sleepbare kaarten tussen BIJ JE en OPGELOST geven
   "kiezen" een handeling.

**Raakt:** `scripts/minigames/mg_oplevering.gd`, `data/minigame_content.json`,
`scripts/ui/ending.gd`, `scripts/ui/scrumbord.gd`,
`scripts/ui/dialogue_controller.gd`, `scripts/ui/dialogue_box.gd`,
`data/dialogue/*.json`.

---

## Losse geverifieerde defecten (los op te pakken)

- **In 37 van 59 ticketbomen beweegt de verkeerde mond, of geen.**
  `Bus.dialogue_started` wordt één keer geëmit met de spreker van de
  **startnode** (`dialogue_controller.gd:78`); elke `tXX_offer` start op een
  vertellerregel en elke `_recruit`/`_complete`/`_fail` op `speler`. De collega
  naast je speelt `idle_` door zijn eigen gesprek. Goedkope fix, groot effect.
- ~~**BBD-209 wijst naar het verkeerde object.**~~ Gedaan in 2a (`76624b2`):
  tickets kennen `zoek_npc`, de wijzer wijst naar het dichtstbijzijnde paard.
- ~~**BBD-208 en BBD-209 hebben geen `camera_focus`**~~ Gedaan in 2a.
- **`mg_whack.gd` is de enige arcademechaniek en draait nooit** (t09 is
  `wereldhandeling`); idem `mg_choicescene.gd`, `mg_cableboard.gd`.
- **Geen `locked`-regel bestaat** voor enig ticket; alles valt door naar één
  gegenereerde zin (`ticket_controller.gd:120`).
- **`_load_dialogue()` heeft geen dubbele-id-wacht** (`game_data.gd:256-267`).
- **Eén dode regel:** `collega_bastiaan/tweede[1]` — `pick_variant` is
  eerste-match, en `docs/dialogue-content.md` beweert een voorrang die niet
  bestaat (`Conditions.pick_variant`, `:104-111`).
- **Documentatiedrift.** `dialogue-content.md` noemt `wereld.json` (19% van de
  dialoog) en Dirk nul keer. `MINIGAMES.md` noemt drie dode scripts als levende
  mechaniek, belooft slotboard-traits die `GEEN_VOORDEEL` weigert, zegt 42 s
  voor een stand-up van 30 s. Vijf codecommentaren liegen tegen de data:
  `ticket_def.gd:12-18`, `quest_engine.gd:461`, `ticket_controller.gd:558`,
  `quest_engine.gd:364-365`, `ending.gd:6-10`.

## Wat níet gebeurt

Buiten scope op Daans keuze: een landschaps-/desktopindeling (responsief *portret* op telefoons is juist wél in scope, zie Fase 1.10), Engelse localisatie,
controllerbindings, desktop-exportpreset, langere speelduur, fictionaliseren van
de collega's. De foto's blijven (met kader). **De dag wordt géén Space Team** —
die toon is voor de oplevering. En **de pixelart van de verdieping wordt niet
complexer** — het beeldwerk zit in licht, momenten en schermen, niet in meer
tegels.

## Verificatie

1. **Testsuite** — `Godot --headless --path . --scene res://tests/test_runner.tscn`.
   Nieuwe invarianten:
   - de eindtijd valt in een venster rond 17:00 (F1);
   - `finale_start()` levert over de 28 geldige scope-sets **meer dan twee**
     `scope`-waarden (F1);
   - nul acties in `mg_oplevering` haalt **niet** de topdrempel, en de finale kán
     falen (F1 + F5);
   - elk ticket heeft minstens één `world_change` die geen `set_text` is (F2);
   - de storingfrequentie loopt monotoon op met de dag (F2);
   - een tweede gesprek met dezelfde collega levert minstens één andere regel (F2);
   - geen minigame is te winnen door drie keer knop 1 (F3);
   - een algemene variant-shadowingcheck over alle 454 varianten;
   - `dialogue_started` noemt een spreker die de animatielaag kan gebruiken.
2. **Geautomatiseerde speelbeurt** per personage —
   `--playthrough --autoplay --quit-when-done`; urenstaat en finaleuitslag per
   personage uitlezen om spreiding te bewijzen. Let op de `_geweigerd`-teller:
   die faalt een run bij overlappende dialoogaanroepen, en Fase 2 en 5 duwen daar
   tegenaan — hij moet een regel over dag-versus-finale worden, geen blanket fail.
3. **Beeld** — `python3 tools/qa_shot.py <scherm>` (gebruikt `--write-movie`, niet
   `--shot`) voor elk scherm dat een fase raakt, en één **tijdreeks** van dezelfde
   ruimte op 09:12 / 12:00 / 15:00 / 17:00 / overwerk om de lichtboog te
   bewijzen. Voor layoutwerk `tools/render_plattegrond.py`. Voor de dialoogbox
   met foto-kader: een shot vóór en na, naast elkaar.
4. **Naar de pixels en naar het gevoel moet Daan zelf kijken.** "Nondeju dit is
   een leuk spel" is niet headless te meten. Na Fase 2 en na Fase 5 een
   speelsessie op een echte telefoon, en één bij iemand die het spel niet kent.

> Werk in een eigen worktree op de kop van de actieve branch: er lopen op dit
> moment drie andere sessies in deze checkout. Eerst
> `Godot --headless --path . --import`, en `export_presets.cfg` uit de
> hoofdcheckout kopiëren als er geëxporteerd moet worden.

---

## Ronde 1 (3 september 2026, afgerond en gemerged)

Het plan van ronde 1 (F0–F5: van "goed geschreven" naar "leuk") stond hier als
archief en zorgde voor verwarring — wie doorscrolde zag een oude plattegrond en
oude statussen. Het staat in de git-geschiedenis: `git show c765d4e:docs/PLAN.md`.
