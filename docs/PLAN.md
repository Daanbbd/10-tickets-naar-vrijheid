# PLAN — 10 Tickets naar Vrijheid

> **Ronde 2 — het herontwerp** (nacht van 4 op 5 september 2026), op basis van de
> audit van 4 september van dialoog, minigames, tickets en de visuele wereld.
> Begin bij *Overdracht*. Ronde 1 (F0–F5, afgerond en gemerged op 3 september)
> staat onderaan als archief.

## Overdracht — lees dit eerst

### Waar het werk staat

- **Worktree:** `/Users/daan/Documents/fun/.claude/worktrees/fase1-fundament`,
  branch `fase1-fundament`. Sinds `d6abdcd` bevat hij óók Daans playtestronde
  van 4 september (`audit/opening-besturing-standup`, 16 commits: besturings-
  uitleg, bord met To Do / Doing / Done zonder ▤, Dennis loopt voorop, de
  Dennis-storing die nooit eindigde, BFS-padvinding, wereldlabels op maat,
  dialoogfixes). Samen 26 commits bovenop `main`. Niets is gepusht of gemerged
  naar `main`; dat is Daans call. **Let op:** de webbuild op gh-pages komt nog
  van die playtestbranch en mist het herontwerp — opnieuw deployen vanuit deze
  worktree (`cp ../../../export_presets.cfg . && tools/deploy_web.sh`).
- **Stand:** suite 23.405 controles, 0 fout; alle zeven personages halen 10/10
  in de geautomatiseerde speelbeurt. Elke fase is als eigen commit gecommit met
  een leesbare boodschap — lees `git log` als je wilt weten wát er veranderde
  en waarom.
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

**C. Fase 3 rest (Sonnet met spec).** `build_speelveld()` als tweede chrome in
`minigame_base.gd` (vast, niet-scrollend veld — `mg_heatmap`/`mg_uitlijnen`
laten zien hoe het eruit moet zien); `mg_pijplijn` strakker (3× ruimte over);
`mg_standup` is één binaire beslissing; `mg_whack`/`mg_choicescene`/
`mg_cableboard` zijn dode code — verwijderen of herleven.

**D. Fase 2 rest.** Ophaalvariatie (`fetch`/`recruit` is 8-9× dezelfde beat;
`Npc.start_following`, `HelperStand` bestaan al) — Fable voor het ontwerp, Sonnet
voor de regels. De klant heeft geen gezicht (`"portrait": ""` in `data/npcs.json`;
art wordt door `tools/generators/*.py` gemaakt met Pillow uit
`/Users/daan/Documents/fun/tools/.venv`). Audio-escalatie via
`AudioDirector.LAGEN`.

**E. Klein en Sonnet-waardig.** Het scrumbord als sleepbaar bord
(`scripts/ui/scrumbord.gd`); dialoogkeuzes op de `recruit`-momenten
(`data/dialogue/tickets.json`, `variants`/`choices`-grammatica);
`docs/dialogue-content.md` bijwerken (mist `wereld.json` en Dirk); de 37
ticketbomen waar de verkeerde mond beweegt (`Bus.dialogue_started` emit alleen
de startspreker — `dialogue_controller.gd:78`, `npc.gd:71-84`).
Nog één kleintje: `Hud._on_toast()` stapelt toasts zonder plafond; bij drie of
meer tegelijk (een opgelost ticket, een storing en Dennis) vult de stapel het
scherm (zie `praat_dirk.png`, gemaakt met `--ticket=t06`, dat alles tegelijk
laat vuren). Cap op drie, oudste weg.

**F. Overgenomen uit de playtestronde (Sonnet).** De Done-landing-animatie
voor het bord: Daan vroeg "animatie, geen wandeling" voor een ticket dat naar
Done gaat; nu herklasseert het stil (vgl. `Hud.laat_landen()` /
`Scrumbord.laat_briefje_landen()` voor nieuwe tickets). En de flaky test op
`mag_onderbreken_minigame()` (`storingen.gd`): meet nu echte wandtijd; geef de
injecteerbare `nu` door in de test.

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

# Archief — Ronde 1 (3 september 2026, afgerond en gemerged)

## PLAN — 10 Tickets naar Vrijheid — van "goed geschreven" naar "leuk"

### Status (bijgewerkt 3 september 2026)

**F0 t/m F5 zijn klaar en gemerged in `main`,** en daarbovenop is een
auditronde gelopen — zie "Auditronde" hieronder. Testsuite staat op
**20.619 controles, 0 fout, ALLES GOED** (17.489 bij het eind van F5, 16.658
als baseline bij de start van dit plan). Alleen F6 (verificatie/docs) is nog
niet als fase begonnen, al is er in de auditronde flink aan docs gewerkt.

| Fase | Status | Noot |
|---|---|---|
| F0-a save/laden/pauzemenu | ✅ Klaar | `_test_save_ronde()` erbij, `--doorgaan`-QA-vlag toegevoegd |
| F0-b kapotte layouts | ✅ Klaar | Ook `ui_kit.gd`/`mg_slotboard.gd`'s dode minimum-overrides meegepakt |
| F0-c dode data/code | ✅ Klaar | Zie "Afwijkingen" hieronder — groter dan de briefing beschreef |
| F0-d losse eindjes | 🟡 Klaar, één blokkade | Dirks portret kan niet: `assets/personen/dirk.png` (bronfoto) ontbreekt — heeft een foto van jou nodig |
| F1-a vloer herontwerp | ✅ Klaar | Beide correcties uit de tweede schets zijn doorgevoerd — zie "Correcties uit de tweede schets" |
| F1-b 40% vloer belonen | ⬜ Geen eigen actie | Realiseert zichzelf via F3-a (toilet) en F4-b (paardenbugs) — nog te doen als onderdeel daarvan |
| F1-c prop-art en diepte | ✅ Klaar | Vond en repareerde de y-sort-bug zelf; ontdekte dat HUD+balk ~6,5 tegelrijen permanent afdekken (gedocumenteerd in `docs/TESTING.md`) |
| F2-a typografie | ✅ Klaar | Fonts gedownload, geen fallback nodig |
| F2-b knopstijl | ✅ Klaar | 13 bevestigende acties, `KNOP_MIN_H` 30 |
| F2-c leesbaarheid | ✅ Klaar | Twee grijzen i.p.v. één (licht/donker ondergrond); vond een 4e stapelfout die de briefing niet noemde |
| F2-d kompasstrip | ✅ Klaar | Leest vloerbreedte uit data, geen hardcoded 130 |
| F2-e minigame-chrome | ✅ Klaar | Vond en repareerde een portret-overflow-bug en twee misplaatste knoppen |
| F3-a De inbox loopt vol | ✅ Klaar | 4 tickets open bij start (west-cluster, 4 eigenaren), rest via `unlocks`-keten |
| F3-b De klant kan ontsporen | ✅ Klaar | 4 → 6 beats, `Gevolgen.DREMPELS` uitgebreid, effects op klantberichten |
| F3-c Storingen | ✅ Klaar | Dirk gegeneraliseerd naar `data/storingen.json`; nieuw `QuestEngine.reopen()` |
| F3-d De klok gaat lopen | ✅ Klaar | Geen ticket-herbalancering nodig, zie "Afwijkingen" |
| F4-a Zes minigames herzien | ✅ Klaar | `mg_scope`/`mg_standup`/`mg_uitlijnen`/`mg_abtest`/`mg_pijplijn` + `mg_urenstaat`-vervanging |
| F4-b Vier wereldhandelingen | ✅ Klaar | BBD-203/205/207/209 lossen op zonder wereld-pauze, geen minigame-scherm meer |
| F4-c Druk op de finale | ✅ Klaar | Klok, echte onderbreking, titel beweegt mee met score, fase 2 van 7 naar 3 regels |
| F4-d Elk gevolg landt | ✅ Klaar | Alle 9 niet-finale tickets wegen nu mee in `finale_start()` (eis was ≥8) |
| F5-a Invoerslot i.p.v. wereldpauze | ✅ Klaar | `Shell.run_minigame()` gebruikt nu `Session.lock_input()`, geen `get_tree().paused` meer |
| F5-b Storingen landen in de minigame | ✅ Klaar | `MinigameBase.storing()`, max 1 per minigame, nooit in eerste 5s |
| F6 Verificatie en docs | ⬜ Nog te doen | — |

#### Correcties uit de tweede schets (afgehandeld)

Uit een tweede, preciezere schets kwamen twee correcties naar boven op wat
F1-a al bouwde. **Beide zijn nu doorgevoerd**, details in `docs/LEVEL.md`:

1. **Trappenhuis + de ingang-hoek.** ✅ De voordeur stond op x0, y16–18 met een
   lege tegelrij (y15) tussen zichzelf en de zuidwand van het Patchhok; de
   schets tekent trappenhuis en ingang strak tegen elkaar, meteen onder het
   serverhok. De deur staat nu op **x0, y15–17** en sluit dus aan op y14. Het
   trappenhuis is terug als **decor op x0, y18–19**: geen kamer, maar twee
   tegels in de buitenwand zelf met een glazen pui waar je tegen de traptreden
   aan kijkt. Legenda-teken `X` is daarmee weer in gebruik. Het kost geen
   vloer, dus bereikbaarheid blijft 0 onbereikbaar.
2. **"Blauwe tijger."** ✅ De x klopte (x38, tussen koffiecorner en Summit), de
   y niet: op y4 zat hij achter de HUD, die de bovenste vijf à zes tegelrijen
   afdekt. Hij staat nu op **x38, y6** — dezelfde open ruimte, eerste rij die
   er helemaal onder vandaan komt. Het `blauwe_tijger`-object verhuisde mee
   van `[38, 5]` naar `[38, 7]`.
3. De bureau-eiland-indeling (8·4·4·4·4) is **bevestigd correct** zoals
   F1-a hem bouwde — geen actie nodig.

#### Afwijkingen t.o.v. de oorspronkelijke briefing (F0–F2)

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

#### Afwijkingen t.o.v. de oorspronkelijke briefing (F3)

- **Ticketverdeling.** Start open: t02 (daan), t03 (willem), t04 (victor),
  t05 (jonathan) — een west-cluster die toevallig ook meteen vier eigenaren
  bedient. De rest ontsluit via het bestaande `unlocks`-veld op tickets:
  t02→t09, t03→t08→t01, t04→t07, t05→t06. Danny (t06/t07), koen (t08) en
  bastiaan (t09) krijgen zo hun eigen werk in de eerste ontsluitingsgolf,
  daan heeft al t02 en krijgt t01 pas laat.
- **`_qa_playthrough()` (harnas, niet gameplay) moest twee keer mee-evolueren**,
  buiten de letterlijke briefing om: eerst omdat de vaste t01..t10-volgorde
  niet meer klopte (F3-a), toen omdat een heropend ticket (F3-c) een tweede
  keer opgepakt moest kunnen worden zonder de collega opnieuw te werven. De
  twee parallelle agents losten dit allebei zelf op met een verschillende
  structuur (inline while vs. `_qa_doe_ticket()`-helper); bij het samenvoegen
  is gekozen voor de laatste, want die dekt ook het heropening-geval.
- **F3-d deed geen ticket-herbalancering.** De ~30/45 minuten-kosten staan
  niet in `data/tickets/*.json` maar zijn `urenstaat.gd`-constanten; de klok
  (1 in-game minuut / 2,5 seconde) haalt op zichzelf al ruim boven de 8 uur
  bij elk personage, dus dubbel tellen bleek in de praktijk geen probleem.
  `_test_urenstaat()` bevestigt dit voor een gesimuleerde dag van 24 uur.
- Nieuw op `QuestEngine`: `reopen(id)` + effect-op `reopen_ticket`, nodig om
  "iets gaat stuk" (F3-c) een DONE-ticket terug naar AVAILABLE te zetten
  zonder ooit naar LOCKED terug te vallen.

#### Afwijkingen t.o.v. de oorspronkelijke briefing (F4)

- **BBD-203 werd geen letterlijk telefoongesprek.** De fictie (`t03_offer`)
  beschrijft de klant fysiek op de wachtbank met een mapje, niet aan de lijn —
  een telefoonscherm zou tegen de bestaande scène ingaan. Opgelost met
  hetzelfde bouwblok (`DialogueController.ask_choice()`) zonder de aparte
  `Telefoon`-laag erbij te halen.
- **`mg_uitlijnen`'s "slepen primair"** bleek al zo te werken — `_op_sleep()`
  snapte al continu naar het raster. Alleen de documentatie beschreef de
  dpad-knoppen nog als hoofdroute; de echte bug zat uitsluitend in de
  `afwijking`-data (zie F1-c-achtige bijvangst hierboven).
- **`mg_pijplijn`'s halvering**: de Review-stage (kostte nooit credits, voegde
  alleen een derde tik toe) en het losse voortgangstellertje zijn geschrapt.
  Het knelpunt blijft de Render-stage; Prompt → Render → Publish.
- **`mg_abtest`'s trait omgedraaid naar "spreiding"** (een bandbreedte i.p.v.
  het exacte effectgetal), niet naar "extra ronde" — de contentdata had geen
  ruimte voor een extra ronde zonder nieuwe leveldata.
- **`mg_urenstaat` werd een dialoogkeuze** (drie voorgestelde verdelingen),
  niet een schuifform — hergebruikt het bestaande keuzepatroon uit
  `mg_choicescene.gd`/`UiKit.keuzeknop()`.
- **F4-c's onderbreking bij 6 bestede handelingen** kreeg een eigen
  "OPGELET"-presentatie (rode rand, geluid, fade) in plaats van volledige
  koppeling met het generieke storingen-systeem — die koppeling hoort bij F5,
  waar de wereld sowieso niet meer pauzeert tijdens een minigame.
- De vier oude minigame-scenes (`mg_choicescene`, `mg_cableboard`,
  `mg_tagpicker`, `mg_whack`) zijn **niet verwijderd**, alleen niet meer
  aangeroepen voor hun tickets — opruimen was expliciet buiten scope.

### Auditronde (2–3 september 2026)

Na F5 is er een speelaudit gedaan met één vraag: is dit spel leuk,
begrijpelijk en samenhangend voor een casual speler, of ligt de oorspronkelijke
essentie begraven onder wat er sindsdien bovenop is gebouwd. Het rapport staat
in [`docs/AUDIT.md`](AUDIT.md), met de gerenderde frames in `docs/audit-shots/`
en de deelaudit van de questmotor in
[`docs/AUDIT-TICKETSTROOM.md`](AUDIT-TICKETSTROOM.md).

Uit die audit liepen zes werkstromen parallel, elk op een eigen branch. Alle
zes zijn gemerged in `main`.

| Werkstroom | Wat erin zit |
|---|---|
| Dialoogaudit | Getoetst aan de character bible; het dialoogvenster blijft binnen het scherm; De Klant is weer één persoon (schoonzus én neef, in de entree én op de telefoon); Dirks slotregel komt uit de data |
| Cast versus foto's | De `look`-velden gevalideerd tegen `assets/personen/` — Koen had een bril die hij niet heeft, Victor een koptelefoon die hij nooit draagt. Drie nieuwe laagvarianten (`fade`, `kuif`, `sik`) en een test die elke look-waarde tegen de sheets op schijf legt |
| Questmotor | Elf van twaalf bevindingen: de ticketketen wordt afgeleid uit `available_when` i.p.v. een `unlocks`-lijst, en een opgelost ticket zegt niet meer letterlijk "t01_done" |
| Collectielus | Zes bevindingen: de storing valt niet meer midden in een afronding, de wijzer stuurt je eerst naar wat je nog moet ophalen, en afsluiten bewaart de dag |
| Mobiel | Tikken op waar je voor staat i.p.v. een vaste actieknop, Koen weer bereikbaar in de personagekeuze, en geen toetsenbordverwijzingen op een aanraakscherm |
| Minigame-intro | Een wat/waarom/Starten-scherm vóór alle elf minigames, los van de personagestem. Slaat zichzelf over onder `--autoplay` |

Daarna nog één losse toevoeging: **De Klant klopt eerst.** Haar eerste
pushbericht kon koud binnenvallen, want `Gevolgen.DREMPELS` begint op 1 en `k1`
valt dus al bij één opgelost ticket — mogelijk vóór de speler ooit in de entree
is geweest waar zij staat. Nu komt haar melding in twee stappen: een
meldingsscherm met haar naam en één knop `Openen`, dan het bericht. Geen
sluitknop, en de `effects` draaien pas bij het openen — een bericht dat de
speler niet gelezen heeft mag de wereld niet veranderd hebben.

#### Wat de auditronde niet heeft opgelost

Dit staat hier expliciet, want het is bewust open gelaten en niet vergeten.

- **Mag een storing voortgang afpakken?** `storingen.gd` schrijft de invariant
  op: een storing kost tijd en informatie, *nooit* voortgang. Maar `reopen()`
  haalt het ticket uit `done_order`, en dat ís voortgang. De volgorde en de
  timing zijn gefixt, die regelbreuk niet. Dit is een ontwerpvraag en geen bug;
  hij hangt samen met de eenrichtingsvlag `alle_tickets_klaar` tegenover het
  tweerichtingsfeit `all_done()` — de voordeur leest live en gaat weer dicht,
  maar zes dialoogvarianten lezen de vlag en blijven beweren dat de dag klaar
  is.
- **Drie dingen die een headless suite niet kan zien** en die met eigen ogen
  gecontroleerd moeten worden: de mobiele balklayout, de personagekeuze-scroll
  en de tik-ring; de drie nieuwe laagvarianten (de test bewijst dat de sheet
  bestáát, niet dat het personage op de foto lijkt); en `_refresh_marker()`,
  dat de wijzer nu eerst naar een ontbrekend vereist item stuurt en dus een
  ander object kan aanwijzen dan voorheen.
- **Het QA-harnas vuurt interacties af zonder te wachten.** `_qa_doe_ticket()`
  roept `_interact_with()` aan zonder `await` en gaat daarna pollen, waarmee
  het langs het invoerslot gaat dat een speler wél tegenhoudt. Gevolg: op het
  BBD-203-pad worden drie geschreven dialoogregels in de doorloop stil
  overgeslagen, met een `push_error` erbij. Een speler kan dit niet uitlokken
  (`_unhandled_input()` stopt op `Session.input_locked`, en `handle()` heeft
  daarbovenop `_busy`), dus het is een tekortkoming van het harnas en geen
  regressie in het spel. Er staan drie zulke aanroepen in `main.gd`; de fix
  hoort daar.
- **`zone_entered` als trigger voor de backend-storing** zou eerlijker fictie
  zijn dan een wachttijd: je loopt langs het serverrack en het is weer stuk.
  Niet urgent — de wachttijd telt inmiddels verstreken minuten en kan daardoor
  niet meer in de afrondingsdialoog vallen.

#### Afwijkingen t.o.v. de oorspronkelijke briefing (F5)

- **Twee echte regressies gevonden en gefixt die de briefing niet noemde.**
  `Klok._process()` en `Telefoon._process()` stopten allebei op
  `Session.input_locked` — na F5-a staat die vlag óók aan tijdens een gewone
  minigame (dat is precies wat `Session.lock_input()` nu doet), dus zonder
  ingrijpen was de klok alsnog blijven stilstaan tijdens elke minigame en had
  F5-a zijn eigen doel gemist. Fix: `Klok` krijgt een expliciete
  `and not Shell.minigame_active()`-uitzondering (blijft tikken tijdens een
  minigame); `Telefoon` krijgt `Shell.minigame_active()` juist wél als expliciete
  extra voorwaarde (een melding mag een minigame nog steeds niet onderbreken) —
  eerst leunde dat toevallig op dezelfde vlag, nu staat het er met opzet.
- **`pauzeer_voor_menu()`'s `_active != null`-guard is nu onbereikbare
  achtervang** in plaats van actieve logica: `main.gd::_unhandled_input()`
  blokkeert het openen van het pauzemenu al zelf zolang
  `Shell.minigame_active()` waar is. Bewust laten staan, niet weggehaald.
- **De "storing tijdens een minigame"-verificatie kon niet als levende
  `--playthrough`-observatie**: elke minigame lost via `--autoplay` binnen
  ~0,45–5s op, vrijwel altijd onder de "nooit in de eerste 5 seconden"-gate.
  Gedekt met een deterministische unit-test die hetzelfde codepad
  (`Storingen._vuur_eenmalig()` → `MinigameBase.storing()`) op een echte,
  via `Shell.run_minigame()` gestarte minigame uitvoert.
- `npc_komt_langs`-storingen (een collega die blijft meelopen) routeren
  bewust **niet** naar `storing()` — dat is doorlopend gedrag, geen eenmalig
  bericht, en er is geen "hij bereikt je"-moment om aan te haken.

---

### Context

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

#### Vier richtinggevende besluiten (door jou gemaakt)

| Vraag | Besluit |
|---|---|
| Ticketaantal | **Tien blijven.** Vier ervan worden opgelost dóór in de wereld te handelen in plaats van in een puzzelscherm. Titel blijft kloppen, geen geschreven materiaal weg. |
| Chaos | **Volledig.** De wereld pauzeert niet meer; onderbrekingen landen tijdens je werk. |
| Klok | **Loopt echt.** Harde regel blijft: tijd blokkeert nooit iets en kan het spel nooit onwinbaar maken. |
| Visueel | **Volledige art-direction pass.** |

#### De centrale ingreep, in één regel

> **De inbox loopt vol.** Je begint met vier tickets, niet met negen. De rest
> komt binnen terwijl je werkt — van de klant, van een collega, doordat iets
> stuk gaat. Geen enkel ticket zit áchter een ander (vrije volgorde blijft
> intact), maar de stapel groeit, en dus is er eindelijk een "waarom nu".

Dat is wat de zes uitwisselbare middenboodschappen uit de audit verandert in
een dag die uit de hand loopt, en het kost bijna geen nieuwe code:
`unlock_ticket` bestaat en is getest.

---

### Wat onaangeraakt blijft

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

### Fasering

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

## F0 · Fundament & hygiëne

Geen ontwerprisico, alles onafhankelijk. Vier parallelle sub-agents.

#### F0-a · Save, laden en een pauzemenu

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

#### F0-b · De twee kapotte layouts, meteen

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

#### F0-c · Dode data en dode code opruimen

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

#### F0-d · Losse eindjes met eigen impact

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

## F1 · De vloer volgens de nieuwe schets

**Bron van waarheid:** `tools/generators/gen_floor.py`. `data/floor.json`
**nooit** met de hand bewerken — de volgende run draait het stil terug
(`docs/LEVEL.md:118`).

#### Wat de schets zegt en de huidige vloer niet doet

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

#### De vondst die het t08-anker gratis repareert

`gen_floor.py:258-271` heeft een `ACCENT_ROOMS`-regel op `(31, 8, 37, 9, 'I')`
met het commentaar `# "vergaderhokje"` — een **stale accent uit een oudere
layout**, want het hokje staat nu op x44–50. En precies op x31–36, y8–9 staan
`hokje_ipad`, `hokje_telefoon` en `samen_bingo_poster`.

De audit noemt dat een bug (§E: "het anker van t08 ligt niet in de zone die het
ontdekt"). De schets zegt dat het hokje daar *hoort*. Verplaats het hokje terug
naar x30–38, y8–11 en het anker, de zone en de accentvloer kloppen weer in één
zet — geen enkel object hoeft te verhuizen.

#### Doelindeling

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

#### F1-a · Herteken de vloer

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

#### F1-b · 40% van de vloer belonen

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

#### F1-c · Prop-art en diepte

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

## F2 · Visueel systeem

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

#### F2-a · Typografische hiërarchie

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

#### F2-b · Eén primaire knopstijl

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

#### F2-c · De vijf leesbaarheidsingrepen uit de audit

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

#### F2-d · Navigatie: de kompasstrip

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

#### F2-e · Minigames in de shell-look

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

## F3 · De dag aanzetten

**Status: ✅ Klaar. Alle vier substappen gemerged, testsuite groen (17.215
controles, 0 fout).**

Dit is de fase die de audit "de kernlus" noemt.

#### F3-a · De inbox loopt vol

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

#### F3-b · De klant kan de middag laten ontsporen

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

#### F3-c · Storingen: het kantoor wil iets van je

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

#### F3-d · De klok gaat lopen

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

## F4 · Tien tickets, zes puzzelschermen

**Status: ✅ Klaar. Alle vier substappen gemerged, testsuite groen (17.463
controles, 0 fout).**

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

#### F4-a · Blijft een volwaardig scherm (6)

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

#### F4-b · Wordt een wereldhandeling (4)

| Ticket | Nu | Wordt |
|---|---|---|
| BBD-203 De klant heeft feedback | `mg_choicescene` — een quiz waarvan het 3-puntsantwoord in alle drie de rondes **de eerste knop** is, en in alle drie de "stel een verduidelijkende vraag"-optie | **Een gesprek op de telefoon.** Zij bestaat al als telefoonscherm; maak dat scherm één keer tweerichtings. `DialogueBox.show_choices()` bestaat, `Telefoon` heeft al een eigen laag. Dit is het beste kanaal in het spel en het wordt eindelijk interactief. |
| BBD-205 De backend is stuk | `mg_cableboard` — één juist antwoord dat in de intro staat | **Een handeling bij het serverrack in het Patchhok.** Jonathans briefing geeft de aanwijzing, de dialoogkeuze is de handeling, `set_modulate` (na F0-d echt werkend) is het gevolg. |
| BBD-207 We hebben muziek nodig | `mg_tagpicker` — kapot gerenderd; de keuze is "ontwijk vijf grappen" | **Een dialoogkeuze van drie bij de speaker in de koffiecorner.** De grap blijft, het scherm verdwijnt. |
| BBD-209 Paardenbugs | `mg_whack` — slechtste fictie-fit (1/5), kapot gerenderd, nul gevolg | **De paarden lopen door het kantoor.** Als wereldobjecten die dwalen — ook in het toilet, de gang en Weekend, de 40% van de vloer die nu niets beloont. Je spreekt ze aan. `paard_bug.png` en `paard_klant.png` bestaan al, `spawn_npc`/`despawn_npc` bestaan al, en het klantpaard-dat-op-een-bug-lijkt blijft de grap. |

**Randvoorwaarde:** deze vier tickets moeten nog steeds een *werkwoord* hebben
dat uit hun eigenaar komt, en nog steeds in `Gevolgen` landen (F4-d). Een
wereldhandeling is geen degradatie — het is de vorm die de fictie al had.

#### F4-c · Druk op de finale

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

#### F4-d · Elk gevolg landt

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

## F5 · De wereld gaat van pause af

**Status: ✅ Klaar. `Shell.run_minigame()` gebruikt `Session.lock_input()`,
storingen landen in de minigame-chrome, testsuite groen (17.489 controles,
0 fout).**

De zwaarste ingreep en de enige die de kernervaring echt verandert.

**Waarom:** `Shell.run_minigame()` zet `get_tree().paused = true`
(`shell.gd:190`), dus het kantoor is stil op precies de momenten dat de speler
werkt. De goede chaos die de opdracht beschrijft — een collega onderbreekt, een
ticket verandert, iets anders gaat stuk *terwijl* je bezig bent — is met een
pauzemodel structureel onmogelijk.

#### F5-a · Ontkoppel "de speler kan niet lopen" van "de wereld staat stil"

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

#### F5-b · Storingen landen in de minigame

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

## F6 · Verificatie en docs

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

### Expliciet niet doen

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

### Orkestratie

Ik voer dit niet zelf uit — per stap gaat er een sub-agent op af met de
bovenstaande sectie als briefing, plus de codemap-feiten die erbij horen.

| Stap | Sub-agent | Uitgevoerd als | Status |
|---|---|---|---|
| F0-a t/m F0-d | 4 agents, parallel | 4 agents, parallel (git worktrees) | ✅ Alle vier gemerged |
| F1-a | 1 agent (vloergenerator) | 1 agent | ✅ Gemerged (met openstaand correctiepunt, zie boven) |
| F1-b, F1-c | 2 agents, ná F1-a | F1-b geen aparte agent (zie F1-b); F1-c 1 agent | 🟡 F1-c ✅, F1-b ⬜ |
| F2-a t/m F2-e | 3 agents | 3 waves: (F2-a+F2-b samen), (F2-c+F2-d samen), F2-e apart, telkens 1 agent | ✅ Alle vijf gemerged |
| F3-a, F3-b | 1 agent (data + telefoon) | 1 agent, parallel met F3-c/d | ✅ Gemerged |
| F3-c, F3-d | 1 agent (storingen + klok) | 1 agent, parallel met F3-a/b | ✅ Gemerged (1 conflict in `main.gd`, handmatig) |
| F4-a | 1 agent per minigame, max 3 tegelijk | 2 golven van 3, parallel met F4-b in golf 1 | ✅ Gemerged (6 minigames) |
| F4-b | 1 agent (vier wereldhandelingen) | 1 agent, parallel met golf 1 van F4-a | ✅ Gemerged |
| F4-c, F4-d | 1 agent | 1 agent, ná alle F4-a/F4-b-merges | ✅ Gemerged |
| F5 | 1 agent, seriëel — dit raakt Shell | 1 agent, seriëel, zoals gepland | ✅ Gemerged |
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
